# BÁO CÁO TIẾN ĐỘ THỰC HIỆN TUẦN 3
## Dự án: ENIGMA - Hệ thống ứng dụng di động hỗ trợ sinh hoạt & tâm lý cho sinh viên thực tập
**Thời gian:** 22/09/2026 – 28/09/2026

---

## TỔNG QUAN TIẾN ĐỘ TUẦN 3

Trong Tuần 3, nhóm đã hoàn thành toàn diện 4 nhiệm vụ trọng tâm:
1. **Xử lý, làm sạch và số hóa dữ liệu khảo sát thực tế:** Phân tích tập mẫu 18 phản hồi chi tiết từ sinh viên thực tập và cựu sinh viên, trích xuất các bài học thực chiến và nạp vào cơ sở tri thức (Knowledge Base).
2. **Thiết kế CSDL quan hệ (PostgreSQL) và thiết lập CSDL vector (ChromaDB):** Xây dựng 12 bảng PostgreSQL với Async ORM SQLAlchemy, cấu hình ChromaDB lưu trữ vector nhúng với không gian khoảng cách Cosine Similarity.
3. **Viết các API xác thực người dùng (JWT) và khởi tạo khung Backend với FastAPI:** Triển khai 5 endpoint Auth hoàn chỉnh (Register, Login, Refresh Token Rotation, Me, Logout) với cơ chế bảo mật mã hóa `bcrypt`.
4. **Thiết kế wireframe, prototype và tạo khung giao diện cơ bản bằng Flutter:** Hoàn thiện luồng Auth, bộ State Management (Provider), Dark Theme chuyên sâu và 8 màn hình chức năng sinh viên.

---

## NHIỆM VỤ 1: Xử lý, làm sạch và số hóa dữ liệu khảo sát để xây dựng cơ sở tri thức ban đầu

### 1.1. Phân tích tập dữ liệu khảo sát thực tế
Nhóm đã thu thập và xử lý tập dữ liệu từ tệp khảo sát chính thức `docs/Dữ liệu khảo sát thực tập (Phản hồi).xlsx` (18 phản hồi hợp lệ).

* **Phân bố đối tượng tham gia:**
  - **77.8% (14 người):** Đang hoặc đã hoàn thành kỳ thực tập (Cựu sinh viên).
  - **22.2% (4 người):** Chuẩn bị bước vào kỳ thực tập.
* **Môi trường & Tính chất công việc:**
  - **88.9%** sinh viên phải thực tập xa nhà / thuê trọ / ở ký túc xá tại các khu công nghiệp.
  - Phần lớn sinh viên làm việc tại các nhà máy sản xuất (như LG Display Hải Phòng), làm việc theo ca kíp (ca ngày 08:00–20:00, ca đêm 20:00–08:00) hoặc ở các vị trí thao tác kỹ thuật, vận hành dây chuyền.

### 1.2. Thống kê các khó khăn thực tế nổi cộm (Reality Shock)
1. **Giấc ngủ & Nhịp sinh học:** Đảo lộn nghiêm trọng khi đổi ca làm việc. Đa số sinh viên chỉ ngủ từ 4 đến dưới 6 tiếng/ngày, thường xuyên mệt mỏi và kiệt sức.
2. **Thể chất & Đau nhức cơ xương khớp:** Đứng liên tục 8–12 tiếng mỗi ngày, mang giày bảo hộ công nghiệp/chống tĩnh điện (ESD) gây đau nhức dữ dội gan bàn chân, gót chân và mỏi thắt lưng, cổ vai gáy.
3. **Mức độ Căng thẳng (Stress Level):** Điểm stress trung bình trong tháng đầu tiên rất cao (**4.0 – 5.0 / 5.0**). Nguyên nhân chủ yếu từ việc "làm trái ngành như công nhân", bỡ ngỡ với kỷ luật công xưởng và ngại giao tiếp với Trưởng ca.
4. **Môi trường sống:** Mâu thuẫn với bạn cùng phòng ký túc xá do lệch giờ giấc làm việc (người ngủ, người thức) và chưa nắm rõ quyền lợi, phụ cấp, an toàn lao động.

