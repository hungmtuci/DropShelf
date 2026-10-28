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

        let toggleTitle = ShelfPanelController.shared.isVisible
            ? "Ẩn Kệ nổi (\(settings.hotKeyBinding.readableDisplay))"
            : "Hiện Kệ nổi (\(settings.hotKeyBinding.readableDisplay))"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleShelfAction), keyEquivalent: "")
        toggleItem.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: nil)
        toggleItem.target = self
        menu.addItem(toggleItem)

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

        // Dock Show/Hide Option right on the Menu Bar!
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
            title: "Tự khởi động cùng macOS",
            action: #selector(toggleLaunchAtLoginAction),
            keyEquivalent: ""
        )
        launchItem.state = settings.launchAtLogin ? .on : .off
        launchItem.target = self
        menu.addItem(launchItem)

        menu.addItem(.separator())

        if let newVer = updater.availableVersion {
            let installItem = NSMenuItem(
                title: "Tải & Cập nhật tự động v\(newVer)",
                action: #selector(installUpdateAction),
                keyEquivalent: ""
            )
            installItem.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
            installItem.target = self
            menu.addItem(installItem)
        }

        let checkTitle: String = {
            switch updater.state {
            case .checking: return "Đang kiểm tra cập nhật..."
            case .downloading(let v): return "Đang tải v\(v)..."
            case .installing(let v): return "Đang cài đặt v\(v)..."
            default: return "Kiểm tra cập nhật từ GitHub..."
            }
        }()
        let checkItem = NSMenuItem(
            title: checkTitle,
            action: updater.isBusy ? nil : #selector(checkUpdatesAction),
            keyEquivalent: ""
        )
        checkItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
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

    @objc private func pasteClipboardAction() {
        if !ShelfStore.shared.addFromGeneralClipboard() {
            NSSound.beep()
        }
    }

    @objc private func clearShelfAction() {
        ShelfStore.shared.clearUnpinnedEntries()
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

    @objc private func installUpdateAction() {
        UpdateCheckerService.shared.installAvailableUpdate()
    }

    @objc private func checkUpdatesAction() {
        AppDelegate.shared?.showSettingsWindow()
        UpdateCheckerService.shared.checkForUpdatesManually()
    }

    @objc private func openSettingsAction() {
        AppDelegate.shared?.showSettingsWindow()
    }

    @objc private func quitAction() {
        ShelfStore.shared.saveShelfIfNeeded()
        NSApp.terminate(nil)
    }
}

// MARK: - Interactive Status Bar View (Supports Left-Click, Right-Click, AND Direct File Drag-Drop!)

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
