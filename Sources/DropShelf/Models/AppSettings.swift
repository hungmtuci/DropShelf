import Foundation
import AppKit
import Carbon
import ServiceManagement

enum ShelfEdgePosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case rightTop = "right_top"
    case rightCenter = "right_center"
    case rightBottom = "right_bottom"
    case leftTop = "left_top"
    case leftCenter = "left_center"
    case leftBottom = "left_bottom"
    case freeFloating = "free_floating"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rightTop: return "Cạnh phải — Trên"
        case .rightCenter: return "Cạnh phải — Giữa"
        case .rightBottom: return "Cạnh phải — Dưới"
        case .leftTop: return "Cạnh trái — Trên"
        case .leftCenter: return "Cạnh trái — Giữa"
        case .leftBottom: return "Cạnh trái — Dưới"
        case .freeFloating: return "Tự do (Kéo vị trí bất kỳ)"
        }
    }

    var isLeftEdge: Bool {
        switch self {
        case .leftTop, .leftCenter, .leftBottom:
            return true
        default:
            return false
        }
    }

    var isRightEdge: Bool {
        switch self {
        case .rightTop, .rightCenter, .rightBottom:
            return true
        default:
            return false
        }
    }
}

enum AutoShowTrigger: String, Codable, CaseIterable, Identifiable, Sendable {
    case immediateOnDrag = "immediate"
    case edgeOrShake = "edge_or_shake"
    case manualOnly = "manual"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .immediateOnDrag:
            return "Hiện ngay khi bắt đầu kéo tệp / nội dung (Chuẩn Yoink)"
        case .edgeOrShake:
            return "Hiện khi kéo tới sát mép màn hình hoặc lắc chuột"
        case .manualOnly:
            return "Chỉ mở thủ công bằng phím tắt / Menu Bar"
        }
    }

    var shortNote: String {
        switch self {
        case .immediateOnDrag:
            return "Tự động trượt ra mỗi khi phát hiện thao tác kéo thực sự và tự đóng nếu bạn không thả vào kệ."
        case .edgeOrShake:
            return "Giữ màn hình thoáng tối đa — chỉ trượt ra khi rê tệp lại gần cạnh kệ hoặc lắc nhẹ con trỏ chuột."
        case .manualOnly:
            return "Không tự bật khi kéo chuột; mở kệ bằng phím tắt toàn cục hoặc bấm icon trên Menu Bar."
        }
    }
}

enum DragOutBehavior: String, Codable, CaseIterable, Identifiable, Sendable {
    case moveLikeFinder = "move_finder"
    case copyByDefault = "copy_default"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moveLikeFinder:
            return "Di chuyển như Finder / Yoink (Giữ ⌥ Option để Sao chép)"
        case .copyByDefault:
            return "Sao chép an toàn mặc định (Giữ ⌘ Command để Di chuyển)"
        }
    }
}

enum ShelfSizePreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case compact = "compact"
    case standard = "standard"
    case large = "large"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: return "Nhỏ gọn"
        case .standard: return "Tiêu chuẩn"
        case .large: return "Rộng rãi"
        }
    }

    var panelWidth: CGFloat {
        switch self {
        case .compact: return 228
        case .standard: return 266
        case .large: return 312
        }
    }

    var cardHeight: CGFloat {
        switch self {
        case .compact: return 56
        case .standard: return 64
        case .large: return 72
        }
    }
}

struct HotKeyBinding: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    /// Default: `Ctrl + Y` (`⌃Y`) — inspired by Yoink, avoids conflicting with `⌘⇧D` (QuickFolder) & `⌃B` (BarFlow).
    static let defaultToggle = HotKeyBinding(
        keyCode: UInt32(kVK_ANSI_Y),
        carbonModifiers: UInt32(controlKey)
    )

    static let f5Preset = HotKeyBinding(
        keyCode: UInt32(kVK_F5),
        carbonModifiers: 0
    )

    static let optSpacePreset = HotKeyBinding(
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(optionKey)
    )

    var readableDisplay: String {
        var parts: [String] = []
        if (carbonModifiers & UInt32(controlKey)) != 0 { parts.append("⌃") }
        if (carbonModifiers & UInt32(optionKey)) != 0 { parts.append("⌥") }
        if (carbonModifiers & UInt32(shiftKey)) != 0 { parts.append("⇧") }
        if (carbonModifiers & UInt32(cmdKey)) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: "")
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_ANSI_Grave: return "`"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return "Key\(keyCode)"
        }
    }
}