### 1.3. Nhu cầu tính năng từ người dùng thực tế
- **88.9%** sinh viên đánh giá tính năng *Nhật ký vi mô theo dõi giấc ngủ, mức độ stress và tự động cảnh báo kiệt sức* là Cần thiết / Rất cần thiết.
- **88.9%** đánh giá tính năng *Tra cứu cẩm nang kinh nghiệm cựu sinh viên* là Cần thiết / Rất cần thiết.
- **72.2%** đánh giá tính năng *Trợ lý AI giải đáp tình huống bám sát cẩm nang thực tế* là Cần thiết / Rất cần thiết.

### 1.4. Số hóa tri thức cẩm nang & Nạp vào ChromaDB
Dựa trên các bài học và lời khuyên thực chiến được chia sẻ trong khảo sát, nhóm đã xây dựng và số hóa 9 bài viết tri thức mẫu theo 5 trụ cột sức khỏe:
- `h1-5s-lgd` *(Career)*: Quy tắc 5S và An toàn lao động tại nhà máy LG Display.
- `h2-sleep-shift` *(Sleep)*: Bí quyết cân bằng nhịp sinh học và giấc ngủ khi đổi ca làm việc.
- `h3-stress-relief` *(Mental)*: Kỹ thuật Hít thở Box Breathing 4-4-4-4 giảm căng thẳng tức thì.
- `h4-social-comm` *(Social)*: Kỹ năng giao tiếp và chia sẻ khó khăn với quản lý nhóm thực tập.
- `h5-physical-care` *(Physical)*: Chăm sóc thể chất và bài tập giãn cơ cổ vai gáy ca đứng.
- `h6-esd-shoes-care` *(Physical)*: Kinh nghiệm giảm đau chân khi mang giày bảo hộ ESD và đứng ca dài (lót giày y tế, massage chân sau ca, kê cao chân khi ngủ).
- `h7-roommate-conflict` *(Social)*: Kỹ năng xử lý bất đồng bạn cùng phòng ký túc xá và thủ tục xin đổi phòng sớm.
- `h8-rights-allowance` *(Career)*: Cẩm nang tìm hiểu hợp đồng, phụ cấp ca đêm và an toàn lao động thực tập sinh.
- `h9-mindset-career` *(Career)*: Tâm thế thích ứng khi làm việc trái ngành và định hướng giá trị bản thân.

Toàn bộ các bài viết được xử lý qua thuật toán *Sliding Window Chunking* (500 ký tự, overlap 100 ký tự) và lưu trữ bền vững tại Vector Database.

---

## NHIỆM VỤ 2: Thiết kế cơ sở dữ liệu quan hệ (PostgreSQL) và thiết lập cơ sở dữ liệu vector (ChromaDB)

### 2.1. Thiết kế Cơ sở dữ liệu quan hệ (PostgreSQL 18)
- File kịch bản DDL `backend/schema.sql` gồm 12 bảng thực thể:
  1. `users`: Thông tin tài khoản, mật khẩu băm, vai trò (student/admin), mã sinh viên, trường, khoa.
  2. `intern_profiles`: Hồ sơ thực tập (đơn vị thực tập, ngày bắt đầu/kết thúc, chặng hiện tại, điểm đánh giá ban đầu 5 trụ cột).
  3. `daily_checkins`: Ghi nhận điểm danh mỗi ngày và thông điệp gacha nhận được.
  4. `user_streaks`: Quản lý chuỗi ngày điểm danh liên tục (current streak, longest streak).
  5. `journals`: Nhật ký sinh hoạt (giờ ngủ, mức độ stress 1-5, triệu chứng thể chất mệt mỏi, ghi chú cảm xúc).
  6. `tasks`: Danh mục nhiệm vụ mẫu theo 3 chặng (Chuẩn bị -> Hòa nhập -> Duy trì) và 5 trụ cột.
  7. `user_task_progress`: Theo dõi trạng thái hoàn thành nhiệm vụ của từng sinh viên.
  8. `handbook_articles`: Bài viết cẩm nang kinh nghiệm (hỗ trợ quy trình kiểm duyệt Human-in-the-loop).
  9. `chat_sessions`: Quản lý phiên hội thoại với AI.
  10. `chat_messages`: Nội dung tin nhắn hội thoại 2 chiều, phản hồi RAG kèm trích dẫn nguồn.
  11. `refresh_tokens`: Lưu trữ Refresh Token băm bảo mật phục vụ cơ chế xoay vòng phiên đăng nhập.
  12. `notification_logs`: Lịch sử thông báo đẩy gửi qua Firebase FCM.
