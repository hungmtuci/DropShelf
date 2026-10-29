import SwiftUI
import AppKit
import QuickLookUI

final class DropShelfApplication: NSApplication {
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        MainActor.assumeIsolated {
            panel.dataSource = QuickLookCoordinator.shared
            panel.delegate = QuickLookCoordinator.shared
        }
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {}
}

@main
enum DropShelfMain {
    static func main() {
        let app = DropShelfApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        MainActor.assumeIsolated {
            delegate.installMainMenu()
        }
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static weak var shared: AppDelegate?

    private var settingsWindow: NSWindow?

    var isSettingsWindowVisible: Bool {
        settingsWindow?.isVisible ?? false
    }

    // MARK: - Main Menu

    func installMainMenu() {
        let mainMenu = NSMenu()

        // Application Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Giới thiệu & Cài đặt DropShelf...",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        ).target = self
        appMenu.addItem(
            withTitle: "Hiện / Ẩn Kệ nổi",
            action: #selector(toggleShelfFromMenu),
            keyEquivalent: "y"
        ).target = self
        appMenu.addItem(
            withTitle: "Kiểm tra cập nhật từ GitHub...",
            action: #selector(checkUpdatesFromMenu),
            keyEquivalent: ""
        ).target = self
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Ẩn DropShelf",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        let quitItem = appMenu.addItem(
            withTitle: "Thoát DropShelf",
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        )
        quitItem.target = self
        appMenuItem.submenu = appMenu

        // Shelf Menu
        let shelfMenuItem = NSMenuItem()
        mainMenu.addItem(shelfMenuItem)
        let shelfMenu = NSMenu(title: "Kệ tạm")
        let pasteToShelf = shelfMenu.addItem(
            withTitle: "Dán từ Clipboard vào Kệ",
            action: #selector(pasteToShelfFromMenu),
            keyEquivalent: "v"
        )
        pasteToShelf.keyEquivalentModifierMask = [.command, .shift]
        pasteToShelf.target = self

        let quickLookItem = shelfMenu.addItem(
            withTitle: "Xem nhanh mục đang chọn (Quick Look)",
            action: #selector(quickLookFromMenu),
            keyEquivalent: "y"
        )
        quickLookItem.keyEquivalentModifierMask = [.command]
        quickLookItem.target = self

        let clearShelf = shelfMenu.addItem(
            withTitle: "Dọn sạch các mục chưa ghim",
            action: #selector(clearShelfFromMenu),
            keyEquivalent: "\u{08}"
        )
        clearShelf.keyEquivalentModifierMask = [.command]
        clearShelf.target = self
        shelfMenuItem.submenu = shelfMenu

        // Edit Menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Chỉnh sửa")
        editMenu.addItem(withTitle: "Hoàn tác", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Làm lại", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cắt", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Sao chép", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Dán", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Chọn tất cả", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        // Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Cửa sổ")
        windowMenu.addItem(withTitle: "Đóng cửa sổ", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Thu nhỏ", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenuItem.submenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self

        if let bundleID = Bundle.main.bundleIdentifier {
            let ownPID = ProcessInfo.processInfo.processIdentifier
            let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .first(where: { $0.processIdentifier != ownPID })
            if let existing {
                existing.activate()
                NSApp.terminate(nil)
                return
            }
        }

        let settings = AppSettings.shared
        let store = ShelfStore.shared
        let panelController = ShelfPanelController.shared
        let statusBar = StatusBarController.shared
        let hotKeys = HotKeyService.shared
        let dragMonitor = DragMonitorService.shared
        let screenshotMonitor = ScreenshotMonitorService.shared

        _ = store
        settings.applyDockVisibilityPolicy()

        statusBar.start()
        panelController.setupPanels()

        hotKeys.onToggleShelf = {
            ShelfPanelController.shared.toggleShelf()
        }
        hotKeys.installHandlerAndRegister(binding: settings.hotKeyBinding)

        dragMonitor.start()
        screenshotMonitor.start()

        if settings.openSettingsOnLaunch {
            showSettingsWindow()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            UpdateCheckerService.shared.checkSilentlyOnLaunchIfNeeded()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let added = ShelfStore.shared.addFileURLs(urls)
        if added {
            ShelfPanelController.shared.showShelfManually()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !ShelfPanelController.shared.isVisible {
            ShelfPanelController.shared.showShelfManually()
        }
        showSettingsWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        ScreenshotMonitorService.shared.stop()
        DragMonitorService.shared.stop()
        HotKeyService.shared.unregister()
        ShelfStore.shared.saveShelfIfNeeded()
    }

    // MARK: - Settings Window Management

    func showSettingsWindow() {
        AppSettings.shared.refreshLaunchAtLoginStatus()
        ShelfPanelController.shared.refreshAvailableDisplays()

        let wasVisible = settingsWindow?.isVisible ?? false
        if settingsWindow == nil {
            let rootView = SettingsDashboardView(
                settings: AppSettings.shared,
                store: ShelfStore.shared,
                panelController: ShelfPanelController.shared,
                hotKeyService: HotKeyService.shared,
                screenshotService: ScreenshotMonitorService.shared,
                updateService: UpdateCheckerService.shared
            )
            let hosting = NSHostingController(rootView: rootView)
            let win = NSWindow(contentViewController: hosting)
            win.title = "DropShelf — Kệ kéo thả tệp tạm thời (Cài đặt & Quản lý)"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.setContentSize(NSSize(width: 820, height: 750))
            win.center()
            self.settingsWindow = win
        }

        if let win = settingsWindow,
           let targetScreen = ShelfPanelController.screenContaining(NSEvent.mouseLocation) ?? NSScreen.main {
            if !wasVisible || win.screen?.dsDisplayID != targetScreen.dsDisplayID {
                let vf = targetScreen.visibleFrame
                let size = win.frame.size
                let origin = NSPoint(
                    x: round(vf.midX - size.width / 2),
                    y: round(vf.midY - size.height / 2)
                )
                win.setFrameOrigin(origin)
            }
        }

        bringSettingsWindowToFront()
    }

    func bringSettingsWindowToFront() {
        guard let win = settingsWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    // MARK: - Menu Actions

    @objc private func openSettingsFromMenu() {
        showSettingsWindow()
    }

    @objc private func toggleShelfFromMenu() {
        ShelfPanelController.shared.toggleShelf()
    }

    @objc private func checkUpdatesFromMenu() {
        showSettingsWindow()
        UpdateCheckerService.shared.checkForUpdatesManually()
    }

    @objc private func pasteToShelfFromMenu() {
        if !ShelfStore.shared.addFromGeneralClipboard() {
            NSSound.beep()
        }
    }

    @objc private func quickLookFromMenu() {
        QuickLookCoordinator.shared.toggleQuickLook(for: nil)
    }

    @objc private func clearShelfFromMenu() {
        ShelfStore.shared.clearUnpinnedEntries()
    }

    @objc private func quitFromMenu() {
        ShelfStore.shared.saveShelfIfNeeded()
        NSApp.terminate(nil)
    }
}