private struct PersistedSettingsPayload: Codable, Sendable {
    var initialized: Bool = true
    var showInDock: Bool = true
    var openSettingsOnLaunch: Bool = true
    var edgePosition: ShelfEdgePosition = .rightCenter
    var autoShowTrigger: AutoShowTrigger = .immediateOnDrag
    var dragOutBehavior: DragOutBehavior = .moveLikeFinder
    var autoRemoveAfterDrop: Bool = true
    var autoStackMultipleFiles: Bool = true
    var persistItemsAcrossLaunches: Bool = true
    var showEdgeHandle: Bool = true
    var shelfSize: ShelfSizePreset = .standard
    var isShelfPinned: Bool = false
    var hotKeyBinding: HotKeyBinding = .defaultToggle
    var customFloatingX: Double? = nil
    var customFloatingY: Double? = nil
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var showInDock: Bool {
        didSet {
            guard showInDock != oldValue else { return }
            applyDockVisibilityPolicy()
            saveSettingsAsync()
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue, !isSyncingLaunchAtLogin else { return }
            applyLaunchAtLogin()
        }
    }

    @Published var openSettingsOnLaunch: Bool {
        didSet {
            guard openSettingsOnLaunch != oldValue else { return }
            saveSettingsAsync()
        }
    }

    @Published var edgePosition: ShelfEdgePosition {
        didSet {
            guard edgePosition != oldValue else { return }
            saveSettingsAsync()
            onLayoutPreferenceChanged?()
        }
    }

    @Published var autoShowTrigger: AutoShowTrigger {
        didSet {
            guard autoShowTrigger != oldValue else { return }
            saveSettingsAsync()
        }
    }

    @Published var dragOutBehavior: DragOutBehavior {
        didSet {
            guard dragOutBehavior != oldValue else { return }
            saveSettingsAsync()
        }
    }

    @Published var autoRemoveAfterDrop: Bool {
        didSet {
            guard autoRemoveAfterDrop != oldValue else { return }
            saveSettingsAsync()
        }
    }

    @Published var autoStackMultipleFiles: Bool {
        didSet {
            guard autoStackMultipleFiles != oldValue else { return }
            saveSettingsAsync()
        }
    }

    @Published var persistItemsAcrossLaunches: Bool {
        didSet {
            guard persistItemsAcrossLaunches != oldValue else { return }
            saveSettingsAsync()
            ShelfStore.shared.saveShelfIfNeeded()
        }
    }

    @Published var showEdgeHandle: Bool {
        didSet {
            guard showEdgeHandle != oldValue else { return }
            saveSettingsAsync()
            onEdgeHandlePreferenceChanged?()
        }
    }

    @Published var shelfSize: ShelfSizePreset {
        didSet {
            guard shelfSize != oldValue else { return }
            saveSettingsAsync()
            onLayoutPreferenceChanged?()
        }
    }

    @Published var isShelfPinned: Bool {
        didSet {
            guard isShelfPinned != oldValue else { return }
            saveSettingsAsync()
            onPinStateChanged?()
        }
    }

    @Published var hotKeyBinding: HotKeyBinding {
        didSet {
            guard hotKeyBinding != oldValue else { return }
            saveSettingsAsync()
            HotKeyService.shared.register(binding: hotKeyBinding)
        }
    }

    @Published var statusBannerMessage: String = ""

    var customFloatingX: Double?
    var customFloatingY: Double?

    var onLayoutPreferenceChanged: (() -> Void)?
    var onEdgeHandlePreferenceChanged: (() -> Void)?
    var onPinStateChanged: (() -> Void)?

