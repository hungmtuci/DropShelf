import SwiftUI
import AppKit

struct SettingsDashboardView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: ShelfStore
    @ObservedObject var panelController: ShelfPanelController
    @ObservedObject var hotKeyService: HotKeyService
    @ObservedObject var screenshotService: ScreenshotMonitorService
    @ObservedObject var updateService: UpdateCheckerService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroCard

                if settings.shouldOfferMoveToApplications {
                    moveToApplicationsBanner
                }

                if !settings.statusBannerMessage.isEmpty {
                    statusBanner
                }

                screenshotAutoCaptureSection

                dockAndStartupSection

                positionAndAutoTriggerSection

                dragBehaviorAndShortcutsSection

                githubUpdateFooterSection
            }
            .padding(22)
        }
        .frame(minWidth: 740, minHeight: 680)
    }

    // MARK: - 1. Hero Card

    private var heroCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.indigo, Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.indigo.opacity(0.28), radius: 8, y: 4)

                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("DropShelf")
                        .font(.system(size: 19, weight: .bold))

                    Text("v\(updateService.currentVersion)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())

                    Text(panelController.isVisible ? "Kệ đang mở" : "Tự trượt khi kéo tệp / chụp màn hình")
                        .font(.system(size: 10.5, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background((panelController.isVisible ? Color.green : Color.secondary).opacity(0.15))
                        .foregroundStyle(panelController.isVisible ? Color.green : Color.secondary)
                        .clipShape(Capsule())
                }

                Text("Kệ tạm thời lấy cảm hứng từ Yoink — kéo thả tệp vào cạnh màn hình, tự động gom ảnh chụp màn hình mới và tự ẩn gọn sau 3 giây khi trống.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 7) {
                Button {
                    panelController.toggleShelf()
                } label: {
                    Label(
                        panelController.isVisible
                            ? "Ẩn Kệ nổi (\(settings.hotKeyBinding.readableDisplay))"
                            : "Hiện Kệ nổi ngay (\(settings.hotKeyBinding.readableDisplay))",
                        systemImage: "sidebar.right"
                    )
                    .font(.system(size: 12.5, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)

                HStack(spacing: 8) {
                    Button {
                        store.createDemoSampleItems()
                    } label: {
                        Label("Tạo tệp mẫu thử kéo thả", systemImage: "sparkles")
                            .font(.system(size: 11))
                    }
                    .controlSize(.small)

                    updateActionButton
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var updateActionButton: some View {
        switch updateService.state {
        case .available(let ver, _, _, _):
            Button {
                updateService.installAvailableUpdate()
            } label: {
                Label("Cập nhật v\(ver)", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)

        case .checking:
            Button {} label: {
                Label("Đang kiểm tra...", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
            }
            .controlSize(.small)
            .disabled(true)

        case .downloading(let ver):
            Button {} label: {
                Label("Đang tải v\(ver)...", systemImage: "arrow.down.circle")
                    .font(.system(size: 11))
            }
            .controlSize(.small)
            .disabled(true)

        case .installing(let ver):
            Button {} label: {
                Label("Đang cài v\(ver)...", systemImage: "gearshape.2")
                    .font(.system(size: 11))
            }
            .controlSize(.small)
            .disabled(true)

        default:
            Button {
                updateService.checkForUpdatesManually()
            } label: {
                Label("Kiểm tra cập nhật", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11))
            }
            .controlSize(.small)
        }
    }

    private var moveToApplicationsBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 18))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("DropShelf đang chạy ngoài thư mục /Applications")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("Di chuyển vào /Applications giúp cập nhật tự động từ GitHub và Khởi động cùng macOS hoạt động ổn định nhất.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Chuyển vào /Applications") {
                moveSelfToApplications()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    private var statusBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text(settings.statusBannerMessage)
                .font(.system(size: 12))
            Spacer()
            Button {
                settings.statusBannerMessage = ""
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.opacity(0.1))
        )
    }

    // MARK: - 2. Automatic Screenshot Capture Section

    private var screenshotAutoCaptureSection: some View {
        sectionContainer(
            title: "TỰ ĐỘNG ĐƯA HÌNH CHỤP MÀN HÌNH VÀO KỆ (SCREENSHOT AUTO-CAPTURE)",
            icon: "camera.viewfinder"
        ) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Toggle("Tự động nhận mọi hình chụp màn hình mới và bật Kệ ngay lập tức (⌘⇧3, ⌘⇧4, ⌘⇧5)", isOn: $settings.autoCaptureScreenshots)
                        .toggleStyle(.switch)
                        .font(.system(size: 12.5, weight: .semibold))

                    Spacer()

                    if settings.autoCaptureScreenshots {
                        Text("Đang theo dõi: \(screenshotService.primaryWatchedFolderDisplay)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.teal.opacity(0.14))
                            .foregroundStyle(Color.teal)
                            .clipShape(Capsule())
                    }
                }

                if settings.autoCaptureScreenshots {
                    Toggle("Tự động bắt cả ảnh chụp màn hình lưu vào Clipboard (⌘⌃⇧3 / ⌘⌃⇧4)", isOn: $settings.autoCaptureClipboardScreenshots)
                        .toggleStyle(.switch)
                        .font(.system(size: 12))

                    Divider()

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                screenshotService.isMacOSFloatingThumbnailEnabled
                                    ? "Mẹo tăng tốc: macOS đang bật 'Xem trước ảnh thu nhỏ góc dưới' (~4s sau khi chụp mới lưu tệp)"
                                    : "Chế độ Tức thì đang bật: Ảnh chụp màn hình nhảy thẳng vào DropShelf trong 0 giây!"
                            )
                            .font(.system(size: 11.5, weight: .medium))

                            Text("Bạn có thể tắt/bật chờ ảnh thu nhỏ góc dưới của macOS để ảnh nhảy vào kệ ngay khoảnh khắc thả chuột.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            screenshotService.setMacOSFloatingThumbnailEnabled(!screenshotService.isMacOSFloatingThumbnailEnabled)
                        } label: {
                            Text(
                                screenshotService.isMacOSFloatingThumbnailEnabled
                                    ? "Bật nhảy tức thì (0 giây)"
                                    : "Khôi phục ảnh góc macOS"
                            )
                            .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    // MARK: - 3. Dock Visibility & Startup Section

    private var dockAndStartupSection: some View {
        sectionContainer(
            title: "HIỂN THỊ TRÊN THANH DOCK & HỆ THỐNG",
            icon: "dock.rectangle"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    dockModeCard(
                        isSelected: settings.showInDock,
                        title: "Hiện trên thanh Dock & Menu Bar",
                        subtitle: "Hiển thị icon trên thanh Dock, Cmd+Tab và cho phép kéo thả tệp trực tiếp vào icon trên Dock.",
                        symbol: "dock.arrow.up.rectangle"
                    ) {
                        settings.showInDock = true
                    }

                    dockModeCard(
                        isSelected: !settings.showInDock,
                        title: "Ẩn khỏi thanh Dock (Chỉ Menu Bar)",
                        subtitle: "Ẩn hoàn toàn khỏi thanh Dock và Cmd+Tab để tối ưu không gian như tiện ích nền Yoink.",
                        symbol: "menubar.rectangle"
                    ) {
                        settings.showInDock = false
                    }
                }

                Divider()

                HStack(spacing: 24) {
                    Toggle("Tự khởi động cùng macOS", isOn: $settings.launchAtLogin)
                        .toggleStyle(.switch)
                        .font(.system(size: 12.5, weight: .medium))

                    Toggle("Mở cửa sổ Cài đặt khi khởi động ứng dụng", isOn: $settings.openSettingsOnLaunch)
                        .toggleStyle(.switch)
                        .font(.system(size: 12.5, weight: .medium))

                    Spacer()
                }
            }
        }
    }

    private func dockModeCard(
        isSelected: Bool,
        title: String,
        subtitle: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(title)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.5))
                    }
                    Text(subtitle)
                        .font(.system(size: 11.2))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.1),
                        lineWidth: isSelected ? 1.6 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 4. Screen Position, Auto-Show & 3-Second Empty Auto-Hide

    private var positionAndAutoTriggerSection: some View {
        sectionContainer(
            title: "VỊ TRÍ KỆ, TỰ ĐỘNG XUẤT HIỆN & TỰ ẨN SAU 3 GIÂY KHI TRỐNG",
            icon: "sparkles.rectangle.stack"
        ) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chọn nhanh vị trí neo Kệ")
                        .font(.system(size: 12, weight: .semibold))

                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.indigo.opacity(0.16), Color.cyan.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 236, height: 146)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.18), lineWidth: 1.2)
                            )

                        HStack {
                            VStack(spacing: 10) {
                                screenEdgeSlot(.leftTop, label: "Trái Trên")
                                screenEdgeSlot(.leftCenter, label: "Trái Giữa")
                                screenEdgeSlot(.leftBottom, label: "Trái Dưới")
                            }
                            Spacer()
                            Button {
                                settings.edgePosition = .freeFloating
                                panelController.showShelfManually()
                            } label: {
                                Text("Tự do")
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(
                                        settings.edgePosition == .freeFloating
                                            ? Color.accentColor
                                            : Color.primary.opacity(0.08)
                                    )
                                    .foregroundStyle(settings.edgePosition == .freeFloating ? .white : .secondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            VStack(spacing: 10) {
                                screenEdgeSlot(.rightTop, label: "Phải Trên")
                                screenEdgeSlot(.rightCenter, label: "Phải Giữa")
                                screenEdgeSlot(.rightBottom, label: "Phải Dưới")
                            }
                        }
                        .padding(10)
                        .frame(width: 236, height: 146)
                    }

                    Text("Đang chọn: \(settings.edgePosition.title)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 11) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Thời điểm tự động hiện Kệ khi kéo chuột")
                            .font(.system(size: 12, weight: .semibold))

                        Picker("", selection: $settings.autoShowTrigger) {
                            ForEach(AutoShowTrigger.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)

                        Text(settings.autoShowTrigger.shortNote)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 10) {
                        Text("Tự ẩn khi Kệ trống (lướt nhầm chuột):")
                            .font(.system(size: 12, weight: .semibold))
                        Picker("", selection: $settings.emptyAutoHideOption) {
                            ForEach(EmptyAutoHideOption.allCases) { opt in
                                Text(opt.title).tag(opt)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 175)
                    }

                    HStack(spacing: 16) {
                        Text("Kích thước Kệ:")
                            .font(.system(size: 12, weight: .semibold))
                        Picker("", selection: $settings.shelfSize) {
                            ForEach(ShelfSizePreset.allCases) { preset in
                                Text(preset.title).tag(preset)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 240)
                    }

                    Toggle("Hiện thanh gờ mỏng sát mép màn hình (rê hoặc kéo tệp chạm mép để mở kệ)", isOn: $settings.showEdgeHandle)
                        .toggleStyle(.switch)
                        .font(.system(size: 12))

                    Toggle("Ghim giữ Kệ luôn hiển thị cố định trên màn hình (bỏ qua tự ẩn)", isOn: $settings.isShelfPinned)
                        .toggleStyle(.switch)
                        .font(.system(size: 12))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func screenEdgeSlot(_ position: ShelfEdgePosition, label: String) -> some View {
        let active = settings.edgePosition == position
        return Button {
            settings.edgePosition = position
            panelController.showShelfManually()
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(active ? Color.accentColor : Color.primary.opacity(0.16))
                .frame(width: 58, height: 28)
                .overlay(
                    Text(label)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(active ? Color.white : Color.primary)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 5. Drag Behavior, Stacks & Global HotKey

    private var dragBehaviorAndShortcutsSection: some View {
        sectionContainer(
            title: "HÀNH VI KÉO THẢ, SMART STACK & PHÍM TẮT TOÀN CỤC",
            icon: "hand.draw"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("Khi kéo tệp từ Kệ ra Finder:")
                        .font(.system(size: 12.5, weight: .semibold))
                    Picker("", selection: $settings.dragOutBehavior) {
                        ForEach(DragOutBehavior.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                Toggle("Tự động gỡ mục khỏi kệ sau khi kéo thả thành công đến vị trí mới (các mục Ghim 📌 luôn giữ lại)", isOn: $settings.autoRemoveAfterDrop)
                    .toggleStyle(.switch)
                    .font(.system(size: 12))

                Toggle("Tự động gộp nhóm (Smart Stack) khi kéo thả nhiều tệp vào kệ cùng lúc", isOn: $settings.autoStackMultipleFiles)
                    .toggleStyle(.switch)
                    .font(.system(size: 12))

                Toggle("Lưu giữ các mục đang có trên kệ khi thoát / khởi động lại DropShelf", isOn: $settings.persistItemsAcrossLaunches)
                    .toggleStyle(.switch)
                    .font(.system(size: 12))

                Divider()

                HStack(spacing: 10) {
                    Text("Phím tắt Hiện / Ẩn Kệ nổi:")
                        .font(.system(size: 12.5, weight: .semibold))

                    Button {
                        if hotKeyService.isRecordingShortcut {
                            hotKeyService.stopRecordingShortcut()
                            hotKeyService.register(binding: settings.hotKeyBinding)
                        } else {
                            hotKeyService.startRecordingShortcut()
                        }
                    } label: {
                        Text(hotKeyService.isRecordingShortcut ? "Nhấn tổ hợp phím mới... (Esc huỷ)" : settings.hotKeyBinding.readableDisplay)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(hotKeyService.isRecordingShortcut ? .orange : .accentColor)
                    .controlSize(.small)

                    Text("Chọn nhanh:")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)

                    Button("⌃Y (Mặc định)") {
                        settings.hotKeyBinding = .defaultToggle
                    }
                    .controlSize(.small)

                    Button("F5 (Kiểu Yoink)") {
                        settings.hotKeyBinding = .f5Preset
                    }
                    .controlSize(.small)

                    Button("⌥Space") {
                        settings.hotKeyBinding = .optSpacePreset
                    }
                    .controlSize(.small)

                    Spacer()
                }
            }
        }
    }

    // MARK: - 6. GitHub Releases Auto-Update Section

    private var githubUpdateFooterSection: some View {
        sectionContainer(
            title: "CẬP NHẬT PHIÊN BẢN TỪ GITHUB RELEASES",
            icon: "arrow.triangle.2.circlepath.circle"
        ) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kho mã nguồn & Phát hành chính thức: github.com/hungmtuci/DropShelf")
                        .font(.system(size: 12.5, weight: .semibold))

                    Text(updateStatusDescription)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    if let url = URL(string: "https://github.com/hungmtuci/DropShelf/releases") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Mở GitHub Releases", systemImage: "safari")
                        .font(.system(size: 11.5))
                }
                .controlSize(.small)

                updateActionButton
            }
        }
    }

    private var updateStatusDescription: String {
        switch updateService.state {
        case .idle:
            return "Tự động kiểm tra bản mới định kỳ trên GitHub và hỗ trợ cập nhật 1 chạm không cần cài lại thủ công."
        case .checking:
            return "Đang kết nối tới GitHub Releases (hungmtuci/DropShelf)..."
        case .upToDate(let ver):
            return "Bạn đang sử dụng phiên bản mới nhất v\(ver)."
        case .available(let ver, _, _, _):
            return "Đã phát hiện phiên bản mới v\(ver) trên GitHub! Nhấn 'Cập nhật v\(ver)' để tự động tải và nâng cấp."
        case .downloading(let ver):
            return "Đang tải gói cập nhật DropShelf v\(ver)..."
        case .installing(let ver):
            return "Đang giải nén, gỡ cờ Gatekeeper và thay thế phiên bản v\(ver)..."
        case .failed(let msg):
            return msg
        }
    }

    // MARK: - Helpers

    private func sectionContainer<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
            )
        }
    }

    private func moveSelfToApplications() {
        let src = Bundle.main.bundlePath
        let dst = "/Applications/DropShelf.app"
        let pid = ProcessInfo.processInfo.processIdentifier

        let script = """
        OLD_PID="$1"
        SRC_APP="$2"
        DST_APP="$3"
        for _ in 1 2 3 4 5 6 7 8 9 10; do
            kill -0 "$OLD_PID" 2>/dev/null || break
            sleep 0.2
        done
        rm -rf "$DST_APP"
        /usr/bin/ditto --noextattr "$SRC_APP" "$DST_APP"
        /usr/bin/xattr -cr "$DST_APP" 2>/dev/null || true
        /usr/bin/open "$DST_APP"
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        proc.arguments = ["/bin/sh", "-c", script, "dropshelf-mover", "\(pid)", src, dst]
        try? proc.run()
        NSApp.terminate(nil)
    }
}
