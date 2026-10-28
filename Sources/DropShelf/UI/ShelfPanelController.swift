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

    private var shelfPanel: NonActivatingShelfPanel?
    private var edgeHandlePanel: NonActivatingShelfPanel?
    private var wasSummonedByDrag: Bool = false
    private var didReceiveDropDuringCurrentSummon: Bool = false
    private var activeScreen: NSScreen?

    private init() {}

    func setupPanels() {
        guard shelfPanel == nil else { return }

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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = (AppSettings.shared.edgePosition == .freeFloating)

        let dropContainer = ShelfRootDropContainerView(frame: initialRect)
        dropContainer.autoresizingMask = [.width, .height]
        dropContainer.onDragTargetedChanged = { [weak self] targeted in
            self?.isIncomingDragTargeted = targeted
        }
        dropContainer.onDropCompleted = { [weak self] in
            self?.resizePanelToFitContent(animated: true)
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

        // Observe window moves in freeFloating mode
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, let p = self.shelfPanel else { return }
                if AppSettings.shared.edgePosition == .freeFloating {
                    AppSettings.shared.saveCustomFloatingOrigin(p.frame.origin)
                }
            }
        }

        // 2. Subtle Edge Handle Panel
        setupEdgeHandlePanel()

        // Wire live setting updates
        AppSettings.shared.onLayoutPreferenceChanged = { [weak self] in
            guard let self else { return }
            self.shelfPanel?.isMovableByWindowBackground = (AppSettings.shared.edgePosition == .freeFloating)
            if self.isVisible {
                self.repositionShelfPanel(animated: true)
            }
            self.syncEdgeHandleVisibility()
        }
        AppSettings.shared.onEdgeHandlePreferenceChanged = { [weak self] in
            self?.syncEdgeHandleVisibility()
        }
        AppSettings.shared.onPinStateChanged = { [weak self] in
            guard let self else { return }
            if AppSettings.shared.isShelfPinned && !self.isVisible {
                self.showShelfManually()
            }
        }

        if AppSettings.shared.isShelfPinned || !ShelfStore.shared.entries.isEmpty {
            showShelfManually()
        } else {
            syncEdgeHandleVisibility()
        }
    }

    private func setupEdgeHandlePanel() {
        let handleRect = NSRect(x: 0, y: 0, width: 10, height: 84)
        let hp = NonActivatingShelfPanel(
            contentRect: handleRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        hp.isFloatingPanel = true
        hp.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue)
        hp.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hp.backgroundColor = .clear
        hp.isOpaque = false
        hp.hasShadow = false
        hp.hidesOnDeactivate = false

        let handleView = EdgeHandleTriggerNSView(frame: handleRect)
        handleView.autoresizingMask = [.width, .height]
        handleView.onActivateShelf = { [weak self] in
            self?.showShelfManually()
        }
        hp.contentView = handleView
        self.edgeHandlePanel = hp
    }

    // MARK: - Show / Hide / Summon Lifecycle

    func toggleShelf() {
        if isVisible {
            hideShelf()
        } else {
            showShelfManually()
        }
    }

    func showShelfManually() {
        wasSummonedByDrag = false
        didReceiveDropDuringCurrentSummon = false
        presentShelf(near: NSEvent.mouseLocation)
    }

    func summonForIncomingDrag(at mousePoint: NSPoint) {
        didReceiveDropDuringCurrentSummon = false
        if !isVisible {
            wasSummonedByDrag = true
            presentShelf(near: mousePoint)
        } else {
            ensureFront()
        }
    }

    func markDropReceived() {
        didReceiveDropDuringCurrentSummon = true
        wasSummonedByDrag = false
    }

    func handleGlobalMouseUpAfterDrag() {
        guard isVisible, wasSummonedByDrag else { return }
        // Allow performDragOperation to complete first if the user dropped right onto DropShelf
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
            guard let self else { return }
            if self.wasSummonedByDrag
                && !self.didReceiveDropDuringCurrentSummon
                && ShelfStore.shared.entries.isEmpty
                && !AppSettings.shared.isShelfPinned {
                self.hideShelf()
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

    private func presentShelf(near mousePoint: NSPoint) {
        guard let panel = shelfPanel else { return }
        activeScreen = NSScreen.screens.first(where: { NSMouseInRect(mousePoint, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        let targetFrame = computeTargetShelfFrame(on: activeScreen)
        let pos = AppSettings.shared.edgePosition

        if !panel.isVisible {
            var startFrame = targetFrame
            if pos.isRightEdge {
                startFrame.origin.x += 28
            } else if pos.isLeftEdge {
                startFrame.origin.x -= 28
            }
            panel.setFrame(startFrame, display: false)
            panel.alphaValue = 0.0
            panel.orderFrontRegardless()
            isVisible = true
            syncEdgeHandleVisibility()

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.16
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
                panel.animator().alphaValue = 1.0
            }
        } else {
            repositionShelfPanel(animated: true)
            panel.orderFrontRegardless()
        }
        StatusBarController.shared.refreshBadge()
    }

    func hideShelf() {
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

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(exitFrame, display: true)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, !self.isVisible else { return }
                panel.orderOut(nil)
                self.syncEdgeHandleVisibility()
                StatusBarController.shared.refreshBadge()
            }
        })
    }

    func ensureFront() {
        guard isVisible, let panel = shelfPanel else { return }
        panel.orderFrontRegardless()
    }

    func containsScreenPoint(_ point: NSPoint) -> Bool {
        guard isVisible, let panel = shelfPanel else { return false }
        return NSMouseInRect(point, panel.frame, false)
    }

    // MARK: - Sizing & Screen Edge Positioning

    func resizePanelToFitContent(animated: Bool) {
        guard isVisible else { return }
        repositionShelfPanel(animated: animated)
    }

    func repositionShelfPanel(animated: Bool) {
        guard let panel = shelfPanel else { return }
        let screen = activeScreen
            ?? NSScreen.screens.first(where: { $0.frame.intersects(panel.frame) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let targetFrame = computeTargetShelfFrame(on: screen)

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
        }
    }

    private func computeTargetShelfFrame(on screen: NSScreen?) -> NSRect {
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let sizePreset = AppSettings.shared.shelfSize
        let width = sizePreset.panelWidth

        let store = ShelfStore.shared
        let count = store.entries.count
        let headerHeight: CGFloat = 46
        let dropBannerHeight: CGFloat = count == 0 ? 156 : 58
        let footerHeight: CGFloat = count > 1 ? 38 : 26

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
        let height = min(max(desiredHeight, 226), min(560, vf.height - 32))
        let edgeMargin: CGFloat = 8

        let pos = AppSettings.shared.edgePosition
        if pos == .freeFloating,
           let savedX = AppSettings.shared.customFloatingX,
           let savedY = AppSettings.shared.customFloatingY {
            let clampedX = max(vf.minX + 8, min(CGFloat(savedX), vf.maxX - width - 8))
            let clampedY = max(vf.minY + 8, min(CGFloat(savedY), vf.maxY - height - 8))
            return NSRect(x: round(clampedX), y: round(clampedY), width: width, height: round(height))
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

    private func syncEdgeHandleVisibility() {
        guard let hp = edgeHandlePanel else { return }
        let settings = AppSettings.shared
        guard settings.showEdgeHandle, !isVisible, settings.edgePosition != .freeFloating else {
            hp.orderOut(nil)
            return
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        let vf = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let handleWidth: CGFloat = 8
        let handleHeight: CGFloat = 86

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

        hp.setFrame(NSRect(x: round(x), y: round(y), width: handleWidth, height: handleHeight), display: true)
        hp.orderFrontRegardless()
    }
}

// MARK: - Subtle Screen Edge Handle View

private final class EdgeHandleTriggerNSView: NSView {
    var onActivateShelf: (() -> Void)?
    private var isHovered = false {
        didSet { needsDisplay = true }
    }
    private var trackingRef: NSTrackingArea?

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
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }

    override func mouseDown(with event: NSEvent) {
        MainActor.assumeIsolated { onActivateShelf?() }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !ShelfStore.shared.isDraggingOutFromShelf else { return [] }
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
