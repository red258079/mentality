# TÀI LIỆU ĐẶC TẢ YÊU CẦU PHẦN MỀM (SRS)
## Dự án: ENIGMA - Hệ thống ứng dụng di động hỗ trợ sinh hoạt & tâm lý cho sinh viên thực tập

---

## 1. TỔNG QUAN & PHẠM VI ĐẶC TẢ HỆ THỐNG

### 1.1. Bối cảnh bài toán & Mục tiêu ứng dụng
- **Bối cảnh thực tế:** Sinh viên khi bước vào giai đoạn thực tập tại doanh nghiệp thường gặp phải hiện tượng "Sốc thực tế" (Reality Shock) do sự thay đổi đột ngột về môi trường sống, sinh hoạt đảo lộn và chế độ ăn uống. Áp lực làm việc trái ngành hoặc ca kíp dẫn đến căng thẳng, mất ngủ, kiệt sức và nguy cơ bỏ dở kỳ thực tập giữa chừng. Trong khi đó, các kênh hỗ trợ truyền thống hiện nay còn mang tính thụ động, thiếu các cẩm nang kinh nghiệm thực chiến từ người đi trước.
- **Mục tiêu ứng dụng:** Hệ thống được xây dựng dưới dạng ứng dụng di động thông minh tích hợp kỹ thuật RAG và AI Agent nhằm giải quyết các mục tiêu cốt lõi:
  - **Ghi nhận & Theo dõi sinh hoạt:** Giúp sinh viên chủ động theo dõi nhịp sinh hoạt, thời gian ngủ và mức độ căng thẳng hằng ngày qua nhật ký và khảo sát vi mô.
  - **Đồng hành & Định hướng theo chặng:** Hướng dẫn sinh viên hòa nhập thông qua hệ thống nhiệm vụ 3 giai đoạn (Chuẩn bị hành trang -> Hòa nhập tháng đầu -> Duy trì tiến độ) kết hợp điểm danh nhận thông điệp tích cực (gacha) tạo động lực thích ứng.
  - **Tư vấn tri thức thực tế (RAG):** Trích xuất chính xác các bài học thích ứng, kỹ năng sinh hoạt, an toàn và quyền lợi từ cẩm nang cựu sinh viên, hạn chế tối đa ảo giác thông tin.
  - **Tương tác chủ động (AI Agent):** Tác tử AI tự động nhận diện chỉ số bất thường hoặc thiếu hụt dữ liệu để chủ động đặt câu hỏi khảo sát ngược và hỗ trợ kịp thời.
  - **Vòng lặp dữ liệu (Data Flywheel):** Vận hành cơ chế tích lũy khép kín: thu thập các bài học mới từ sinh viên khóa hiện tại để liên tục làm giàu kho tri thức cho các thế hệ sau.

### 1.2. Khoanh vùng phạm vi hệ thống (System Boundaries & Non-goals)
- **Phạm vi hệ thống (System Boundaries):**
  - *Nền tảng & Thiết bị:* Ứng dụng di động (Mobile App) đa nền tảng phát triển bằng Flutter, tập trung hoàn thiện và kiểm thử trên hệ điều hành Android.
  - *Đối tượng phục vụ:* Sinh viên chuẩn bị đi thực tập hoặc đang trong quá trình thực tập doanh nghiệp (đặc biệt là sinh viên thực tập xa, gặp khó khăn trong việc thích ứng môi trường).
  - *Quy mô kiểm thử:* Thử nghiệm ứng dụng trên tập mẫu sinh viên trong phạm vi khoa để đánh giá mức độ tương tác và độ ổn định thực tế.
- **Ranh giới giới hạn (Non-goals / Out-of-Scope):**
  - *Giới hạn y tế:* Hệ thống đóng vai trò là công cụ hỗ trợ thích ứng môi trường, quản lý lối sống và định hướng kinh nghiệm; tuyệt đối không có chức năng chẩn đoán y khoa, kê đơn hoặc điều trị các bệnh lý tâm thần chuyên sâu.
  - *Giới hạn doanh nghiệp:* Hệ thống không can thiệp vào quy trình chấm công, đánh giá nhân sự chính thức hay nghiệp vụ điều hành nội bộ của doanh nghiệp tiếp nhận thực tập.

---

## 2. KIẾN TRÚC TỔNG QUAN & LUỒNG TƯƠNG TÁC (ARCHITECTURE & DATA FLOW)

