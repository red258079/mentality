# TÀI LIỆU ĐẶC TẢ YÊU CẦU PHẦN MỀM (SRS)
## Dự án: ENIGMA - Ứng dụng hỗ trợ sinh viên thực tập

---

## 1. GIỚI THIỆU
### 1.1 Mục đích
Tài liệu này đặc tả chi tiết các yêu cầu chức năng (Functional Requirements - FR) và phi chức năng (Non-Functional Requirements - NFR) cho hệ thống ứng dụng di động Enigma, bao gồm cả Frontend (Mobile App) và Backend (API, AI Engine).

### 1.2 Phạm vi sản phẩm
Enigma là một nền tảng hỗ trợ sinh viên trong quá trình thực tập, tích hợp RAG để cung cấp cẩm nang và AI Agent để theo dõi sức khỏe tâm lý, nhắc nhở sinh hoạt.

---

## 2. ĐẶC TẢ YÊU CẦU CHỨC NĂNG (Functional Requirements)

### 2.1 Nhóm chức năng Tài khoản & Xác thực (Authentication)
- **FR-AUTH-01:** Sinh viên có thể đăng ký tài khoản bằng Email, Mật khẩu và Mã sinh viên.
- **FR-AUTH-02:** Người dùng có thể đăng nhập bằng Email và Mật khẩu (sử dụng JWT token).
- **FR-AUTH-03:** Hệ thống cấp phát Access Token và Refresh Token để duy trì phiên đăng nhập.
- **FR-AUTH-04:** Quản trị viên (Admin) đăng nhập thông qua cổng riêng.

### 2.2 Nhóm chức năng Quản lý Sinh hoạt (Checkin & Tasks)
- **FR-TASK-01:** Hệ thống cung cấp danh sách nhiệm vụ (checklist) theo 3 chặng thực tập: Chuẩn bị, Hòa nhập, Duy trì.
- **FR-TASK-02:** Sinh viên có thể đánh dấu hoàn thành các nhiệm vụ.
- **FR-TASK-03:** Các nhiệm vụ sẽ được mở khóa (unlock) dần theo số ngày thực tập.
- **FR-CHK-01:** Sinh viên điểm danh (check-in) mỗi ngày và nhận thông điệp tạo động lực qua cơ chế Gacha ngẫu nhiên.
- **FR-CHK-02:** Hệ thống theo dõi số ngày điểm danh liên tiếp (Streak) và cấp các huy hiệu (Achievements) tương ứng.

### 2.3 Nhóm chức năng Đánh giá & Nhật ký (Wellbeing & Journals)
- **FR-JRN-01:** Sinh viên có thể tạo nhật ký cảm xúc hằng ngày (chỉ số stress, thời gian ngủ, triệu chứng thể chất, ghi chú).
- **FR-JRN-02:** Sinh viên thực hiện đánh giá tổng quan (Wellbeing Assessment) qua bài test 5 trụ cột: Tâm lý, Giấc ngủ, Thể chất, Xã hội, Sự nghiệp.
- **FR-JRN-03:** Ứng dụng hiển thị biểu đồ xu hướng cảm xúc dựa trên lịch sử nhật ký.

### 2.4 Nhóm chức năng Tra cứu Cẩm nang (Handbook - RAG)
- **FR-HBK-01:** Ứng dụng hiển thị danh sách các bài viết cẩm nang kinh nghiệm (phân loại theo danh mục: 5S, Quyền lợi, Sức khỏe...).
- **FR-HBK-02:** Sinh viên có thể xem chi tiết bài viết.
- **FR-HBK-03:** AI Agent sử dụng kỹ thuật RAG truy vấn vào cơ sở dữ liệu Vector (ChromaDB) chứa nội dung cẩm nang để trả lời câu hỏi của sinh viên.

### 2.5 Nhóm chức năng AI Chatbot (AI Agent)
- **FR-AI-01:** Sinh viên trò chuyện bằng ngôn ngữ tự nhiên với trợ lý AI Enigma.
- **FR-AI-02:** Trợ lý AI có thể tư vấn, đưa ra lời khuyên dựa trên cơ sở tri thức (Knowledge Base).
- **FR-AI-03:** AI Agent có khả năng tự động phân tích dữ liệu nhật ký (Function Calling) và gửi câu hỏi khảo sát ngược khi phát hiện chỉ số bất thường (ví dụ: Stress Level = 5 trong 3 ngày).

### 2.6 Nhóm chức năng Quản trị (Admin)
- **FR-ADM-01:** Admin có thể thêm, sửa, xóa các bài viết Cẩm nang vào kho tri thức.
- **FR-ADM-02:** Admin kích hoạt quá trình index dữ liệu cẩm nang mới vào ChromaDB.
- **FR-ADM-03:** Thống kê số lượng người dùng, tần suất sử dụng ứng dụng.

---

## 3. ĐẶC TẢ YÊU CẦU PHI CHỨC NĂNG (Non-Functional Requirements)

### 3.1 Yêu cầu Hiệu năng (Performance)
- **NFR-PERF-01:** Thời gian phản hồi của API thông thường (không phải AI) phải dưới 500ms.
- **NFR-PERF-02:** Thời gian phản hồi của AI Chatbot (RAG pipeline + Gemini API) phải dưới 4 giây.
- **NFR-PERF-03:** Ứng dụng di động hoạt động mượt mà ở mức 60 FPS trên các thiết bị Android tầm trung.

### 3.2 Yêu cầu Bảo mật (Security)
- **NFR-SEC-01:** Mật khẩu người dùng phải được mã hóa một chiều (Bcrypt) trước khi lưu vào CSDL.
- **NFR-SEC-02:** Toàn bộ API endpoint (trừ login/register) yêu cầu xác thực bằng Bearer JWT Token hợp lệ.
- **NFR-SEC-03:** Dữ liệu nhật ký cảm xúc của người dùng được coi là dữ liệu nhạy cảm, không được chia sẻ cho bên thứ 3 (trừ việc gửi ẩn danh đến LLM để phân tích).

### 3.3 Yêu cầu Khả dụng (Usability)
- **NFR-USE-01:** Giao diện ứng dụng di động thiết kế theo phong cách Dark Theme, thân thiện với mắt khi sử dụng vào ban đêm (phù hợp với sinh viên làm ca kíp).
- **NFR-USE-02:** Luồng điểm danh Gacha và làm nhiệm vụ phải tạo cảm giác gamification để giữ chân người dùng.

### 3.4 Yêu cầu Công nghệ & Nền tảng (Technology)
- **NFR-TECH-01:** Mobile App được phát triển bằng Flutter, xuất bản trên nền tảng Android.
- **NFR-TECH-02:** Backend API sử dụng FastAPI (Python), tận dụng cơ chế Asynchronous I/O.
- **NFR-TECH-03:** Lưu trữ dữ liệu quan hệ dùng PostgreSQL, lưu trữ vector dùng ChromaDB.
