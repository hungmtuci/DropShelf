import Foundation
import AppKit
import QuickLookThumbnailing

@MainActor
final class ShelfStore: ObservableObject {
    static let shared = ShelfStore()

    @Published private(set) var entries: [ShelfEntry] = []
    @Published var selectedEntryID: UUID? = nil
    @Published var hoveredEntryID: UUID? = nil
    @Published var expandedStackID: UUID? = nil
    @Published private(set) var thumbnails: [String: NSImage] = [:]

    /// Set to `true` while the user is actively dragging an item OUT of DropShelf,
    /// preventing DragMonitorService from treating our own outgoing drag as a new incoming drag.
    var isDraggingOutFromShelf: Bool = false

    private let shelfFileURL: URL
    private let snippetsDirectoryURL: URL

    var totalFileCount: Int {
        entries.reduce(0) { $0 + $1.items.count }
    }

    private init() {
        let supportDir = AppSettings.shared.appSupportDirectory
        self.shelfFileURL = supportDir.appendingPathComponent("shelf_entries.json")
        self.snippetsDirectoryURL = supportDir.appendingPathComponent("Snippets", isDirectory: true)
        try? FileManager.default.createDirectory(at: snippetsDirectoryURL, withIntermediateDirectories: true)

        if AppSettings.shared.persistItemsAcrossLaunches {
            loadPersistedShelf()
        }
    }

    // MARK: - Persistence

    private func loadPersistedShelf() {
        guard let data = try? Data(contentsOf: shelfFileURL),
              let decoded = try? JSONDecoder().decode([ShelfEntry].self, from: data) else {
            return
        }
        let valid = decoded.compactMap { entry -> ShelfEntry? in
            var copy = entry
            copy.refreshBookmarksAfterMove()
            let existingItems = copy.items.filter { $0.existsOnDisk }
            guard !existingItems.isEmpty else { return nil }
            copy.items = existingItems
            return copy
        }
        self.entries = valid
        for entry in valid {
            warmThumbnails(for: entry)
        }
    }