### 2.1. Mô hình kiến trúc 3 tầng (Mobile Client — Backend API — Vector DB / LLM Engine)
- **Tầng Trình diễn (Presentation Layer - Mobile Client):**
  - Xây dựng trên nền tảng Flutter (tối ưu hóa cho Android), đóng vai trò tiếp nhận tương tác trực tiếp từ sinh viên thực tập.
  - Quản lý các phân hệ giao diện: Bảng điều khiển chính (Dashboard), điểm danh nhận quà tinh thần (Gacha), nhật ký sinh hoạt, nhiệm vụ 3 chặng, tra cứu cẩm nang và khung chat hội thoại 2 chiều.
  - Tích hợp bộ nhớ tạm cục bộ (Local Storage qua Hive/SQLite) để lưu trữ ngoại tuyến dữ liệu khảo sát và tự động đồng bộ khi có kết nối mạng; nhận thông báo đẩy chủ động thông qua Firebase Cloud Messaging (FCM).
- **Tầng Nghiệp vụ & Điều phối (Application / Service Layer - Backend API):**
  - Xây dựng bằng framework FastAPI (Python), quản lý toàn bộ logic nghiệp vụ và phân quyền truy cập thông qua cơ chế xác thực JWT Token.
  - *Bộ điều phối tác tử (AI Agent Engine):* Hiện thực hóa luồng suy luận ReAct và cơ chế gọi hàm (Function Calling). Tác tử AI phân tích ngữ cảnh người dùng để tự động quyết định tra cứu tri thức hoặc chủ động kích hoạt câu hỏi khảo sát ngược khi phát hiện thiếu hụt dữ liệu.
  - *Mô-đun RAG (Retrieval-Augmented Generation):* Tiếp nhận truy vấn, thực hiện tìm kiếm vector ngữ nghĩa và kiểm tra ngưỡng tương đồng an toàn (Similarity Threshold) trước khi chuyển tiếp dữ liệu đến mô hình ngôn ngữ lớn (Google Gemini API) nhằm ngăn chặn hiện tượng ảo giác.
  - *Dịch vụ tác vụ nền (Background Worker):* Vận hành bằng APScheduler/Cron Job độc lập với LLM; định kỳ quét dữ liệu nhịp sinh hoạt theo chu kỳ 48 giờ để phát hiện bất thường và kích hoạt dịch vụ FCM gửi thông báo nhắc nhở tự động.
  - *Hàng đợi kiểm duyệt (Curation Queue - Human-in-the-loop):* Tiếp nhận các phản hồi, bài học thích ứng mới phát sinh từ thực tế để Quản trị viên phê duyệt trước khi cập nhật vào cơ sở tri thức chính thức.
- **Tầng Dữ liệu (Data Layer - Database Tier):**
  - *Cơ sở dữ liệu quan hệ (PostgreSQL):* Lưu trữ có cấu trúc thông tin tài khoản người dùng, phân quyền, nhật ký sinh hoạt hằng ngày, chỉ số căng thẳng, trạng thái nhiệm vụ và danh sách dữ liệu chờ kiểm duyệt.
  - *Cơ sở dữ liệu vector (ChromaDB):* Lưu trữ các đoạn nhúng văn bản (Vector Embeddings) của cẩm nang kinh nghiệm cựu sinh viên và các tình huống thích ứng thực tế đã được chuẩn hóa để phục vụ truy vấn ngữ nghĩa nhanh chóng.

### 2.2. Sơ đồ Use Case tổng quát
- **Tác nhân Sinh viên thực tập (Actor: Student):**
  - **UC01** - Quản lý tài khoản cá nhân: Đăng ký, đăng nhập hệ thống qua JWT và cập nhật hồ sơ cá nhân.
  - **UC02** - Điểm danh & Nhận thông điệp tạo động lực: Thực hiện điểm danh hằng ngày và quay ngẫu nhiên (Gacha) nhận thông điệp tinh thần.
  - **UC03** - Ghi nhận nhịp sinh hoạt: Điền nhật ký ngủ, chế độ sinh hoạt và trả lời khảo sát vi mô đo mức độ căng thẳng.
  - **UC04** - Thực hiện nhiệm vụ theo chặng: Theo dõi và đánh dấu hoàn thành nhiệm vụ theo 3 giai đoạn thực tập (Chuẩn bị, Hòa nhập, Duy trì).
  - **UC05** - Tra cứu cẩm nang thực tế: Tìm kiếm các mẹo sinh hoạt, an toàn, quyền lợi và kinh nghiệm thích ứng môi trường.
  - **UC06** - Tương tác hội thoại với AI: Trò chuyện giải tỏa căng thẳng với Trợ lý AI, nhận lời khuyên trích xuất từ cẩm nang và phản hồi các câu hỏi khảo sát chủ động từ hệ thống.