- Đã ánh xạ toàn bộ lược đồ sang mô hình ORM bất đồng bộ `SQLAlchemy Async` tại `backend/app/db/models/`.

### 2.2. Thiết lập Cơ sở dữ liệu Vector (ChromaDB)
- Triển khai `chromadb.PersistentClient` tại đường dẫn `backend/chroma_db/`.
- Khởi tạo Collection `enigma_handbook` với cấu hình metric `hnsw:space: cosine`.
- Tự động hóa quá trình nạp và đồng bộ tri thức (seed/upsert) khi ứng dụng Backend khởi chạy thông qua `lifespan event`.
- Cài đặt hàm tìm kiếm ngữ nghĩa `search_similar_chunks(query, top_k)` đạt độ tương đồng cao (Cosine Similarity từ 0.65 – 0.75 trên các truy vấn thực tế).

---

## NHIỆM VỤ 3: Viết các API xác thực người dùng (JWT) và khởi tạo khung Backend với FastAPI

### 3.1. Khởi tạo khung Backend FastAPI
- Cấu trúc thư mục chuẩn:
  - `app/core/`: Quản lý cấu hình môi trường (`config.py`) và thuật toán bảo mật (`security.py`).
  - `app/db/`: Kết nối Connection Pool `asyncpg` và các Base Models.
  - `app/schemas/`: Lớp kiểm định dữ liệu Pydantic V2 cho Request/Response.
  - `app/services/`: Tầng xử lý logic nghiệp vụ tách biệt.
  - `app/api/routes/`: Tầng điều hướng API RESTful.
- Tích hợp Middleware CORS cho phép kết nối an toàn từ ứng dụng Flutter di động.

### 3.2. Hiện thực hóa các API Xác thực (Authentication Endpoints)
Tại `backend/app/api/routes/auth.py`, hoàn thiện đầy đủ 5 API:
1. `POST /auth/register`: Đăng ký tài khoản sinh viên mới, kiểm tra trùng lặp email, băm mật khẩu `bcrypt` và tự động tạo hồ sơ thực tập (`intern_profiles`).
2. `POST /auth/login`: Xác thực thông tin đăng nhập, kiểm tra trạng thái hoạt động tài khoản và cấp phát cặp mã `access_token` (thời hạn 60 phút) + `refresh_token` (thời hạn 30 ngày).
3. `POST /auth/refresh`: Triển khai cơ chế **Refresh Token Rotation** (thu hồi token cũ, cấp token mới), ngăn chặn triệt để nguy cơ tái sử dụng token bị rò rỉ.
4. `GET /auth/me`: Kiểm tra quyền truy cập và trả về thông tin chi tiết của sinh viên đang đăng nhập qua `Authorization: Bearer <token>`.
5. `POST /auth/logout`: Thu hồi Refresh Token trong cơ sở dữ liệu và kết thúc phiên làm việc an toàn.

---

## NHIỆM VỤ 4: Thiết kế wireframe, prototype và tạo khung giao diện cơ bản bằng Flutter