    func saveShelfIfNeeded() {
        let targetURL = shelfFileURL
        guard AppSettings.shared.persistItemsAcrossLaunches else {
            DispatchQueue.global(qos: .utility).async {
                try? FileManager.default.removeItem(at: targetURL)
            }
            return
        }
        let snapshot = entries
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: targetURL, options: .atomic)
            }
        }
    }

    private func notifyShelfContentMutated() {
        saveShelfIfNeeded()
        StatusBarController.shared.refreshBadge()
        ShelfPanelController.shared.scheduleEmptyAutoHideIfNeeded()
    }

    // MARK: - Automatic Screenshot Ingestion

    func addCapturedScreenshotFile(_ rawURL: URL) {
        let url = rawURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        // Avoid duplicating if already present on the shelf
        let alreadyOnShelf = entries.contains { entry in
            entry.items.contains { $0.resolvedURL().path == url.path }
        }
        guard !alreadyOnShelf else { return }

        let ref = ShelfFileRef(url: url, kind: .screenshot)
        let entry = ShelfEntry(items: [ref])
        entries.insert(entry, at: 0)
        selectedEntryID = entry.id
        warmThumbnails(for: entry)
        notifyShelfContentMutated()
        ShelfPanelController.shared.summonForCapturedScreenshot()
    }

    func addClipboardScreenshotImage(_ image: NSImage) {
        guard let pngData = Self.pngData(from: image) else { return }
        let stamp = Self.timestampToken()
        let readableTime = Self.humanTimeToken()
        guard let ref = createTemporarySnippetFile(
            data: pngData,
            fileName: "Anh-chup-man-hinh-\(stamp).png",
            kind: .screenshot,
            customTitle: "Ảnh chụp \(readableTime) (\(Int(image.size.width))×\(Int(image.size.height)))"
        ) else {
            return
        }

        let entry = ShelfEntry(items: [ref])
        entries.insert(entry, at: 0)
        selectedEntryID = entry.id
        warmThumbnails(for: entry)
        notifyShelfContentMutated()
        ShelfPanelController.shared.summonForCapturedScreenshot()
    }

    // MARK: - Adding Files & Pasteboard Content

    @discardableResult
    func addFileURLs(
        _ rawURLs: [URL],
        forceIndividual: Bool = false,
        mergeIntoEntryID: UUID? = nil
    ) -> Bool {
        var seen = Set<String>()
        var validRefs: [ShelfFileRef] = []

        for raw in rawURLs {
            let url = raw.standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            guard seen.insert(url.path).inserted else { continue }
            validRefs.append(ShelfFileRef(url: url))
        }

        guard !validRefs.isEmpty else { return false }

        if let targetID = mergeIntoEntryID,
           let idx = entries.firstIndex(where: { $0.id == targetID }) {
            let existingPaths = Set(entries[idx].items.map { $0.resolvedURL().path })
            let newUnique = validRefs.filter { !existingPaths.contains($0.resolvedURL().path) }
            if !newUnique.isEmpty {
                entries[idx].items.append(contentsOf: newUnique)
                selectedEntryID = entries[idx].id
                warmThumbnails(for: entries[idx])
                notifyShelfContentMutated()
            }
            return true
        }

        if validRefs.count > 1 && AppSettings.shared.autoStackMultipleFiles && !forceIndividual {
            let stackEntry = ShelfEntry(items: validRefs)
            entries.insert(stackEntry, at: 0)
            selectedEntryID = stackEntry.id
            warmThumbnails(for: stackEntry)
        } else {
            for ref in validRefs.reversed() {
                let single = ShelfEntry(items: [ref])
                entries.insert(single, at: 0)
                selectedEntryID = single.id
                warmThumbnails(for: single)
            }
        }

        notifyShelfContentMutated()
        return true
    }

    @discardableResult
    func ingestPasteboard(_ pasteboard: NSPasteboard, mergeIntoEntryID: UUID? = nil) -> Bool {
        // 1. Native File URLs
        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !fileURLs.isEmpty {
            return addFileURLs(fileURLs, mergeIntoEntryID: mergeIntoEntryID)
        }

        // 2. Images
        if let image = NSImage(pasteboard: pasteboard),
           let pngData = Self.pngData(from: image) {
            if let snippetRef = createTemporarySnippetFile(
                data: pngData,
                fileName: "Hinh-anh-\(Self.timestampToken()).png",
                kind: .imageSnippet,
                customTitle: "Ảnh tạm (\(Int(image.size.width))×\(Int(image.size.height)))"
            ) {
                insertSnippetRef(snippetRef, mergeIntoEntryID: mergeIntoEntryID)
                return true
            }
        }

        // 3. Web URLs
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: false]
        ) as? [URL],
           let webURL = urls.first(where: { !$0.isFileURL && ($0.scheme == "http" || $0.scheme == "https") }) {
            let host = webURL.host ?? "Web"
            let weblocDict: [String: String] = ["URL": webURL.absoluteString]
            if let plistData = try? PropertyListSerialization.data(
                fromPropertyList: weblocDict,
                format: .xml,
                options: 0
            ),
               let snippetRef = createTemporarySnippetFile(
                data: plistData,
                fileName: "Lien-ket-\(Self.sanitizeFileName(host))-\(Self.timestampToken()).webloc",
                kind: .urlSnippet,
                customTitle: host,
                webURLString: webURL.absoluteString
               ) {
                insertSnippetRef(snippetRef, mergeIntoEntryID: mergeIntoEntryID)
                return true
            }
        }

        // 4. Plain / Rich Text selections
        if let rawText = pasteboard.string(forType: .string) {
            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if let detectedURL = URL(string: trimmed),
                   (detectedURL.scheme == "http" || detectedURL.scheme == "https"),
                   !trimmed.contains(" "), !trimmed.contains("\n") {
                    let host = detectedURL.host ?? "Web"
                    let weblocDict: [String: String] = ["URL": detectedURL.absoluteString]
                    if let plistData = try? PropertyListSerialization.data(
                        fromPropertyList: weblocDict,
                        format: .xml,
                        options: 0
                    ),
                       let snippetRef = createTemporarySnippetFile(
                        data: plistData,
                        fileName: "Lien-ket-\(Self.sanitizeFileName(host))-\(Self.timestampToken()).webloc",
                        kind: .urlSnippet,
                        customTitle: host,
                        webURLString: detectedURL.absoluteString
                       ) {
                        insertSnippetRef(snippetRef, mergeIntoEntryID: mergeIntoEntryID)
                        return true
                    }
                }

                let firstLine = trimmed
                    .components(separatedBy: .newlines)
                    .first?
                    .trimmingCharacters(in: .whitespaces) ?? "Văn bản tạm"
                let shortTitle = String(firstLine.prefix(34))
                let preview = String(trimmed.replacingOccurrences(of: "\n", with: " ").prefix(60))

                if let utf8Data = rawText.data(using: .utf8),
                   let snippetRef = createTemporarySnippetFile(
                    data: utf8Data,
                    fileName: "Van-ban-\(Self.timestampToken()).txt",
                    kind: .textSnippet,
                    customTitle: shortTitle.isEmpty ? "Đoạn văn bản" : shortTitle,
                    textPreview: preview
                   ) {
                    insertSnippetRef(snippetRef, mergeIntoEntryID: mergeIntoEntryID)
                    return true
                }
            }
        }

        return false
    }

    @discardableResult
    func addFromGeneralClipboard() -> Bool {
        let ok = ingestPasteboard(.general)
        if ok {
            ShelfPanelController.shared.showShelfManually()
        }
        return ok
    }

    private func insertSnippetRef(_ ref: ShelfFileRef, mergeIntoEntryID: UUID?) {
        if let targetID = mergeIntoEntryID,
           let idx = entries.firstIndex(where: { $0.id == targetID }) {
            entries[idx].items.append(ref)
            selectedEntryID = entries[idx].id
            warmThumbnails(for: entries[idx])
        } else {
            let entry = ShelfEntry(items: [ref])
            entries.insert(entry, at: 0)
            selectedEntryID = entry.id
            warmThumbnails(for: entry)
        }
        notifyShelfContentMutated()
    }

    private func createTemporarySnippetFile(
        data: Data,
        fileName: String,
        kind: ShelfItemKind,
        customTitle: String? = nil,
        webURLString: String? = nil,
        textPreview: String? = nil
    ) -> ShelfFileRef? {
        let folder = snippetsDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let fileURL = folder.appendingPathComponent(fileName)
            try data.write(to: fileURL, options: .atomic)
            return ShelfFileRef(
                url: fileURL,
                kind: kind,
                isTemporarySnippet: true,
                customTitle: customTitle,
                webURLString: webURLString,
                textPreview: textPreview
            )
        } catch {
            return nil
        }
    }

    // MARK: - Outgoing Drag Completion

    func didFinishDraggingOut(entryIDs: [UUID], operation: NSDragOperation) {
        isDraggingOutFromShelf = false
        guard operation != [] else { return }

        let idSet = Set(entryIDs)
        var removedRefs: [ShelfFileRef] = []

        if AppSettings.shared.autoRemoveAfterDrop {
            var remaining: [ShelfEntry] = []
            for var entry in entries {
                if idSet.contains(entry.id) && !entry.isPinned {
                    removedRefs.append(contentsOf: entry.items)
                } else {
                    entry.refreshBookmarksAfterMove()
                    remaining.append(entry)
                }
            }
            entries = remaining
        } else {
            for idx in entries.indices where idSet.contains(entries[idx].id) {
                entries[idx].refreshBookmarksAfterMove()
            }
        }

        if let sel = selectedEntryID, !entries.contains(where: { $0.id == sel }) {
            selectedEntryID = entries.first?.id
        }

        scheduleCleanupForRemovedSnippets(removedRefs, delaySeconds: 30)
        notifyShelfContentMutated()

        if entries.isEmpty && !AppSettings.shared.isShelfPinned {
            ShelfPanelController.shared.dismissAfterLastItemDraggedOut()
        } else {
            ShelfPanelController.shared.resizePanelToFitContent(animated: true)
        }
    }

    // MARK: - Shelf Item & Stack Actions

    func togglePin(entryID: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[idx].isPinned.toggle()
        saveShelfIfNeeded()
    }

    func removeEntry(entryID: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let removed = entries.remove(at: idx)
        if expandedStackID == entryID {
            expandedStackID = nil
        }
        if selectedEntryID == entryID {
            selectedEntryID = entries.first?.id
        }
        scheduleCleanupForRemovedSnippets(removed.items, delaySeconds: 5)
        notifyShelfContentMutated()
        ShelfPanelController.shared.resizePanelToFitContent(animated: true)
    }

    func removeSubItem(fileID: UUID, fromEntryID entryID: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let removedItems = entries[idx].items.filter { $0.id == fileID }
        entries[idx].items.removeAll { $0.id == fileID }
        if entries[idx].items.isEmpty {
            entries.remove(at: idx)
            if expandedStackID == entryID {
                expandedStackID = nil
            }
        } else if entries[idx].items.count == 1 && expandedStackID == entryID {
            expandedStackID = nil
        }
        scheduleCleanupForRemovedSnippets(removedItems, delaySeconds: 5)
        notifyShelfContentMutated()
        ShelfPanelController.shared.resizePanelToFitContent(animated: true)
    }

    func splitStack(entryID: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let stack = entries[idx]
        guard stack.items.count > 1 else { return }
        let singles = stack.items.map { ShelfEntry(items: [$0], isPinned: stack.isPinned) }
        entries.replaceSubrange(idx...idx, with: singles)
        if expandedStackID == entryID {
            expandedStackID = nil
        }
        selectedEntryID = singles.first?.id
        for single in singles {
            warmThumbnails(for: single)
        }
        notifyShelfContentMutated()
        ShelfPanelController.shared.resizePanelToFitContent(animated: true)
    }

    func combineAllIntoStack() {
        guard entries.count > 1 else { return }
        var combinedRefs: [ShelfFileRef] = []
        var anyPinned = false
        for entry in entries {
            combinedRefs.append(contentsOf: entry.items)
            if entry.isPinned { anyPinned = true }
        }
        let merged = ShelfEntry(items: combinedRefs, isPinned: anyPinned)
        entries = [merged]
        expandedStackID = nil
        selectedEntryID = merged.id
        warmThumbnails(for: merged)
        notifyShelfContentMutated()
        ShelfPanelController.shared.resizePanelToFitContent(animated: true)
    }

    func clearUnpinnedEntries() {
        let removed = entries.filter { !$0.isPinned }
        entries.removeAll { !$0.isPinned }
        expandedStackID = nil
        selectedEntryID = entries.first?.id
        let refs = removed.flatMap(\.items)
        scheduleCleanupForRemovedSnippets(refs, delaySeconds: 5)
        notifyShelfContentMutated()
        ShelfPanelController.shared.resizePanelToFitContent(animated: true)
    }

    func revealInFinder(entry: ShelfEntry) {
        let urls = entry.existingURLs()
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func openEntry(_ entry: ShelfEntry) {
        for item in entry.items {
            if item.kind == .urlSnippet,
               let webStr = item.webURLString,
               let webURL = URL(string: webStr) {
                NSWorkspace.shared.open(webURL)
            } else {
                let url = item.resolvedURL()
                if FileManager.default.fileExists(atPath: url.path) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    func copyEntryToClipboard(_ entry: ShelfEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let urls = entry.existingURLs() as [NSURL]
        if !urls.isEmpty {
            pb.writeObjects(urls)
        }
        ScreenshotMonitorService.shared.markInternalClipboardWrite()
    }

    func createDemoSampleItems() {
        let demoText = """
        Xin chào từ DropShelf!
        Bạn có thể kéo tệp này ra Desktop, Finder, Mail, Zalo, Slack hoặc nhấn phím Space để Xem nhanh (Quick Look).
        Giữ phím Option (⌥) khi kéo ra Finder để Sao chép thay vì Di chuyển.
        """
        if let data = demoText.data(using: .utf8),
           let ref = createTemporarySnippetFile(
            data: data,
            fileName: "Huong-dan-DropShelf.txt",
            kind: .textSnippet,
            customTitle: "Huong-dan-DropShelf.txt",
            textPreview: "Kéo tệp này ra Finder hoặc nhấn Space để xem nhanh"
           ) {
            insertSnippetRef(ref, mergeIntoEntryID: nil)
            ShelfPanelController.shared.showShelfManually()
        }
    }

    private func scheduleCleanupForRemovedSnippets(_ refs: [ShelfFileRef], delaySeconds: TimeInterval) {
        let snippetFolders = refs.compactMap { ref -> URL? in
            guard ref.isTemporarySnippet else { return nil }
            let url = URL(fileURLWithPath: ref.originalPath)
            let parent = url.deletingLastPathComponent()
            guard parent.path.contains("/DropShelf/Snippets/") else { return nil }
            return parent
        }
        guard !snippetFolders.isEmpty else { return }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delaySeconds) {
            for folder in snippetFolders {
                try? FileManager.default.removeItem(at: folder)
            }
        }
    }

    // MARK: - QuickLook Thumbnail Generation

    func iconOrThumbnail(for ref: ShelfFileRef) -> NSImage {
        let url = ref.resolvedURL()
        if let cached = thumbnails[url.path] {
            return cached
        }
        if FileManager.default.fileExists(atPath: url.path) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "doc.questionmark", accessibilityDescription: nil)
            ?? NSWorkspace.shared.icon(forFile: "/tmp")
    }

    func warmThumbnails(for entry: ShelfEntry) {
        for ref in entry.items.prefix(3) {
            let url = ref.resolvedURL()
            let path = url.path
            guard thumbnails[path] == nil, FileManager.default.fileExists(atPath: path) else { continue }

            let fallbackIcon = NSWorkspace.shared.icon(forFile: path)
            fallbackIcon.size = NSSize(width: 48, height: 48)
            thumbnails[path] = fallbackIcon

            let req = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: 96, height: 96),
                scale: NSScreen.main?.backingScaleFactor ?? 2.0,
                representationTypes: .thumbnail
            )
            QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { [weak self] representation, _ in
                guard let nsImage = representation?.nsImage else { return }
                Task { @MainActor in
                    self?.thumbnails[path] = nsImage
                }
            }
        }
    }

    // MARK: - Formatting Helpers

    private static func timestampToken() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HHmmss"
        return fmt.string(from: Date())
    }

    private static func humanTimeToken() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: Date())
    }

    private static func sanitizeFileName(_ input: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = input.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        return String(cleaned).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}
