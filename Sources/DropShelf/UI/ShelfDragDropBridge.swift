import Foundation
import AppKit
import SwiftUI

// MARK: - Custom Pasteboard Writer for Web / Text Snippets

final class SnippetPasteboardWriter: NSObject, NSPasteboardWriting {
    private let fileURL: NSURL
    private let webURLString: String?
    private let textBody: String?

    init(fileURL: URL, webURLString: String?, textBody: String?) {
        self.fileURL = fileURL as NSURL
        self.webURLString = webURLString
        self.textBody = textBody
        super.init()
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        var types = fileURL.writableTypes(for: pasteboard)
        if webURLString != nil && !types.contains(.URL) {
            types.append(.URL)
        }
        if (textBody != nil || webURLString != nil) && !types.contains(.string) {
            types.append(.string)
        }
        return types
    }

    func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        if fileURL.writableTypes(for: pasteboard).contains(type) {
            return fileURL.writingOptions(forType: type, pasteboard: pasteboard)
        }
        return []
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        if type == .URL, let webStr = webURLString, let url = NSURL(string: webStr) {
            return url.pasteboardPropertyList(forType: .URL)
        }
        if type == .string {
            if let text = textBody {
                return text
            }
            if let webStr = webURLString {
                return webStr
            }
        }
        return fileURL.pasteboardPropertyList(forType: type)
    }
}

// MARK: - Root Drop Container NSView (Wraps Shelf Panel Content & Status Bar Icon)

final class ShelfRootDropContainerView: NSView {
    var onDragTargetedChanged: ((Bool) -> Void)?
    var onDropCompleted: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerAllSupportedTypes()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerAllSupportedTypes()
    }

    private func registerAllSupportedTypes() {
        var types: [NSPasteboard.PasteboardType] = [
            .fileURL,
            .png,
            .tiff,
            .pdf,
            .URL,
            .rtf,
            .string
        ]
        types.append(contentsOf: NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
        registerForDraggedTypes(types)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !ShelfStore.shared.isDraggingOutFromShelf else { return [] }
        let op = preferredIncomingOperation(for: sender.draggingPasteboard)
        if op != [] {
            Task { @MainActor in
                self.onDragTargetedChanged?(true)
            }
        }
        return op
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !ShelfStore.shared.isDraggingOutFromShelf else { return [] }
        return preferredIncomingOperation(for: sender.draggingPasteboard)
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        Task { @MainActor in
            self.onDragTargetedChanged?(false)
        }
    }

    override func draggingEnded(_ sender: any NSDraggingInfo) {
        Task { @MainActor in
            self.onDragTargetedChanged?(false)
        }
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard !ShelfStore.shared.isDraggingOutFromShelf else { return false }
        let pb = sender.draggingPasteboard

        // 1. Check File Promises (e.g. Apple Photos, Safari promised media, Mail attachments)
        if let receivers = pb.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver],
           !receivers.isEmpty {
            let destFolder = AppSettings.shared.appSupportDirectory
                .appendingPathComponent("Snippets", isDirectory: true)
                .appendingPathComponent("Promised-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)

            let queue = OperationQueue()
            queue.qualityOfService = .userInitiated
            for receiver in receivers {
                receiver.receivePromisedFiles(atDestination: destFolder, options: [:], operationQueue: queue) { fileURL, error in
                    guard error == nil else { return }
                    Task { @MainActor in
                        ShelfStore.shared.addFileURLs([fileURL])
                        ShelfPanelController.shared.markDropReceived()
                        self.onDragTargetedChanged?(false)
                        self.onDropCompleted?()
                    }
                }
            }
            return true
        }

        // 2. Standard Files / Images / Links / Text
        var accepted = false
        MainActor.assumeIsolated {
            accepted = ShelfStore.shared.ingestPasteboard(pb)
            self.onDragTargetedChanged?(false)
            if accepted {
                ShelfPanelController.shared.markDropReceived()
                self.onDropCompleted?()
            }
        }
        return accepted
    }

    private func preferredIncomingOperation(for pb: NSPasteboard) -> NSDragOperation {
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            // Returning .generic tells Finder we accept the drop onto our holding shelf
            // WITHOUT deleting the source file OR showing a misleading green '+' copy badge!
            return .generic
        }
        if pb.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil) {
            return .copy
        }
        if pb.availableType(from: [.png, .tiff, .pdf, .URL, .rtf, .string]) != nil {
            return .copy
        }
        return []
    }
}