### 4.1. Thiết kế Giao diện & Trải nghiệm người dùng (UI/UX)
- Tối ưu hóa bảng màu theo phong cách **Dark Theme** hiện đại (`AppTheme.darkTheme`), sử dụng gam màu trầm dịu mắt, giảm thiểu căng thẳng thị giác cho sinh viên sau ca làm việc căng thẳng.
- Ứng dụng kiểu chữ Google Font Inter, các hiệu ứng chuyển động mượt mà và bo tròn hiện đại.

### 4.2. Khung ứng dụng di động Flutter
Đã tổ chức mã nguồn bài bản tại `Enigma/lib/` với các phân hệ:
1. **Quản lý trạng thái (State Management):**
   - `AuthState`: Quản lý trạng thái đăng nhập, lưu trữ bảo mật qua `flutter_secure_storage`, tự động kiểm tra phiên khi mở app.
   - `AppState`: Quản lý dữ liệu tổng quan, streak điểm danh và các chỉ số sức khỏe.
2. **Mạng & Xử lý lỗi (Networking):**
   - Tích hợp `Dio` Client với Interceptor tự động gắn JWT Header vào mọi request.
   - Cơ chế tự động bắt lỗi `401 Unauthorized` để gọi API `/auth/refresh` và tự động điều hướng về màn hình đăng nhập nếu token không hợp lệ.
3. **Các màn hình chức năng đã hoàn thiện:**
   - **Luồng Xác thực:** `SplashScreen`, `LoginScreen`, `RegisterScreen` (nhập thông tin trường, khoa, chuyên ngành, đơn vị thực tập), `OnboardingScreen`.
   - **Luồng Sinh viên:**
     - `HomeScreen`: Bảng điều khiển sức khỏe 5 trụ cột, biểu đồ nhịp sinh hoạt, thẻ lời khuyên AI.
     - `CheckinGachaScreen`: Điểm danh nhận thông điệp tích cực hằng ngày.
     - `JournalScreen` & `LifeLogScreen`: Ghi chép nhật ký sinh hoạt, thời gian ngủ, mức độ stress, triệu chứng thể chất.
     - `TasksScreen`: Danh sách nhiệm vụ theo 3 chặng thực tập (Chuẩn bị, Hòa nhập, Duy trì).
     - `ChatScreen`: Khung hội thoại hỏi đáp 2 chiều với trợ lý AI Enigma.
     - `HandbookScreen` & `HandbookDetailScreen`: Tra cứu cẩm nang kinh nghiệm cựu sinh viên.

---

## BẢNG TỔNG KẾT TIẾN ĐỘ TUẦN 3

| Nhiệm vụ | Chỉ tiêu kế hoạch | Kết quả thực tế | Trạng thái |
|:---|:---|:---|:---:|
| **1. Khảo sát & Số hóa tri thức** | Xử lý khảo sát, tạo KB ban đầu | Phân tích 18 phản hồi Excel, số hóa 9 cẩm nang theo 5 trụ cột | **Đạt 100%** |
| **2. CSDL PostgreSQL & ChromaDB** | 12 bảng PostgreSQL, Vector DB | 12 bảng DDL + SQLAlchemy Async ORM, ChromaDB Cosine HNSW | **Đạt 100%** |
| **3. Backend FastAPI & Auth JWT** | 5 API Auth, Middleware | Hoàn thiện Register, Login, Refresh, Me, Logout, Pydantic Schemas | **Đạt 100%** |
| **4. Wireframe & Giao diện Flutter** | Luồng Auth + Màn hình cơ bản | Hoàn thiện luồng Auth + 8 màn hình chức năng sinh viên + Dark Theme | **Đạt 100%** |

---

## KẾ HOẠCH TUẦN 4 TIẾP THEO (29/09/2026 – 05/10/2026)
1. Hoàn thiện toàn bộ các nhóm API nghiệp vụ cốt lõi: Check-ins API, Journals & Life-logs API, Tasks API.
2. Tích hợp phân tích tâm trạng AI (Sentiment Analysis) tự động khi sinh viên lưu nhật ký.
3. Kiểm thử tích hợp tự động qua Swagger UI / Postman và tối ưu hóa hiệu năng truy vấn CSDL.
