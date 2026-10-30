import Foundation
import AppKit
import Carbon
import ServiceManagement

enum SettingsSidebarTab: String, CaseIterable, Identifiable, Sendable {
    case general = "general"
    case displayAndPosition = "display_position"
    case screenshots = "screenshots"
    case dragAndShortcuts = "drag_shortcuts"
    case systemAndDock = "system_dock"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "Tổng quan & Cập nhật"
        case .displayAndPosition: return "Màn hình & Vị trí"
        case .screenshots: return "Chụp màn hình"
        case .dragAndShortcuts: return "Kéo thả & Phím tắt"
        case .systemAndDock: return "Hệ thống & Dock"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "sparkles.rectangle.stack.fill"
        case .displayAndPosition: return "display.2"
        case .screenshots: return "camera.viewfinder"
        case .dragAndShortcuts: return "hand.draw.fill"
        case .systemAndDock: return "dock.rectangle"
        }
    }
}

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

enum ShelfDisplayMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case followActiveScreen = "follow_active"
    case specificDisplay = "specific_display"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followActiveScreen:
            return "Tự động theo màn hình đang chọn"
        case .specificDisplay:
            return "Cố định trên màn hình chỉ định"
        }
    }
}

struct ConnectedDisplayInfo: Identifiable, Equatable {
    let displayID: UInt32
    let index: Int
    let name: String
    let resolutionText: String
    let isMain: Bool

    var id: UInt32 { displayID }

    var shortTitle: String {
        "Màn hình \(index): \(name)"
    }

    var detailedTitle: String {
        "Màn hình \(index): \(name) (\(resolutionText))"
    }

    var symbolName: String {
        let lower = name.lowercased()
        if lower.contains("built-in") || lower.contains("tích hợp") || lower.contains("macbook") || lower.contains("internal") {
            return "laptopcomputer"
        }
        return "display"
    }
}

extension NSScreen {
    var dsDisplayID: UInt32 {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    var dsResolutionText: String {
        "\(Int(frame.width))×\(Int(frame.height))"
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
            return "Hiện ngay khi bắt đầu kéo"
        case .edgeOrShake:
            return "Khi kéo sát mép hoặc lắc chuột"
        case .manualOnly:
            return "Chỉ mở bằng phím tắt / Menu Bar"
        }
    }

    var shortNote: String {
        switch self {
        case .immediateOnDrag:
            return "Tự động trượt ra khi phát hiện thao tác kéo tệp và tự ẩn sau 3 giây nếu Kệ trống."
        case .edgeOrShake:
            return "Chỉ trượt ra khi rê tệp tới sát cạnh Kệ hoặc lắc nhẹ con trỏ chuột."
        case .manualOnly:
            return "Không tự mở khi kéo chuột; chỉ mở bằng phím tắt hoặc icon Menu Bar."
        }
    }
}

enum EmptyAutoHideOption: Int, Codable, CaseIterable, Identifiable, Sendable {
    case twoSeconds = 2
    case threeSeconds = 3
    case fiveSeconds = 5
    case eightSeconds = 8
    case disabled = 0

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .twoSeconds: return "Sau 2 giây"
        case .threeSeconds: return "Sau 3 giây (Mặc định)"
        case .fiveSeconds: return "Sau 5 giây"
        case .eightSeconds: return "Sau 8 giây"
        case .disabled: return "Không tự ẩn"
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
            return "Di chuyển tệp như Finder (Giữ ⌥ để Sao chép)"
        case .copyByDefault:
            return "Sao chép mặc định (Giữ ⌘ để Di chuyển)"
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
    var displayMode: ShelfDisplayMode = .followActiveScreen
    var preferredDisplayID: UInt32? = nil
    var autoShowTrigger: AutoShowTrigger = .immediateOnDrag
    var emptyAutoHideOption: EmptyAutoHideOption = .threeSeconds
    var dragOutBehavior: DragOutBehavior = .moveLikeFinder
    var autoRemoveAfterDrop: Bool = true
    var autoStackMultipleFiles: Bool = true
    var persistItemsAcrossLaunches: Bool = true
    var showEdgeHandle: Bool = true
    var shelfSize: ShelfSizePreset = .standard
    var isShelfPinned: Bool = false
    var autoCaptureScreenshots: Bool = true
    var autoCaptureClipboardScreenshots: Bool = true
    var instantScreenshotCapture: Bool = true
    var hotKeyBinding: HotKeyBinding = .defaultToggle
    var customFloatingX: Double? = nil
    var customFloatingY: Double? = nil
    var customFloatingRelX: Double? = nil
    var customFloatingRelY: Double? = nil