- **Tác nhân Quản trị viên (Actor: Admin):**
  - **UC07** - Quản lý người dùng: Theo dõi danh sách tài khoản sinh viên và quản lý phân quyền truy cập.
  - **UC08** - Kiểm duyệt tri thức mới (Curation Queue): Rà soát, phê duyệt hoặc từ chối các bài học thích ứng mới do người dùng đóng góp trước khi nạp vào Vector DB.
  - **UC09** - Quản lý cơ sở tri thức & Vector DB: Thêm, sửa, xóa tài liệu cẩm nang và kích hoạt tiến trình vector hóa văn bản trên ChromaDB.
  - **UC10** - Giám sát hệ thống & Thống kê: Theo dõi mức độ tương tác, các chỉ số nhịp sinh hoạt tổng hợp và giám sát độ ổn định của dịch vụ Backend/AI.

---

## 3. ĐẶC TẢ YÊU CẦU CHỨC NĂNG (FUNCTIONAL REQUIREMENTS — FRs)

### 3.1. Phân hệ Sinh viên thực tập (Mobile App — Flutter)

#### FR1: Quản lý tài khoản & Xác thực an toàn (JWT Token)
- **Đầu vào:** Mã số sinh viên/Email, mật khẩu, thông tin hồ sơ cơ bản (họ tên, vị trí thực tập, đơn vị thực tập).
- **Luồng xử lý:** Ứng dụng gửi yêu cầu đăng ký/đăng nhập về Backend; tiếp nhận và lưu trữ an toàn cặp mã xác thực Access Token và Refresh Token; tự động đính kèm Token vào Header của các yêu cầu tiếp theo; hỗ trợ đăng xuất và làm mới phiên làm việc.
- **Đầu ra:** Đăng nhập thành công, điều hướng vào màn hình chính; hiển thị thông báo lỗi khi thông tin không hợp lệ.

#### FR2: Điểm danh hằng ngày & Vòng quay Gacha tạo động lực
- **Đầu vào:** Lệnh bấm nút điểm danh hằng ngày từ người dùng.
- **Luồng xử lý:** Kiểm tra điều kiện điểm danh trong ngày; ghi nhận lượt chuyên cần vào CSDL; kích hoạt hiệu ứng mở hộp quà/vòng quay ngẫu nhiên (Gacha) để trích xuất một thông điệp tinh thần hoặc lời khuyên tích cực.
- **Đầu ra:** Điểm danh được ghi nhận, hiển thị thẻ thông điệp tích cực trong ngày và cập nhật chuỗi ngày điểm danh liên tục.

#### FR3: Nhật ký sinh hoạt & Khảo sát vi mô (Micro-survey)
- **Đầu vào:** Số giờ ngủ thực tế, đánh giá mức độ căng thẳng (thang điểm 1–5) và lựa chọn nhanh các yếu tố tác động (áp lực công việc, mâu thuẫn bạn cùng phòng, ăn uống, ca kíp).
- **Luồng xử lý:** Xác thực dữ liệu nhập; lưu trữ tạm vào bộ nhớ cục bộ (Local Storage qua Hive/SQLite) nếu mất mạng; tự động gửi lên máy chủ khi có kết nối Internet.
- **Đầu ra:** Giao diện phản hồi trạng thái ghi nhận thành công và hiển thị biểu đồ xu hướng sinh hoạt tuần.

#### FR4: Hệ thống theo dõi Nhiệm vụ theo 3 chặng thực tập
- **Đầu vào:** Lệnh xem danh sách nhiệm vụ và thao tác tích chọn hoàn thành từng đầu việc của sinh viên.
- **Luồng xử lý:** Phân loại và hiển thị nhiệm vụ theo 3 giai đoạn: Giai đoạn 1: Chuẩn bị hành trang trước khi đi, Giai đoạn 2: Thích nghi tháng đầu tiên, Giai đoạn 3: Duy trì và kết thúc kỳ thực tập; cập nhật trạng thái hoàn thành và tính toán phần trăm tiến độ chặng.
- **Đầu ra:** Thanh tiến độ hoàn thành theo từng chặng và danh sách các quyền lợi, việc cần làm tương ứng.

