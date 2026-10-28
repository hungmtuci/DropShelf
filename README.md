# DropShelf for macOS

**DropShelf** là tiện ích kệ kéo thả tệp tạm thời siêu nhẹ cho macOS (lấy cảm hứng từ [Yoink](https://setapp.com/apps/yoink)), giúp bạn **thả tệp, thư mục, hình ảnh web, liên kết hoặc đoạn văn bản vào một kệ nổi ở cạnh màn hình**, rảnh tay chuyển sang cửa sổ / màn hình `Spaces` / thư mục đích rồi **kéo từ kệ ra vị trí mới** cực kỳ mượt mà.

---

## ✨ Tính năng nổi bật

- **Tự động trượt ra khi bắt đầu kéo tệp (Chuẩn Yoink — `0%` CPU khi nghỉ)**:
  - Theo dõi thông minh phiên kéo hệ thống (`NSPasteboard.Name.drag`) — chỉ tự động hiện kệ khi bạn thực sự đang kéo tệp / ảnh / văn bản, **tuyệt đối không bật nhầm** khi bôi đen chữ hay di chuyển cửa sổ.
  - Tự động trượt ẩn lại nếu bạn không thả gì vào kệ, và tự đóng gọn sau khi bạn kéo hết các mục ra vị trí mới (trừ khi đang bật **Ghim kệ 📌**).
  - Hỗ trợ 3 chế độ kích hoạt: **Hiện ngay khi bắt đầu kéo**, **Hiện khi kéo sát mép / lắc chuột**, hoặc **Chỉ mở thủ công bằng phím tắt**.
- **Hỗ trợ đa dạng nội dung & Gộp nhóm thông minh (Smart Stack)**:
  - **Tệp & Thư mục**: Giữ tham chiếu tức thì (`0ms` kể cả tệp video hàng chục GB) kèm theo dõi **APFS Bookmark** tự động cập nhật nếu tệp đổi tên.
  - **Smart Stack**: Kéo nhiều tệp vào kệ cùng lúc sẽ tự động gom thành 1 thẻ nhóm gọn gàng — kéo cả nhóm ra 1 lần, mở xem từng tệp con, hoặc tách rời bất kỳ lúc nào. Também có thể kéo tệp mới thả đè lên thẻ cũ để gộp chung vào nhóm.
  - **Ảnh chụp, Ảnh Web, Liên kết URL & Văn bản**: Tự động đóng gói thành tệp `.png`, `.webloc`, `.txt` tạm thời để bạn kéo thẳng ra Finder lưu thành tệp thật hoặc thả vào Mail, Notes, Slack, Zalo, trình duyệt.
  - **Dán nhanh từ Clipboard (`⌘⇧V` / nút 📋)**: Đưa ngay tệp, ảnh chụp màn hình hoặc văn bản vừa copy lên kệ.
- **Chuẩn thao tác Kéo Ra như Finder gốc**:
  - **Cùng ổ đĩa**: Mặc định **Di chuyển (`Move`)** tệp sang thư mục mới giống hệt Yoink & Finder (có tuỳ chọn đổi sang **Sao chép mặc định** trong Cài đặt).
  - Giữ **`⌥ Option`** khi kéo ra để ép **Sao chép (`Copy` `+`)**, giữ **`⌘ Command`** để ép **Di chuyển (`Move`)**.
  - Các mục được **Ghim 📌** trên kệ luôn tự động **Sao chép** khi kéo ra để giữ nguyên tệp mẫu tái sử dụng nhiều lần.
- **Xem nhanh Quick Look (`Space`) & Hình thu nhỏ Retina**:
  - Tích hợp `QLThumbnailGenerator` và `QLPreviewPanel` gốc của macOS — rê chuột lên mục bất kỳ và nhấn **`Space`** (hoặc bấm biểu tượng 👁) để xem trước PDF, ảnh, video, tài liệu trước khi thả.
- **Tuỳ chọn Ẩn / Hiện linh hoạt trên Thanh Dock & Menu Bar**:
  - Chuyển đổi tức thì (`0ms`) giữa **Hiện trên thanh Dock & Menu Bar** (hỗ trợ kéo thả tệp trực tiếp vào icon trên Dock) và **Ẩn khỏi thanh Dock — Chỉ hiện trên Menu Bar** ngay trong Cài đặt hoặc menu chuột phải trên Menu Bar.
- **Không cần cấp quyền nhạy cảm (Zero TCC Permissions)**:
  - Hoạt động 100% ngay khi mở lần đầu mà **không đòi quyền Accessibility hay Screen Recording**.
- **Cập nhật tự động 1 chạm từ GitHub Releases**:
  - Tự động kiểm tra bản phát hành mới từ [`hungmtuci/DropShelf`](https://github.com/hungmtuci/DropShelf/releases/latest), tải gói `.zip`, xác thực, cài đè vào `/Applications/DropShelf.app`, gỡ cờ Gatekeeper (`xattr -cr`) và tự khởi động lại.

---

## ⌨️ Phím tắt & Thao tác nhanh

| Phím tắt / Thao tác | Chức năng |
| :--- | :--- |
| `Ctrl + Y` (`⌃Y`) *(hoặc `F5`, `⌥Space`, tự ghi phím tắt)* | Hiện / Ẩn nhanh Kệ nổi ở cạnh màn hình |
| `Space` *(khi rê chuột trên kệ)* | Mở Xem nhanh **Quick Look** cho tệp / nhóm Stack |
| `⌘ + V` *(khi rê chuột trên kệ)* hoặc `⌘ + ⇧ + V` | Dán nội dung từ Clipboard vào Kệ |
| Giữ `⌥ Option` khi kéo tệp ra Finder | Ép **Sao chép (Copy)** thay vì Di chuyển |
| Giữ `⌘ Command` khi kéo tệp ra Finder | Ép **Di chuyển (Move)** tệp sang vị trí mới |
| **Click trái** icon trên Menu Bar | Bật / Tắt nhanh Kệ nổi |
| **Click phải** icon trên Menu Bar | Mở menu nhanh (Ẩn/Hiện trên Dock, Dán Clipboard, Kiểm tra cập nhật GitHub, Cài đặt, Thoát) |
| **Kéo tệp thả vào icon Menu Bar hoặc Dock** | Thêm thẳng tệp vào Kệ và mở Kệ ngay |

---

## 📥 Tải về & Cài đặt nhanh (macOS 14.0+ Universal: Apple Silicon & Intel)

1. Tải bộ cài mới nhất tại trang **[Releases](https://github.com/hungmtuci/DropShelf/releases/latest)**:
   - **`DropShelf-Installer-v1.0.0.dmg`** *(Khuyên dùng)*
   - Hoặc **`DropShelf-v1.0.0-macOS.zip`**
2. Mở file `.dmg`:
   - Kéo `DropShelf.app` thả vào thư mục **`Applications`**, **HOẶC** nhấp chuột phải vào `Cai_Dat_DropShelf.command` → chọn **Open** để tự động cài đặt vào `/Applications` và gỡ cờ cách ly Gatekeeper.
3. Nếu macOS cảnh báo ứng dụng chưa công chứng Apple Developer ID khi mở lần đầu trên máy mới, chạy lệnh sau trong Terminal:
   ```bash
   xattr -cr /Applications/DropShelf.app && open /Applications/DropShelf.app
   ```

---

## 🛠️ Tự biên dịch từ mã nguồn (Build from Source)

Yêu cầu: macOS 14.0+ và Xcode hoặc Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/hungmtuci/DropShelf.git
cd DropShelf
chmod +x build_dropshelf.sh
./build_dropshelf.sh
```

Sau khi chạy xong `./build_dropshelf.sh`:
- Ứng dụng được tạo tại `./DropShelf.app`
- Bộ cài `.dmg` và `.zip` được xuất ra tại thư mục `./dist/`

## 📄 Giấy phép

Phát hành theo giấy phép [MIT License](LICENSE).
