import Foundation
import AppKit
import SwiftUI

final class NonActivatingShelfPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class ShelfPanelController: ObservableObject {
    static let shared = ShelfPanelController()

    @Published private(set) var isVisible: Bool = false
    @Published var isIncomingDragTargeted: Bool = false
    @Published private(set) var availableDisplays: [ConnectedDisplayInfo] = []
    @Published private(set) var currentDisplayID: UInt32 = 0

    private var shelfPanel: NonActivatingShelfPanel?
    private var edgeHandlePanels: [UInt32: NonActivatingShelfPanel] = [:]
    private var wasSummonedByDrag: Bool = false
    private var didReceiveDropDuringCurrentSummon: Bool = false
    private var activeScreen: NSScreen?
    private var lastObservedMainDisplayID: UInt32 = 0
    private var emptyAutoHideTimer: Timer?
    private var isProgrammaticFrameUpdate: Bool = false

    private static let shelfCollectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .fullScreenAuxiliary,
        .ignoresCycle
    ]

    private init() {}

    func setupPanels() {
        guard shelfPanel == nil else { return }

        refreshAvailableDisplays()
        lastObservedMainDisplayID = NSScreen.main?.dsDisplayID ?? 0

        // 1. Main Floating Shelf Panel
        let initialWidth = AppSettings.shared.shelfSize.panelWidth
        let initialRect = NSRect(x: 0, y: 0, width: initialWidth, height: 240)
        let panel = NonActivatingShelfPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = Self.shelfCollectionBehavior
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = (AppSettings.shared.edgePosition == .freeFloating)

        let dropContainer = ShelfRootDropContainerView(frame: initialRect)
        dropContainer.autoresizingMask = [.width, .height]
        dropContainer.onDragTargetedChanged = { [weak self] targeted in
            guard let self else { return }
            self.isIncomingDragTargeted = targeted
            if targeted {
                self.cancelEmptyAutoHideTimer()
            } else {
                self.scheduleEmptyAutoHideIfNeeded()
            }
        }
        dropContainer.onDropCompleted = { [weak self] in
            self?.resizePanelToFitContent(animated: true)
            self?.scheduleEmptyAutoHideIfNeeded()
        }

        let hosting = NSHostingView(
            rootView: ShelfPanelView(
                store: ShelfStore.shared,
                settings: AppSettings.shared,
                panelController: self
            )
        )
        hosting.frame = dropContainer.bounds
        hosting.autoresizingMask = [.width, .height]
        dropContainer.addSubview(hosting)

        panel.contentView = dropContainer
        self.shelfPanel = panel

        installScreenAndWorkspaceObservers(for: panel)

        // Wire live setting updates
        AppSettings.shared.onLayoutPreferenceChanged = { [weak self] in
            guard let self else { return }
            self.shelfPanel?.isMovableByWindowBackground = (AppSettings.shared.edgePosition == .freeFloating)
            if self.isVisible {
                self.repositionShelfPanel(animated: true)
            }
            self.syncEdgeHandleVisibility()
        }
        AppSettings.shared.onDisplayPreferenceChanged = { [weak self] in
            guard let self else { return }
            self.refreshAvailableDisplays()
            let target = self.resolveTargetScreen(preferredPoint: NSEvent.mouseLocation)
            if self.isVisible || AppSettings.shared.displayMode == .specificDisplay {
                self.wasSummonedByDrag = false
                self.presentShelf(on: target)
                self.scheduleEmptyAutoHideIfNeeded()
            } else {
                self.activeScreen = target
                self.currentDisplayID = target?.dsDisplayID ?? 0
            }
            self.syncEdgeHandleVisibility()
        }
        AppSettings.shared.onEdgeHandlePreferenceChanged = { [weak self] in
            self?.syncEdgeHandleVisibility()
        }
        AppSettings.shared.onPinStateChanged = { [weak self] in
            guard let self else { return }
            if AppSettings.shared.isShelfPinned {
                self.cancelEmptyAutoHideTimer()
                if !self.isVisible {
                    self.showShelfManually()
                }
            } else {
                self.scheduleEmptyAutoHideIfNeeded()
            }
        }
        AppSettings.shared.onEmptyAutoHideChanged = { [weak self] in
            self?.scheduleEmptyAutoHideIfNeeded()
        }

        if AppSettings.shared.isShelfPinned || !ShelfStore.shared.entries.isEmpty {
            showShelfManually()
        } else {
            activeScreen = resolveTargetScreen(preferredPoint: NSEvent.mouseLocation)
            currentDisplayID = activeScreen?.dsDisplayID ?? 0
            syncEdgeHandleVisibility()
        }
    }

    private func installScreenAndWorkspaceObservers(for panel: NonActivatingShelfPanel) {
        // Track manual user dragging of the shelf when in Free-Floating mode across monitors
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.isProgrammaticFrameUpdate, let p = self.shelfPanel else { return }
                guard AppSettings.shared.edgePosition == .freeFloating else { return }

                let center = NSPoint(x: p.frame.midX, y: p.frame.midY)
                if let scr = Self.screenContaining(center) ?? p.screen {
                    self.activeScreen = scr
                    self.currentDisplayID = scr.dsDisplayID
                    let vf = scr.visibleFrame
                    let relX = Double((p.frame.minX - vf.minX) / max(1.0, vf.width - p.frame.width))
                    let relY = Double((p.frame.minY - vf.minY) / max(1.0, vf.height - p.frame.height))
                    AppSettings.shared.saveCustomFloatingPosition(origin: p.frame.origin, relX: relX, relY: relY)
                } else {
                    AppSettings.shared.saveCustomFloatingPosition(origin: p.frame.origin, relX: nil, relY: nil)
                }
            }
        }

        // Track physical monitor connect / disconnect / rearrangement / resolution changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refreshAvailableDisplays()
                let resolved = self.resolveTargetScreen(preferredPoint: NSEvent.mouseLocation)
                self.activeScreen = resolved
                self.currentDisplayID = resolved?.dsDisplayID ?? 0
                if self.isVisible {
                    self.repositionShelfPanel(animated: false)
                }
                self.syncEdgeHandleVisibility()
            }
        }

        // Track Mission Control Space switches & Full-Screen transitions
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.reapplySpaceCollectionBehavior()
                self.handleActiveSpaceOrScreenFocusChanged()
            }
        }

        // Track active application focus switches across multiple monitors (e.g. Cmd+Tab or Dock click)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let activatedBundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor in
                guard let self else { return }
                if activatedBundleID == Bundle.main.bundleIdentifier {
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                    guard let self else { return }
                    guard let mainScr = NSScreen.main else { return }
                    let newMainID = mainScr.dsDisplayID
                    guard newMainID != 0, newMainID != self.lastObservedMainDisplayID else { return }
                    self.lastObservedMainDisplayID = newMainID

                    guard AppSettings.shared.displayMode == .followActiveScreen,
                          self.isVisible,
                          !ShelfStore.shared.isDraggingOutFromShelf else {
                        return
                    }
                    if newMainID != self.currentDisplayID {
                        self.presentShelf(on: mainScr)
                        self.scheduleEmptyAutoHideIfNeeded()
                    }
                }
            }
        }
    }

    func refreshAvailableDisplays() {
        let mainID = NSScreen.main?.dsDisplayID ?? 0
        availableDisplays = NSScreen.screens.enumerated().map { idx, scr in
            ConnectedDisplayInfo(
                displayID: scr.dsDisplayID,
                index: idx + 1,
                name: scr.localizedName,
                resolutionText: scr.dsResolutionText,
                isMain: scr.dsDisplayID == mainID
            )
        }
    }

    func reapplySpaceCollectionBehavior() {
        shelfPanel?.collectionBehavior = Self.shelfCollectionBehavior
        for hp in edgeHandlePanels.values {
            hp.collectionBehavior = Self.shelfCollectionBehavior
        }
        if isVisible {
            shelfPanel?.orderFrontRegardless()
        }
    }

    // MARK: - Multi-Monitor Selection & Automatic Screen Following

    func selectFollowActiveScreen() {
        AppSettings.shared.preferredDisplayID = nil
        if AppSettings.shared.displayMode != .followActiveScreen {
            AppSettings.shared.displayMode = .followActiveScreen
        } else {
            let target = resolveTargetScreen(preferredPoint: NSEvent.mouseLocation)
            presentShelf(on: target)
            scheduleEmptyAutoHideIfNeeded()
        }
    }

    func selectSpecificDisplay(_ displayID: UInt32) {
        let previousMode = AppSettings.shared.displayMode
        let previousID = AppSettings.shared.preferredDisplayID
        AppSettings.shared.preferredDisplayID = displayID
        AppSettings.shared.displayMode = .specificDisplay

        if previousMode == .specificDisplay && previousID == displayID {
            let target = NSScreen.screens.first(where: { $0.dsDisplayID == displayID })
            presentShelf(on: target)
            scheduleEmptyAutoHideIfNeeded()
        }
    }

    func cycleToNextScreen() {
        let screens = NSScreen.screens
        guard screens.count > 1 else {
            showShelfManually()
            return
        }

        let currentIdx = screens.firstIndex(where: { $0.dsDisplayID == currentDisplayID }) ?? 0
        let nextScreen = screens[(currentIdx + 1) % screens.count]

        if AppSettings.shared.displayMode == .specificDisplay {
            selectSpecificDisplay(nextScreen.dsDisplayID)
        } else {
            wasSummonedByDrag = false
            presentShelf(on: nextScreen)
            scheduleEmptyAutoHideIfNeeded()
        }
    }

    /// Called immediately when the user clicks anywhere on another monitor (Desktop, Finder, Browser, Menu Bar, Settings).
    func handleUserClickedScreen(at mousePoint: NSPoint) {
        guard !ShelfStore.shared.isDraggingOutFromShelf else { return }
        guard !containsScreenPoint(mousePoint), !isPointInsideAnyEdgeHandle(mousePoint) else { return }
        guard let clickedScreen = Self.screenContaining(mousePoint) else { return }

        lastObservedMainDisplayID = clickedScreen.dsDisplayID
        refreshAvailableDisplays()

        guard AppSettings.shared.displayMode == .followActiveScreen else { return }

        if isVisible {
            if clickedScreen.dsDisplayID != currentDisplayID {
                presentShelf(on: clickedScreen)
                scheduleEmptyAutoHideIfNeeded()
            }
        } else {
            activeScreen = clickedScreen
            currentDisplayID = clickedScreen.dsDisplayID
        }
    }

    private func handleActiveSpaceOrScreenFocusChanged() {
        refreshAvailableDisplays()
        guard !ShelfStore.shared.isDraggingOutFromShelf else { return }

        if AppSettings.shared.displayMode == .followActiveScreen {
            let target = Self.screenContaining(NSEvent.mouseLocation) ?? NSScreen.main
            if let target {
                lastObservedMainDisplayID = target.dsDisplayID
                if isVisible && target.dsDisplayID != currentDisplayID {
                    presentShelf(on: target)
                    scheduleEmptyAutoHideIfNeeded()
                    return
                }
            }
        }

        if isVisible {
            ensureFront()
        } else {
            syncEdgeHandleVisibility()
        }
    }

    func isShelfOrHandleWindow(_ window: NSWindow?) -> Bool {
        guard let window else { return false }
        if window === shelfPanel { return true }
        return edgeHandlePanels.values.contains(where: { $0 === window })
    }

    private func isPointInsideAnyEdgeHandle(_ point: NSPoint) -> Bool {
        for hp in edgeHandlePanels.values where hp.isVisible {
            if hp.frame.insetBy(dx: -2, dy: -2).contains(point) {
                return true
            }
        }
        return false
    }

    static func screenContaining(_ point: NSPoint) -> NSScreen? {
        if let exact = NSScreen.screens.first(where: { $0.frame.contains(point) }) {
            return exact
        }
        return NSScreen.screens.first(where: { $0.frame.insetBy(dx: -2, dy: -2).contains(point) })
    }

    private func resolveTargetScreen(preferredPoint: NSPoint?) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        if AppSettings.shared.displayMode == .specificDisplay,
           let preferredID = AppSettings.shared.preferredDisplayID,
           let matched = screens.first(where: { $0.dsDisplayID == preferredID }) {
            return matched
        }

        if let pt = preferredPoint, let byPoint = Self.screenContaining(pt) {
            return byPoint
        }

        return NSScreen.main ?? screens.first
    }

    // MARK: - Show / Hide / Summon Lifecycle

    func toggleShelf() {
        if isVisible {
            if AppSettings.shared.displayMode == .followActiveScreen,
               let mouseScr = Self.screenContaining(NSEvent.mouseLocation),
               mouseScr.dsDisplayID != currentDisplayID {
                // Shelf is open on Monitor A, user triggered toggle on Monitor B -> bring Shelf to Monitor B!
                wasSummonedByDrag = false
                presentShelf(on: mouseScr)
                scheduleEmptyAutoHideIfNeeded()
                return
            }
            hideShelf()
        } else {
            showShelfManually()
        }
    }

    func showShelfManually() {
        wasSummonedByDrag = false
        didReceiveDropDuringCurrentSummon = false
        let target = resolveTargetScreen(preferredPoint: NSEvent.mouseLocation)
        presentShelf(on: target)
        scheduleEmptyAutoHideIfNeeded()
    }

    func showShelfFromEdgeTrigger(on screen: NSScreen?) {
        wasSummonedByDrag = false
        didReceiveDropDuringCurrentSummon = false
        let target: NSScreen? = {
            if AppSettings.shared.displayMode == .specificDisplay {
                return resolveTargetScreen(preferredPoint: NSEvent.mouseLocation)
            }
            return screen ?? resolveTargetScreen(preferredPoint: NSEvent.mouseLocation)
        }()
        presentShelf(on: target)
        scheduleEmptyAutoHideIfNeeded()
    }

    func summonForCapturedScreenshot() {
        wasSummonedByDrag = false
        didReceiveDropDuringCurrentSummon = true
        cancelEmptyAutoHideTimer()
        let target = resolveTargetScreen(preferredPoint: NSEvent.mouseLocation)
        presentShelf(on: target)
        resizePanelToFitContent(animated: true)
    }

    func summonForIncomingDrag(at mousePoint: NSPoint) {
        didReceiveDropDuringCurrentSummon = false
        if !isVisible {
            wasSummonedByDrag = true
        }
        let target = resolveTargetScreen(preferredPoint: mousePoint)
        presentShelf(on: target)
        scheduleEmptyAutoHideIfNeeded()
    }

    func markDropReceived() {
        didReceiveDropDuringCurrentSummon = true
        wasSummonedByDrag = false
        cancelEmptyAutoHideTimer()
    }

    func handleGlobalMouseUpAfterDrag() {
        guard isVisible else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            guard let self else { return }
            if self.wasSummonedByDrag
                && !self.didReceiveDropDuringCurrentSummon
                && ShelfStore.shared.entries.isEmpty
                && !AppSettings.shared.isShelfPinned {
                self.hideShelf()
            } else {
                self.scheduleEmptyAutoHideIfNeeded()
            }
        }
    }

    func dismissAfterLastItemDraggedOut() {
        guard isVisible, !AppSettings.shared.isShelfPinned, ShelfStore.shared.entries.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
            guard let self else { return }
            if ShelfStore.shared.entries.isEmpty && !AppSettings.shared.isShelfPinned {
                self.hideShelf()
            }
        }
    }

    // MARK: - 3-Second Empty Shelf Auto-Hide Watchdog

    func cancelEmptyAutoHideTimer() {
        emptyAutoHideTimer?.invalidate()
        emptyAutoHideTimer = nil
    }

    func scheduleEmptyAutoHideIfNeeded() {
        cancelEmptyAutoHideTimer()

        guard isVisible,
              ShelfStore.shared.entries.isEmpty,
              !AppSettings.shared.isShelfPinned else {
            return
        }

        let seconds = AppSettings.shared.emptyAutoHideOption.rawValue
        guard seconds > 0 else { return }

        scheduleEmptyTimer(after: TimeInterval(seconds))
    }

    private func scheduleEmptyTimer(after interval: TimeInterval) {
        cancelEmptyAutoHideTimer()
        emptyAutoHideTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.isVisible,
                      ShelfStore.shared.entries.isEmpty,
                      !AppSettings.shared.isShelfPinned else {
                    return
                }
                if self.isIncomingDragTargeted || DragMonitorService.shared.isSystemDragActive {
                    self.scheduleEmptyTimer(after: 1.0)
                    return
                }
                self.hideShelf()
            }
        }
    }

    private func presentShelf(on screen: NSScreen?) {
        guard let panel = shelfPanel else { return }
        let resolvedScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        let newDisplayID = resolvedScreen?.dsDisplayID ?? 0
        let switchedMonitor = (panel.isVisible && currentDisplayID != 0 && newDisplayID != 0 && newDisplayID != currentDisplayID)

        activeScreen = resolvedScreen
        currentDisplayID = newDisplayID
        refreshAvailableDisplays()

        let targetFrame = computeTargetShelfFrame(on: resolvedScreen)
        let pos = AppSettings.shared.edgePosition

        if !panel.isVisible || switchedMonitor {
            var startFrame = targetFrame
            if pos.isRightEdge {
                startFrame.origin.x += 26
            } else if pos.isLeftEdge {
                startFrame.origin.x -= 26
            }

            setPanelFrameProgrammatically(panel, frame: startFrame, display: false)
            panel.alphaValue = switchedMonitor ? 0.35 : 0.0
            panel.collectionBehavior = Self.shelfCollectionBehavior
            panel.orderFrontRegardless()
            isVisible = true
            syncEdgeHandleVisibility()

            isProgrammaticFrameUpdate = true
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
                panel.animator().alphaValue = 1.0
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    self?.isProgrammaticFrameUpdate = false
                }
            })
        } else {
            repositionShelfPanel(animated: true)
            panel.orderFrontRegardless()
        }
        StatusBarController.shared.refreshBadge()
    }

    func hideShelf() {
        cancelEmptyAutoHideTimer()
        guard let panel = shelfPanel, panel.isVisible else { return }
        wasSummonedByDrag = false
        isIncomingDragTargeted = false
        isVisible = false

        let pos = AppSettings.shared.edgePosition
        var exitFrame = panel.frame
        if pos.isRightEdge {
            exitFrame.origin.x += 24
        } else if pos.isLeftEdge {
            exitFrame.origin.x -= 24
        }

        isProgrammaticFrameUpdate = true
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(exitFrame, display: true)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isProgrammaticFrameUpdate = false
                guard !self.isVisible else { return }
                panel.orderOut(nil)
                self.syncEdgeHandleVisibility()
                StatusBarController.shared.refreshBadge()
            }
        })
    }

    func ensureFront() {
        guard isVisible, let panel = shelfPanel else { return }
        panel.collectionBehavior = Self.shelfCollectionBehavior
        panel.orderFrontRegardless()
    }

    func containsScreenPoint(_ point: NSPoint) -> Bool {
        guard isVisible, let panel = shelfPanel else { return false }
        return panel.frame.insetBy(dx: -1, dy: -1).contains(point)
    }

    // MARK: - Sizing & Screen Edge Positioning

    func resizePanelToFitContent(animated: Bool) {
        guard isVisible else { return }
        repositionShelfPanel(animated: animated)
    }

    func repositionShelfPanel(animated: Bool) {
        guard let panel = shelfPanel else { return }
        let screen: NSScreen? = {
            if AppSettings.shared.displayMode == .specificDisplay,
               let prefID = AppSettings.shared.preferredDisplayID,
               let matched = NSScreen.screens.first(where: { $0.dsDisplayID == prefID }) {
                return matched
            }
            return activeScreen
                ?? NSScreen.screens.first(where: { $0.dsDisplayID == currentDisplayID })
                ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) })
                ?? NSScreen.main
                ?? NSScreen.screens.first
        }()

        activeScreen = screen
        currentDisplayID = screen?.dsDisplayID ?? 0
        let targetFrame = computeTargetShelfFrame(on: screen)

        if animated {
            isProgrammaticFrameUpdate = true
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
            }, completionHandler: { [weak self] in
                Task { @MainActor in
                    self?.isProgrammaticFrameUpdate = false
                }
            })
        } else {
            setPanelFrameProgrammatically(panel, frame: targetFrame, display: true)
        }
    }

    private func setPanelFrameProgrammatically(_ panel: NSPanel, frame: NSRect, display: Bool) {
        isProgrammaticFrameUpdate = true
        panel.setFrame(frame, display: display)
        isProgrammaticFrameUpdate = false
    }

    private func computeTargetShelfFrame(on screen: NSScreen?) -> NSRect {
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let sizePreset = AppSettings.shared.shelfSize
        let width = sizePreset.panelWidth

        let store = ShelfStore.shared
        let count = store.entries.count
        let headerHeight: CGFloat = 46
        let dropBannerHeight: CGFloat = count == 0 ? 156 : 58
        let footerHeight: CGFloat = count > 1 ? 38 : 28

        var cardsHeight: CGFloat = 0
        if count > 0 {
            let visibleCards = min(count, 5)
            cardsHeight = CGFloat(visibleCards) * (sizePreset.cardHeight + 8) + 8
            if let expID = store.expandedStackID,
               let expEntry = store.entries.first(where: { $0.id == expID }),
               expEntry.isStack {
                cardsHeight += min(CGFloat(expEntry.items.count) * 32 + 12, 148)
            }
        }

        let desiredHeight = headerHeight + dropBannerHeight + cardsHeight + footerHeight + 16
        let height = min(max(desiredHeight, 228), min(560, vf.height - 32))
        let edgeMargin: CGFloat = 8

        let pos = AppSettings.shared.edgePosition
        if pos == .freeFloating {
            if let relX = AppSettings.shared.customFloatingRelX,
               let relY = AppSettings.shared.customFloatingRelY {
                let rawX = vf.minX + CGFloat(relX) * max(1.0, vf.width - width)
                let rawY = vf.minY + CGFloat(relY) * max(1.0, vf.height - height)
                let clampedX = max(vf.minX + 8, min(rawX, vf.maxX - width - 8))
                let clampedY = max(vf.minY + 8, min(rawY, vf.maxY - height - 8))
                return NSRect(x: round(clampedX), y: round(clampedY), width: width, height: round(height))
            } else if let savedX = AppSettings.shared.customFloatingX,
                      let savedY = AppSettings.shared.customFloatingY,
                      vf.contains(NSPoint(x: savedX, y: savedY)) {
                let clampedX = max(vf.minX + 8, min(CGFloat(savedX), vf.maxX - width - 8))
                let clampedY = max(vf.minY + 8, min(CGFloat(savedY), vf.maxY - height - 8))
                return NSRect(x: round(clampedX), y: round(clampedY), width: width, height: round(height))
            } else {
                // Default neat free-floating placement near right-center of the target monitor
                let x = vf.maxX - width - 24
                let y = vf.midY - height / 2
                return NSRect(x: round(x), y: round(y), width: width, height: round(height))
            }
        }

        let x: CGFloat
        if pos.isLeftEdge {
            x = vf.minX + edgeMargin
        } else {
            x = vf.maxX - width - edgeMargin
        }

        let y: CGFloat
        switch pos {
        case .leftTop, .rightTop:
            y = vf.maxY - height - 18
        case .leftBottom, .rightBottom:
            y = vf.minY + 18
        case .leftCenter, .rightCenter, .freeFloating:
            y = vf.midY - height / 2
        }

        let clampedY = max(vf.minY + 10, min(y, vf.maxY - height - 10))
        return NSRect(x: round(x), y: round(clampedY), width: width, height: round(height))
    }

    // MARK: - Multi-Monitor Edge Handle Panels

    private func makeEdgeHandlePanel(for displayID: UInt32) -> NonActivatingShelfPanel {
        let handleRect = NSRect(x: 0, y: 0, width: 10, height: 86)
        let hp = NonActivatingShelfPanel(
            contentRect: handleRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        hp.isFloatingPanel = true
        hp.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue)
        hp.collectionBehavior = Self.shelfCollectionBehavior
        hp.backgroundColor = .clear
        hp.isOpaque = false
        hp.hasShadow = false
        hp.hidesOnDeactivate = false

        let handleView = EdgeHandleTriggerNSView(frame: handleRect)
        handleView.autoresizingMask = [.width, .height]
        handleView.onActivateShelf = { [weak self] in
            guard let self else { return }
            let matchedScreen = NSScreen.screens.first(where: { $0.dsDisplayID == displayID })
            self.showShelfFromEdgeTrigger(on: matchedScreen)
        }
        hp.contentView = handleView
        return hp
    }

    private func syncEdgeHandleVisibility() {
        let settings = AppSettings.shared
        let allScreens = NSScreen.screens
        let connectedIDs = Set(allScreens.map(\.dsDisplayID))

        // Cleanup handles for disconnected monitors
        for (id, panel) in edgeHandlePanels where !connectedIDs.contains(id) {
            panel.orderOut(nil)
            edgeHandlePanels.removeValue(forKey: id)
        }

        guard settings.showEdgeHandle, !isVisible, settings.edgePosition != .freeFloating else {
            for hp in edgeHandlePanels.values {
                hp.orderOut(nil)
            }
            return
        }

        let targetScreens: [NSScreen] = {
            if settings.displayMode == .specificDisplay,
               let prefID = settings.preferredDisplayID,
               let specific = allScreens.first(where: { $0.dsDisplayID == prefID }) {
                return [specific]
            }
            return allScreens
        }()

        let activeIDs = Set(targetScreens.map(\.dsDisplayID))
        for (id, hp) in edgeHandlePanels where !activeIDs.contains(id) {
            hp.orderOut(nil)
        }

        let handleWidth: CGFloat = 8
        let handleHeight: CGFloat = 86

        for screen in targetScreens {
            let id = screen.dsDisplayID
            let hp = edgeHandlePanels[id] ?? {
                let created = makeEdgeHandlePanel(for: id)
                edgeHandlePanels[id] = created
                return created
            }()

            let vf = screen.visibleFrame
            let x: CGFloat = settings.edgePosition.isLeftEdge ? vf.minX : (vf.maxX - handleWidth)
            let y: CGFloat
            switch settings.edgePosition {
            case .leftTop, .rightTop:
                y = vf.maxY - handleHeight - 60
            case .leftBottom, .rightBottom:
                y = vf.minY + 60
            default:
                y = vf.midY - handleHeight / 2
            }

            let handleFrame = NSRect(x: round(x), y: round(y), width: handleWidth, height: handleHeight)

            // Detect if this edge sits on a shared seam between two side-by-side monitors
            let edgeProbeX = settings.edgePosition.isLeftEdge ? (screen.frame.minX - 6) : (screen.frame.maxX + 6)
            let probePoint = NSPoint(x: edgeProbeX, y: handleFrame.midY)
            let touchesAdjacentScreen = allScreens.contains(where: { $0.dsDisplayID != id && $0.frame.contains(probePoint) })

            if let triggerView = hp.contentView as? EdgeHandleTriggerNSView {
                triggerView.hoverTriggerDelay = touchesAdjacentScreen ? 0.42 : 0.18
            }

            hp.collectionBehavior = Self.shelfCollectionBehavior
            hp.setFrame(handleFrame, display: true)
            hp.orderFrontRegardless()
        }
    }
}