#### FR5: Tra cứu Cẩm nang kinh nghiệm cựu sinh viên
- **Đầu vào:** Từ khóa tìm kiếm hoặc chọn danh mục chủ đề (ăn uống, an toàn lao động, giao tiếp bạn cùng phòng, xử lý sự cố).
- **Luồng xử lý:** Gửi truy vấn tìm kiếm về Backend; lọc và phân loại các bài học kinh nghiệm đã được kiểm duyệt từ Sổ tay cựu sinh viên.
- **Đầu ra:** Danh sách các bài chia sẻ kinh nghiệm thực tế kèm nội dung chi tiết và mẹo xử lý tình huống.

#### FR6: Khung Chat AI tương tác 2 chiều (RAG & Phản hồi câu hỏi chủ động)
- **Đầu vào:** Tin nhắn hỏi đáp của sinh viên hoặc phản hồi đối với câu hỏi gợi mở từ AI.
- **Luồng xử lý:** Gửi chuỗi hội thoại qua API; hiển thị hiệu ứng gõ phím/chờ phản hồi; nhận luồng dữ liệu (Streaming/SSE) từ AI Agent và mô-đun RAG; hiển thị các câu hỏi khảo sát ngược/nút bấm chọn nhanh khi AI Agent chủ động hỏi làm rõ ngữ cảnh.
- **Đầu ra:** Câu trả lời tư vấn chính xác, bám sát cẩm nang hoặc các thẻ tương tác khảo sát bổ sung xuất hiện ngay trong luồng chat.

### 3.2. Phân hệ Backend, Mô-đun RAG & AI Agent Engine (FastAPI)

#### FR7: Mô-đun Tra cứu Tăng cường Tạo sinh (RAG Engine)
- **Đầu vào:** Câu truy vấn dạng văn bản từ giao diện chat của ứng dụng di động.
- **Luồng xử lý:** Hệ thống chuẩn hóa câu hỏi, chuyển đổi thành vector nhúng (Dense Vector) và thực hiện tìm kiếm ngữ nghĩa (Semantic Search) trên ChromaDB để trích xuất các đoạn tài liệu liên quan nhất (Top-K Chunks). Tiến hành kiểm tra ngưỡng tương đồng an toàn (Similarity Threshold):
  1. Nếu điểm tương đồng >= threshold: Hệ thống ghép ngữ cảnh (Context) đã lọc kèm System Prompt và chuyển tiếp sang Gemini API để sinh câu trả lời chính xác, bám sát cẩm nang thực tế.
  2. Nếu điểm tương đồng < threshold: Hệ thống ngắt luồng RAG và chuyển hướng sang câu thoại an toàn mặc định, thông báo chưa có dữ liệu và hướng dẫn sinh viên cách thức liên hệ quản trị viên/thầy cô, triệt tiêu nguy cơ ảo giác thông tin.
- **Đầu ra:** Đoạn văn bản phản hồi chính xác hoặc câu thông báo an toàn được gửi về ứng dụng di động.

#### FR8: Tác tử AI & Cơ chế gọi hàm (Function Calling)
- **Đầu vào:** Ý định hội thoại (Intent) và ngữ cảnh tương tác thời gian thực từ sinh viên.
- **Luồng xử lý:** Vận hành chu trình suy luận ReAct (Reasoning + Acting). Tác tử AI đánh giá nội dung trò chuyện của sinh viên; khi phát hiện câu hỏi cần dữ liệu thực tế hoặc phát hiện thông tin sinh hoạt bị khuyết, mô hình tự động sinh tham số có cấu trúc (Function Calling dạng JSON) để kích hoạt các hàm tra cứu dữ liệu hoặc gọi hàm tạo bộ câu hỏi khảo sát ngược phù hợp với tình huống.
- **Đầu ra:** Dữ liệu phản hồi được cấu trúc hóa để trả lời câu hỏi hoặc giao diện khảo sát tương tác trực tiếp trong khung chat.

