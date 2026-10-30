import Foundation
import AppKit

/// Checks `hungmtuci/DropShelf` GitHub Releases and performs 1-click download, atomic installation,
/// Gatekeeper quarantine removal (`xattr -cr`), and seamless app relaunch.
@MainActor
final class UpdateCheckerService: ObservableObject {
    static let shared = UpdateCheckerService()

    enum UpdateState: Equatable {
        case idle
        case checking
        case upToDate(version: String)
        case available(version: String, zipURL: URL?, releasePageURL: URL, releaseNotes: String?)
        case downloading(version: String)
        case installing(version: String)
        case failed(message: String)
    }

    private struct GitHubReleaseResponse: Decodable, Sendable {
        let tag_name: String
        let html_url: String
        let body: String?
        let assets: [GitHubAsset]
    }

    private struct GitHubAsset: Decodable, Sendable {
        let name: String
        let browser_download_url: String
    }

    @Published private(set) var state: UpdateState = .idle {
        didSet {
            StatusBarController.shared.refreshBadge()
        }
    }
    @Published private(set) var shelfBadgeFeedback: String? = nil
    @Published private(set) var isShelfFeedbackPositive: Bool = true
    @Published private(set) var latestRemoteVersion: String? = nil
    @Published private(set) var latestRemoteZipURL: URL? = nil
    @Published private(set) var lastCheckedDate: Date? = nil

