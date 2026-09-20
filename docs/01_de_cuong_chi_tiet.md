# ĐỀ CƯƠNG CHI TIẾT ĐỒ ÁN

## ENIGMA — Ứng Dụng Di Động Hỗ Trợ Sinh Hoạt và Tâm Lý Cho Sinh Viên Thực Tập Dựa Trên Kỹ Thuật RAG và AI Agent

---

## 1. Lý Do Chọn Đề Tài

### 1.1. Bối cảnh thực tế

Giai đoạn thực tập doanh nghiệp là bước chuyển giao quan trọng từ môi trường đại học sang môi trường làm việc thực tế. Đặc biệt với các sinh viên thực tập xa nhà (ví dụ: thực tập tại LG Display Hải Phòng), quá trình này đặt ra nhiều thách thức:

- **Sốc thực tế (Reality Shock)**: Khoảng cách giữa kỳ vọng học đường và thực tiễn công việc nhà máy (ca kíp, kỷ luật 5S, quy trình nghiêm ngặt).
- **Đảo lộn sinh hoạt**: Thay đổi múi giờ sinh hoạt (ca đêm, dậy sớm), ăn uống không quen, ở trọ xa gia đình.
- **Áp lực tâm lý**: Cô đơn, nhớ nhà, mâu thuẫn với bạn cùng phòng, cảm giác "làm trái ngành" dẫn đến chán nản.
- **Nguy cơ bỏ dở**: Khi các yếu tố trên tích lũy → kiệt sức (burnout) → sinh viên bỏ thực tập giữa chừng.

### 1.2. Hạn chế của các kênh hỗ trợ hiện tại

| Kênh hiện tại | Hạn chế |
|---|---|
| Giảng viên hướng dẫn | Liên hệ thụ động, chỉ khi sinh viên chủ động báo cáo |
| Nhóm chat Zalo/Facebook | Thông tin loãng, thiếu cấu trúc, khó tìm kiếm lại |
| Phòng tham vấn tâm lý | Không tiếp cận được khi thực tập xa trường |
| Tài liệu hướng dẫn truyền thống | Dạng PDF tĩnh, không tương tác, không cá nhân hóa |

### 1.3. Giải pháp đề xuất

Xây dựng ứng dụng di động **Enigma** tích hợp:
- **RAG (Retrieval-Augmented Generation)**: Tra cứu chính xác cẩm nang kinh nghiệm từ cựu sinh viên, hạn chế hallucination.
- **AI Agent**: Chủ động phát hiện bất thường và tương tác ngược với sinh viên.
- **Gamification**: Điểm danh gacha + nhiệm vụ theo chặng để tạo động lực duy trì.

---

## 2. Phân Tích Khó Khăn Thực Tế Của Sinh Viên Thực Tập

### 2.1. Mô hình 5 trụ cột (Five Pillars of Intern Wellbeing)

Hệ thống Enigma xây dựng mô hình đánh giá sức khỏe toàn diện dựa trên 5 trụ cột:

| Trụ cột | Ký hiệu | Các chỉ số theo dõi | Ví dụ khó khăn |
|---|---|---|---|
| **Tâm lý (Mental)** | 🧠 | Mức stress, cảm xúc hàng ngày, lo lắng | Sốc văn hóa, cô đơn xa nhà, cảm giác vô dụng |
| **Giấc ngủ (Sleep)** | 😴 | Số giờ ngủ, chất lượng giấc ngủ, giờ đi ngủ | Ca đêm, tiếng ồn ký túc, dùng điện thoại khuya |
| **Thể chất (Physical)** | 💪 | Triệu chứng cơ thể, hoạt động thể chất | Đau mỏi, ăn không quen, ốm vặt |
| **Xã hội (Social)** | 👥 | Mức độ kết nối, giao tiếp | Khó hòa nhập, mâu thuẫn bạn phòng |
| **Sự nghiệp (Career)** | 🎯 | Định hướng, kỹ năng học được, hài lòng công việc | Làm trái ngành, không biết quyền lợi |

### 2.2. Bảng khó khăn theo timeline thực tập

| Giai đoạn | Thời gian | Khó khăn chính | Mức độ rủi ro |
|---|---|---|---|
| **Chuẩn bị** (Preparation) | Trước khi đi | Lo lắng, thiếu thông tin, không biết chuẩn bị gì | 🟡 Trung bình |
| **Hòa nhập** (Adaptation) | Tháng 1 | Sốc thực tế, mất ngủ, nhớ nhà, bỡ ngỡ quy trình | 🔴 Cao |
| **Duy trì** (Sustain) | Tháng 2–3 | Mệt mỏi tích lũy, chán nản, burnout, muốn bỏ | 🔴 Rất cao |

