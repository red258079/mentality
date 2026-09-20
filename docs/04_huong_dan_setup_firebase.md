# HƯỚNG DẪN THIẾT LẬP FIREBASE CHO DỰ ÁN ENIGMA

Để tính năng gửi thông báo (Push Notifications - FCM) hoạt động từ Backend (FastAPI) đến thiết bị di động (Flutter), bạn cần thiết lập dự án Firebase. Dưới đây là hướng dẫn chi tiết từng bước:

---

## PHẦN 1: TẠO DỰ ÁN TRÊN FIREBASE CONSOLE

1. Truy cập [Firebase Console](https://console.firebase.google.com/).
2. Đăng nhập bằng tài khoản Google của bạn.
3. Nhấn vào nút **"Add project"** (Thêm dự án).
4. Nhập tên dự án: `Enigma-Mentality` (hoặc tên bất kỳ bạn thích).
5. Tắt Google Analytics (để quá trình tạo nhanh hơn, dự án sinh viên chưa cần thiết).
6. Nhấn **"Create project"** và đợi Firebase khởi tạo xong.

---

## PHẦN 2: KẾT NỐI FIREBASE VỚI FLUTTER (ANDROID & IOS)

> **💡 Lưu ý về iOS:** Flutter hỗ trợ cả **Android** và **iOS** (cùng Web, Desktop). Tuy nhiên, do bạn đang làm việc trên hệ điều hành **Windows**, việc build và testPush Notification trên iOS sẽ cần máy **macOS (Xcode)** và **Tài khoản Apple Developer**. Vì vậy trong hướng dẫn này, chúng ta tập trung chọn **Android** để dễ dàng test ngay. Nếu sau này build cho iOS, bạn chỉ cần chọn thêm `ios` khi chạy `flutterfire configure`.

### Bước 2.1: Cài đặt công cụ (Mở Terminal)

1. Cài đặt Firebase CLI (nếu chưa có):
   ```bash
   npm install -g firebase-tools
   ```
2. Đăng nhập vào Firebase bằng Terminal:
   ```bash
   firebase login
   ```
   *(Trình duyệt sẽ mở ra để bạn chọn tài khoản Google, hãy cấp quyền cho nó).*

3. Kích hoạt FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```

### Bước 2.2: Cấu hình FlutterFire cho dự án

1. Trỏ Terminal vào thư mục Flutter của bạn (`d:\mentality\Enigma`):
   ```bash
   cd d:\mentality\Enigma
   ```
2. Chạy lệnh cấu hình:
   ```bash
   flutterfire configure
   ```
   *(Nếu Windows báo lỗi `'flutterfire' is not recognized...`, chạy lệnh bằng đường dẫn đầy đủ sau:)*
   ```cmd
   "C:\Users\DELL 5540\AppData\Local\Pub\Cache\bin\flutterfire" configure
   ```
3. Các bước trên màn hình Terminal:
   - Nó sẽ liệt kê các dự án Firebase của bạn → **Chọn dự án `Enigma-Mentality` bạn vừa tạo**.
   - Chọn nền tảng muốn hỗ trợ → **Chọn `android`** (nếu dùng máy Windows để chạy giả lập/điện thoại Android). Bạn vẫn có thể tích chọn cả `ios` nếu sau này muốn build trên macOS.
   - Đợi lệnh chạy xong. Khi hoàn tất, nó sẽ tự động tạo file `lib/firebase_options.dart` và thêm file cấu hình `google-services.json` vào thư mục Android.

### Bước 2.3: Thêm package vào Flutter

Mở terminal tại thư mục `Enigma` và chạy lệnh:
```bash
flutter pub add firebase_core firebase_messaging
```

---

## PHẦN 3: LẤY KHÓA BẢO MẬT CHO BACKEND (FASTAPI)

Để Backend (FastAPI) có quyền ra lệnh cho Firebase gửi thông báo xuống điện thoại, Backend cần một chiếc "chìa khóa" (Service Account Key).

1. Quay lại [Firebase Console](https://console.firebase.google.com/), vào dự án `Enigma-Mentality`.
2. Ở góc trên bên trái, nhấn vào biểu tượng **Bánh răng (Project settings)**.
3. Chuyển sang tab **"Service accounts"**.
4. Đảm bảo đang chọn "Firebase Admin SDK".
5. Nhấn nút **"Generate new private key"** (Tạo khóa cá nhân mới).
6. Một file `.json` sẽ được tải xuống máy tính của bạn (tên thường có dạng `enigma-mentality-firebase-adminsdk-...json`).
7. **Đổi tên file đó thành:** `firebase_credentials.json`.
8. Copy file này và **đặt vào thư mục root của Backend** (`d:\mentality\backend\firebase_credentials.json`).

> **⚠️ LƯU Ý BẢO MẬT:** Tuyệt đối không upload file `firebase_credentials.json` này lên GitHub (hãy thêm nó vào file `.gitignore` của backend). File này có quyền kiểm soát toàn bộ dự án Firebase của bạn.

---

## HOÀN TẤT

Sau khi làm xong 3 phần trên, cấu hình Firebase của bạn đã hoàn tất! Trong các tuần tiếp theo, chúng ta sẽ viết code để:
1. Flutter App xin quyền gửi thông báo từ người dùng và lấy mã FCM Token.
2. FastAPI Backend đọc file `firebase_credentials.json` để bắn thông báo nhắc nhở (Ví dụ: "Bạn đã quên ghi nhật ký hôm nay!") đến FCM Token đó.
