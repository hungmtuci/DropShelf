import Foundation
import AppKit
import CoreServices
import Darwin

@MainActor
final class ScreenshotMonitorService: ObservableObject {
    static let shared = ScreenshotMonitorService()

    @Published private(set) var watchedDirectories: [String] = []

    private var fsEventStream: FSEventStreamRef?
    private let fsEventQueue = DispatchQueue(label: "com.hunglx.DropShelf.ScreenshotFSEvents", qos: .userInteractive)
    private var clipboardPollTimer: Timer?
    private var folderConfigRefreshTimer: Timer?
    private var lastObservedClipboardChangeCount: Int
    private var recentlyIngestedTimestamps: [String: TimeInterval] = [:]

    var primaryWatchedFolderDisplay: String {
        guard let first = watchedDirectories.first else { return "~/Desktop" }
        return (first as NSString).abbreviatingWithTildeInPath
    }

    private init() {
        self.lastObservedClipboardChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        syncMonitoringState()
    }

    func stop() {
        stopFSEventStream()
        clipboardPollTimer?.invalidate()
        clipboardPollTimer = nil
        folderConfigRefreshTimer?.invalidate()
        folderConfigRefreshTimer = nil
    }

    func syncMonitoringState() {
        applyMacOSInstantScreenshotPreference()

        guard AppSettings.shared.autoCaptureScreenshots else {
            stop()
            return
        }

        let targetDirs = Self.resolveScreenshotDirectories()
        if targetDirs != watchedDirectories || fsEventStream == nil {
            watchedDirectories = targetDirs
            restartFSEventStream(for: targetDirs)
        }

        if AppSettings.shared.autoCaptureClipboardScreenshots {
            startClipboardPollingIfNeeded()
        } else {
            clipboardPollTimer?.invalidate()
            clipboardPollTimer = nil
        }

        if folderConfigRefreshTimer == nil {
            folderConfigRefreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, AppSettings.shared.autoCaptureScreenshots else { return }
                    let updated = Self.resolveScreenshotDirectories()
                    if updated != self.watchedDirectories {
                        self.watchedDirectories = updated
                        self.restartFSEventStream(for: updated)
                    }
                }
            }
        }
    }

    func markInternalClipboardWrite() {
        lastObservedClipboardChangeCount = NSPasteboard.general.changeCount
    }

    /// Ensures `screencaptureui` (`⌘⇧3` Full Screen, `⌘⇧4` Window/Portion, `⌘⇧5` Toolbar) writes files immediately (`0ms`)
    /// instead of holding them in RAM inside `AnnotationsThumbWindow` at the bottom-right corner for 5–6 seconds!
    func applyMacOSInstantScreenshotPreference() {
        let shouldDisableMacOSDelay = AppSettings.shared.autoCaptureScreenshots && AppSettings.shared.instantScreenshotCapture
        let desiredShowThumbnail = !shouldDisableMacOSDelay
        let currentShowThumbnail = Self.readMacOSShowThumbnailFlag()
        guard currentShowThumbnail != desiredShowThumbnail else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            CFPreferencesSetAppValue(
                "show-thumbnail" as CFString,
                desiredShowThumbnail ? kCFBooleanTrue : kCFBooleanFalse,
                "com.apple.screencapture" as CFString
            )
            CFPreferencesAppSynchronize("com.apple.screencapture" as CFString)

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            proc.arguments = ["write", "com.apple.screencapture", "show-thumbnail", "-bool", desiredShowThumbnail ? "true" : "false"]
            try? proc.run()
            proc.waitUntilExit()

            // Terminate any idle lingering screencaptureui instance so the next screenshot uses the new flag immediately
            let killProc = Process()
            killProc.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killProc.arguments = ["screencaptureui"]
            killProc.standardError = FileHandle.nullDevice
            try? killProc.run()
            killProc.waitUntilExit()
        }
    }

    // MARK: - FSEvents File-Level Screenshot Watcher (20ms latency, 0% idle CPU)

    private func restartFSEventStream(for directories: [String]) {
        stopFSEventStream()
        guard !directories.isEmpty else { return }

        let callback: FSEventStreamCallback = { _, _, numEvents, eventPaths, _, _ in
            guard numEvents > 0 else { return }
            let cfArray = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
            guard let paths = cfArray as? [String], !paths.isEmpty else { return }

            let uniquePaths = Array(Set(paths))
            Task { @MainActor in
                for path in uniquePaths {
                    ScreenshotMonitorService.shared.evaluateCandidateFilePath(path, retryCount: 0)
                }
            }
        }

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes
            | kFSEventStreamCreateFlagFileEvents
            | kFSEventStreamCreateFlagNoDefer
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            nil,
            directories as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.02,
            flags
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, fsEventQueue)
        FSEventStreamStart(stream)
        self.fsEventStream = stream
    }

    private func stopFSEventStream() {
        guard let stream = fsEventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        fsEventStream = nil
    }

    private func evaluateCandidateFilePath(_ rawPath: String, retryCount: Int) {
        guard AppSettings.shared.autoCaptureScreenshots else { return }
        let url = URL(fileURLWithPath: rawPath).standardizedFileURL
        let fileName = url.lastPathComponent

        guard !fileName.hasPrefix(".") else { return }

        let ext = url.pathExtension.lowercased()
        let supportedExts: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "webp", "pdf", "mov", "mp4"]
        guard supportedExts.contains(ext) else { return }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            return
        }

        let now = Date()
        let nowUptime = ProcessInfo.processInfo.systemUptime

        recentlyIngestedTimestamps = recentlyIngestedTimestamps.filter { (nowUptime - $0.value) < 60.0 }
        guard recentlyIngestedTimestamps[url.path] == nil else { return }

        guard let resourceValues = try? url.resourceValues(
            forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey]
        ) else {
            return
        }

        let fileSize = resourceValues.fileSize ?? 0
        if fileSize == 0 {
            if retryCount < 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                    self?.evaluateCandidateFilePath(rawPath, retryCount: retryCount + 1)
                }
            }
            return
        }

        let refDate = resourceValues.creationDate ?? resourceValues.contentModificationDate ?? .distantPast
        guard abs(now.timeIntervalSince(refDate)) <= 20.0 else { return }

        guard Self.isVerifiedScreenshotFile(url: url, fileName: fileName) else { return }

        recentlyIngestedTimestamps[url.path] = nowUptime
        ShelfStore.shared.addCapturedScreenshotFile(url)
    }

    nonisolated private static func isVerifiedScreenshotFile(url: URL, fileName: String) -> Bool {
        if getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) >= 0 {
            return true
        }

        let lower = fileName.lowercased()
        let knownPrefixes = [
            "screen shot",
            "screenshot",
            "ảnh màn hình",
            "ảnh chụp màn hình",
            "cleanshot",
            "shottr",
            "snipaste",
            "screen recording",
            "ghi màn hình"
        ]
        if knownPrefixes.contains(where: { lower.hasPrefix($0) }) {
            return true
        }

        return false
    }

    // MARK: - Clipboard Screenshot Watcher (Cmd+Ctrl+Shift+3 / Cmd+Ctrl+Shift+4)

    private func startClipboardPollingIfNeeded() {
        guard clipboardPollTimer == nil else { return }
        lastObservedClipboardChangeCount = NSPasteboard.general.changeCount

        clipboardPollTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkClipboardForNewScreenshot()
            }
        }
    }

    private func checkClipboardForNewScreenshot() {
        guard AppSettings.shared.autoCaptureScreenshots,
              AppSettings.shared.autoCaptureClipboardScreenshots else {
            lastObservedClipboardChangeCount = NSPasteboard.general.changeCount
            return
        }

        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        guard currentCount != lastObservedClipboardChangeCount else { return }
        lastObservedClipboardChangeCount = currentCount

        guard let types = pb.types, !types.isEmpty else { return }

        let hasImageBitmap = types.contains(.png) || types.contains(.tiff)
        guard hasImageBitmap else { return }

        let excludedTypes: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .string,
            .rtf,
            .rtfd,
            .html,
            .URL,
            NSPasteboard.PasteboardType("public.url"),
            NSPasteboard.PasteboardType("org.chromium.source-url"),
            NSPasteboard.PasteboardType("Apple Web Archive pasteboard type"),
            NSPasteboard.PasteboardType("com.apple.safari.bookmark")
        ]
        for excluded in excludedTypes where types.contains(excluded) {
            return
        }

        if let image = NSImage(pasteboard: pb), image.size.width >= 16, image.size.height >= 16 {
            ShelfStore.shared.addClipboardScreenshotImage(image)
        }
    }

    // MARK: - Screenshot Directory Discovery

    nonisolated static func resolveScreenshotDirectories() -> [String] {
        var candidates: [String] = []

        if let scDefaults = UserDefaults(suiteName: "com.apple.screencapture") {
            let keys = ["location-screenshot", "location", "location-screenrecording"]
            for key in keys {
                if let raw = scDefaults.string(forKey: key), !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let expanded = (raw as NSString).expandingTildeInPath
                    let std = URL(fileURLWithPath: expanded).standardizedFileURL.path
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: std, isDirectory: &isDir), isDir.boolValue {
                        candidates.append(std)
                    }
                }
            }
        }

        let desktopPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop", isDirectory: true)
            .standardizedFileURL.path
        var isDesktopDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: desktopPath, isDirectory: &isDesktopDir), isDesktopDir.boolValue {
            candidates.append(desktopPath)
        }

        var unique: [String] = []
        var seen = Set<String>()
        for path in candidates where seen.insert(path).inserted {
            unique.append(path)
        }
        return unique
    }

    nonisolated static func readMacOSShowThumbnailFlag() -> Bool {
        CFPreferencesAppSynchronize("com.apple.screencapture" as CFString)
        if let scDefaults = UserDefaults(suiteName: "com.apple.screencapture"),
           scDefaults.object(forKey: "show-thumbnail") != nil {
            return scDefaults.bool(forKey: "show-thumbnail")
        }
        return true
    }
}
