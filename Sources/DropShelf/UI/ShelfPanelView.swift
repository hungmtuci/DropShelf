import SwiftUI
import AppKit

struct VisualEffectGlassView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

struct ShelfPanelView: View {
    @ObservedObject var store: ShelfStore
    @ObservedObject var settings: AppSettings
    @ObservedObject var panelController: ShelfPanelController

    var body: some View {
        ZStack {
            VisualEffectGlassView(material: .popover, blendingMode: .behindWindow)

            VStack(spacing: 8) {
                headerBar

                dropTargetBanner

                if !store.entries.isEmpty {
                    entriesScrollList
                }

                footerBar
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    panelController.isIncomingDragTargeted
                        ? Color.accentColor.opacity(0.95)
                        : Color.primary.opacity(0.16),
                    lineWidth: panelController.isIncomingDragTargeted ? 2.2 : 1.0
                )
        )
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("DropShelf")
                .font(.system(size: 12.5, weight: .bold))

            if store.totalFileCount > 0 {
                Text("\(store.totalFileCount)")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1.5)
                    .background(Color.accentColor.opacity(0.18))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }

            Spacer(minLength: 4)

            // Paste from Clipboard
            Button {
                if !store.addFromGeneralClipboard() {
                    NSSound.beep()
                }
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Dán tệp / ảnh / văn bản từ Clipboard (⌘V)")

            // Pin / Lock Shelf
            Button {
                settings.isShelfPinned.toggle()
            } label: {
                Image(systemName: settings.isShelfPinned ? "pin.fill" : "pin")
                    .font(.system(size: 11.5, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(settings.isShelfPinned ? Color.orange : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(settings.isShelfPinned ? "Đang ghim kệ luôn hiển thị (Nhấn để bỏ ghim)" : "Ghim kệ luôn hiển thị trên màn hình")

            // Clear Unpinned
            if !store.entries.isEmpty {
                Button {
                    store.clearUnpinnedEntries()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11.5, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Dọn sạch kệ tạm (Không xoá tệp gốc trên máy)")
            }

            // Open Settings
            Button {
                AppDelegate.shared?.showSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Mở Cài đặt & Tuỳ chọn (⌘,)")

            // Hide Shelf
            Button {
                panelController.hideShelf()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Ẩn kệ (\(settings.hotKeyBinding.readableDisplay))")
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Drop Zone

    private var dropTargetBanner: some View {
        let isEmpty = store.entries.isEmpty
        let targeted = panelController.isIncomingDragTargeted

        return VStack(spacing: isEmpty ? 8 : 4) {
            Image(systemName: targeted ? "arrow.down.doc.fill" : "plus.viewfinder")
                .font(.system(size: isEmpty ? 26 : 15, weight: .semibold))
                .foregroundStyle(targeted ? Color.accentColor : Color.secondary)

            Text(targeted ? "Thả vào đây để giữ trên kệ!" : (isEmpty ? "Kéo thả tệp vào đây" : "Thả thêm tệp mới vào kệ"))
                .font(.system(size: isEmpty ? 13 : 11.5, weight: .semibold))
                .foregroundStyle(targeted ? Color.accentColor : Color.primary)

            if isEmpty {
                Text("Hỗ trợ tệp, thư mục, nhiều tệp (Stack),\nhình ảnh web, liên kết & đoạn văn bản")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: isEmpty ? 148 : 48)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(targeted ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    targeted ? Color.accentColor : Color.primary.opacity(0.18),
                    style: StrokeStyle(lineWidth: targeted ? 1.8 : 1.1, dash: [5, 4])
                )
        )
    }

    // MARK: - Shelf Entries Scroll List

    private var entriesScrollList: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 7) {
                ForEach(store.entries) { entry in
                    VStack(spacing: 4) {
                        ShelfEntryCardView(
                            entry: entry,
                            store: store,
                            settings: settings,
                            isIncomingDragActive: panelController.isIncomingDragTargeted
                        )

                        if entry.isStack && store.expandedStackID == entry.id {
                            expandedStackDrawer(for: entry)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func expandedStackDrawer(for stack: ShelfEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Tệp trong nhóm (\(stack.items.count))")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    store.splitStack(entryID: stack.id)
                } label: {
                    Label("Tách rời tất cả", systemImage: "rectangle.split.2x1")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            ForEach(stack.items) { ref in
                let singleTempEntry = ShelfEntry(id: ref.id, items: [ref], isPinned: true)
                ZStack {
                    HStack(spacing: 7) {
                        Image(nsImage: store.iconOrThumbnail(for: ref))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                        Text(ref.displayName)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay(
                        ShelfDragSourceRepresentable(
                            entriesToDrag: [singleTempEntry],
                            primaryEntry: nil,
                            showContextMenu: false
                        )
                    )

                    HStack {
                        Spacer()
                        Button {
                            store.removeSubItem(fileID: ref.id, fromEntryID: stack.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 6)
                    }
                }
            }
        }
        .padding(.bottom, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 8) {
            if store.entries.count > 1 {
                ZStack {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text("Kéo tất cả (\(store.totalFileCount))")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.16))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
                    .overlay(
                        ShelfDragSourceRepresentable(
                            entriesToDrag: store.entries,
                            primaryEntry: nil,
                            showContextMenu: false
                        )
                    )
                }
                .help("Nhấn giữ và kéo nút này để kéo toàn bộ các tệp trên kệ ra cùng lúc")

                Spacer()

                Button {
                    store.combineAllIntoStack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 10))
                        Text("Gộp Stack")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.07))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Gộp tất cả các mục hiện có trên kệ thành 1 nhóm Stack")
            } else {
                Text("Giữ ⌥ khi kéo: Sao chép • Space: Xem nhanh")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Single Shelf Entry / Smart Stack Card

private struct ShelfEntryCardView: View {
    let entry: ShelfEntry
    @ObservedObject var store: ShelfStore
    @ObservedObject var settings: AppSettings
    let isIncomingDragActive: Bool

    private var isHovered: Bool {
        store.hoveredEntryID == entry.id
    }

    private var isSelected: Bool {
        store.selectedEntryID == entry.id
    }

    var body: some View {
        ZStack {
            // 1. Visual Card + AppKit Outgoing Drag Source Overlay
            HStack(spacing: 10) {
                thumbnailView

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 4) {
                        if entry.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                        Text(entry.displayTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    HStack(spacing: 5) {
                        if let badge = entry.primaryItem?.kind.badgeLabel, !entry.isStack {
                            Text(badge)
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1)
                                .background(Color.indigo.opacity(0.16))
                                .foregroundStyle(Color.indigo)
                                .clipShape(Capsule())
                        }
                        Text(entry.subtitleText)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: isHovered ? 64 : 6)
            }
            .padding(.horizontal, 9)
            .frame(height: settings.shelfSize.cardHeight)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.14)
                            : (isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.045))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.09),
                        lineWidth: 1
                    )
            )
            .overlay(
                ShelfDragSourceRepresentable(
                    entriesToDrag: [entry],
                    primaryEntry: entry,
                    showContextMenu: true
                )
            )
            .overlay(
                // Allow dropping another dragged file directly onto this card to merge into a Stack!
                StackMergeDropZoneRepresentable(targetEntryID: entry.id)
            )

            // 2. Quick Hover Action Buttons (Top Z-Layer so clicks trigger cleanly)
            if isHovered && !isIncomingDragActive {
                HStack(spacing: 3) {
                    Spacer()

                    if entry.isStack {
                        cardIconButton(
                            symbol: store.expandedStackID == entry.id ? "chevron.up.circle.fill" : "square.stack.3d.up",
                            help: "Xem / Tách từng tệp trong nhóm Stack"
                        ) {
                            if store.expandedStackID == entry.id {
                                store.expandedStackID = nil
                            } else {
                                store.expandedStackID = entry.id
                            }
                            ShelfPanelController.shared.resizePanelToFitContent(animated: true)
                        }
                    }

                    cardIconButton(
                        symbol: "eye",
                        help: "Xem nhanh Quick Look (Phím Space)"
                    ) {
                        QuickLookCoordinator.shared.toggleQuickLook(for: entry)
                    }

                    cardIconButton(
                        symbol: entry.isPinned ? "pin.slash.fill" : "pin",
                        tint: entry.isPinned ? .orange : .secondary,
                        help: entry.isPinned ? "Bỏ ghim mục này" : "Ghim giữ mục này trên kệ"
                    ) {
                        store.togglePin(entryID: entry.id)
                    }

                    cardIconButton(
                        symbol: "xmark",
                        help: "Gỡ khỏi kệ (Không xoá tệp gốc)"
                    ) {
                        store.removeEntry(entryID: entry.id)
                    }
                }
                .padding(.trailing, 7)
            }
        }
    }

    private var thumbnailView: some View {
        ZStack(alignment: .bottomTrailing) {
            if entry.isStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(7))
                    .offset(x: 2, y: -2)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(-5))
                    .offset(x: -2, y: 1)
            }

            if let primary = entry.primaryItem {
                Image(nsImage: store.iconOrThumbnail(for: primary))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            if entry.isStack {
                Text("\(entry.items.count)")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .offset(x: 4, y: 4)
            }
        }
        .frame(width: 44, height: 44)
    }

    private func cardIconButton(
        symbol: String,
        tint: Color = .secondary,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.88))
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