    init(
        initialized: Bool = true,
        showInDock: Bool = true,
        openSettingsOnLaunch: Bool = true,
        edgePosition: ShelfEdgePosition = .rightCenter,
        displayMode: ShelfDisplayMode = .followActiveScreen,
        preferredDisplayID: UInt32? = nil,
        autoShowTrigger: AutoShowTrigger = .immediateOnDrag,
        emptyAutoHideOption: EmptyAutoHideOption = .threeSeconds,
        dragOutBehavior: DragOutBehavior = .moveLikeFinder,
        autoRemoveAfterDrop: Bool = true,
        autoStackMultipleFiles: Bool = true,
        persistItemsAcrossLaunches: Bool = true,
        showEdgeHandle: Bool = true,
        shelfSize: ShelfSizePreset = .standard,
        isShelfPinned: Bool = false,
        autoCaptureScreenshots: Bool = true,
        autoCaptureClipboardScreenshots: Bool = true,
        instantScreenshotCapture: Bool = true,
        hotKeyBinding: HotKeyBinding = .defaultToggle,
        customFloatingX: Double? = nil,
        customFloatingY: Double? = nil,
        customFloatingRelX: Double? = nil,
        customFloatingRelY: Double? = nil
    ) {
        self.initialized = initialized
        self.showInDock = showInDock
        self.openSettingsOnLaunch = openSettingsOnLaunch
        self.edgePosition = edgePosition
        self.displayMode = displayMode
        self.preferredDisplayID = preferredDisplayID
        self.autoShowTrigger = autoShowTrigger
        self.emptyAutoHideOption = emptyAutoHideOption
        self.dragOutBehavior = dragOutBehavior
        self.autoRemoveAfterDrop = autoRemoveAfterDrop
        self.autoStackMultipleFiles = autoStackMultipleFiles
        self.persistItemsAcrossLaunches = persistItemsAcrossLaunches
        self.showEdgeHandle = showEdgeHandle
        self.shelfSize = shelfSize
        self.isShelfPinned = isShelfPinned
        self.autoCaptureScreenshots = autoCaptureScreenshots
        self.autoCaptureClipboardScreenshots = autoCaptureClipboardScreenshots
        self.instantScreenshotCapture = instantScreenshotCapture
        self.hotKeyBinding = hotKeyBinding
        self.customFloatingX = customFloatingX
        self.customFloatingY = customFloatingY
        self.customFloatingRelX = customFloatingRelX
        self.customFloatingRelY = customFloatingRelY
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        initialized = try c.decodeIfPresent(Bool.self, forKey: .initialized) ?? true
        showInDock = try c.decodeIfPresent(Bool.self, forKey: .showInDock) ?? true
        openSettingsOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .openSettingsOnLaunch) ?? true
        edgePosition = try c.decodeIfPresent(ShelfEdgePosition.self, forKey: .edgePosition) ?? .rightCenter
        displayMode = try c.decodeIfPresent(ShelfDisplayMode.self, forKey: .displayMode) ?? .followActiveScreen
        preferredDisplayID = try c.decodeIfPresent(UInt32.self, forKey: .preferredDisplayID)
        autoShowTrigger = try c.decodeIfPresent(AutoShowTrigger.self, forKey: .autoShowTrigger) ?? .immediateOnDrag
        emptyAutoHideOption = try c.decodeIfPresent(EmptyAutoHideOption.self, forKey: .emptyAutoHideOption) ?? .threeSeconds
        dragOutBehavior = try c.decodeIfPresent(DragOutBehavior.self, forKey: .dragOutBehavior) ?? .moveLikeFinder
        autoRemoveAfterDrop = try c.decodeIfPresent(Bool.self, forKey: .autoRemoveAfterDrop) ?? true
        autoStackMultipleFiles = try c.decodeIfPresent(Bool.self, forKey: .autoStackMultipleFiles) ?? true
        persistItemsAcrossLaunches = try c.decodeIfPresent(Bool.self, forKey: .persistItemsAcrossLaunches) ?? true
        showEdgeHandle = try c.decodeIfPresent(Bool.self, forKey: .showEdgeHandle) ?? true
        shelfSize = try c.decodeIfPresent(ShelfSizePreset.self, forKey: .shelfSize) ?? .standard
        isShelfPinned = try c.decodeIfPresent(Bool.self, forKey: .isShelfPinned) ?? false
        autoCaptureScreenshots = try c.decodeIfPresent(Bool.self, forKey: .autoCaptureScreenshots) ?? true
        autoCaptureClipboardScreenshots = try c.decodeIfPresent(Bool.self, forKey: .autoCaptureClipboardScreenshots) ?? true
        instantScreenshotCapture = try c.decodeIfPresent(Bool.self, forKey: .instantScreenshotCapture) ?? true
        hotKeyBinding = try c.decodeIfPresent(HotKeyBinding.self, forKey: .hotKeyBinding) ?? .defaultToggle
        customFloatingX = try c.decodeIfPresent(Double.self, forKey: .customFloatingX)
        customFloatingY = try c.decodeIfPresent(Double.self, forKey: .customFloatingY)
        customFloatingRelX = try c.decodeIfPresent(Double.self, forKey: .customFloatingRelX)
        customFloatingRelY = try c.decodeIfPresent(Double.self, forKey: .customFloatingRelY)
    }
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

    @Published var displayMode: ShelfDisplayMode {
        didSet {
            guard displayMode != oldValue else { return }
            saveSettingsAsync()
            onDisplayPreferenceChanged?()
        }
    }

    @Published var preferredDisplayID: UInt32? {
        didSet {
            guard preferredDisplayID != oldValue else { return }
            saveSettingsAsync()
            onDisplayPreferenceChanged?()
        }
    }

    @Published var autoShowTrigger: AutoShowTrigger {
        didSet {
            guard autoShowTrigger != oldValue else { return }
            saveSettingsAsync()
        }
    }

    @Published var emptyAutoHideOption: EmptyAutoHideOption {
        didSet {
            guard emptyAutoHideOption != oldValue else { return }
            saveSettingsAsync()
            onEmptyAutoHideChanged?()
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

    @Published var autoCaptureScreenshots: Bool {
        didSet {
            guard autoCaptureScreenshots != oldValue else { return }
            saveSettingsAsync()
            ScreenshotMonitorService.shared.syncMonitoringState()
        }
    }

    @Published var autoCaptureClipboardScreenshots: Bool {
        didSet {
            guard autoCaptureClipboardScreenshots != oldValue else { return }
            saveSettingsAsync()
            ScreenshotMonitorService.shared.syncMonitoringState()
        }
    }

    @Published var instantScreenshotCapture: Bool {
        didSet {
            guard instantScreenshotCapture != oldValue else { return }
            saveSettingsAsync()
            ScreenshotMonitorService.shared.applyMacOSInstantScreenshotPreference()
        }
    }

    @Published var hotKeyBinding: HotKeyBinding {
        didSet {
            guard hotKeyBinding != oldValue else { return }
            saveSettingsAsync()
            HotKeyService.shared.register(binding: hotKeyBinding)
        }
    }

    @Published var selectedSettingsTab: SettingsSidebarTab = .general
    @Published var statusBannerMessage: String = ""

    var customFloatingX: Double?
    var customFloatingY: Double?
    var customFloatingRelX: Double?
    var customFloatingRelY: Double?

    var onLayoutPreferenceChanged: (() -> Void)?
    var onDisplayPreferenceChanged: (() -> Void)?
    var onEdgeHandlePreferenceChanged: (() -> Void)?
    var onPinStateChanged: (() -> Void)?
    var onEmptyAutoHideChanged: (() -> Void)?

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
        self.displayMode = loaded.displayMode
        self.preferredDisplayID = loaded.preferredDisplayID
        self.autoShowTrigger = loaded.autoShowTrigger
        self.emptyAutoHideOption = loaded.emptyAutoHideOption
        self.dragOutBehavior = loaded.dragOutBehavior
        self.autoRemoveAfterDrop = loaded.autoRemoveAfterDrop
        self.autoStackMultipleFiles = loaded.autoStackMultipleFiles
        self.persistItemsAcrossLaunches = loaded.persistItemsAcrossLaunches
        self.showEdgeHandle = loaded.showEdgeHandle
        self.shelfSize = loaded.shelfSize
        self.isShelfPinned = loaded.isShelfPinned
        self.autoCaptureScreenshots = loaded.autoCaptureScreenshots
        self.autoCaptureClipboardScreenshots = loaded.autoCaptureClipboardScreenshots
        self.instantScreenshotCapture = loaded.instantScreenshotCapture
        self.hotKeyBinding = loaded.hotKeyBinding
        self.customFloatingX = loaded.customFloatingX
        self.customFloatingY = loaded.customFloatingY
        self.customFloatingRelX = loaded.customFloatingRelX
        self.customFloatingRelY = loaded.customFloatingRelY
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    func applyDockVisibilityPolicy() {
        let wasSettingsVisible = AppDelegate.shared?.isSettingsWindowVisible ?? false
        let wasShelfVisible = ShelfPanelController.shared.isVisible

        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

        DispatchQueue.main.async {
            ShelfPanelController.shared.reapplySpaceCollectionBehavior()
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

    func saveCustomFloatingPosition(origin: NSPoint, relX: Double?, relY: Double?) {
        customFloatingX = Double(origin.x)
        customFloatingY = Double(origin.y)
        if let relX { customFloatingRelX = min(max(relX, 0.0), 1.0) }
        if let relY { customFloatingRelY = min(max(relY, 0.0), 1.0) }
        saveSettingsAsync()
    }

    func saveSettingsAsync() {
        let payload = PersistedSettingsPayload(
            initialized: true,
            showInDock: showInDock,
            openSettingsOnLaunch: openSettingsOnLaunch,
            edgePosition: edgePosition,
            displayMode: displayMode,
            preferredDisplayID: preferredDisplayID,
            autoShowTrigger: autoShowTrigger,
            emptyAutoHideOption: emptyAutoHideOption,
            dragOutBehavior: dragOutBehavior,
            autoRemoveAfterDrop: autoRemoveAfterDrop,
            autoStackMultipleFiles: autoStackMultipleFiles,
            persistItemsAcrossLaunches: persistItemsAcrossLaunches,
            showEdgeHandle: showEdgeHandle,
            shelfSize: shelfSize,
            isShelfPinned: isShelfPinned,
            autoCaptureScreenshots: autoCaptureScreenshots,
            autoCaptureClipboardScreenshots: autoCaptureClipboardScreenshots,
            instantScreenshotCapture: instantScreenshotCapture,
            hotKeyBinding: hotKeyBinding,
            customFloatingX: customFloatingX,
            customFloatingY: customFloatingY,
            customFloatingRelX: customFloatingRelX,
            customFloatingRelY: customFloatingRelY
        )
        let targetURL = settingsFileURL
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(payload) {
                try? data.write(to: targetURL, options: .atomic)
            }
        }
    }
}
