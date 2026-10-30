# DropShelf for macOS

**DropShelf** là tiện ích kệ kéo thả tệp tạm thời siêu nhẹ cho macOS (lấy cảm hứng từ [Yoink](https://setapp.com/apps/yoink)), giúp bạn **thả tệp, thư mục, hình ảnh web, liên kết hoặc đoạn văn bản vào một kệ nổi ở cạnh màn hình**, **tự động gom mọi ảnh chụp màn hình mới vào kệ**, và **kéo từ kệ ra vị trí mới** cực kỳ mượt mà.

---

## ✨ Tính năng nổi bật

- **Hỗ trợ Đa Màn Hình & Đa Không Gian Làm Việc (`v1.2.0` — Multi-Monitor & Mission Control Spaces)**:
  - **Tự động đi theo màn hình đang chọn**: Khi bấm chuột sang màn hình khác, kéo tệp ở màn hình phụ hoặc bấm icon Menu Bar trên màn hình phụ, cửa sổ Kệ tự động nhảy sang đúng màn hình bạn đang thao tác.
  - **Chọn cố định màn hình hiển thị**: Hỗ trợ ghim Kệ cố định trên từng màn hình cụ thể ngay trong **Cài đặt**, **Menu Bar** hoặc nút chuyển nhanh trên Kệ.
  - **Thanh gờ mép trên tất cả màn hình** & giữ hiển thị mượt qua mọi Desktop Space / Full-Screen.
- **Tự động đưa Hình chụp màn hình mới vào Kệ (`v1.1.1` — `0%` CPU với `FSEventStream`)**:
  - Tự động phát hiện thư mục lưu ảnh chụp màn hình của macOS (hỗ trợ cả thư mục tuỳ chỉnh trong `com.apple.screencapture` lẫn `~/Desktop`) qua nhân `FSEventStream` và kiểm tra siêu dữ liệu `kMDItemIsScreenCapture` — **không quét thư mục cũ**, tốc độ tức thì kể cả thư mục có hàng chục nghìn tệp.
  - Bắt cả **ảnh chụp màn hình lưu vào Clipboard (`⌘ + ⌃ + ⇧ + 3` / `⌘ + ⌃ + ⇧ + 4`)**, tự động đóng gói thành tệp `.png` sắc nét và bật kệ ra ngay để kéo thả vào Zalo, Messenger, Slack, Mail, Docs hoặc Finder.
  - Tích hợp nút 1 chạm bật **Chế độ nhảy tức thì `0 giây`** (tắt độ trễ xem trước 4–5 giây ở góc dưới màn hình của macOS nếu muốn).
- **Tự động ẩn sau `3 giây` khi Kệ trống (Chống lướt nhầm chuột — `v1.1.0`)**:
  - Nếu bạn vô tình lướt chuột chạm vào vạch gờ mép màn hình làm kệ bật ra (hoặc mở kệ nhưng không thả nội dung gì vào), kệ sẽ **tự động trượt ẩn gọn sau `3 giây`** (tuỳ chỉnh được `2s / 3s / 5s / 8s / Không tự ẩn`, và tự động tạm hoãn nếu bạn đang giữ chuột kéo tệp hoặc đang bật **Ghim kệ 📌**).
- **Tự động trượt ra khi bắt đầu kéo tệp (Chuẩn Yoink)**:
  - Theo dõi thông minh phiên kéo hệ thống (`NSPasteboard.Name.drag`) — chỉ tự động hiện kệ khi bạn thực sự đang kéo tệp / ảnh / văn bản, **tuyệt đối không bật nhầm** khi bôi đen chữ hay di chuyển cửa sổ.
- **Hỗ trợ đa dạng nội dung & Gộp nhóm thông minh (Smart Stack)**:
  - **Tệp & Thư mục**: Giữ tham chiếu tức thì (`0ms` kể cả tệp video hàng chục GB) kèm theo dõi **APFS Bookmark** tự động cập nhật nếu tệp đổi tên.
  - **Smart Stack**: Kéo nhiều tệp vào kệ cùng lúc sẽ tự động gom thành 1 thẻ nhóm gọn gàng — kéo cả nhóm ra 1 lần, mở xem từng tệp con, hoặc tách rời bất kỳ lúc nào.
  - **Ảnh Web, Liên kết URL & Văn bản**: Tự động tạo tệp `.png`, `.webloc`, `.txt` tạm thời để kéo thẳng ra Finder lưu thành tệp thật hoặc thả vào ứng dụng bất kỳ.
- **Chuẩn thao tác Kéo Ra như Finder gốc**:
  - **Cùng ổ đĩa**: Mặc định **Di chuyển (`Move`)** tệp sang thư mục mới giống hệt Yoink & Finder (có tuỳ chọn đổi sang **Sao chép mặc định** trong Cài đặt).
  - Giữ **`⌥ Option`** khi kéo ra để ép **Sao chép (`Copy` `+`)**, giữ **`⌘ Command`** để ép **Di chuyển (`Move`)**.
- **Xem nhanh Quick Look (`Space`) & Tuỳ chọn Ẩn / Hiện trên Thanh Dock**:
  - Rê chuột lên mục bất kỳ và nhấn **`Space`** để xem trước PDF, ảnh, video.
  - Chuyển đổi tức thì (`0ms`) giữa **Hiện trên thanh Dock & Menu Bar** và **Ẩn khỏi thanh Dock — Chỉ hiện trên Menu Bar**.
- **Cập nhật tự động 1 chạm từ GitHub Releases**:
  - Tự động kiểm tra bản phát hành mới từ [`hungmtuci/DropShelf`](https://github.com/hungmtuci/DropShelf/releases/latest), tải gói `.zip`, xác thực, cài đè vào `/Applications/DropShelf.app`, gỡ cờ Gatekeeper (`xattr -cr`) và tự khởi động lại.

---

## ⌨️ Phím tắt & Thao tác nhanh

| Phím tắt / Thao tác | Chức năng |
| :--- | :--- |
| `⌘ + ⇧ + 3` / `⌘ + ⇧ + 4` / `⌘ + ⌃ + ⇧ + 4` | Chụp màn hình — **ảnh tự động nhảy thẳng vào DropShelf!** |
| `Ctrl + Y` (`⌃Y`) *(hoặc `F5`, `⌥Space`, tự ghi phím tắt)* | Hiện / Ẩn nhanh Kệ nổi ở cạnh màn hình |
| `Space` *(khi rê chuột trên kệ)* | Mở Xem nhanh **Quick Look** cho tệp / nhóm Stack |
| `⌘ + V` *(khi rê chuột trên kệ)* hoặc `⌘ + ⇧ + V` | Dán nội dung từ Clipboard vào Kệ |
| Giữ `⌥ Option` khi kéo tệp ra Finder | Ép **Sao chép (Copy)** thay vì Di chuyển |
| Giữ `⌘ Command` khi kéo tệp ra Finder | Ép **Di chuyển (Move)** tệp sang vị trí mới |
| **Click trái** icon trên Menu Bar | Bật / Tắt nhanh Kệ nổi |
| **Click phải** icon trên Menu Bar | Mở menu nhanh (Tự bắt Screenshot, Ẩn/Hiện trên Dock, Kiểm tra cập nhật GitHub, Cài đặt, Thoát) |

---

## 📥 Tải về & Cài đặt nhanh (macOS 14.0+ Universal: Apple Silicon & Intel)

1. Tải bộ cài mới nhất tại trang **[Releases](https://github.com/hungmtuci/DropShelf/releases/latest)**:
   - **`DropShelf-Installer-v1.4.0.dmg`** *(Khuyên dùng)*
   - Hoặc **`DropShelf-v1.4.0-macOS.zip`** *(Hoặc bấm nút **Update qua GitHub** ngay trên Kệ / Cài đặt để tự nâng cấp 1 chạm!)*
2. Mở file `.dmg`:
   - Kéo `DropShelf.app` thả vào thư mục **`Applications`**, **HOẶC** nhấp chuột phải vào `Cai_Dat_DropShelf.command` → chọn **Open** để tự động cài đặt vào `/Applications` và gỡ cờ cách ly Gatekeeper.
3. Nếu macOS cảnh báo ứng dụng chưa công chứng Apple Developer ID khi mở lần đầu trên máy mới, chạy lệnh sau trong Terminal:
   ```bash
   xattr -cr /Applications/DropShelf.app && open /Applications/DropShelf.app
   ```

---

## 🛠️ Tự biên dịch từ mã nguồn (Build from Source)

```bash
git clone https://github.com/hungmtuci/DropShelf.git
cd DropShelf
chmod +x build_dropshelf.sh
./build_dropshelf.sh
```

## 📄 Giấy phép

Phát hành theo giấy phép [MIT License](LICENSE).
