# BÁO CÁO TIẾN ĐỘ THỰC HIỆN TUẦN 2
## Dự án: ENIGMA - Hệ thống ứng dụng di động hỗ trợ sinh hoạt & tâm lý cho sinh viên thực tập
**Thời gian:** 15/09/2026 – 21/09/2026

---

## NHIỆM VỤ 1: Khởi tạo repository GitHub dự án và thiết lập cấu trúc thư mục chuẩn
- Khởi tạo thành công repository chính thức trên GitHub tại địa chỉ: [internship-support-app](https://github.com/ChauGiaBao-23050010/internship-support-app).
- Thiết lập cấu trúc monorepo phân tầng rõ ràng giữa `Enigma/` (Flutter Mobile Client), `backend/` (FastAPI Server, RAG, ChromaDB), `docs/` (Tài liệu SRS, Thiết kế) và `.github/workflows/` (Quy trình CI/CD).
- Bổ sung thư mục `backend/app/services/data/` (lưu trữ dữ liệu khảo sát thô và cẩm nang) và `backend/app/services/scripts/` (chứa kịch bản băm nhỏ và nạp vector tri thức vào ChromaDB).
- Thiết lập đầy đủ cấu hình bảo mật thông qua `.gitignore` tổng và file mẫu `backend/.env.example`, ngăn chặn nguy cơ rò rỉ khóa bí mật (Gemini API Key, JWT Secret, thông tin xác thực Firebase, chuỗi kết nối PostgreSQL).
- Khởi tạo nhánh làm việc chính `dev` và nhánh phát hành `main` theo đúng mô hình GitHub Flow, đồng thời thiết lập quy tắc bảo vệ nhánh (Branch Protection Rule).

---

## NHIỆM VỤ 2: Cài đặt môi trường phát triển và cấu hình Firebase
- **Phía Client:** Hoàn tất cài đặt Flutter SDK và cấu hình môi trường phát triển trên Android Studio; khởi tạo khung dự án di động tối ưu cho hệ điều hành Android.
- **Phía Server:** Thiết lập môi trường ảo Python, cài đặt FastAPI, Uvicorn, các thư viện điều phối AI/RAG (LangChain/Google Generative AI, ChromaDB) và chuẩn bị CSDL quan hệ PostgreSQL.
- **Cấu hình Firebase (FCM):** Khởi tạo dự án trên Firebase Console, tích hợp Firebase Cloud Messaging để sẵn sàng kết nối với tác vụ chạy nền (Background Worker) phục vụ việc gửi thông báo đẩy chủ động đến thiết bị sinh viên.

---

## NHIỆM VỤ 3: Thiết kế và phát hành bảng khảo sát nhu cầu thực tế
- Xây dựng và hoàn thiện cấu trúc bảng câu hỏi gồm 4 phần trọng tâm: Thông tin chung (phân luồng đối tượng), Thực trạng khó khăn & Hiện tượng sốc thực tế (giờ ngủ, mức độ căng thẳng, ăn uống, ca kíp), Nhu cầu tính năng hỗ trợ trên ứng dụng di động, và Đóng góp câu chuyện thực chiến (thu thập tri thức cho vòng lặp Data Flywheel).
- Bổ sung mục cam kết đồng ý tham gia nghiên cứu (Consent Checkbox) nhằm đảm bảo tiêu chuẩn bảo mật dữ liệu và đạo đức nghiên cứu học thuật.
- Tự động hóa quá trình sinh biểu mẫu trực tuyến bằng Google Apps Script:
  - [Link chỉnh sửa biểu mẫu](https://docs.google.com/forms/d/1fRXBvvtpyjvqo86sHCMMe4tN5BFUM6h6syjKhL5mtLc/edit)
  - [Link phát hành khảo sát](https://docs.google.com/forms/d/e/1FAIpQLSeqePXmFz4HbXk-23rN4BuIBYrKrdnmxybZ9Z8ApdVZSyGOZA/viewform)
- Chính thức gửi liên kết khảo sát tới các nhóm sinh viên và cựu sinh viên, đặt mục tiêu thu thập từ 50 đến 100 phản hồi hợp lệ phục vụ phân tích dữ liệu ở Tuần 3.

---

## NHIỆM VỤ 4: Phân tích và đặc tả các yêu cầu chức năng, phi chức năng của hệ thống (SRS)

### 1. TỔNG QUAN & PHẠM VI ĐẶC TẢ HỆ THỐNG
#### 1.1. Bối cảnh bài toán & Mục tiêu ứng dụng
- **Bối cảnh thực tế:** Sinh viên khi bước vào giai đoạn thực tập tại doanh nghiệp thường gặp phải hiện tượng "Sốc thực tế" (Reality Shock) do sự thay đổi đột ngột về môi trường sống, sinh hoạt đảo lộn và chế độ ăn uống. Áp lực làm việc trái ngành hoặc ca kíp dẫn đến căng thẳng, mất ngủ, kiệt sức và nguy cơ bỏ dở kỳ thực tập giữa chừng. Trong khi đó, các kênh hỗ trợ truyền thống hiện nay còn mang tính thụ động, thiếu các cẩm nang kinh nghiệm thực chiến từ người đi trước.
- **Mục tiêu ứng dụng:** Hệ thống được xây dựng dưới dạng ứng dụng di động thông minh tích hợp kỹ thuật RAG và AI Agent nhằm giải quyết các mục tiêu cốt lõi:
  - **Ghi nhận & Theo dõi sinh hoạt:** Giúp sinh viên chủ động theo dõi nhịp sinh hoạt, thời gian ngủ và mức độ căng thẳng hằng ngày qua nhật ký và khảo sát vi mô.
  - **Đồng hành & Định hướng theo chặng:** Hướng dẫn sinh viên hòa nhập thông qua hệ thống nhiệm vụ 3 giai đoạn (Chuẩn bị hành trang -> Hòa nhập tháng đầu -> Duy trì tiến độ) kết hợp điểm danh nhận thông điệp tích cực (gacha) tạo động lực thích ứng.
  - **Tư vấn tri thức thực tế (RAG):** Trích xuất chính xác các bài học thích ứng, kỹ năng sinh hoạt, an toàn và quyền lợi từ cẩm nang cựu sinh viên, hạn chế tối đa ảo giác thông tin.
  - **Tương tác chủ động (AI Agent):** Tác tử AI tự động nhận diện chỉ số bất thường hoặc thiếu hụt dữ liệu để chủ động đặt câu hỏi khảo sát ngược và hỗ trợ kịp thời.
  - **Vòng lặp dữ liệu (Data Flywheel):** Vận hành cơ chế tích lũy khép kín: thu thập các bài học mới từ sinh viên khóa hiện tại để liên tục làm giàu kho tri thức cho các thế hệ sau.

#### 1.2. Khoanh vùng phạm vi hệ thống (System Boundaries & Non-goals)
- **Phạm vi hệ thống (System Boundaries):**
  - *Nền tảng & Thiết bị:* Ứng dụng di động (Mobile App) đa nền tảng phát triển bằng Flutter, tập trung hoàn thiện và kiểm thử trên hệ điều hành Android.
  - *Đối tượng phục vụ:* Sinh viên chuẩn bị đi thực tập hoặc đang trong quá trình thực tập doanh nghiệp.
  - *Quy mô kiểm thử:* Thử nghiệm ứng dụng trên tập mẫu sinh viên trong phạm vi khoa để đánh giá mức độ tương tác và độ ổn định thực tế.
- **Ranh giới giới hạn (Non-goals / Out-of-Scope):**
  - *Giới hạn y tế:* Hệ thống đóng vai trò là công cụ hỗ trợ thích ứng môi trường, quản lý lối sống và định hướng kinh nghiệm; tuyệt đối không có chức năng chẩn đoán y khoa, kê đơn hoặc điều trị các bệnh lý tâm thần chuyên sâu.
  - *Giới hạn doanh nghiệp:* Hệ thống không can thiệp vào quy trình chấm công, đánh giá nhân sự chính thức hay nghiệp vụ điều hành nội bộ của doanh nghiệp tiếp nhận thực tập.

---

### 2. KIẾN TRÚC TỔNG QUAN & LUỒNG TƯƠNG TÁC (ARCHITECTURE & DATA FLOW)
#### 2.1. Mô hình kiến trúc 3 tầng (Mobile Client — Backend API — Vector DB / LLM Engine)
- **Tầng Trình diễn (Presentation Layer - Mobile Client):** Xây dựng trên nền tảng Flutter (tối ưu hóa cho Android), quản lý các phân hệ giao diện: Bảng điều khiển chính (Dashboard), điểm danh nhận quà tinh thần (Gacha), nhật ký sinh hoạt, nhiệm vụ 3 chặng, tra cứu cẩm nang và khung chat hội thoại 2 chiều.
- **Tầng Nghiệp vụ & Điều phối (Application / Service Layer - Backend API):** Xây dựng bằng framework FastAPI (Python), tích hợp AI Agent Engine (ReAct + Function Calling), RAG Engine (Vector search + Similarity thresholding), Background Worker (APScheduler/Cron Job) và Curation Queue (Human-in-the-loop).
- **Tầng Dữ liệu (Data Layer - Database Tier):** PostgreSQL (lưu trữ có cấu trúc tài khoản, nhật ký, nhiệm vụ) và ChromaDB (lưu trữ Vector Embeddings cẩm nang tri thức).

#### 2.2. Sơ đồ Use Case tổng quát
- **Tác nhân Sinh viên thực tập (Actor: Student):** UC01 (Tài khoản), UC02 (Điểm danh & Gacha), UC03 (Nhật ký sinh hoạt), UC04 (Nhiệm vụ 3 chặng), UC05 (Tra cứu cẩm nang), UC06 (Chat AI 2 chiều).
- **Tác nhân Quản trị viên (Actor: Admin):** UC07 (Quản lý người dùng), UC08 (Kiểm duyệt tri thức - Curation Queue), UC09 (Quản lý Vector DB), UC10 (Giám sát chỉ số hệ thống & AI).

---

### 3. ĐẶC TẢ YÊU CẦU CHỨC NĂNG (FUNCTIONAL REQUIREMENTS — FRs)
- **FR1:** Quản lý tài khoản & Xác thực an toàn (JWT Token).
- **FR2:** Điểm danh hằng ngày & Vòng quay Gacha tạo động lực.
- **FR3:** Nhật ký sinh hoạt & Khảo sát vi mô (Micro-survey).
- **FR4:** Hệ thống theo dõi Nhiệm vụ theo 3 chặng thực tập.
- **FR5:** Tra cứu Cẩm nang kinh nghiệm cựu sinh viên.
- **FR6:** Khung Chat AI tương tác 2 chiều (RAG & Phản hồi câu hỏi chủ động).
- **FR7:** Mô-đun Tra cứu Tăng cường Tạo sinh (RAG Engine) kèm ngưỡng tương đồng (Similarity Threshold).
- **FR8:** Tác tử AI & Cơ chế gọi hàm (Function Calling).
- **FR9:** Tác vụ quét ngầm định kỳ (Background Worker) & Thông báo đẩy (FCM).
- **FR10:** Quản lý Người dùng & Phân quyền truy cập.
- **FR11:** Hàng đợi kiểm duyệt tri thức (Curation Queue — Human-in-the-loop).
- **FR12:** Quản lý Kho tri thức (Knowledge Base) & Vector DB (ChromaDB).
- **FR13:** Báo cáo thống kê & Giám sát chỉ số AI.

---

### 4. ĐẶC TẢ YÊU CẦU PHI CHỨC NĂNG (NON-FUNCTIONAL REQUIREMENTS — NFRs)
- **NFR1 (Hiệu năng):** API thông thường <= 1s; Chatbot AI <= 5–7s (TTFT < 2s khi dùng Streaming/SSE).
- **NFR2 (Độ trung thực & Ngưỡng an toàn):** Faithfulness Score >= 85–90%; Cosine Similarity >= 0.65 (dưới 0.65 tự động kích hoạt câu trả lời an toàn chuyển hướng).
- **NFR3 (Bảo mật & Quyền riêng tư):** Mã hóa HTTPS/TLS, JWT Auth, bảo mật dữ liệu riêng tư cá nhân.
- **NFR4 (Khả năng Offline & Đồng bộ):** Lưu trữ tạm Hive/SQLite khi mất kết nối, tự động Batch Sync khi có Internet.
- **NFR5 (Trải nghiệm & Ràng buộc):** Thời gian điền khảo sát vi mô < 60s; hỗ trợ Android 8.0 trở lên.