    private var isSyncingLaunchAtLogin = false
    private let settingsFileURL: URL

    var appSupportDirectory: URL {
        settingsFileURL.deletingLastPathComponent()
    }

    var shouldOfferMoveToApplications: Bool {
        let path = Bundle.main.bundlePath
        return path.contains("/Downloads/") || path.hasPrefix("/Volumes/") || path.contains("/AppTranslocation/")
    }

    private init() {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        let dir = baseDir.appendingPathComponent("DropShelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.settingsFileURL = dir.appendingPathComponent("settings.json")

        let loaded: PersistedSettingsPayload = {
            if let data = try? Data(contentsOf: dir.appendingPathComponent("settings.json")),
               let decoded = try? JSONDecoder().decode(PersistedSettingsPayload.self, from: data) {
                return decoded
            }
            return PersistedSettingsPayload()
        }()

        self.showInDock = loaded.showInDock
        self.openSettingsOnLaunch = loaded.openSettingsOnLaunch
        self.edgePosition = loaded.edgePosition
        self.autoShowTrigger = loaded.autoShowTrigger
        self.dragOutBehavior = loaded.dragOutBehavior
        self.autoRemoveAfterDrop = loaded.autoRemoveAfterDrop
        self.autoStackMultipleFiles = loaded.autoStackMultipleFiles
        self.persistItemsAcrossLaunches = loaded.persistItemsAcrossLaunches
        self.showEdgeHandle = loaded.showEdgeHandle
        self.shelfSize = loaded.shelfSize
        self.isShelfPinned = loaded.isShelfPinned
        self.hotKeyBinding = loaded.hotKeyBinding
        self.customFloatingX = loaded.customFloatingX
        self.customFloatingY = loaded.customFloatingY
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    func applyDockVisibilityPolicy() {
        let wasSettingsVisible = AppDelegate.shared?.isSettingsWindowVisible ?? false
        let wasShelfVisible = ShelfPanelController.shared.isVisible

        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

        DispatchQueue.main.async {
            if wasShelfVisible {
                ShelfPanelController.shared.ensureFront()
            }
            if wasSettingsVisible {
                AppDelegate.shared?.bringSettingsWindowToFront()
            }
        }
    }

    func refreshLaunchAtLoginStatus() {
        isSyncingLaunchAtLogin = true
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
        isSyncingLaunchAtLogin = false
    }

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
                statusBannerMessage = "Đã bật Tự khởi động DropShelf cùng macOS."
            } else {
                try SMAppService.mainApp.unregister()
                statusBannerMessage = "Đã tắt Tự khởi động cùng macOS."
            }
        } catch {
            isSyncingLaunchAtLogin = true
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            isSyncingLaunchAtLogin = false
            statusBannerMessage = "Lưu ý: Cài đặt DropShelf vào /Applications để bật Khởi động cùng macOS."
        }
    }

    func saveCustomFloatingOrigin(_ origin: NSPoint) {
        customFloatingX = Double(origin.x)
        customFloatingY = Double(origin.y)
        saveSettingsAsync()
    }

    func saveSettingsAsync() {
        let payload = PersistedSettingsPayload(
            initialized: true,
            showInDock: showInDock,
            openSettingsOnLaunch: openSettingsOnLaunch,
            edgePosition: edgePosition,
            autoShowTrigger: autoShowTrigger,
            dragOutBehavior: dragOutBehavior,
            autoRemoveAfterDrop: autoRemoveAfterDrop,
            autoStackMultipleFiles: autoStackMultipleFiles,
            persistItemsAcrossLaunches: persistItemsAcrossLaunches,
            showEdgeHandle: showEdgeHandle,
            shelfSize: shelfSize,
            isShelfPinned: isShelfPinned,
            hotKeyBinding: hotKeyBinding,
            customFloatingX: customFloatingX,
            customFloatingY: customFloatingY
        )
        let targetURL = settingsFileURL
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(payload) {
                try? data.write(to: targetURL, options: .atomic)
            }
        }
    }
}
