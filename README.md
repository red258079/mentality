# 🌟 ENIGMA - Ứng Dụng Hỗ Trợ Sinh Hoạt & Tâm Lý Sinh Viên Thực Tập

![Enigma Banner](https://via.placeholder.com/1200x300.png?text=ENIGMA+-+Student+Wellbeing+App)

## 📌 Tên Đề Tài
**ENIGMA** — Ứng dụng di động hỗ trợ sinh hoạt và tâm lý cho sinh viên thực tập dựa trên kỹ thuật RAG (Retrieval-Augmented Generation) và AI Agent.

## 🎯 Mục Đích & Mục Tiêu
Giai đoạn thực tập thường mang lại cú "sốc thực tế" (Reality Shock) do thay đổi môi trường làm việc, ca kíp và áp lực. Enigma được sinh ra để:
- **Theo dõi sức khỏe toàn diện (5 Trụ cột):** Giấc ngủ (Sleep), Thể chất (Physical), Tâm lý (Mental), Xã hội (Social) và Sự nghiệp (Career).
- **Gamification tạo động lực:** Hệ thống điểm danh nhận thông điệp tích cực (Gacha) và chuỗi nhiệm vụ hướng dẫn thích nghi theo 3 chặng (Chuẩn bị $\rightarrow$ Hòa nhập $\rightarrow$ Duy trì).
- **Trợ lý AI bám sát thực tế (RAG):** Thay vì các lời khuyên sáo rỗng, AI trả lời dựa trên kho Cẩm nang kinh nghiệm (Knowledge Base) thu thập từ các thế hệ cựu sinh viên đi trước.
- **Cảnh báo sớm:** Theo dõi nhật ký vi mô (Micro-survey) để AI tự động đánh giá và cảnh báo khi sinh viên có dấu hiệu kiệt sức.

---

## 💻 Công Nghệ & Ngôn Ngữ Sử Dụng

### Khung Kiến Trúc (Architecture)
Hệ thống sử dụng mô hình Client-Server hiện đại, chia tách rõ ràng Frontend và Backend.

* **Frontend (Mobile Client):**
  * **Ngôn ngữ:** Dart
  * **Framework:** Flutter (Hỗ trợ đa nền tảng, tối ưu cho Android)
  * **State Management:** Provider
  * **Networking:** Dio (kèm Interceptors quản lý JWT tự động)
* **Backend (API Server):**
  * **Ngôn ngữ:** Python 3.9+
  * **Framework:** FastAPI (Hỗ trợ xử lý bất đồng bộ - Async, tốc độ cao)
  * **ORM:** SQLAlchemy (Async)
* **Cơ Sở Dữ Liệu (Databases):**
  * **RDBMS:** PostgreSQL 18 (Lưu trữ tài khoản, nhật ký, điểm danh, nhiệm vụ)
  * **Vector DB:** ChromaDB (Lưu trữ các vector nhúng của cẩm nang, phục vụ RAG)
* **AI & Machine Learning:**
  * **LLM Engine:** Google Gemini API (Tạo sinh câu trả lời & Đánh giá tâm lý)
  * **Kỹ thuật:** RAG (Truy xuất tương cường tạo sinh) với Cosine Similarity.

---

## ⚙️ Hướng Dẫn Cài Đặt & Khởi Chạy (Setup Guide)

Yêu cầu kiên quyết (Prerequisites):
- [Python 3.9+](https://www.python.org/downloads/)
- [PostgreSQL 18](https://www.postgresql.org/download/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Khuyến nghị dùng Android Studio)
- Git

### 1. Cài đặt và Chạy Backend (FastAPI)

Mở terminal và thực hiện các bước sau:

```bash
# Bước 1: Clone repository và di chuyển vào thư mục backend
git clone https://github.com/red258079/mentality.git
cd mentality/backend

# Bước 2: Tạo và kích hoạt môi trường ảo (Virtual Environment)
# (Trên Windows)
python -m venv .venv
.venv\Scripts\activate
# (Trên macOS/Linux)
python3 -m venv .venv
source .venv/bin/activate

# Bước 3: Cài đặt các thư viện cần thiết
pip install -r requirements.txt

# Bước 4: Thiết lập biến môi trường
# Copy file mẫu .env.example thành .env và điền các thông tin của bạn
cp .env.example .env
# Chỉnh sửa nội dung .env (Sửa DATABASE_URL, GEMINI_API_KEY, JWT_SECRET_KEY,...)

# Bước 5: Khởi tạo Database PostgreSQL
# Đảm bảo dịch vụ PostgreSQL đang chạy. Bạn có thể sử dụng script tự động:
./setup_db.ps1
# Hoặc copy nội dung file schema.sql chạy thủ công trong pgAdmin/DBeaver.

# Bước 6: Khởi chạy Server Backend
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
> **Lưu ý:** Khi chạy lần đầu, server sẽ tự động seed (nạp) dữ liệu cẩm nang mẫu vào ChromaDB. Bạn có thể truy cập tài liệu API tự động tại: `http://localhost:8000/docs`.

### 2. Cài đặt và Chạy Mobile App (Flutter qua Android Studio)

```bash
# Bước 1: Khởi động Android Studio
# Mở thư mục "Enigma" trong thư mục dự án (mentality/Enigma)

# Bước 2: Tải các gói phụ thuộc (Dependencies)
# Mở Terminal trong Android Studio và chạy:
flutter pub get

# Bước 3: Cấu hình địa chỉ IP kết nối Backend
# Do máy ảo Android (Emulator) không nhận 'localhost' là máy tính của bạn,
# bạn cần trỏ API_BASE_URL trong mã nguồn (vd: lib/core/api/api_client.dart hoặc file .env của flutter)
# về địa chỉ IP mạng LAN của máy tính (Ví dụ: http://192.168.1.X:8000).

# Bước 4: Khởi chạy Ứng dụng
# Mở một Android Emulator hoặc cắm thiết bị Android thật vào máy.
# Nhấn nút "Run (Tam giác màu xanh)" trên thanh công cụ của Android Studio 
# Hoặc chạy lệnh trong terminal:
flutter run
```

---
## 📄 Bản Quyền & Giấy Phép
Dự án được phát triển nhằm mục đích nghiên cứu học thuật.

*Được phát triển bởi nhóm Enigma - 2026*