// MARK: - Per-Card Merge Drop Target Badge ("+ Gộp Stack")

struct StackMergeDropZoneRepresentable: NSViewRepresentable {
    let targetEntryID: UUID

    func makeNSView(context: Context) -> StackMergeDropNSView {
        let view = StackMergeDropNSView()
        view.targetEntryID = targetEntryID
        return view
    }

    func updateNSView(_ nsView: StackMergeDropNSView, context: Context) {
        nsView.targetEntryID = targetEntryID
    }
}

final class StackMergeDropNSView: NSView {
    var targetEntryID: UUID?
    private var isTargeted = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL, .png, .tiff, .URL, .string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .png, .tiff, .URL, .string])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
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
        guard let id = targetEntryID else { return false }
        var ok = false
        MainActor.assumeIsolated {
            ok = ShelfStore.shared.ingestPasteboard(sender.draggingPasteboard, mergeIntoEntryID: id)
            if ok {
                ShelfPanelController.shared.markDropReceived()
            }
        }
        return ok
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard isTargeted else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)
        NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
        path.fill()
        NSColor.controlAccentColor.setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}

// MARK: - Outgoing Native AppKit Drag Source Surface (Supports Single Item, Stack, or Batch All)

struct ShelfDragSourceRepresentable: NSViewRepresentable {
    let entriesToDrag: [ShelfEntry]
    let primaryEntry: ShelfEntry?
    let showContextMenu: Bool

    func makeNSView(context: Context) -> ShelfDragSourceNSView {
        let view = ShelfDragSourceNSView()
        view.entriesToDrag = entriesToDrag
        view.primaryEntry = primaryEntry
        view.showContextMenu = showContextMenu
        return view
    }

    func updateNSView(_ nsView: ShelfDragSourceNSView, context: Context) {
        nsView.entriesToDrag = entriesToDrag
        nsView.primaryEntry = primaryEntry
        nsView.showContextMenu = showContextMenu
    }
}

final class ShelfDragSourceNSView: NSView, NSDraggingSource {
    var entriesToDrag: [ShelfEntry] = []
    var primaryEntry: ShelfEntry?
    var showContextMenu: Bool = true