---

## 3. Mục Tiêu Đề Tài

### 3.1. Mục tiêu tổng quát

Xây dựng ứng dụng di động theo dõi và hỗ trợ sinh hoạt, tâm lý cho sinh viên thực tập dựa trên kỹ thuật RAG và AI Agent, nhằm cung cấp giải pháp thích ứng môi trường kịp thời dựa trên tri thức thực tế.

### 3.2. Mục tiêu cụ thể

| # | Mục tiêu | Chỉ tiêu đo lường |
|---|---|---|
| MT1 | Thu thập và số hóa dữ liệu kinh nghiệm thực tế từ cựu sinh viên → Knowledge Base | ≥ 50 bài kinh nghiệm được embed vào ChromaDB |
| MT2 | Xây dựng mô-đun RAG truy xuất chính xác theo ngữ cảnh, hạn chế hallucination | Accuracy ≥ 80% trên tập test câu hỏi |
| MT3 | Thiết lập AI Agent chủ động phát hiện bất thường về sinh hoạt | Phát hiện ≥ 3 loại bất thường (thiếu ngủ, stress cao, bỏ check-in) |
| MT4 | Phát triển ứng dụng di động đầy đủ chức năng | ≥ 6 module hoàn chỉnh trên Android |
| MT5 | Kiểm thử và đánh giá trải nghiệm người dùng | ≥ 20 sinh viên tham gia thử nghiệm |

---

## 4. Phạm Vi Đề Tài

### 4.1. Trong phạm vi (In Scope)

- Ứng dụng di động Android (Flutter)
- Backend API (FastAPI + PostgreSQL)
- RAG module (ChromaDB + Gemini API)
- AI Agent với Function Calling
- Hệ thống điểm danh gacha + nhiệm vụ theo chặng
- Nhật ký sinh hoạt và khảo sát vi mô
- Firebase Cloud Messaging cho push notifications
- Thử nghiệm trên tập mẫu sinh viên trong phạm vi khoa

### 4.2. Ngoài phạm vi (Out of Scope)

- Chẩn đoán y khoa hoặc điều trị bệnh lý tâm thần chuyên sâu
- Phát triển trên iOS (chỉ tập trung Android trong giai đoạn đồ án)
- Tích hợp thiết bị đeo (smartwatch, fitness band)
- Hệ thống quản lý thực tập cho phía doanh nghiệp
- Đa ngôn ngữ (chỉ hỗ trợ tiếng Việt)

---

## 5. Ý Nghĩa Đề Tài

### 5.1. Ý nghĩa thực tiễn
- Giúp sinh viên **chủ động** theo dõi nhịp sinh hoạt thay vì đợi kiệt sức mới tìm giúp đỡ
- Hệ thống nhiệm vụ theo chặng **hướng dẫn từng bước** chuẩn bị và thích nghi
- AI Agent **chủ động tương tác** — khắc phục tính thụ động của các kênh hỗ trợ truyền thống
- Tạo **vòng lặp tri thức**: kinh nghiệm cựu sinh viên → Knowledge Base → hỗ trợ thế hệ sau

### 5.2. Ý nghĩa học thuật
- Nghiên cứu và hiện thực hóa kiến trúc tích hợp đa tầng: Mobile App ↔ REST API ↔ RDBMS ↔ Vector DB ↔ LLM
- Đánh giá hiệu quả thực tế của RAG trong việc giảm hallucination
- Thử nghiệm cơ chế Function Calling của AI Agent trong bài toán thực tế

---

## 6. Tổng Quan Công Nghệ Sử Dụng

### 6.1. Bảng tổng hợp công nghệ

| Tầng | Công nghệ | Phiên bản | Vai trò |
|---|---|---|---|
| **Mobile App** | Flutter | SDK ≥ 3.0 | Framework đa nền tảng, UI engine |
| | Dart | ≥ 3.0 | Ngôn ngữ lập trình chính cho mobile |
| | Provider | 6.1.2 | State management (ChangeNotifier pattern) |
| | Dio | 5.7.0 | HTTP client với interceptors |
| | flutter_secure_storage | 9.2.2 | Lưu trữ JWT token an toàn |
| | fl_chart | 0.69.0 | Biểu đồ xu hướng tâm trạng |
| | flutter_animate | 4.5.0 | Micro-animations |
| | google_fonts | 6.2.1 | Typography (Inter font) |
| | lottie | 3.1.0 | Hoạt ảnh Lottie JSON |
| **Backend API** | FastAPI | 0.111.0 | Python async web framework |
| | Uvicorn | 0.29.0 | ASGI server |
| | SQLAlchemy | 2.0.30 | ORM (async mode) |
| | asyncpg | 0.29.0 | Async PostgreSQL driver |
| | Pydantic | 2.7.1 | Data validation & serialization |
| | python-jose | 3.3.0 | JWT token generation/verification |
| | passlib | 1.7.4 | Password hashing (bcrypt) |
| | Alembic | 1.13.1 | Database migration tool |
| **Database** | PostgreSQL | 18 | RDBMS chính |
| **AI/ML** | Google Gemini API | 0.7.2 | Large Language Model |
| | ChromaDB | 0.5.0 | Vector database cho semantic search |
| **Cloud Services** | Firebase Admin SDK | 6.5.0 | Push notifications (FCM) |