#### FR9: Tác vụ quét ngầm định kỳ (Background Worker) & Thông báo đẩy (FCM)
- **Đầu vào:** Dữ liệu lịch sử điểm danh và nhật ký sinh hoạt lưu trong CSDL PostgreSQL; dữ liệu đồng bộ ngoại tuyến từ ứng dụng di động.
- **Luồng xử lý:** Cung cấp cổng tiếp nhận dữ liệu đồng bộ hàng loạt (Batch Sync API) khi thiết bị di động khôi phục kết nối Internet sau thời gian hoạt động ngoại tuyến. Sử dụng bộ lập lịch ngầm độc lập với LLM (APScheduler / Cron Job) định kỳ rà soát dữ liệu người dùng theo chu kỳ 48 giờ. Nếu phát hiện sinh viên không nhập nhật ký liên tiếp 48 giờ hoặc có chỉ số giấc ngủ dưới 4 tiếng liên tục 2 ngày, hệ thống tự động xác định điều kiện kích hoạt và tạo lệnh gửi thông báo.
- **Đầu ra:** Cập nhật dữ liệu từ chế độ ngoại tuyến vào PostgreSQL; kích hoạt Firebase Cloud Messaging (FCM) gửi thông báo đẩy (Push Notification) chủ động tới thiết bị di động của sinh viên để nhắc nhở và thăm hỏi.

### 3.3. Phân hệ Quản trị viên (Admin Web Panel / Dashboard)

#### FR10: Quản lý Người dùng & Phân quyền truy cập
- **Đầu vào:** Yêu cầu cấp, khóa tài khoản hoặc phân quyền từ Quản trị viên.
- **Luồng xử lý:** Hệ thống kiểm tra quyền của Quản trị viên qua JWT; thực hiện cập nhật trạng thái hoạt động (Active/Inactive), vai trò (Sinh viên/Quản trị viên) và lưu trữ thay đổi vào CSDL PostgreSQL.
- **Đầu ra:** Cập nhật danh sách người dùng và áp dụng phân quyền truy cập trên toàn hệ thống.

#### FR11: Hàng đợi kiểm duyệt tri thức (Curation Queue — Human-in-the-loop)
- **Đầu vào:** Các tình huống thực tế, mẹo sinh hoạt mới được gắn cờ (flagged) từ luồng chat AI hoặc các đóng góp chia sẻ từ sinh viên.
- **Luồng xử lý:** Hệ thống đưa các nội dung mới vào danh sách chờ duyệt (trạng thái Pending). Quản trị viên tiến hành rà soát, chỉnh sửa nội dung cho chuẩn xác và thực hiện thao tác Duyệt (Approve) hoặc Từ chối (Reject).
- **Đầu ra:** Các nội dung được duyệt sẽ kích hoạt tiến trình tự động tính toán vector nhúng và nạp vào ChromaDB (vận hành vòng lặp Data Flywheel an toàn); các nội dung bị từ chối sẽ bị loại bỏ khỏi hàng đợi.

#### FR12: Quản lý Kho tri thức (Knowledge Base) & Vector DB (ChromaDB)
- **Đầu vào:** Các tệp tài liệu cẩm nang, sổ tay thực tập hoặc dữ liệu văn bản cần cập nhật.
- **Luồng xử lý:** Cho phép Quản trị viên thêm, sửa, xóa các tài liệu văn bản gốc; hệ thống thực hiện phân đoạn (Chunking) và cập nhật đồng bộ các vector đại diện tương ứng trong ChromaDB.
- **Đầu ra:** Kho tri thức và cơ sở dữ liệu vector được làm mới, sẵn sàng phục vụ cho các truy vấn của mô-đun RAG.

#### FR13: Báo cáo thống kê & Giám sát chỉ số AI
- **Đầu vào:** Dữ liệu nhật ký sinh hoạt, lịch sử tương tác chat và nhật ký vận hành hệ thống (system logs).
- **Luồng xử lý:** Hệ thống tính toán, tổng hợp các chỉ số định lượng: tần suất điểm danh, mức độ căng thẳng trung bình của sinh viên theo đợt thực tập, số lượng truy vấn AI, tỷ lệ câu hỏi rơi vào vùng chuyển hướng an toàn và đo lường chỉ số trung thực/bám sát nguồn (Faithfulness Score) trên tập dữ liệu kiểm thử.
- **Đầu ra:** Bảng điều khiển (Dashboard) trực quan hóa các biểu đồ thống kê phục vụ công tác theo dõi, quản lý và đánh giá thực nghiệm.

