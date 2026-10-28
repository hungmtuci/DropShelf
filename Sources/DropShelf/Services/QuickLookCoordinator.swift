import Foundation
import AppKit
import QuickLookUI

@MainActor
final class QuickLookCoordinator: NSObject, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    static let shared = QuickLookCoordinator()

    private var previewURLs: [URL] = []

    private override init() {
        super.init()
    }

    func toggleQuickLook(for entry: ShelfEntry?) {
        guard let panel = QLPreviewPanel.shared() else { return }
        if QLPreviewPanel.sharedPreviewPanelExists() && panel.isVisible {
            panel.orderOut(nil)
            return
        }
        showQuickLook(for: entry)
    }

    func showQuickLook(for entry: ShelfEntry?) {
        let targetEntry = entry
            ?? ShelfStore.shared.entries.first(where: { $0.id == ShelfStore.shared.hoveredEntryID })
            ?? ShelfStore.shared.entries.first(where: { $0.id == ShelfStore.shared.selectedEntryID })
            ?? ShelfStore.shared.entries.first

        guard let validEntry = targetEntry else { return }
        let urls = validEntry.existingURLs()
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }

        previewURLs = urls
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
        panel.makeKeyAndOrderFront(nil)
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURLs.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard index >= 0 && index < previewURLs.count else { return nil }
        return previewURLs[index] as NSURL
    }
}
