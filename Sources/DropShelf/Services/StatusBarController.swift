import Foundation
import AppKit

@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var dropOverlayView: StatusBarInteractiveDropView?

    private override init() {
        super.init()
    }

    func start() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item

        if let button = item.button {
            let overlay = StatusBarInteractiveDropView(frame: button.bounds)
            overlay.autoresizingMask = [.width, .height]
            overlay.onLeftClick = {
                ShelfPanelController.shared.toggleShelf()
            }
            overlay.onRightClick = { [weak self] in
                self?.presentContextMenu()
            }
            button.addSubview(overlay)
            self.dropOverlayView = overlay
        }

        refreshBadge()
    }

    func refreshBadge() {
        guard let button = statusItem?.button else { return }
        let count = ShelfStore.shared.totalFileCount
        let symbolName = count > 0 ? "tray.and.arrow.down.fill" : "tray"
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "DropShelf")
        img?.isTemplate = true
        button.image = img
        button.imagePosition = count > 0 ? .imageLeading : .imageOnly
        button.title = count > 0 ? " \(count)" : ""
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)

        let hk = AppSettings.shared.hotKeyBinding.readableDisplay
        if let newVer = UpdateCheckerService.shared.availableVersion {
            button.toolTip = "DropShelf — Đã có bản mới v\(newVer)! (Click trái: Hiện/Ẩn kệ \(hk) • Click phải: Menu)"
        } else {
            button.toolTip = "DropShelf — Click trái: Hiện/Ẩn kệ (\(hk)) • Click phải: Tuỳ chọn • Kéo tệp thả vào đây"
        }
    }

    func presentContextMenu() {
        guard let item = statusItem, let button = item.button else { return }
        AppSettings.shared.refreshLaunchAtLoginStatus()

        let menu = NSMenu()
        let updater = UpdateCheckerService.shared
        let settings = AppSettings.shared
        let store = ShelfStore.shared

        let header = NSMenuItem(
            title: "DropShelf v\(updater.currentVersion) — Kệ kéo thả tệp tạm thời",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)

        let panelCtrl = ShelfPanelController.shared
        panelCtrl.refreshAvailableDisplays()

        let mouseScreenID = ShelfPanelController.screenContaining(NSEvent.mouseLocation)?.dsDisplayID ?? 0
        let isShelfOnOtherScreen = panelCtrl.isVisible
            && settings.displayMode == .followActiveScreen
            && mouseScreenID != 0
            && mouseScreenID != panelCtrl.currentDisplayID

        let toggleTitle: String = {
            if isShelfOnOtherScreen {
                return "Đưa Kệ sang màn hình này (\(settings.hotKeyBinding.readableDisplay))"
            }
            return panelCtrl.isVisible
                ? "Ẩn Kệ nổi (\(settings.hotKeyBinding.readableDisplay))"
                : "Hiện Kệ nổi (\(settings.hotKeyBinding.readableDisplay))"
        }()
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleShelfAction), keyEquivalent: "")
        toggleItem.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: nil)
        toggleItem.target = self
        menu.addItem(toggleItem)

        if panelCtrl.availableDisplays.count > 1 {
            let hopItem = NSMenuItem(
                title: "Chuyển Kệ sang màn hình kia",
                action: #selector(cycleShelfScreenAction),
                keyEquivalent: ""
            )
            hopItem.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: nil)
            hopItem.target = self
            menu.addItem(hopItem)

            let displayMenuParent = NSMenuItem(title: "Chọn màn hình hiển thị Kệ", action: nil, keyEquivalent: "")
            displayMenuParent.image = NSImage(systemSymbolName: "display", accessibilityDescription: nil)
            let displaySubmenu = NSMenu(title: "Chọn màn hình hiển thị Kệ")

            let autoItem = NSMenuItem(
                title: "Tự động theo màn hình đang chọn",
                action: #selector(selectAutoFollowScreenAction),
                keyEquivalent: ""
            )
            autoItem.state = (settings.displayMode == .followActiveScreen) ? .on : .off
            autoItem.target = self
            displaySubmenu.addItem(autoItem)
            displaySubmenu.addItem(.separator())

            for disp in panelCtrl.availableDisplays {
                let item = NSMenuItem(
                    title: disp.detailedTitle,
                    action: #selector(selectSpecificDisplayMenuAction(_:)),
                    keyEquivalent: ""
                )
                item.tag = Int(disp.displayID)
                item.state = (settings.displayMode == .specificDisplay && settings.preferredDisplayID == disp.displayID) ? .on : .off
                item.target = self
                displaySubmenu.addItem(item)
            }

            displayMenuParent.submenu = displaySubmenu
            menu.addItem(displayMenuParent)
        }

        let pasteItem = NSMenuItem(title: "Dán từ Clipboard vào Kệ", action: #selector(pasteClipboardAction), keyEquivalent: "")
        pasteItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        pasteItem.target = self
        menu.addItem(pasteItem)

        if !store.entries.isEmpty {
            let clearItem = NSMenuItem(
                title: "Dọn sạch kệ (\(store.totalFileCount) tệp)",
                action: #selector(clearShelfAction),
                keyEquivalent: ""
            )
            clearItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
            clearItem.target = self
            menu.addItem(clearItem)
        }

        menu.addItem(.separator())

        let autoScreenshotItem = NSMenuItem(
            title: "Tự động bắt Ảnh chụp màn hình vào Kệ",
            action: #selector(toggleAutoScreenshotAction),
            keyEquivalent: ""
        )
        autoScreenshotItem.state = settings.autoCaptureScreenshots ? .on : .off
        autoScreenshotItem.target = self
        menu.addItem(autoScreenshotItem)

        let showDockItem = NSMenuItem(
            title: "Hiển thị biểu tượng trên thanh Dock",
            action: #selector(toggleShowInDockAction),
            keyEquivalent: ""
        )
        showDockItem.state = settings.showInDock ? .on : .off
        showDockItem.target = self
        menu.addItem(showDockItem)

        let pinShelfItem = NSMenuItem(
            title: "Ghim Kệ luôn hiển thị trên màn hình",
            action: #selector(togglePinShelfAction),
            keyEquivalent: ""
        )
        pinShelfItem.state = settings.isShelfPinned ? .on : .off
        pinShelfItem.target = self
        menu.addItem(pinShelfItem)

        let launchItem = NSMenuItem(
            title: "Khởi động cùng macOS",
            action: #selector(toggleLaunchAtLoginAction),
            keyEquivalent: ""
        )
        launchItem.state = settings.launchAtLogin ? .on : .off
        launchItem.target = self
        menu.addItem(launchItem)

        let openShelfOnLaunchItem = NSMenuItem(
            title: "Bật bảng Kệ nổi khi khởi động",
            action: #selector(toggleOpenShelfOnLaunchAction),
            keyEquivalent: ""
        )
        openShelfOnLaunchItem.state = settings.openShelfOnLaunch ? .on : .off
        openShelfOnLaunchItem.target = self
        menu.addItem(openShelfOnLaunchItem)

        let openSettingsOnLaunchItem = NSMenuItem(
            title: "Bật bảng Cài đặt khi khởi động",
            action: #selector(toggleOpenSettingsOnLaunchAction),
            keyEquivalent: ""
        )
        openSettingsOnLaunchItem.state = settings.openSettingsOnLaunch ? .on : .off
        openSettingsOnLaunchItem.target = self
        menu.addItem(openSettingsOnLaunchItem)

        menu.addItem(.separator())

        let checkTitle: String = {
            switch updater.state {
            case .available(let v, _, _, _): return "Update qua GitHub ngay (v\(v))"
            case .checking: return "Đang kiểm tra GitHub..."
            case .downloading(let v): return "Đang tải v\(v) từ GitHub..."
            case .installing(let v): return "Đang cài đặt v\(v)..."
            default: return "Update qua GitHub (Kiểm tra & Cập nhật ngay)"
            }
        }()
        let checkItem = NSMenuItem(
            title: checkTitle,
            action: updater.isBusy ? nil : #selector(checkUpdatesAction),
            keyEquivalent: ""
        )
        checkItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath.circle.fill", accessibilityDescription: nil)
        checkItem.isEnabled = !updater.isBusy
        checkItem.target = self
        menu.addItem(checkItem)

        let settingsItem = NSMenuItem(
            title: "Cài đặt & Quản lý DropShelf...",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Thoát DropShelf",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func toggleShelfAction() {
        ShelfPanelController.shared.toggleShelf()
    }

    @objc private func cycleShelfScreenAction() {
        ShelfPanelController.shared.cycleToNextScreen()
    }

    @objc private func selectAutoFollowScreenAction() {
        ShelfPanelController.shared.selectFollowActiveScreen()
    }

    @objc private func selectSpecificDisplayMenuAction(_ sender: NSMenuItem) {
        let id = UInt32(bitPattern: Int32(truncatingIfNeeded: sender.tag))
        ShelfPanelController.shared.selectSpecificDisplay(id)
    }

    @objc private func pasteClipboardAction() {
        if !ShelfStore.shared.addFromGeneralClipboard() {
            NSSound.beep()
        }
    }

    @objc private func clearShelfAction() {
        ShelfStore.shared.clearUnpinnedEntries()
    }

    @objc private func toggleAutoScreenshotAction() {
        AppSettings.shared.autoCaptureScreenshots.toggle()
    }

    @objc private func toggleShowInDockAction() {
        AppSettings.shared.showInDock.toggle()
    }

    @objc private func togglePinShelfAction() {
        AppSettings.shared.isShelfPinned.toggle()
    }

    @objc private func toggleLaunchAtLoginAction() {
        AppSettings.shared.launchAtLogin.toggle()
    }

    @objc private func toggleOpenShelfOnLaunchAction() {
        AppSettings.shared.openShelfOnLaunch.toggle()
    }

    @objc private func toggleOpenSettingsOnLaunchAction() {
        AppSettings.shared.openSettingsOnLaunch.toggle()
    }

    @objc private func checkUpdatesAction() {
        UpdateCheckerService.shared.oneClickUpdateFromGitHub()
    }

    @objc private func openSettingsAction() {
        AppDelegate.shared?.showSettingsWindow()
    }

    @objc private func quitAction() {
        ShelfStore.shared.saveShelfIfNeeded()
        NSApp.terminate(nil)
    }
}

private final class StatusBarInteractiveDropView: NSView {
    var onLeftClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    private var isTargeted = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        var types: [NSPasteboard.PasteboardType] = [.fileURL, .png, .tiff, .pdf, .URL, .rtf, .string]
        types.append(contentsOf: NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        registerForDraggedTypes(types)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) || flags.contains(.option) {
            MainActor.assumeIsolated { onRightClick?() }
        } else {
            MainActor.assumeIsolated { onLeftClick?() }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        MainActor.assumeIsolated { onRightClick?() }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !ShelfStore.shared.isDraggingOutFromShelf else { return [] }
        isTargeted = true
        return .generic
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        isTargeted = false
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        isTargeted = false
        var accepted = false
        MainActor.assumeIsolated {
            accepted = ShelfStore.shared.ingestPasteboard(sender.draggingPasteboard)
            if accepted {
                ShelfPanelController.shared.showShelfManually()
            }
        }
        return accepted
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isTargeted else { return }
        let rect = bounds.insetBy(dx: 1, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        NSColor.controlAccentColor.withAlphaComponent(0.32).setFill()
        path.fill()
    }
}
