# 🌟 ENIGMA — ỨNG DỤNG DI ĐỘNG HỖ TRỢ SINH HOẠT VÀ TÂM LÝ CHO SINH VIÊN THỰC TẬP DỰA TRÊN KỸ THUẬT RAG VÀ AI AGENT

> **Hệ sinh thái thông minh chăm sóc sức khỏe tinh thần, đồng hành và định hướng sinh hoạt cho sinh viên trong giai đoạn thực tập doanh nghiệp.**

---

## 📌 MỤC LỤC
1. [Giới Thiệu Đề Tài & Mục Tiêu](#1-giới-thiệu-đề-tài--mục-tiêu)
   - [Bối cảnh thực tế](#11-bối-cảnh-thực-tế)
   - [Mục tiêu của đề tài](#12-mục-tiêu-của-đề-tài)
   - [Mô hình 5 trụ cột sức khỏe (5 Pillars of Intern Wellbeing)](#13-mô-hình-5-trụ-cột-sức-khỏe-5-pillars-of-intern-wellbeing)
   - [Các tính năng nổi bật](#14-các-tính-năng-nổi-bật)
2. [Kiến Trúc & Công Nghệ Sử Dụng](#2-kiến-trúc--công-nghệ-sử-dụng)
   - [Kiến trúc hệ thống](#21-kiến-trúc-hệ-thống)
   - [Công nghệ & Thư viện Mobile App (Frontend)](#22-công-nghệ--thư-viện-mobile-app-frontend)
   - [Công nghệ & Thư viện Backend API & AI Engine](#23-công-nghệ--thư-viện-backend-api--ai-engine)
   - [Cơ sở dữ liệu & Lưu trữ](#24-cơ-sở-dữ-liệu--lưu-trữ)
3. [Cấu Trúc Thư Mục Dự Án](#3-cấu-trúc-thư-mục-dự-án)
4. [Hướng Dẫn Cài Đặt & Khởi Chạy Chi Tiết](#4-hướng-dẫn-cài-đặt--khởi-chạy-chi-tiết)
   - [Yêu cầu môi trường (Prerequisites)](#41-yêu-cầu-môi-trường-prerequisites)
   - [Bước 1: Clone mã nguồn](#bước-1-clone-mã-nguồn)
   - [Bước 2: Cài đặt và cấu hình Cơ sở dữ liệu (PostgreSQL)](#bước-2-cài-đặt-và-cấu-hình-cơ-sở-dữ-liệu-postgresql)
   - [Bước 3: Cài đặt & Chạy Backend API (FastAPI + ChromaDB + Gemini)](#bước-3-cài-đặt--chạy-backend-api-fastapi--chromadb--gemini)
   - [Bước 4: Cài đặt & Chạy ứng dụng di động (Flutter App)](#bước-4-cài-đặt--chạy-ứng-dụng-di-động-flutter-app)
5. [Kiểm Thử & Tài Liệu API](#5-kiểm-thử--tài-liệu-api)
6. [Tác Giả & Bản Quyền](#6-tác-giả--bản-quyền)

---

## 1. GIỚI THIỆU ĐỀ TÀI & MỤC TIÊU

### 1.1. Bối cảnh thực tế
Giai đoạn thực tập tại doanh nghiệp là bước chuyển tiếp quan trọng từ giảng đường đại học sang môi trường làm việc thực tế. Đặc biệt với các sinh viên thực tập xa nhà (như tại các khu công nghiệp, nhà máy công nghệ cao), các bạn thường phải đối mặt với nhiều khó khăn:
- **Sốc thực tế (Reality Shock):** Môi trường làm việc nghiêm ngặt, quy trình 5S, áp lực công việc ca kíp (ca ngày / ca đêm 8-12 tiếng).
- **Đảo lộn nhịp sinh hoạt:** Thay đổi giờ giấc ăn ngủ, mệt mỏi thể chất, đau cơ khi mang giày bảo hộ ESD ca đứng dài.
- **Áp lực tâm lý & Cô đơn:** Sống xa gia đình, mâu thuẫn sinh hoạt phòng trọ/ký túc xá, cảm giác lo âu về định hướng sự nghiệp dẫn đến kiệt sức (*burnout*) và nguy cơ bỏ dở kỳ thực tập giữa chừng.
- **Hạn chế của các kênh truyền thống:** Các kênh hỗ trợ hiện tại (thầy cô, nhóm chat, tài liệu PDF tĩnh) mang tính thụ động, thông tin phân tán và thiếu tính cá nhân hóa theo thời gian thực.

### 1.2. Mục tiêu của đề tài
Dự án **ENIGMA** được xây dựng nhằm mang lại một giải pháp toàn diện:
1. **Theo dõi và đánh giá sức khỏe sinh hoạt:** Ghi nhận nhật ký hàng ngày, nhịp ngủ, biểu đồ cảm xúc và mức độ căng thẳng của sinh viên.
2. **Đồng hành theo lộ trình 3 chặng:** Hướng dẫn sinh viên hòa nhập từng bước qua 3 giai đoạn: *Chuẩn bị hành trang ➔ Hòa nhập tháng đầu ➔ Duy trì & Bứt phá*.
3. **Cố vấn thông minh với RAG (Retrieval-Augmented Generation):** Trích xuất tri thức và kinh nghiệm thực chiến từ cựu sinh viên và chuyên gia qua cơ sở dữ liệu Vector (ChromaDB), hạn chế tối đa hiện tượng "ảo giác" (hallucination) của AI.
4. **Tương tác chủ động qua AI Agent:** Tác tử AI phân tích dữ liệu bất thường hoặc chu kỳ thiếu hụt để chủ động gửi thông điệp, khảo sát vi mô và đề xuất giải pháp thích ứng.
5. **Cơ chế Gamification & Vòng lặp tri thức (Data Flywheel):** Điểm danh nhận quà tinh thần (Gacha), bài tập thở Box Breathing, đồng thời thu thập bài học mới để không ngừng làm giàu kho tri thức cẩm nang.

### 1.3. Mô hình 5 trụ cột sức khỏe (5 Pillars of Intern Wellbeing)
Enigma tiếp cận sức khỏe sinh viên thực tập một cách toàn diện qua mô hình 5 trụ cột:
* 🧠 **Tâm lý (Mental):** Cảm xúc hàng ngày, giải tỏa căng thẳng, bài tập hít thở tức thì.
* 😴 **Giấc ngủ (Sleep):** Thời lượng ngủ, nhịp sinh học đổi ca ngày/đêm, chất lượng giấc ngủ.
* 💪 **Thể chất (Physical):** Đau mỏi cơ bắp, dinh dưỡng, mẹo giảm đau chân khi đứng ca dài.
* 👥 **Xã hội (Social):** Hòa nhập văn hóa doanh nghiệp, kỹ năng giải quyết bất đồng phòng trọ/KTX.
* 🎯 **Sự nghiệp (Career):** Quy định an toàn lao động, quyền lợi hợp đồng, kỹ năng làm việc thực tế.

### 1.4. Các tính năng nổi bật
- 🎲 **Gacha Daily Check-in:** Điểm danh nhận thông điệp truyền cảm hứng và lời khuyên mỗi ngày.
- 📊 **Mood & Habit Tracker:** Biểu đồ xu hướng tâm trạng, theo dõi nhịp ngủ và khảo sát vi mô (Life Logs).
- 🧭 **Internship Roadmap (3 Chặng):** Hệ thống nhiệm vụ từng tuần giúp sinh viên không bị bỡ ngỡ.
- 💬 **RAG AI Chat Companion:** Trợ lý ảo tư vấn tâm lý và kinh nghiệm thích ứng dựa trên nguồn tài liệu chuẩn hóa.
- 📖 **Cẩm nang thực chiến (Handbook):** Kho bài viết kinh nghiệm thực tế phân loại theo chủ đề, tích hợp chức năng gửi đóng góp bài viết mới (Curation Queue).
- 🔔 **Proactive Notifications:** Thông báo đẩy nhắc nhở sinh hoạt, hỗ trợ phục hồi năng lượng qua Firebase Cloud Messaging.

---

## 2. KIẾN TRÚC & CÔNG NGHỆ SỬ DỤNG

### 2.1. Kiến trúc hệ thống
Hệ thống được thiết kế theo mô hình **Client - Server - AI Engine** 3 tầng phân tách rõ ràng:
```
┌────────────────────────────────────────────────────────┐
│               MOBILE CLIENT (Flutter)                  │
│   (UI/UX, State Provider, Dio HTTP, Secure Storage)    │
└───────────────────────────┬────────────────────────────┘
                            │ RESTful APIs (HTTPS/JSON + JWT)
┌───────────────────────────▼────────────────────────────┐
│                BACKEND API (FastAPI)                   │
│   (Auth, Business Logic, Scheduler, ReAct Agent)       │
└─────────────┬────────────────────────────┬─────────────┘
              │                            │
┌─────────────▼─────────────┐ ┌────────────▼─────────────┐
│    PostgreSQL Database    │ │   AI Engine & Knowledge  │
│ (User, Logs, Tasks, Feed) │ │  - ChromaDB (Vector RAG) │
│                           │ │  - Google Gemini Pro/Exp │
└───────────────────────────┘ └──────────────────────────┘
```

### 2.2. Công nghệ & Thư viện Mobile App (Frontend)
- **Ngôn ngữ:** `Dart` (SDK `>=3.0.0 <4.0.0`)
- **Framework:** `Flutter` (Đa nền tảng, tập trung tối ưu Android)
- **Quản lý trạng thái (State Management):** `provider: ^6.1.2`
- **Giao diện & Trải nghiệm (UI/UX):**
  - `google_fonts: ^6.2.1`: Font chữ hiện đại (Inter).
  - `flutter_animate: ^4.5.0`: Hiệu ứng micro-interactions mượt mà.
  - `lottie: ^3.1.0`: Animation vector sống động.
  - `shimmer: ^3.0.0`: Hiệu ứng skeleton loading khi tải dữ liệu.
  - `fl_chart: ^0.69.0`: Vẽ biểu đồ xu hướng cảm xúc và chỉ số sinh hoạt.
- **Mạng & Lưu trữ:**
  - `dio: ^5.7.0`: Xử lý HTTP Request, đính kèm Interceptors và tự động làm mới JWT Token.
  - `flutter_secure_storage: ^9.2.2`: Lưu trữ an toàn mật mã và Access/Refresh Token.
  - `shared_preferences: ^2.3.4`: Lưu trữ cài đặt người dùng cục bộ.
- **Dịch vụ thông báo:**
  - `firebase_core: ^4.15.0` & `firebase_messaging: ^16.7.0`: Nhận thông báo đẩy (Push Notification) từ hệ thống.

### 2.3. Công nghệ & Thư viện Backend API & AI Engine
- **Ngôn ngữ:** `Python 3.10+`
- **Framework:** `FastAPI 0.111.0` (Xây dựng RESTful API bất đồng bộ hiệu năng cao).
- **ASGI Server:** `uvicorn[standard] 0.29.0`.
- **Xác thực & Phân quyền:**
  - `python-jose[cryptography]`: Tạo và xác thực chuẩn JWT Token.
  - `passlib[bcrypt]`: Băm mật khẩu người dùng chuẩn bảo mật cao.
  - `python-multipart`: Xử lý form-data đăng nhập OAuth2.
- **Trí tuệ nhân tạo (AI & Vector Database):**
  - `google-generativeai 0.7.2`: Tích hợp mô hình Large Language Model (Google Gemini).
  - `chromadb 0.5.0`: Cơ sở dữ liệu Vector lưu trữ Embeddings và tra cứu ngữ nghĩa tương đồng (Semantic Search RAG).
- **Push Notification Backend:**
  - `firebase-admin 6.5.0`: Gửi thông báo chủ động từ Agent tới thiết bị sinh viên.
- **Tiện ích & Validation:**
  - `pydantic 2.7.1` & `pydantic-settings 2.3.0`: Xác thực cấu trúc dữ liệu nghiêm ngặt.
  - `httpx 0.27.0`: Client bất đồng bộ.

### 2.4. Cơ sở dữ liệu & Lưu trữ
- **PostgreSQL 14+ / 18:** Cơ sở dữ liệu quan hệ lưu trữ thông tin tài khoản, nhật ký sinh hoạt (Life Logs), trạng thái nhiệm vụ, bài viết cẩm nang và hàng đợi kiểm duyệt (Curation Queue).
- **SQLAlchemy 2.0.30 (Async) + asyncpg 0.29.0:** Trình ánh xạ dữ liệu ORM bất đồng bộ cực nhanh.
- **Alembic 1.13.1:** Quản lý di chuyển lược đồ cơ sở dữ liệu (Database Migrations).
- **ChromaDB Local Vector Storage:** Lưu trữ các tài liệu cẩm nang đã được vector hóa để truy vấn RAG theo độ đo tương đồng Cosine.

---

## 3. CẤU TRÚC THƯ MỤC DỰ ÁN

```text
mentality/
├── README.md                          # Tài liệu tổng quan & hướng dẫn chạy dự án
├── backend/                           # Phân hệ Backend API (FastAPI)
│   ├── app/
│   │   ├── api/routes/                # Các API Endpoints (auth, chat, checkins, journals, tasks, handbook,...)
│   │   ├── core/                      # Cấu hình môi trường (config.py, security.py)
│   │   ├── db/                        # Kết nối DB & Định nghĩa ORM Models
│   │   ├── schemas/                   # Pydantic Schemas (Data Validation)
│   │   └── services/                  # Business Logic & AI Services (RAG, Gemini, Vector Store)
│   ├── chroma_db/                     # Thư mục lưu trữ dữ liệu Vector ChromaDB
│   ├── firebase_credentials.json      # File chứng thực Firebase Service Account
│   ├── main.py                        # Điểm khởi chạy ứng dụng FastAPI
│   ├── requirements.txt               # Danh sách thư viện Python cần cài đặt
│   ├── schema.sql                     # Mã nguồn DDL khởi tạo toàn bộ CSDL PostgreSQL
│   ├── setup_db.ps1                   # Script tự động tạo DB và khởi chạy schema trên Windows
│   └── test_api_endpoints.py          # Script kiểm thử tự động các API chính
├── Enigma/                            # Phân hệ Mobile App (Flutter)
│   ├── assets/                        # Hình ảnh, Font chữ và Animation Lottie
│   ├── lib/
│   │   ├── app.dart                   # Cấu hình Theme và Routing chính
│   │   ├── main.dart                  # Điểm khởi chạy ứng dụng Flutter
│   │   ├── core/                      # Cấu hình Theme, Constants, Network Client (Dio)
│   │   ├── models/                    # Data Models (Dart)
│   │   ├── providers/                 # Quản lý State bằng Provider
│   │   ├── screens/                   # Màn hình giao diện (Auth, Home, Chat, Handbook, Tasks,...)
│   │   └── widgets/                   # Các UI Component tái sử dụng
│   └── pubspec.yaml                   # Khai báo thư viện & dependencies của Flutter
└── docs/                              # Tài liệu phân tích yêu cầu (SRS, Đề cương, Tiến độ)
```

---

## 4. HƯỚNG DẪN CÀI ĐẶT & KHỞI CHẠY CHI TIẾT

### 4.1. Yêu cầu môi trường (Prerequisites)
Để chạy được toàn bộ dự án, máy tính cần được cài đặt sẵn:
1. **Python:** Phiên bản `3.10` trở lên (Khuyến nghị 3.10 hoặc 3.11).
2. **Flutter SDK:** Phiên bản `3.x.x` trở lên ([Tải Flutter](https://docs.flutter.dev/get-started/install)).
3. **PostgreSQL:** Phiên bản `14` trở lên (Đã chạy service trên cổng `5432`).
4. **Android Studio / Thiết bị thật / Emulator:** Để biên dịch và chạy ứng dụng Flutter.
5. **Google Gemini API Key:** Lấy key miễn phí tại [Google AI Studio](https://aistudio.google.com/).

---

### Bước 1: Clone mã nguồn
Mở Terminal / PowerShell và điều hướng tới thư mục làm việc:
```bash
git clone <URL_REPO_CUA_BAN>
cd mentality
```

---

### Bước 2: Cài đặt và cấu hình Cơ sở dữ liệu (PostgreSQL)

#### Cách 1: Sử dụng PowerShell Script tự động (Dành cho Windows)
Mở PowerShell với quyền **Administrator** tại thư mục `backend`:
```powershell
cd d:\mentality\backend
.\setup_db.ps1
```

#### Cách 2: Thiết lập thủ công qua PostgreSQL CLI (`psql`)
1. Đăng nhập vào PostgreSQL và tạo database:
```sql
CREATE DATABASE enigma_db ENCODING 'UTF8';
```
2. Thực thi file `schema.sql` để tạo toàn bộ bảng và chỉ mục:
```bash
psql -U postgres -d enigma_db -f backend/schema.sql
```

---

### Bước 3: Cài đặt & Chạy Backend API (FastAPI + ChromaDB + Gemini)

1. **Điều hướng vào thư mục backend và tạo môi trường ảo Python:**
```bash
cd backend
python -m venv venv
```

2. **Kích hoạt môi trường ảo:**
- Trên Windows (PowerShell):
  ```powershell
  .\venv\Scripts\Activate.ps1
  ```
- Trên Linux / macOS:
  ```bash
  source venv/bin/activate
  ```

3. **Cài đặt các module & package cần thiết:**
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

4. **Cấu hình file môi trường `.env`:**
Tạo file `.env` tại thư mục `backend/` với nội dung mẫu:
```env
APP_NAME="Enigma API"
DEBUG=True

# Cấu hình kết nối PostgreSQL (Thay đổi username/password tương ứng của bạn)
DATABASE_URL=postgresql+asyncpg://postgres:258079@localhost:5432/enigma_db

# Cấu hình Secret Key cho mã hóa JWT
SECRET_KEY=super_secret_jwt_key_for_enigma_internship_support_2026
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60
REFRESH_TOKEN_EXPIRE_DAYS=30

# Khóa API Google Gemini AI
GEMINI_API_KEY=YOUR_GOOGLE_GEMINI_API_KEY_HERE

# Đường dẫn file chứng thực Firebase (nếu sử dụng thông báo)
FIREBASE_CREDENTIALS_PATH=firebase_credentials.json
```

5. **Khởi chạy máy chủ Backend:**
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
> Khi khởi chạy lần đầu, hệ thống sẽ **tự động khởi tạo và seed dữ liệu cẩm nang mẫu** vào cả PostgreSQL và cơ sở dữ liệu Vector ChromaDB.

---

### Bước 4: Cài đặt & Chạy ứng dụng di động (Flutter App)

1. **Mở một cửa sổ Terminal mới và điều hướng vào thư mục `Enigma`:**
```bash
cd Enigma
```

2. **Tải các gói thư viện Flutter (Dependencies):**
```bash
flutter pub get
```

3. **Kiểm tra thiết bị kết nối:**
```bash
flutter devices
```

4. **Cấu hình IP Backend (Nếu chạy trên Android Emulator hoặc Máy thật):**
- Mở file cấu hình mạng trong Flutter (ví dụ: `lib/core/constants/` hoặc Base URL của Dio):
  - **Android Emulator:** Dùng `http://10.0.2.2:8000` (đại diện cho localhost của máy tính).
  - **Thiết bị thật kết nối chung mạng Wifi:** Dùng địa chỉ IP nội bộ của máy chủ (Ví dụ: `http://192.168.1.x:8000`).

5. **Khởi chạy ứng dụng:**
```bash
flutter run
```

---

## 5. KIỂM THỬ & TÀI LIỆU API

### 5.1. Tài liệu API tương tác trực quan (Swagger UI)
Sau khi khởi động Backend, bạn có thể truy cập tài liệu API đầy đủ và dùng thử trực tiếp tại:
- 📖 **Swagger UI:** `http://localhost:8000/docs`
- 📑 **Redoc UI:** `http://localhost:8000/redoc`

### 5.2. Chạy kịch bản kiểm thử API tự động
Để kiểm tra tính toàn vẹn của hệ thống backend và các endpoint quan trọng:
```bash
cd backend
python test_api_endpoints.py
```

### 5.3. Sử dụng Postman Collection
Dự án đã tích hợp sẵn file cấu hình Postman để test toàn bộ luồng nghiệp vụ:
- Import file: `backend/postman_enigma_collection.json` vào ứng dụng Postman để kiểm thử các API: Đăng ký, Đăng nhập, Điểm danh, Chat RAG, Lấy danh sách cẩm nang, Gửi khảo sát vi mô,...

---

## 6. TÁC GIẢ & BẢN QUYỀN

- **Dự án:** ENIGMA — Student Mental & Internship Adaptation Assistant
- **Nghiên cứu & Phát triển:** Nhóm sinh viên thực hiện Đề tài tốt nghiệp / Nghiên cứu ứng dụng
- **Cố vấn & Hướng dẫn:** Giảng viên hướng dẫn & Ban cố vấn thực tập khoa CNTT
- **Bản quyền:** Dự án phát triển phục vụ mục đích học thuật, nghiên cứu và hỗ trợ cộng đồng sinh viên. Mọi quyền được bảo lưu © 2026.