// MARK: - Subtle Screen Edge Handle View

private final class EdgeHandleTriggerNSView: NSView {
    var onActivateShelf: (() -> Void)?
    var hoverTriggerDelay: TimeInterval = 0.18

    private var isHovered = false {
        didSet { needsDisplay = true }
    }
    private var trackingRef: NSTrackingArea?
    private var hoverOpenWorkItem: DispatchWorkItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .png, .tiff, .pdf, .URL, .rtf, .string])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingRef { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        hoverOpenWorkItem?.cancel()
        let delay = hoverTriggerDelay
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isHovered else { return }
            MainActor.assumeIsolated {
                self.onActivateShelf?()
            }
        }
        hoverOpenWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        hoverOpenWorkItem?.cancel()
        hoverOpenWorkItem = nil
    }

    override func mouseDown(with event: NSEvent) {
        hoverOpenWorkItem?.cancel()
        MainActor.assumeIsolated { onActivateShelf?() }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !ShelfStore.shared.isDraggingOutFromShelf else { return [] }
        hoverOpenWorkItem?.cancel()
        MainActor.assumeIsolated { onActivateShelf?() }
        return .generic
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let pill = bounds.insetBy(dx: 1.5, dy: 4)
        let path = NSBezierPath(roundedRect: pill, xRadius: 3, yRadius: 3)
        let alpha: CGFloat = isHovered ? 0.85 : 0.32
        NSColor.controlAccentColor.withAlphaComponent(alpha).setFill()
        path.fill()
    }
}