    private var mouseDownEvent: NSEvent?
    private var didStartDragSession = false
    private var trackingAreaRef: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Allows 1-gesture drag straight out of the non-activating shelf without clicking twice!
        true
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .openHand)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard let entry = primaryEntry else { return }
        MainActor.assumeIsolated {
            ShelfStore.shared.hoveredEntryID = entry.id
        }
    }

    override func mouseExited(with event: NSEvent) {
        guard let entry = primaryEntry else { return }
        MainActor.assumeIsolated {
            if ShelfStore.shared.hoveredEntryID == entry.id {
                ShelfStore.shared.hoveredEntryID = nil
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        didStartDragSession = false
        if let entry = primaryEntry {
            MainActor.assumeIsolated {
                ShelfStore.shared.selectedEntryID = entry.id
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didStartDragSession, let downEvent = mouseDownEvent else { return }
        let p0 = convert(downEvent.locationInWindow, from: nil)
        let p1 = convert(event.locationInWindow, from: nil)
        guard hypot(p1.x - p0.x, p1.y - p0.y) >= 3.5 else { return }

        didStartDragSession = true
        MainActor.assumeIsolated {
            startOutgoingDrag(from: downEvent)
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownEvent = nil
            didStartDragSession = false
        }
        guard !didStartDragSession, let entry = primaryEntry else { return }
        if event.clickCount == 2 {
            MainActor.assumeIsolated {
                if entry.isStack {
                    if ShelfStore.shared.expandedStackID == entry.id {
                        ShelfStore.shared.expandedStackID = nil
                    } else {
                        ShelfStore.shared.expandedStackID = entry.id
                    }
                    ShelfPanelController.shared.resizePanelToFitContent(animated: true)
                } else {
                    ShelfStore.shared.openEntry(entry)
                }
            }
        }
    }

    @MainActor
    private func startOutgoingDrag(from downEvent: NSEvent) {
        var draggingItems: [NSDraggingItem] = []
        let allRefs = entriesToDrag.flatMap(\.items)

        for (idx, ref) in allRefs.enumerated() {
            let resolved = ref.resolvedURL()
            guard FileManager.default.fileExists(atPath: resolved.path) else { continue }

            let writer: any NSPasteboardWriting
            if ref.kind == .urlSnippet || ref.kind == .textSnippet {
                let textBody: String? = (ref.kind == .textSnippet) ? (try? String(contentsOf: resolved, encoding: .utf8)) : nil
                writer = SnippetPasteboardWriter(
                    fileURL: resolved,
                    webURLString: ref.webURLString,
                    textBody: textBody
                )
            } else {
                writer = resolved as NSURL
            }

            let dragItem = NSDraggingItem(pasteboardWriter: writer)
            let thumb = Self.makeDragPreviewImage(for: ShelfStore.shared.iconOrThumbnail(for: ref))
            let offset = CGFloat(min(idx, 4)) * 3.0
            let previewFrame = NSRect(
                x: max(8, (bounds.width - 52) / 2 + offset),
                y: max(4, (bounds.height - 52) / 2 - offset),
                width: 52,
                height: 52
            )
            dragItem.setDraggingFrame(previewFrame, contents: thumb)
            draggingItems.append(dragItem)
        }

        guard !draggingItems.isEmpty else { return }

        ShelfStore.shared.isDraggingOutFromShelf = true
        let session = beginDraggingSession(with: draggingItems, event: downEvent, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        if draggingItems.count > 1 {
            session.draggingFormation = .pile
        }
        DragMonitorService.shared.markOutgoingShelfDragStarted()
    }

    private static func makeDragPreviewImage(for source: NSImage) -> NSImage {
        let size = NSSize(width: 52, height: 52)
        let img = NSImage(size: size)
        img.lockFocus()
        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
        let clip = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)
        NSGraphicsContext.current?.saveGraphicsState()
        clip.addClip()
        source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.96)
        NSGraphicsContext.current?.restoreGraphicsState()
        img.unlockFocus()
        return img
    }

    // MARK: - NSDraggingSource

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        if context == .withinApplication {
            return []
        }

        let flags = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == [.option] {
            return .copy
        }
        if flags == [.command] {
            return [.move, .copy]
        }
        if flags == [.control, .option] || flags == [.command, .option] {
            return .link
        }

        var anyPinned = false
        var preferCopy = false
        MainActor.assumeIsolated {
            anyPinned = entriesToDrag.contains(where: \.isPinned)
            preferCopy = (AppSettings.shared.dragOutBehavior == .copyByDefault)
        }

        if anyPinned || preferCopy {
            return [.copy, .link, .generic]
        }
        // Yoink / Native Finder behavior: Move on same drive, Copy across drives or into apps (Mail/Browser), Option forces Copy!
        return [.move, .copy, .link, .generic]
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let draggedIDs = entriesToDrag.map(\.id)
        Task { @MainActor in
            ShelfStore.shared.didFinishDraggingOut(entryIDs: draggedIDs, operation: operation)
        }
    }

    // MARK: - Right-Click Context Menu

    override func menu(for event: NSEvent) -> NSMenu? {
        guard showContextMenu, let entry = primaryEntry else { return nil }
        let menu = NSMenu()

        let qlItem = NSMenuItem(title: "Xem nhanh (Quick Look)", action: #selector(quickLookAction), keyEquivalent: " ")
        qlItem.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
        qlItem.target = self
        menu.addItem(qlItem)

        let openItem = NSMenuItem(title: entry.isStack ? "Mở tất cả tệp trong nhóm" : "Mở tệp", action: #selector(openEntryAction), keyEquivalent: "")
        openItem.image = NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: nil)
        openItem.target = self
        menu.addItem(openItem)

        let revealItem = NSMenuItem(title: "Hiển thị trong Finder", action: #selector(revealInFinderAction), keyEquivalent: "")
        revealItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        revealItem.target = self
        menu.addItem(revealItem)

        let copyItem = NSMenuItem(title: "Sao chép vào Clipboard", action: #selector(copyEntryAction), keyEquivalent: "")
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        copyItem.target = self
        menu.addItem(copyItem)

        menu.addItem(.separator())

        let pinTitle = entry.isPinned ? "Bỏ ghim khỏi kệ" : "Ghim giữ cố định trên kệ"
        let pinItem = NSMenuItem(title: pinTitle, action: #selector(togglePinAction), keyEquivalent: "")
        pinItem.image = NSImage(systemSymbolName: entry.isPinned ? "pin.slash" : "pin.fill", accessibilityDescription: nil)
        pinItem.target = self
        menu.addItem(pinItem)

        if entry.isStack {
            let expandTitle = (MainActor.assumeIsolated { ShelfStore.shared.expandedStackID == entry.id })
                ? "Thu gọn danh sách nhóm"
                : "Xem từng tệp trong nhóm (\(entry.items.count))"
            let expandItem = NSMenuItem(title: expandTitle, action: #selector(toggleExpandStackAction), keyEquivalent: "")
            expandItem.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: nil)
            expandItem.target = self
            menu.addItem(expandItem)

            let splitItem = NSMenuItem(title: "Tách nhóm thành từng mục rời", action: #selector(splitStackAction), keyEquivalent: "")
            splitItem.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: nil)
            splitItem.target = self
            menu.addItem(splitItem)
        }

        menu.addItem(.separator())

        let removeItem = NSMenuItem(title: "Gỡ khỏi kệ tạm (Không xoá tệp gốc)", action: #selector(removeEntryAction), keyEquivalent: "")
        removeItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        removeItem.target = self
        menu.addItem(removeItem)

        return menu
    }

    @objc private func quickLookAction() {
        guard let entry = primaryEntry else { return }
        MainActor.assumeIsolated {
            QuickLookCoordinator.shared.toggleQuickLook(for: entry)
        }
    }

    @objc private func openEntryAction() {
        guard let entry = primaryEntry else { return }
        MainActor.assumeIsolated {
            ShelfStore.shared.openEntry(entry)
        }
    }

    @objc private func revealInFinderAction() {
        guard let entry = primaryEntry else { return }
        MainActor.assumeIsolated {
            ShelfStore.shared.revealInFinder(entry: entry)
        }
    }

    @objc private func copyEntryAction() {
        guard let entry = primaryEntry else { return }
        MainActor.assumeIsolated {
            ShelfStore.shared.copyEntryToClipboard(entry)
        }
    }

    @objc private func togglePinAction() {
        guard let entry = primaryEntry else { return }
        MainActor.assumeIsolated {
            ShelfStore.shared.togglePin(entryID: entry.id)
        }
    }

    @objc private func toggleExpandStackAction() {
        guard let entry = primaryEntry else { return }
        MainActor.assumeIsolated {
            if ShelfStore.shared.expandedStackID == entry.id {
                ShelfStore.shared.expandedStackID = nil
            } else {
                ShelfStore.shared.expandedStackID = entry.id
            }
            ShelfPanelController.shared.resizePanelToFitContent(animated: true)
        }
    }

    @objc private func splitStackAction() {
        guard let entry = primaryEntry else { return }
        MainActor.assumeIsolated {
            ShelfStore.shared.splitStack(entryID: entry.id)
        }
    }

    @objc private func removeEntryAction() {
        guard let entry = primaryEntry else { return }
        MainActor.assumeIsolated {
            ShelfStore.shared.removeEntry(entryID: entry.id)
        }
    }
}
