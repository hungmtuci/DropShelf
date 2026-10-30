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
        HStack(spacing: 0) {
            sidebarPane
                .frame(width: 220)

            Divider()
                .ignoresSafeArea(.container, edges: .top)

            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 720, minHeight: 500)
    }

    // MARK: - Left Native macOS Vibrancy Sidebar

    private var sidebarPane: some View {
        ZStack {
            VisualEffectGlassView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea(.container, edges: .top)

            VStack(alignment: .leading, spacing: 6) {
                sidebarAppHeader
                    .padding(.top, 38)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)

                VStack(spacing: 3) {
                    ForEach(SettingsSidebarTab.allCases) { tab in
                        sidebarRow(for: tab)
                    }
                }
                .padding(.horizontal, 10)

                Spacer(minLength: 12)

                sidebarBottomShelfControl
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
            }
        }
    }

    private var sidebarAppHeader: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.25, green: 0.38, blue: 0.96),
                                Color(red: 0.08, green: 0.62, blue: 0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 3, y: 1.5)

                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1.5) {
                Text("DropShelf")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Phiên bản \(updateService.currentVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private func sidebarRow(for tab: SettingsSidebarTab) -> some View {
        let isSelected = (settings.selectedSettingsTab == tab)
        let hasUpdateDot = (tab == .general && updateService.availableVersion != nil)

        return Button {
            settings.selectedSettingsTab = tab
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(sidebarIconGradient(for: tab))
                        .frame(width: 22, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                        )

                    Image(systemName: tab.symbolName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if hasUpdateDot {
                    Circle()
                        .fill(isSelected ? Color.white : Color.green)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func sidebarIconGradient(for tab: SettingsSidebarTab) -> LinearGradient {
        let colors: [Color]
        switch tab {
        case .general:
            colors = [Color(red: 0.08, green: 0.55, blue: 0.99), Color(red: 0.02, green: 0.40, blue: 0.88)]
        case .displayAndPosition:
            colors = [Color(red: 0.40, green: 0.36, blue: 0.94), Color(red: 0.29, green: 0.25, blue: 0.82)]
        case .screenshots:
            colors = [Color(red: 0.16, green: 0.72, blue: 0.88), Color(red: 0.04, green: 0.54, blue: 0.78)]
        case .dragAndShortcuts:
            colors = [Color(red: 1.00, green: 0.62, blue: 0.08), Color(red: 0.92, green: 0.46, blue: 0.02)]
        case .systemAndDock:
            colors = [Color(red: 0.56, green: 0.56, blue: 0.59), Color(red: 0.40, green: 0.40, blue: 0.43)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private var sidebarBottomShelfControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            VStack(alignment: .leading, spacing: 5.5) {
                MacCompactStartupCheckbox(
                    id: "sidebar_launch_at_login",
                    title: "Khởi động cùng macOS",
                    isChecked: settings.launchAtLogin,
                    helpText: "Tự động chạy DropShelf ngay khi đăng nhập vào máy Mac",
                    settings: settings
                ) {
                    settings.launchAtLogin.toggle()
                }

                MacCompactStartupCheckbox(
                    id: "sidebar_open_settings_on_launch",
                    title: "Bật bảng này khi khởi động",
                    isChecked: settings.openSettingsOnLaunch,
                    helpText: "Tự động mở bảng Cài đặt này khi khởi động ứng dụng (bỏ chọn để chạy ngầm)",
                    settings: settings
                ) {
                    settings.openSettingsOnLaunch.toggle()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.7)
            )

            HStack(spacing: 6) {
                Circle()
                    .fill(panelController.isVisible ? Color.green : Color.secondary.opacity(0.55))
                    .frame(width: 7, height: 7)

                Text(panelController.isVisible ? "Kệ đang mở (\(store.totalFileCount) mục)" : "Đang chờ kéo thả")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.top, 1)

            Button {
                panelController.toggleShelf()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sidebar.right")
                    Text(panelController.isVisible ? "Ẩn Kệ nổi" : "Hiện Kệ nổi")
                    Spacer()
                    Text(settings.hotKeyBinding.readableDisplay)
                        .font(.system(size: 11, design: .monospaced))
                        .opacity(0.85)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    // MARK: - Right Native macOS Grouped Detail Pane

    private var detailPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(settings.selectedSettingsTab.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if settings.selectedSettingsTab != .general {
                    compactHeaderGitHubButton
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 6)
            .padding(.horizontal, 22)

            switch settings.selectedSettingsTab {
            case .general:
                generalSettingsForm
            case .displayAndPosition:
                displayAndPositionForm
            case .screenshots:
                screenshotsSettingsForm
            case .dragAndShortcuts:
                dragAndShortcutsForm
            case .systemAndDock:
                systemAndDockForm
            }
        }
    }

    @ViewBuilder
    private var compactHeaderGitHubButton: some View {
        if updateService.isBusy {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text(busyStatusShortText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        } else if let avail = updateService.availableVersion {
            Button {
                updateService.oneClickUpdateFromGitHub()
            } label: {
                Label("Cập nhật v\(avail)", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
        } else {
            Button {
                updateService.oneClickUpdateFromGitHub()
            } label: {
                Label("Update qua GitHub", systemImage: "arrow.triangle.2.circlepath")
            }
            .controlSize(.small)
        }
    }

    // MARK: - Tab 1: Tổng quan & Cập nhật

    private var generalSettingsForm: some View {
        Form {
            if settings.shouldOfferMoveToApplications {
                Section {
                    LabeledContent {
                        Button("Chuyển vào /Applications") {
                            moveSelfToApplications()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    } label: {
                        Text("Chưa cài trong thư mục Ứng dụng")
                        Text("Di chuyển vào /Applications giúp tự động cập nhật từ GitHub và Khởi động cùng macOS hoạt động ổn định.")
                    }
                }
            }

            Section("Kệ kéo thả tạm thời") {
                LabeledContent {
                    HStack(spacing: 8) {
                        Button("Tạo tệp mẫu") {
                            store.createDemoSampleItems()
                        }

                        Button(panelController.isVisible ? "Ẩn Kệ" : "Mở Kệ") {
                            panelController.toggleShelf()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } label: {
                    Text("Trạng thái Kệ nổi")
                    Text("Đang lưu \(store.totalFileCount) tệp tạm • Vị trí neo: \(settings.edgePosition.title)")
                }

                Toggle(isOn: $settings.isShelfPinned) {
                    Text("Ghim giữ Kệ luôn hiển thị")
                    Text("Giữ cửa sổ Kệ cố định trên màn hình và bỏ qua bộ đếm tự ẩn khi Kệ trống.")
                }
            }

            Section("Khởi động & Thanh Dock") {
                Toggle(isOn: $settings.launchAtLogin) {
                    Text("Khởi động cùng macOS")
                    Text("Tự động chạy DropShelf ngay khi bạn đăng nhập vào máy Mac.")
                }

                Toggle(isOn: $settings.openShelfOnLaunch) {
                    Text("Bật bảng Kệ nổi khi khởi động")
                    Text("Tự động hiện Kệ nổi ở cạnh màn hình ngay khi mở ứng dụng.")
                }

                Toggle(isOn: $settings.openSettingsOnLaunch) {
                    Text("Bật bảng Cài đặt này khi khởi động")
                    Text("Tắt tuỳ chọn này nếu muốn ứng dụng khởi động êm ở nền không mở bảng Cài đặt.")
                }

                Toggle(isOn: $settings.showInDock) {
                    Text("Hiển thị biểu tượng trên thanh Dock")
                    Text("Khi tắt, DropShelf ẩn hoàn toàn khỏi thanh Dock ngay từ lúc khởi động, chỉ hiện trên Menu Bar.")
                }
            }

            Section("Cập nhật phần mềm (GitHub Releases)") {
                LabeledContent {
                    primaryGitHubUpdateControl
                } label: {
                    HStack(spacing: 6) {
                        Text("DropShelf v\(updateService.currentVersion)")
                            .fontWeight(.medium)

                        if let avail = updateService.availableVersion {
                            Text("Mới: v\(avail)")
                                .font(.system(size: 10.5, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Color.green.opacity(0.16))
                                .foregroundStyle(Color.green)
                                .clipShape(Capsule())
                        }
                    }
                    Text(updateStatusDescription)
                }

                LabeledContent {
                    HStack(spacing: 8) {
                        Button("Cài lại từ GitHub") {
                            updateService.reinstallLatestFromGitHub()
                        }
                        .disabled(updateService.isBusy)
                        .help("Tải lại gói .zip mới nhất trên GitHub Releases và cài đè lên ứng dụng hiện tại")

                        Button("Xem trên GitHub") {
                            if let url = URL(string: "https://github.com/hungmtuci/DropShelf/releases/latest") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                } label: {
                    Text("Kho phát hành chính thức")
                    Text("github.com/hungmtuci/DropShelf")
                }
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var primaryGitHubUpdateControl: some View {
        switch updateService.state {
        case .checking, .downloading, .installing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(busyStatusShortText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

        case .available(let ver, _, _, _):
            Button {
                updateService.oneClickUpdateFromGitHub()
            } label: {
                Label("Cập nhật v\(ver)", systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

        case .upToDate:
            Button {
                updateService.oneClickUpdateFromGitHub()
            } label: {
                Label("Kiểm tra lại", systemImage: "arrow.clockwise")
            }

        default:
            Button {
                updateService.oneClickUpdateFromGitHub()
            } label: {
                Label("Update qua GitHub", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var busyStatusShortText: String {
        switch updateService.state {
        case .checking:
            return "Đang kiểm tra..."
        case .downloading(let ver):
            return "Đang tải v\(ver)..."
        case .installing(let ver):
            return "Đang cài v\(ver)..."
        default:
            return "Đang xử lý..."
        }
    }

    private var updateStatusDescription: String {
        switch updateService.state {
        case .idle:
            return "Tự động kiểm tra, tải bản mới nhất trên GitHub và nâng cấp 1 chạm."
        case .checking:
            return "Đang kết nối tới GitHub Releases..."
        case .upToDate(let ver):
            return "Bạn đang sử dụng phiên bản mới nhất (v\(ver))."
        case .available(let ver, _, _, _):
            return "Đã có bản cập nhật mới v\(ver) sẵn sàng tải về từ GitHub."
        case .downloading(let ver):
            return "Đang tải gói DropShelf v\(ver) từ GitHub Releases..."
        case .installing(let ver):
            return "Đang giải nén và nâng cấp lên phiên bản v\(ver)..."
        case .failed(let msg):
            return msg
        }
    }

    // MARK: - Tab 2: Màn hình & Vị trí

    private var displaySelectionBinding: Binding<Int> {
        Binding<Int>(
            get: {
                if settings.displayMode == .specificDisplay,
                   let id = settings.preferredDisplayID,
                   panelController.availableDisplays.contains(where: { $0.displayID == id }) {
                    return Int(id)
                }
                return -1
            },
            set: { newValue in
                if newValue == -1 {
                    panelController.selectFollowActiveScreen()
                } else {
                    panelController.selectSpecificDisplay(UInt32(bitPattern: Int32(truncatingIfNeeded: newValue)))
                }
            }
        )
    }

    private var displayAndPositionForm: some View {
        Form {
            Section("Màn hình hiển thị") {
                Picker(selection: displaySelectionBinding) {
                    Text("Tự động theo màn hình đang thao tác").tag(-1)
                    Divider()
                    ForEach(panelController.availableDisplays) { disp in
                        Label(disp.detailedTitle, systemImage: disp.symbolName)
                            .tag(Int(disp.displayID))
                    }
                } label: {
                    Text("Hiển thị cửa sổ Kệ trên")
                    Text("Tự động chuyển Kệ sang màn hình bạn vừa bấm chuột hoặc cố định trên 1 màn hình.")
                }

                if panelController.availableDisplays.count > 1 {
                    LabeledContent {
                        Button {
                            panelController.cycleToNextScreen()
                        } label: {
                            Label("Chuyển sang màn hình kia", systemImage: "display.2")
                        }
                    } label: {
                        Text("Đổi nhanh màn hình")
                        Text("Đang kết nối \(panelController.availableDisplays.count) màn hình.")
                    }
                }
            }

            Section("Vị trí neo & Kích thước") {
                VStack(alignment: .center, spacing: 10) {
                    macOSDesktopPositionPreview
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                Picker("Vị trí neo trên màn hình", selection: $settings.edgePosition) {
                    ForEach(ShelfEdgePosition.allCases) { pos in
                        Text(pos.title).tag(pos)
                    }
                }

                Picker("Kích thước Kệ", selection: $settings.shelfSize) {
                    ForEach(ShelfSizePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Tự động hiện & Tự động ẩn") {
                Picker(selection: $settings.autoShowTrigger) {
                    ForEach(AutoShowTrigger.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                } label: {
                    Text("Khi bắt đầu kéo tệp")
                    Text(settings.autoShowTrigger.shortNote)
                }

                Picker(selection: $settings.emptyAutoHideOption) {
                    ForEach(EmptyAutoHideOption.allCases) { opt in
                        Text(opt.title).tag(opt)
                    }
                } label: {
                    Text("Tự ẩn khi Kệ trống")
                    Text("Tự đóng gọn nếu chuột vô tình lướt chạm mép màn hình mà không thả nội dung vào.")
                }

                Toggle(isOn: $settings.showEdgeHandle) {
                    Text("Hiện thanh gờ mảnh sát mép màn hình")
                    Text("Rê chuột hoặc kéo tệp chạm nhẹ vào thanh gờ để gọi Kệ ra ngay.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var macOSDesktopPositionPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.16),
                            Color(nsColor: .controlAccentColor).opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 296, height: 148)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            // Simulated macOS Menu Bar & Dock silhouette
            VStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 10
                )
                .fill(Color.primary.opacity(0.06))
                .frame(height: 12)

                Spacer()

                Capsule()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 76, height: 8)
                    .padding(.bottom, 6)
            }
            .frame(width: 296, height: 148)

            HStack {
                VStack(spacing: 8) {
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
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            settings.edgePosition == .freeFloating
                                ? Color.accentColor
                                : Color(nsColor: .controlBackgroundColor)
                        )
                        .foregroundStyle(settings.edgePosition == .freeFloating ? Color.white : Color.primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: settings.edgePosition == .freeFloating ? 0 : 0.8)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 8) {
                    screenEdgeSlot(.rightTop, label: "Phải Trên")
                    screenEdgeSlot(.rightCenter, label: "Phải Giữa")
                    screenEdgeSlot(.rightBottom, label: "Phải Dưới")
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .frame(width: 296, height: 148)
        }
    }

    private func screenEdgeSlot(_ position: ShelfEdgePosition, label: String) -> some View {
        let active = (settings.edgePosition == position)
        return Button {
            settings.edgePosition = position
            panelController.showShelfManually()
        } label: {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(active ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .frame(width: 68, height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(active ? Color.clear : Color(nsColor: .separatorColor), lineWidth: 0.8)
                )
                .overlay(
                    Text(label)
                        .font(.system(size: 10.5, weight: active ? .semibold : .regular))
                        .foregroundStyle(active ? Color.white : Color.primary)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 3: Chụp màn hình

    private var screenshotsSettingsForm: some View {
        Form {
            Section("Tự động bắt ảnh chụp màn hình") {
                Toggle(isOn: $settings.autoCaptureScreenshots) {
                    Text("Tự động đưa hình chụp màn hình mới vào Kệ")
                    Text("Theo dõi ảnh chụp ⌘⇧3, ⌘⇧4, ⌘⇧5 và tự bật Kệ ngay lập tức với 0% CPU nền.")
                }

                Toggle(isOn: $settings.instantScreenshotCapture) {
                    Text("Nhảy vào Kệ tức thì (0 giây)")
                    Text("Tắt thời gian chờ 5 giây của ảnh thu nhỏ góc dưới macOS để chụp toàn màn hình vào Kệ ngay.")
                }
                .disabled(!settings.autoCaptureScreenshots)

                Toggle(isOn: $settings.autoCaptureClipboardScreenshots) {
                    Text("Tự động bắt ảnh chụp lưu vào Clipboard")
                    Text("Đóng gói ảnh chụp bằng ⌘⌃⇧3 / ⌘⌃⇧4 thành tệp PNG sẵn sàng kéo thả ra Zalo, Slack, Mail.")
                }
                .disabled(!settings.autoCaptureScreenshots)
            }

            Section("Thư mục ảnh chụp macOS") {
                LabeledContent {
                    Button("Mở trong Finder") {
                        if let first = screenshotService.watchedDirectories.first {
                            NSWorkspace.shared.open(URL(fileURLWithPath: first))
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(screenshotService.primaryWatchedFolderDisplay)
                            .font(.system(.body, design: .monospaced))
                    }
                    Text("Tự động đồng bộ theo cấu hình thư mục lưu ảnh chụp của hệ thống macOS.")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 4: Kéo thả & Phím tắt

    private var dragAndShortcutsForm: some View {
        Form {
            Section("Hành vi kéo thả tệp") {
                Picker("Khi kéo tệp từ Kệ ra Finder", selection: $settings.dragOutBehavior) {
                    ForEach(DragOutBehavior.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }

                Toggle(isOn: $settings.autoRemoveAfterDrop) {
                    Text("Tự gỡ mục khỏi Kệ sau khi kéo thả xong")
                    Text("Các mục được đánh dấu Ghim sẽ luôn được giữ lại trên Kệ.")
                }

                Toggle(isOn: $settings.autoStackMultipleFiles) {
                    Text("Tự động gộp nhóm (Smart Stack)")
                    Text("Gom thành 1 thẻ nhóm gọn gàng khi kéo thả nhiều tệp vào Kệ cùng lúc.")
                }

                Toggle(isOn: $settings.persistItemsAcrossLaunches) {
                    Text("Giữ lại các mục trên Kệ khi thoát ứng dụng")
                    Text("Khôi phục danh sách tệp tạm ở lần mở DropShelf tiếp theo.")
                }
            }

            Section("Phím tắt toàn cục") {
                LabeledContent {
                    Button {
                        if hotKeyService.isRecordingShortcut {
                            hotKeyService.stopRecordingShortcut()
                            hotKeyService.register(binding: settings.hotKeyBinding)
                        } else {
                            hotKeyService.startRecordingShortcut()
                        }
                    } label: {
                        Text(hotKeyService.isRecordingShortcut ? "Nhấn phím tắt mới... (Esc huỷ)" : settings.hotKeyBinding.readableDisplay)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(minWidth: 64)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(hotKeyService.isRecordingShortcut ? .orange : .accentColor)
                } label: {
                    Text("Phím tắt Hiện / Ẩn Kệ nổi")
                    Text("Nhấn nút bên phải để ghi tổ hợp phím mới bất kỳ.")
                }

                LabeledContent("Chọn nhanh mẫu phím tắt") {
                    HStack(spacing: 6) {
                        Button("⌃Y (Mặc định)") {
                            settings.hotKeyBinding = .defaultToggle
                        }
                        .controlSize(.small)

                        Button("F5 (Yoink)") {
                            settings.hotKeyBinding = .f5Preset
                        }
                        .controlSize(.small)

                        Button("⌥Space") {
                            settings.hotKeyBinding = .optSpacePreset
                        }
                        .controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Tab 5: Hệ thống & Dock

    private var systemAndDockForm: some View {
        Form {
            Section("Thanh Dock & Menu Bar") {
                Toggle(isOn: $settings.showInDock) {
                    Text("Hiển thị biểu tượng trên thanh Dock")
                    Text("Khi tắt, DropShelf ẩn hoàn toàn khỏi thanh Dock và ⌘Tab ngay cả khi tắt đi mở lại, chỉ hiện trên thanh Menu Bar.")
                }
            }

            Section("Khởi động cùng hệ thống") {
                Toggle(isOn: $settings.launchAtLogin) {
                    Text("Khởi động cùng macOS")
                    Text("Tự động chạy nền sẵn sàng ngay khi bạn đăng nhập vào máy Mac.")
                }

                Toggle(isOn: $settings.openShelfOnLaunch) {
                    Text("Bật bảng Kệ nổi khi khởi động")
                    Text("Tự động mở bảng Kệ nổi ở cạnh màn hình ngay khi khởi động DropShelf.")
                }

                Toggle(isOn: $settings.openSettingsOnLaunch) {
                    Text("Bật bảng Cài đặt này khi khởi động")
                    Text("Tắt tuỳ chọn này nếu bạn muốn ứng dụng khởi động hoàn toàn im lặng ở nền.")
                }

                if !settings.statusBannerMessage.isEmpty {
                    LabeledContent {
                        Button("Đóng") {
                            settings.statusBannerMessage = ""
                        }
                        .controlSize(.small)
                    } label: {
                        Label(settings.statusBannerMessage, systemImage: "info.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Move to /Applications Helper

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
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DST_APP" 2>/dev/null || true
        /usr/bin/open "$DST_APP"
        """

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        proc.arguments = ["/bin/sh", "-c", script, "dropshelf-mover", "\(pid)", src, dst]
        try? proc.run()
        NSApp.terminate(nil)
    }
}