    private var feedbackResetWorkItem: DispatchWorkItem?
    private var periodicCheckTimer: Timer?

    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.5.0"
    }

    var availableVersion: String? {
        if case let .available(version, _, _, _) = state {
            return version
        }
        return nil
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .installing:
            return true
        default:
            return false
        }
    }

    private var lastAutoCheckTimestamp: CFAbsoluteTime = 0
    private let latestReleaseAPIBase = "https://api.github.com/repos/hungmtuci/DropShelf/releases/latest"
    private let releasesPageFallback = URL(string: "https://github.com/hungmtuci/DropShelf/releases/latest")!

    private init() {}

    func checkSilentlyOnLaunchIfNeeded() {
        startPeriodicBackgroundCheckIfNeeded()
        let now = CFAbsoluteTimeGetCurrent()
        guard (now - lastAutoCheckTimestamp) >= 14_400 else { return }
        lastAutoCheckTimestamp = now
        Task { @MainActor in
            await performCheck(manual: false, autoInstallIfNewer: false, forceReinstall: false)
        }
    }

    private func startPeriodicBackgroundCheckIfNeeded() {
        guard periodicCheckTimer == nil else { return }
        periodicCheckTimer = Timer.scheduledTimer(withTimeInterval: 14_400, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performCheck(manual: false, autoInstallIfNewer: false, forceReinstall: false)
            }
        }
    }

    /// 1-click GitHub Update:
    /// - If an update is already known to be available -> immediately downloads & installs it.
    /// - Otherwise queries GitHub Releases -> if a newer version exists, immediately downloads, installs & relaunches;
    ///   if already on the latest version, displays instant confirmation.
    func oneClickUpdateFromGitHub() {
        guard !isBusy else { return }

        if case .available = state {
            installAvailableUpdate()
            return
        }

        Task { @MainActor in
            await performCheck(manual: true, autoInstallIfNewer: true, forceReinstall: false)
        }
    }

    /// Checks GitHub Releases without auto-installing (updates status state).
    func checkForUpdatesManually() {
        guard !isBusy else { return }
        Task { @MainActor in
            await performCheck(manual: true, autoInstallIfNewer: false, forceReinstall: false)
        }
    }

    /// Forces pulling and reinstalling the latest release `.zip` from GitHub even if version numbers match.
    func reinstallLatestFromGitHub() {
        guard !isBusy else { return }
        Task { @MainActor in
            await performCheck(manual: true, autoInstallIfNewer: true, forceReinstall: true)
        }
    }

    private func setTransientShelfFeedback(_ message: String, positive: Bool, duration: TimeInterval = 4.5) {
        feedbackResetWorkItem?.cancel()
        isShelfFeedbackPositive = positive
        shelfBadgeFeedback = message
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.shelfBadgeFeedback = nil
            }
        }
        feedbackResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func performCheck(manual: Bool, autoInstallIfNewer: Bool, forceReinstall: Bool) async {
        guard !isBusy else { return }

        if manual {
            feedbackResetWorkItem?.cancel()
            shelfBadgeFeedback = nil
            state = .checking
        }

        let cacheBuster = Int(Date().timeIntervalSince1970)
        let requestURL = URL(string: "\(latestReleaseAPIBase)?t=\(cacheBuster)") ?? URL(string: latestReleaseAPIBase)!

        var req = URLRequest(url: requestURL)
        req.timeoutInterval = 15
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("DropShelf/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                if manual {
                    let msg = "Không kết nối được GitHub Releases. Vui lòng kiểm tra mạng và thử lại."
                    state = .failed(message: msg)
                    setTransientShelfFeedback("Lỗi kết nối GitHub", positive: false)
                }
                return
            }

            let decoded = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
            let remoteVersion = Self.cleanVersionString(decoded.tag_name)
            let pageURL = URL(string: decoded.html_url) ?? releasesPageFallback

            let zipAssetURL: URL? = decoded.assets
                .first(where: { $0.name.lowercased().hasSuffix(".zip") })
                .flatMap { URL(string: $0.browser_download_url) }

            latestRemoteVersion = remoteVersion
            latestRemoteZipURL = zipAssetURL
            lastCheckedDate = Date()

            let localVer = currentVersion
            let isNewer = Self.isVersion(remoteVersion, newerThan: localVer)

            if isNewer || forceReinstall {
                state = .available(
                    version: remoteVersion,
                    zipURL: zipAssetURL,
                    releasePageURL: pageURL,
                    releaseNotes: decoded.body
                )
                if autoInstallIfNewer {
                    downloadAndInstall(version: remoteVersion, zipURL: zipAssetURL, releasePageURL: pageURL)
                }
            } else {
                state = .upToDate(version: localVer)
                if manual {
                    setTransientShelfFeedback("Đã mới nhất v\(localVer)", positive: true)
                }
            }
        } catch {
            if manual {
                let msg = "Không thể kiểm tra cập nhật từ GitHub (\(error.localizedDescription))."
                state = .failed(message: msg)
                setTransientShelfFeedback("Lỗi kiểm tra GitHub", positive: false)
            }
        }
    }

    func installAvailableUpdate() {
        guard case let .available(version, zipURL, releasePageURL, _) = state else { return }
        downloadAndInstall(version: version, zipURL: zipURL, releasePageURL: releasePageURL)
    }

    private func downloadAndInstall(version: String, zipURL: URL?, releasePageURL: URL) {
        guard let downloadURL = zipURL else {
            NSWorkspace.shared.open(releasePageURL)
            return
        }

        feedbackResetWorkItem?.cancel()
        shelfBadgeFeedback = nil
        state = .downloading(version: version)

        Task { @MainActor in
            let stageDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("DropShelfAutoUpdate-\(UUID().uuidString)", isDirectory: true)
            let zipDest = stageDir.appendingPathComponent("DropShelf-update.zip")
            let extractDir = stageDir.appendingPathComponent("extracted", isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

                var req = URLRequest(url: downloadURL)
                req.timeoutInterval = 90
                req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                req.setValue("DropShelf/\(currentVersion)", forHTTPHeaderField: "User-Agent")

                let (tempDownloadedURL, response) = try await URLSession.shared.download(for: req)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    throw NSError(domain: "DropShelfUpdate", code: http.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "Mã phản hồi HTTP \(http.statusCode)"
                    ])
                }

                if FileManager.default.fileExists(atPath: zipDest.path) {
                    try? FileManager.default.removeItem(at: zipDest)
                }
                try FileManager.default.moveItem(at: tempDownloadedURL, to: zipDest)

                state = .installing(version: version)

                let extractedAppURL = try await Self.extractAndValidateZipOffMain(
                    zipPath: zipDest.path,
                    extractDirPath: extractDir.path
                )

                let targetAppPath: String = {
                    let appsDir = "/Applications"
                    if Bundle.main.bundlePath.hasPrefix("/Applications/") || FileManager.default.isWritableFile(atPath: appsDir) {
                        return "/Applications/DropShelf.app"
                    }
                    return Bundle.main.bundlePath
                }()

                ShelfStore.shared.saveShelfIfNeeded()
                let currentPID = ProcessInfo.processInfo.processIdentifier
                try Self.spawnDetachedSwapAndRelaunch(
                    oldPID: currentPID,
                    extractedAppPath: extractedAppURL.path,
                    targetAppPath: targetAppPath,
                    stageDirPath: stageDir.path
                )

                NSApp.terminate(nil)
            } catch {
                try? FileManager.default.removeItem(at: stageDir)
                let msg = "Cập nhật tự động thất bại: \(error.localizedDescription) — đang mở trang tải GitHub..."
                state = .failed(message: msg)
                setTransientShelfFeedback("Lỗi tải bản mới", positive: false)
                NSWorkspace.shared.open(releasePageURL)
            }
        }
    }

    // MARK: - Helpers

    nonisolated private static func extractAndValidateZipOffMain(
        zipPath: String,
        extractDirPath: String
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                proc.arguments = ["-x", "-k", zipPath, extractDirPath]
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    guard proc.terminationStatus == 0 else {
                        throw NSError(domain: "DropShelfUpdate", code: Int(proc.terminationStatus), userInfo: [
                            NSLocalizedDescriptionKey: "Giải nén gói cập nhật thất bại (mã \(proc.terminationStatus))"
                        ])
                    }

                    let candidateApp = URL(fileURLWithPath: extractDirPath).appendingPathComponent("DropShelf.app")
                    let binaryPath = candidateApp.appendingPathComponent("Contents/MacOS/DropShelf").path
                    guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
                        throw NSError(domain: "DropShelfUpdate", code: -2, userInfo: [
                            NSLocalizedDescriptionKey: "Không tìm thấy DropShelf.app hợp lệ trong gói tải về"
                        ])
                    }
                    continuation.resume(returning: candidateApp)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    nonisolated private static func spawnDetachedSwapAndRelaunch(
        oldPID: pid_t,
        extractedAppPath: String,
        targetAppPath: String,
        stageDirPath: String
    ) throws {
        let script = """
        OLD_PID="$1"
        SRC_APP="$2"
        DST_APP="$3"
        STAGE_DIR="$4"
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
            kill -0 "$OLD_PID" 2>/dev/null || break
            sleep 0.2
        done
        rm -rf "$DST_APP"
        /usr/bin/ditto --noextattr "$SRC_APP" "$DST_APP"
        /usr/bin/xattr -cr "$DST_APP" 2>/dev/null || true
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DST_APP" 2>/dev/null || true
        /usr/bin/open "$DST_APP"
        rm -rf "$STAGE_DIR"
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        proc.arguments = [
            "/bin/sh",
            "-c",
            script,
            "dropshelf-updater",
            "\(oldPID)",
            extractedAppPath,
            targetAppPath,
            stageDirPath
        ]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
    }

    nonisolated private static func cleanVersionString(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix("v") || s.hasPrefix("V") {
            s.removeFirst()
        }
        return s
    }

    nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = cleanVersionString(candidate).split(separator: ".").map { Int($0) ?? 0 }
        let rhs = cleanVersionString(current).split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lhs.count, rhs.count)
        for i in 0..<count {
            let a = i < lhs.count ? lhs[i] : 0
            let b = i < rhs.count ? rhs[i] : 0
            if a != b {
                return a > b
            }
        }
        return false
    }
}