---

## 4. ĐẶC TẢ YÊU CẦU PHI CHỨC NĂNG (NON-FUNCTIONAL REQUIREMENTS — NFRs)

### NFR1: Hiệu năng & Độ trễ phản hồi (Performance & Latency)
- Thời gian phản hồi đối với các tác vụ API thông thường (xác thực, ghi nhận nhật ký, cập nhật nhiệm vụ, điểm danh) không vượt quá 1 giây trong điều kiện mạng ổn định.
- Thời gian phản hồi đầy đủ cho luồng tương tác với Trợ lý AI (bao gồm tính toán vector embedding, truy vấn ChromaDB và gọi Gemini API) không vượt quá 5–7 giây. Trường hợp sử dụng phản hồi dạng dòng (Streaming/SSE), thời gian xuất hiện ký tự đầu tiên (Time to First Token - TTFT) phải đạt dưới 2 giây.
- Ứng dụng di động (Flutter) bắt buộc phải tích hợp chỉ báo trạng thái đang xử lý (Typing Indicator hoặc Skeleton Loading) trong suốt quá trình chờ hệ thống phản hồi để đảm bảo trải nghiệm người dùng liền mạch.

### NFR2: Chỉ số trung thực, Bám sát nguồn & Ngưỡng tương đồng (Faithfulness & Similarity Threshold)
- Đo lường độ chính xác và tính trung thực của các câu trả lời trích xuất từ cẩm nang thông qua chỉ số bám sát nguồn (Faithfulness/Groundedness Score), đạt tối thiểu từ 85% đến 90% trên tập dữ liệu thử nghiệm chuẩn (Golden Dataset).
- Thiết lập ngưỡng tương đồng ngữ nghĩa an toàn trong ChromaDB với hệ số Cosine Similarity >= 0.65. Nếu điểm tương đồng dưới 0.65, hệ thống tự động kích hoạt câu trả lời chuyển hướng an toàn nhằm triệt tiêu hiện tượng mô hình ngôn ngữ tự suy đoán hoặc bịa đặt thông tin (hallucination).
- Triển khai cơ chế kiểm duyệt có sự tham gia của con người (Human-in-the-loop qua Curation Queue) đối với mọi tri thức mới phát sinh trước khi nạp vào cơ sở dữ liệu vector.

### NFR3: Bảo mật thông tin & Quyền riêng tư dữ liệu (Security & Privacy)
- Toàn bộ các kênh truyền thông điệp và trao đổi dữ liệu giữa ứng dụng di động và hệ thống máy chủ Backend phải được mã hóa theo giao thức HTTPS/TLS.
- Xác thực người dùng thông qua cơ chế mã thông báo an toàn JWT (JSON Web Token), trong đó Access Token có thời hạn ngắn và Refresh Token được lưu trữ bảo mật trên thiết bị.
- Bảo đảm tính riêng tư tuyệt đối cho dữ liệu cá nhân, bao gồm nhật ký sinh hoạt, giờ ngủ và điểm số căng thẳng; Quản trị viên chỉ được quyền truy xuất các báo cáo thống kê dưới dạng chỉ số tổng hợp ẩn danh.

### NFR4: Khả năng hoạt động Offline & Tự động đồng bộ (Offline Capability & Auto-sync)
- Ứng dụng di động duy trì hoạt động cục bộ thông qua giải pháp lưu trữ trên máy (Hive hoặc SQLite) khi thiết bị mất kết nối mạng, cho phép người dùng tiếp tục thực hiện điểm danh và điền nhật ký sinh hoạt mà không bị gián đoạn.
- Hệ thống tự động kích hoạt cơ chế đồng bộ nền hàng loạt (Batch Sync) ngay khi thiết bị kết nối lại Internet để đẩy toàn bộ dữ liệu tạm thời lên cơ sở dữ liệu PostgreSQL.

### NFR5: Trải nghiệm người dùng & Ràng buộc nền tảng (Usability & Platform Constraints)
- Giao diện ứng dụng di động được thiết kế trực quan, thao tác điền khảo sát vi mô hằng ngày tối ưu hóa để hoàn thành nhanh chóng trong thời gian dưới 60 giây.
- Ứng dụng được đóng gói, vận hành ổn định và tối ưu tương thích trên hệ điều hành Android (hỗ trợ từ Android 8.0 trở lên).
