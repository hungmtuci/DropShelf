import Foundation
import AppKit

@MainActor
final class DragMonitorService {
    static let shared = DragMonitorService()

    private(set) var isSystemDragActive: Bool = false

    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?

    private var mouseDownPoint: NSPoint?
    private var lastHandledDragChangeCount: Int
    private var lastObservedDragX: CGFloat?
    private var lastHorizontalDirection: Int = 0
    private var shakeFlipCount: Int = 0
    private var firstShakeFlipTime: TimeInterval = 0

    private init() {
        self.lastHandledDragChangeCount = NSPasteboard(name: .drag).changeCount
    }

    func start() {
        guard globalMouseMonitor == nil else { return }
        lastHandledDragChangeCount = NSPasteboard(name: .drag).changeCount

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            let eventType = event.type
            let mouseLoc = NSEvent.mouseLocation
            Task { @MainActor in
                self?.handleGlobalMouseEvent(type: eventType, mouseLocation: mouseLoc)
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if ShelfPanelController.shared.isVisible {
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                // Spacebar -> Quick Look when shelf is hovered or active
                if event.keyCode == 49 && flags.isEmpty {
                    let mouse = NSEvent.mouseLocation
                    if ShelfPanelController.shared.containsScreenPoint(mouse) {
                        QuickLookCoordinator.shared.toggleQuickLook(for: nil)
                        return nil
                    }
                }
                // Escape -> Hide shelf if hovered and not pinned
                if event.keyCode == 53 && flags.isEmpty {
                    let mouse = NSEvent.mouseLocation
                    if ShelfPanelController.shared.containsScreenPoint(mouse) && !AppSettings.shared.isShelfPinned {
                        ShelfPanelController.shared.hideShelf()
                        return nil
                    }
                }
                // Cmd + V -> Paste from Clipboard onto shelf when hovering shelf
                if event.charactersIgnoringModifiers?.lowercased() == "v" && flags == [.command] {
                    let mouse = NSEvent.mouseLocation
                    if ShelfPanelController.shared.containsScreenPoint(mouse) {
                        ShelfStore.shared.addFromGeneralClipboard()
                        return nil
                    }
                }
            }
            return event
        }
    }

    func stop() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let keyMon = localKeyMonitor {
            NSEvent.removeMonitor(keyMon)
            localKeyMonitor = nil
        }
    }

    /// Called right when DropShelf begins its own outgoing drag so we never self-summon.
    func markOutgoingShelfDragStarted() {
        lastHandledDragChangeCount = NSPasteboard(name: .drag).changeCount
    }

    private func handleGlobalMouseEvent(type: NSEvent.EventType, mouseLocation: NSPoint) {
        switch type {
        case .leftMouseDown:
            mouseDownPoint = mouseLocation
            isSystemDragActive = false
            resetShakeState()
            if !ShelfStore.shared.isDraggingOutFromShelf {
                lastHandledDragChangeCount = NSPasteboard(name: .drag).changeCount
            }

        case .leftMouseDragged:
            guard !ShelfStore.shared.isDraggingOutFromShelf else { return }
            let dragPB = NSPasteboard(name: .drag)
            let currentCount = dragPB.changeCount

            if currentCount != lastHandledDragChangeCount {
                isSystemDragActive = true
            }

            let triggerMode = AppSettings.shared.autoShowTrigger
            guard triggerMode != .manualOnly else { return }
            guard currentCount != lastHandledDragChangeCount else { return }

            if let start = mouseDownPoint {
                let dist = hypot(mouseLocation.x - start.x, mouseLocation.y - start.y)
                if dist < 10 { return }
            }

            switch triggerMode {
            case .immediateOnDrag:
                lastHandledDragChangeCount = currentCount
                ShelfPanelController.shared.summonForIncomingDrag(at: mouseLocation)

            case .edgeOrShake:
                if isNearTargetEdge(mouseLocation) || detectCursorShake(at: mouseLocation) {
                    lastHandledDragChangeCount = currentCount
                    ShelfPanelController.shared.summonForIncomingDrag(at: mouseLocation)
                }

            case .manualOnly:
                break
            }

        case .leftMouseUp:
            mouseDownPoint = nil
            isSystemDragActive = false
            resetShakeState()
            lastHandledDragChangeCount = NSPasteboard(name: .drag).changeCount
            ShelfPanelController.shared.handleGlobalMouseUpAfterDrag()

        default:
            break
        }
    }

    private func resetShakeState() {
        lastObservedDragX = nil
        lastHorizontalDirection = 0
        shakeFlipCount = 0
        firstShakeFlipTime = 0
    }

    private func isNearTargetEdge(_ mouse: NSPoint) -> Bool {
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main else {
            return false
        }
        let vf = screen.visibleFrame
        let pos = AppSettings.shared.edgePosition
        let threshold: CGFloat = 120

        if pos.isLeftEdge {
            return (mouse.x - vf.minX) <= threshold
        } else if pos.isRightEdge {
            return (vf.maxX - mouse.x) <= threshold
        } else {
            return (mouse.x - vf.minX) <= threshold || (vf.maxX - mouse.x) <= threshold
        }
    }

    private func detectCursorShake(at mouse: NSPoint) -> Bool {
        guard let prevX = lastObservedDragX else {
            lastObservedDragX = mouse.x
            return false
        }
        let dx = mouse.x - prevX
        guard abs(dx) >= 18 else { return false }

        lastObservedDragX = mouse.x
        let dir = dx > 0 ? 1 : -1
        let now = ProcessInfo.processInfo.systemUptime

        if lastHorizontalDirection != 0 && dir != lastHorizontalDirection {
            if shakeFlipCount == 0 || (now - firstShakeFlipTime) > 0.75 {
                shakeFlipCount = 1
                firstShakeFlipTime = now
            } else {
                shakeFlipCount += 1
            }
            lastHorizontalDirection = dir
            if shakeFlipCount >= 3 {
                resetShakeState()
                return true
            }
        } else {
            lastHorizontalDirection = dir
        }
        return false
    }
}
