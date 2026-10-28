import Foundation
import AppKit
import CoreServices
import Darwin

@MainActor
final class ScreenshotMonitorService: ObservableObject {
    static let shared = ScreenshotMonitorService()

    @Published private(set) var watchedDirectories: [String] = []
    @Published private(set) var isMacOSFloatingThumbnailEnabled: Bool = true

    private var fsEventStream: FSEventStreamRef?
    private let fsEventQueue = DispatchQueue(label: "com.hunglx.DropShelf.ScreenshotFSEvents", qos: .userInitiated)
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
        self.isMacOSFloatingThumbnailEnabled = Self.readMacOSShowThumbnailFlag()
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
        isMacOSFloatingThumbnailEnabled = Self.readMacOSShowThumbnailFlag()

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
                    self.isMacOSFloatingThumbnailEnabled = Self.readMacOSShowThumbnailFlag()
                }
            }
        }
    }

    /// Called by ShelfStore whenever DropShelf itself writes to `NSPasteboard.general`
    /// so we never treat our own copy action as a new Clipboard Screenshot.
    func markInternalClipboardWrite() {
        lastObservedClipboardChangeCount = NSPasteboard.general.changeCount
    }

    /// Optional convenience helper allowing the user to toggle macOS's 5-second Floating Thumbnail delay (`show-thumbnail`).
    func setMacOSFloatingThumbnailEnabled(_ enabled: Bool) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        proc.arguments = ["write", "com.apple.screencapture", "show-thumbnail", "-bool", enabled ? "true" : "false"]
        try? proc.run()
        proc.waitUntilExit()
        isMacOSFloatingThumbnailEnabled = Self.readMacOSShowThumbnailFlag()
        AppSettings.shared.statusBannerMessage = enabled
            ? "Đã bật lại ảnh thu nhỏ góc dưới của macOS (ảnh vào kệ sau ~4s)."
            : "Đã tắt chờ ảnh thu nhỏ macOS — ảnh chụp màn hình mới sẽ nhảy vào Kệ tức thì (0 giây)!"
    }

    // MARK: - FSEvents File-Level Screenshot Watcher (0% CPU, O(1) even in folders with 10,000+ files)

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
            0.08,
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

        // Ignore hidden dotfiles (.Screen Shot...) while macOS Floating Thumbnail is still open
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

        // Prune dedup table older than 60s
        recentlyIngestedTimestamps = recentlyIngestedTimestamps.filter { (nowUptime - $0.value) < 60.0 }
        guard recentlyIngestedTimestamps[url.path] == nil else { return }

        guard let resourceValues = try? url.resourceValues(
            forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey]
        ) else {
            return
        }

        let fileSize = resourceValues.fileSize ?? 0
        if fileSize == 0 {
            // File may still be flushing right after creation; retry briefly once
            if retryCount < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                    self?.evaluateCandidateFilePath(rawPath, retryCount: retryCount + 1)
                }
            }
            return
        }

        // Only capture freshly created/saved screenshots (within last 20 seconds)
        let refDate = resourceValues.creationDate ?? resourceValues.contentModificationDate ?? .distantPast
        guard abs(now.timeIntervalSince(refDate)) <= 20.0 else { return }

        guard Self.isVerifiedScreenshotFile(url: url, fileName: fileName) else { return }

        recentlyIngestedTimestamps[url.path] = nowUptime
        ShelfStore.shared.addCapturedScreenshotFile(url)
    }

    nonisolated private static func isVerifiedScreenshotFile(url: URL, fileName: String) -> Bool {
        // 1. Primary native macOS check: extended attribute `com.apple.metadata:kMDItemIsScreenCapture`
        if getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) >= 0 {
            return true
        }

        // 2. Third-party screenshot tools (CleanShot X, Shottr, Snipaste, Monosnap) or localized names
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

        clipboardPollTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
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

        // A Clipboard Screenshot (`screencapture -c` / Cmd+Ctrl+Shift+4) puts pure bitmap image data
        // WITHOUT file URLs, plain text, HTML, RTF, or browser source URLs.
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

        // Always include ~/Desktop as fallback in case system defaults reset
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
        if let scDefaults = UserDefaults(suiteName: "com.apple.screencapture"),
           scDefaults.object(forKey: "show-thumbnail") != nil {
            return scDefaults.bool(forKey: "show-thumbnail")
        }
        return true
    }
}
