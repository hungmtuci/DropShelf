import Foundation
import AppKit

enum ShelfItemKind: String, Codable, Sendable {
    case file
    case folder
    case imageSnippet
    case textSnippet
    case urlSnippet

    var badgeLabel: String? {
        switch self {
        case .file: return nil
        case .folder: return "Thư mục"
        case .imageSnippet: return "Ảnh tạm"
        case .textSnippet: return "Văn bản"
        case .urlSnippet: return "Liên kết"
        }
    }
}

struct ShelfFileRef: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var originalPath: String
    var bookmarkData: Data?
    var kind: ShelfItemKind
    var isTemporarySnippet: Bool
    var customTitle: String?
    var webURLString: String?
    var textPreview: String?
    var cachedByteSize: Int64

    init(
        id: UUID = UUID(),
        url: URL,
        kind: ShelfItemKind? = nil,
        isTemporarySnippet: Bool = false,
        customTitle: String? = nil,
        webURLString: String? = nil,
        textPreview: String? = nil
    ) {
        self.id = id
        let standardized = url.standardizedFileURL
        self.originalPath = standardized.path
        self.bookmarkData = try? standardized.bookmarkData(
            options: [.minimalBookmark],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDir)
        if let explicitKind = kind {
            self.kind = explicitKind
        } else {
            self.kind = (exists && isDir.boolValue) ? .folder : .file
        }

        self.isTemporarySnippet = isTemporarySnippet
        self.customTitle = customTitle
        self.webURLString = webURLString
        self.textPreview = textPreview
        self.cachedByteSize = Self.computeItemByteSize(at: standardized, isDirectory: isDir.boolValue)
    }

    /// Resolves APFS file reference bookmark so moved or renamed files on the same volume stay tracked automatically.
    func resolvedURL() -> URL {
        if let data = bookmarkData {
            var isStale = false
            if let resolved = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI, .withoutMounting],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return resolved.standardizedFileURL
            }
        }
        return URL(fileURLWithPath: originalPath).standardizedFileURL
    }

    var existsOnDisk: Bool {
        FileManager.default.fileExists(atPath: resolvedURL().path)
    }

    var displayName: String {
        if let custom = customTitle, !custom.isEmpty {
            return custom
        }
        let url = resolvedURL()
        let name = url.lastPathComponent
        return name.isEmpty ? originalPath : name
    }

    var parentFolderName: String {
        let parent = resolvedURL().deletingLastPathComponent().lastPathComponent
        return parent.isEmpty ? "/" : parent
    }

    static func computeItemByteSize(at url: URL, isDirectory: Bool) -> Int64 {
        if !isDirectory {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
            if let size = values?.fileSize {
                return Int64(size)
            }
            if let alloc = values?.totalFileAllocatedSize {
                return Int64(alloc)
            }
            return 0
        }
        // Lightweight shallow folder size estimate (avoid deep traversal blocking)
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var total: Int64 = 0
        for child in children.prefix(200) {
            if let size = try? child.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}

struct ShelfEntry: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var items: [ShelfFileRef]
    var isPinned: Bool
    var createdAt: Date
    var stackTitle: String?

    init(
        id: UUID = UUID(),
        items: [ShelfFileRef],
        isPinned: Bool = false,
        createdAt: Date = Date(),
        stackTitle: String? = nil
    ) {
        self.id = id
        self.items = items
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.stackTitle = stackTitle
    }

    var isStack: Bool {
        items.count > 1
    }

    var primaryItem: ShelfFileRef? {
        items.first
    }

    var totalBytes: Int64 {
        items.reduce(0) { $0 + max(0, $1.cachedByteSize) }
    }

    var displayTitle: String {
        if let customStack = stackTitle, !customStack.isEmpty {
            return customStack
        }
        guard let first = items.first else { return "Mục trống" }
        if items.count == 1 {
            return first.displayName
        }
        return "\(first.displayName) + \(items.count - 1) mục"
    }

    var subtitleText: String {
        let existingCount = items.filter(\.existsOnDisk).count
        if existingCount == 0 {
            return "Tệp gốc không còn tồn tại"
        }

        let sizeStr = Self.formatBytes(totalBytes)
        if items.count > 1 {
            return sizeStr.isEmpty ? "\(items.count) mục trong nhóm" : "\(items.count) mục • \(sizeStr)"
        }

        guard let only = items.first else { return "" }
        switch only.kind {
        case .folder:
            return sizeStr.isEmpty ? "Thư mục • \(only.parentFolderName)" : "Thư mục • \(sizeStr)"
        case .imageSnippet:
            return sizeStr.isEmpty ? "Ảnh chụp / Web tạm" : "Ảnh tạm • \(sizeStr)"
        case .textSnippet:
            if let preview = only.textPreview, !preview.isEmpty {
                return preview
            }
            return "Đoạn văn bản • \(sizeStr)"
        case .urlSnippet:
            return only.webURLString ?? "Liên kết Web"
        case .file:
            if sizeStr.isEmpty {
                return only.parentFolderName
            }
            return "\(sizeStr) • \(only.parentFolderName)"
        }
    }

    func existingURLs() -> [URL] {
        items.map { $0.resolvedURL() }.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    mutating func refreshBookmarksAfterMove() {
        for idx in items.indices {
            let resolved = items[idx].resolvedURL()
            if FileManager.default.fileExists(atPath: resolved.path) {
                items[idx].originalPath = resolved.path
                items[idx].bookmarkData = try? resolved.bookmarkData(
                    options: [.minimalBookmark],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
            }
        }
    }

    static func formatBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