### 6.2. Kiến trúc hệ thống tổng quan

```
┌──────────────────────────────────────────────────────────────┐
│                   TẦNG TRÌNH BÀY (Flutter)                   │
│  ┌──────┐ ┌──────┐ ┌────────┐ ┌───────┐ ┌───────┐ ┌──────┐ │
│  │Splash│ │ Home │ │Check-in│ │ Tasks │ │  Cẩm  │ │  AI  │ │
│  │/Auth │ │Screen│ │ Gacha  │ │Screen │ │ Nang  │ │ Chat │ │
│  └──┬───┘ └──┬───┘ └───┬────┘ └──┬────┘ └──┬────┘ └──┬───┘ │
│     │        │         │         │         │         │      │
│  ┌──┴────────┴─────────┴─────────┴─────────┴─────────┴──┐   │
│  │              Dio HTTP Client + JWT Interceptor         │   │
│  └───────────────────────┬───────────────────────────────┘   │
└──────────────────────────┼───────────────────────────────────┘
                           │ REST API (JSON)
┌──────────────────────────┼───────────────────────────────────┐
│                   TẦNG API (FastAPI)                          │
│  ┌──────┐ ┌──────┐ ┌────────┐ ┌───────┐ ┌───────┐ ┌──────┐ │
│  │ Auth │ │Users │ │Checkins│ │Journals│ │  Chat │ │Admin │ │
│  │ API  │ │ API  │ │  API   │ │  API  │ │  API  │ │ API  │ │
│  └──┬───┘ └──┬───┘ └───┬────┘ └──┬────┘ └──┬────┘ └──┬───┘ │
│     │        │         │         │         │         │      │
│  ┌──┴────────┴─────────┴─────────┴─────────┘         │      │
│  │         Service Layer (Business Logic)             │      │
│  └───────────────────────┬───────────────────────────┘      │
│                          │                                   │
│  ┌───────────────────────┴───────────────────────────┐      │
│  │              RAG Module + AI Agent                 │      │
│  │  ┌─────────────┐  ┌──────────────┐  ┌──────────┐ │      │
│  │  │  Retriever   │  │  Generator   │  │ Function │ │      │
│  │  │ (ChromaDB)   │  │ (Gemini API) │  │ Calling  │ │      │
│  │  └──────┬──────┘  └──────┬───────┘  └────┬─────┘ │      │
│  └─────────┼───────────────┼────────────────┼────────┘      │
└────────────┼───────────────┼────────────────┼────────────────┘
             │               │                │
┌────────────┼───────────────┼────────────────┼────────────────┐
│            │   TẦNG DỮ LIỆU                │                │
│  ┌─────────┴──────┐  ┌────┴────────┐  ┌────┴──────────┐    │
│  │   ChromaDB     │  │   Gemini    │  │  Firebase     │    │
│  │  Vector Store  │  │   Cloud     │  │    FCM        │    │
│  │  (Embeddings)  │  │   API       │  │ (Push Notif)  │    │
│  └────────────────┘  └─────────────┘  └───────────────┘    │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              PostgreSQL Database                       │  │
│  │  users │ intern_profiles │ daily_checkins │ journals   │  │
│  │  tasks │ user_task_progress │ wellbeing_assessments    │  │
│  │  handbook_articles │ chat_sessions │ chat_messages     │  │
│  │  achievements │ notification_logs │ refresh_tokens     │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 6.3. Giải thích lựa chọn công nghệ

**Flutter** (thay vì React Native hay Native):
- Hot Reload tăng tốc phát triển, phù hợp nhóm nhỏ
- Widget-based UI dễ tạo giao diện phức tạp (gacha wheel, radar chart)
- Dart strongly-typed giảm lỗi runtime
- Một codebase duy nhất cho cả Android và iOS

**FastAPI** (thay vì Django hay Express.js):
- Async native: xử lý concurrent requests hiệu quả (quan trọng khi gọi Gemini API)
- Swagger UI tự động → dễ test API
- Pydantic validation type-safe cho request/response
- Python ecosystem tận dụng trực tiếp thư viện AI

**ChromaDB** (thay vì Pinecone hay FAISS):
- Open-source, chạy local, không cần cloud service
- Python-native, tích hợp trực tiếp vào FastAPI
- Nhẹ, đơn giản, phù hợp quy mô đề tài

**Gemini API** (thay vì OpenAI hay Llama):
- Function Calling hỗ trợ AI Agent gọi hàm tự động
- Free tier rộng rãi, phù hợp dự án nghiên cứu
- Hiểu và phản hồi tiếng Việt tốt

---

## 7. Đối Tượng Sử Dụng

### 7.1. Sinh viên (Student)
- Đăng ký, đăng nhập, quản lý hồ sơ cá nhân
- Điểm danh hằng ngày + gacha nhận thông điệp tích cực
- Ghi nhật ký sinh hoạt (giấc ngủ, stress, triệu chứng)
- Theo dõi và hoàn thành nhiệm vụ theo chặng thực tập
- Tra cứu cẩm nang kinh nghiệm cựu sinh viên
- Chat tương tác với trợ lý AI Enigma

### 7.2. Quản trị viên (Admin)
- Quản lý tài khoản người dùng và phân quyền
- Cập nhật, kiểm duyệt Knowledge Base
- Theo dõi chỉ số tương tác và độ chính xác AI
- Giám sát ổn định hệ thống Backend + AI Engine

---

## 8. Phân Công Nhóm (Tham Khảo)

| Thành viên | Vai trò | Trách nhiệm chính |
|---|---|---|
| Thành viên 1 | Team Lead + Backend | FastAPI, PostgreSQL, Auth, Business Logic |
| Thành viên 2 | AI Engineer | RAG module, ChromaDB, Gemini integration, AI Agent |
| Thành viên 3 | Mobile Developer | Flutter UI/UX, State management, API integration |
| Thành viên 4 | Data + Testing | Thu thập dữ liệu, khảo sát, testing, documentation |

*Bảng phân công trên là mẫu tham khảo, cần điều chỉnh theo số lượng và năng lực thực tế của nhóm.*

---

## 9. Kế Hoạch Thực Hiện (10 Tuần)

| Tuần | Thời gian | Nội dung | Sản phẩm |
|---|---|---|---|
| 1 | 08/09 – 14/09 | Hoàn thiện ý tưởng, phân tích, chốt đề tài, tìm hiểu công nghệ | Đề cương chi tiết |
| 2 | 15/09 – 21/09 | Khởi tạo repo, cài đặt môi trường, thiết kế khảo sát, đặc tả yêu cầu | Repo + SRS + Khảo sát |
| 3 | 22/09 – 28/09 | Database schema, Backend Auth (JWT), Flutter Auth screens | Auth hoạt động end-to-end |
| 4 | 29/09 – 05/10 | Backend Checkins + Journals + Tasks API | API Swagger functional |
| 5 | 06/10 – 12/10 | Flutter ↔ Backend integration (xóa mock data) | App kết nối real API |
| 6 | 13/10 – 19/10 | Thu thập dữ liệu cựu SV, xây dựng Knowledge Base, ChromaDB indexing | ≥ 50 articles indexed |
| 7 | 20/10 – 26/10 | RAG module + Handbook API + Chat API | AI Chat trả lời từ KB |
| 8 | 27/10 – 02/11 | AI Agent Function Calling + Anomaly Detection + FCM | Agent chủ động tương tác |
| 9 | 03/11 – 09/11 | Admin Dashboard + Kiểm thử tích hợp + Bug fix | Hệ thống ổn định |
| 10 | 10/11 – 16/11 | Thử nghiệm với sinh viên + Thu thập đánh giá + Viết báo cáo | Báo cáo hoàn chỉnh |

---

## 10. Kết Quả Mong Đợi

1. **Ứng dụng di động (Mobile App)** hoàn chỉnh trên Android, vận hành ổn định, giao diện trực quan
2. **Hệ thống Backend API** đáp ứng tốt các nghiệp vụ xác thực, nhật ký, nhiệm vụ, điểm danh
3. **Mô-đun RAG** truy xuất chính xác cẩm nang, phản hồi phù hợp ngữ cảnh, giảm thiểu hallucination
4. **AI Agent** hoạt động linh hoạt, tự động nhận diện bất thường và tương tác kịp thời
5. **Báo cáo đánh giá** từ thử nghiệm thực tế với sinh viên
