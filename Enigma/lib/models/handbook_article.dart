class HandbookArticle {
  final String id;
  final String title;
  final String category;
  final String content;
  final String author;
  final DateTime publishedAt;
  final int helpfulCount;
  final bool isPublished;
  final String status;
  final String? summary;

  HandbookArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    required this.author,
    required this.publishedAt,
    this.helpfulCount = 0,
    this.isPublished = true,
    this.status = 'published',
    this.summary,
  });

  // TODO: Map isPublished from backend status (status == 'published') once real article data replaces mockArticles.
  static List<HandbookArticle> get mockArticles => [
    HandbookArticle(
      id: '1',
      title: 'Mẹo ăn uống tiết kiệm & an toàn quanh KCN Tràng Duệ',
      category: 'Ăn uống',
      content: '''Kinh nghiệm bỏ túi cho sinh viên thực tập tại KCN Tràng Duệ và An Dương:

1. Bữa trưa / tối tại công ty:
- Tận dụng tối đa suất ăn ca miễn phí của nhà máy (thường có 3-4 món mặn, canh và hoa quả tráng miệng). Đồ ăn nhà máy luôn được kiểm nghiệm an toàn thực phẩm.
- Nếu làm ca đêm, nhớ nhận phiếu ăn đêm hoặc suất ăn nhẹ tại canteen lúc 0h - 1h.

2. Quán ăn bình dân chất lượng gần cổng khu công nghiệp:
- Quán Cơm Cô Hoa (gần Cổng 2): Cơm suất 25k - 30k, đầy đặn, cơm thêm miễn phí.
- Chợ Chiều Tân Tiến: Họp từ 16h - 19h, rau củ quả và thịt cá tươi rẻ hơn siêu thị 30%, thích hợp mua về nấu chung cùng bạn trọ.
- Quán bún cá cay & phở đối diện cổng KTX: Ăn sáng nhanh từ 20k - 25k.

3. Mẹo uống nước & bù khoáng:
- Trong phòng sạch (cleanroom) độ ẩm thường thấp (dễ mất nước). Hãy uống 1 cốc nước ấm trước khi vào ca và tranh thủ bổ sung nước chanh muối / oresol vào giờ giải lao 10 phút.''',
      author: 'Cựu SV K60 - Bách Khoa',
      publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      helpfulCount: 245,
    ),
    HandbookArticle(
      id: '2',
      title: 'Xử lý đau mỏi vai gáy & thắt lưng do đứng chuyền liên tục',
      category: 'Sức khỏe',
      content: '''Đứng thao tác lắp ráp tại line sản xuất 8-12 tiếng liên tục rất dễ dẫn đến căng cứng cơ cổ, hội chứng ống cổ tay và đau thắt lưng.

1. Tư thế đứng chuẩn tại vị trí thao tác:
- Hai chân mở rộng bằng vai, không khóa chặt khớp gối. Tránh dồn toàn bộ trọng lượng vào một chân quá lâu.
- Cứ mỗi 15-20 phút, hãy chủ động đổi chân trụ hoặc nhấc nhẹ gót chân để kích hoạt tuần hoàn máu tĩnh mạch.

2. Bài tập giãn cơ 3 phút trong giờ nghỉ giải lao:
- Xoay tròn khớp cổ nhẹ nhàng theo chiều kim đồng hồ 5 vòng và ngược lại.
- Nâng hai bả vai lên sát tai, giữ 3 giây rồi thở mạnh hạ xuống.
- Đan 10 ngón tay ra sau lưng, ưỡn ngực mở rộng khớp vai để giải tỏa áp lực cột sống ngực.

3. Chăm sóc tại phòng trọ sau ca làm:
- Tắm nước ấm dưới vòi sen trực tiếp vào vùng gáy và thắt lưng.
- Dùng cao dán giảm đau thảo dược hoặc xoa bóp dầu ngải cứu trước khi đi ngủ. Tuyệt đối không bẻ vặn cổ kêu răng rắc quá mạnh.''',
      author: 'Cựu SV Y tế Công cộng',
      publishedAt: DateTime.now().subtract(const Duration(days: 15)),
      helpfulCount: 310,
    ),
    HandbookArticle(
      id: '3',
      title: 'Bí quyết bảo vệ bàn chân khi mang giày bảo hộ ESD 12 tiếng',
      category: 'Sức khỏe',
      content: '''Giày bảo hộ chống tĩnh điện (ESD) thường có đế cứng và mũi thép/composite, dễ gây phồng rộp, đau gan bàn chân và thâm móng chân:

1. Đầu tư miếng lót giày chuyên dụng:
- Thay miếng lót mỏng đi kèm giày bằng lót giày y tế Silicon hoặc Memory Foam có đệm vòm bàn chân (giá 30k - 60k trên Shopee). Điều này giúp giảm tới 60% phản lực từ sàn bê tông/epoxy.

2. Chọn tất (vớ) phù hợp:
- Dùng tất cotton dày có đệm ở mũi và gót chân. Tuyệt đối tránh tất nilon vì gây bí bách, ẩm mồ hôi và dễ nhiễm nấm chân.
- Mang thêm một đôi tất dự phòng trong balo để thay nếu chân ra nhiều mồ hôi giữa ca.

3. Phục hồi đôi chân sau ca làm:
- Ngâm chân nước ấm pha muối hột và gừng đập dập 15 phút trước khi ngủ.
- Kê một chiếc gối dưới bắp chân khi nằm ngủ để chân cao hơn tim khoảng 15cm, giúp giảm sưng phù và xua tan cảm giác nặng trĩu bàn chân.''',
      author: 'Kỹ sư Quy trình - LG Display',
      publishedAt: DateTime.now().subtract(const Duration(days: 12)),
      helpfulCount: 420,
    ),
    HandbookArticle(
      id: '4',
      title: 'Quyền lợi OT, phụ cấp ca đêm và quy chế làm thêm giờ',
      category: 'Quyền lợi',
      content: '''Nắm chắc quyền lợi tài chính theo Bộ luật Lao động và thỏa thuận thực tập sinh:

1. Cách tính lương & phụ cấp làm thêm giờ (OT):
- Ngày làm việc bình thường: Tiền làm thêm giờ tối thiểu bằng 150% đơn giá tiền lương.
- Ngày nghỉ hằng tuần (Chủ nhật): Tiền làm thêm tối thiểu bằng 200%.
- Ngày lễ, Tết hoặc ngày nghỉ có hưởng lương: Tối thiểu bằng 300%.

2. Phụ cấp ca đêm (Khung giờ từ 22h00 đến 06h00 hôm sau):
- Được trả thêm ít nhất 30% tiền lương tính theo đơn giá ngày bình thường.
- Nếu vừa làm ca đêm vừa làm thêm giờ OT đêm, sẽ được cộng gộp thêm 20% lương của ca ngày tương ứng.

3. Giới hạn số giờ làm việc:
- Tổng số giờ làm thêm không được vượt quá 40 giờ/tháng và 200 giờ/năm.
- Công ty không được phép ép buộc thực tập sinh làm thêm giờ khi sinh viên có lý do sức khỏe hoặc học tập chính đáng. Mọi trường hợp ép ca sai quy định, hãy liên hệ ngay Giảng viên hướng dẫn đoàn thực tập.''',
      author: 'Admin Enigma - Ban Cố vấn Pháp lý',
      publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      helpfulCount: 520,
    ),
    HandbookArticle(
      id: '5',
      title: 'Bí quyết cân bằng nhịp sinh học & giấc ngủ khi chuyển ca đêm',
      category: 'Sức khỏe',
      content: '''Đổi ca từ ca ngày (08h - 20h) sang ca đêm (20h - 08h) là thử thách lớn nhất về mặt tâm lý và sức khỏe đối với sinh viên:

1. Chống chọi cơn buồn ngủ lúc 3h - 4h sáng:
- Đây là khung giờ thân nhiệt cơ thể giảm xuống thấp nhất. Hãy đứng dậy đi rửa mặt bằng nước mát, nhai kẹo cao su bạc hà hoặc vươn vai khởi động nhẹ.
- Hạn chế uống cà phê đặc hoặc nước tăng lực sau 03h00 sáng vì chất kích thích sẽ tồn dư trong máu gây mất ngủ khi bạn về phòng trọ lúc 9h sáng.

2. Chuẩn bị phòng ngủ ban ngày đạt chuẩn:
- Lắp rèm cản sáng 100% hoặc đeo bịt mắt chất lượng tốt. Tuyệt đối không để ánh nắng mặt trời chiếu vào mắt vì ánh sáng xanh sẽ ức chế tiết Melatonin (hormone giấc ngủ).
- Dùng nút bịt tai chống ồn (Earplugs) nếu phòng trọ gần đường lớn hoặc bạn cùng phòng sinh hoạt ca ngày.
- Bật quạt hoặc điều hòa giữ nhiệt độ phòng mát mẻ (khoảng 24 - 26 độ C).

3. Đeo kính râm trên đường về phòng:
- Khi tan ca buổi sáng, hãy đeo kính râm tối màu trên đường từ nhà máy về nhà trọ để đánh lừa não bộ rằng trời vẫn chưa sáng hẳn, giúp bạn dễ vào giấc ngủ sâu hơn.''',
      author: 'BS. Nguyễn Hải Đăng - Tư vấn Sức khỏe Nghề nghiệp',
      publishedAt: DateTime.now().subtract(const Duration(days: 8)),
      helpfulCount: 388,
    ),
    HandbookArticle(
      id: '6',
      title: 'Kinh nghiệm thuê phòng trọ an ninh & chi phí hợp lý quanh nhà máy',
      category: 'Nhà trọ',
      content: '''Hướng dẫn tìm phòng trọ tại các khu vực lân cận như An Hưng, Hồng Phong, Lê Lợi gần KCN:

1. Tiêu chí chọn phòng trọ cho sinh viên làm ca kíp:
- Ưu tiên khu trọ có giờ giấc mở cổng tự do hoặc có khóa vân tay riêng (để tiện đi ca đêm về lúc 8h sáng hoặc đi ca 20h tối).
- Kiểm tra độ cách âm của phòng: Gõ thử tường, xem cửa sổ có khít không, tránh các dãy trọ sát đường xe container chạy suốt ngày đêm.
- Hỏi kỹ giá điện nước: Điện nên từ 2.500đ - 3.500đ/số, nước 15k - 20k/khối hoặc 60k - 80k/người/tháng.

2. Hợp đồng thuê phòng:
- Ký hợp đồng đúng thời hạn thực tập (thường 2 - 4 tháng). Không nên ký hợp đồng dài hạn 1 năm nếu không chắc chắn ở lại làm chính thức sau tốt nghiệp để tránh bị phạt mất tiền cọc.
- Chụp ảnh lại hiện trạng phòng (tường, quạt, công tơ điện, khóa cửa) trước khi nhận bàn giao phòng.''',
      author: 'Nhóm Đồng hương Hải Phòng',
      publishedAt: DateTime.now().subtract(const Duration(days: 20)),
      helpfulCount: 195,
    ),
    HandbookArticle(
      id: '7',
      title: 'Quy tắc ứng xử và giải quyết mâu thuẫn phòng trọ khi lệch ca',
      category: 'Nhà trọ',
      content: '''Khi ở ghép phòng trọ hoặc ký túc xá mà người làm ca ngày, người làm ca đêm:

1. Thống nhất quy ước phòng ngay từ ngày đầu:
- Khung giờ yên tĩnh tuyệt đối: Ban ngày từ 09h00 đến 16h00 (giờ người ca đêm ngủ) và ban đêm từ 22h00 đến 06h00 (giờ người ca ngày ngủ).
- Trong khung giờ này: Bắt buộc đeo tai nghe khi xem điện thoại/nghe nhạc, đóng mở cửa thật nhẹ nhàng, tắt đèn chính và chỉ bật đèn ngủ cá nhân.

2. Chia sẻ việc nhà & chi phí sinh hoạt:
- Phân công rõ lịch đổ rác, cọ rửa nhà vệ sinh theo tuần thay vì để dồn lại cuối tháng.
- Lập quỹ chung cho các vật dụng thiết yếu: Nước rửa chén, gia vị, xà phòng, giấy vệ sinh.
- Sử dụng ứng dụng quản lý chi tiêu chung (như Sổ Thu Chi hoặc bảng Excel chia tiền) để minh bạch từng khoản chi.''',
      author: 'CLB Sinh viên Tình nguyện',
      publishedAt: DateTime.now().subtract(const Duration(days: 22)),
      helpfulCount: 260,
    ),
    HandbookArticle(
      id: '8',
      title: 'Quy tắc 5S và An toàn tĩnh điện (ESD) trong phòng sạch công nghiệp',
      category: 'An toàn',
      content: '''Môi trường sản xuất linh kiện màn hình OLED/LCD đòi hỏi kỷ luật phòng sạch (Cleanroom) khắt khe:

1. Quy tắc 5S căn bản tại trạm làm việc:
- Sàng lọc (Seiri): Loại bỏ ngay các bao bì, khay lỗi, phế phẩm ra khỏi bàn thao tác.
- Sắp xếp (Seiton): Dụng cụ (nhíp gắp, máy quét barcode, bình cồn) phải để đúng ô quy định, dán nhãn nhận diện.
- Sạch sẽ (Seiso): Lau bụi bàn thao tác bằng khăn chống xước chuyên dụng trước và sau mỗi ca.
- Săn sóc (Seiketsu): Duy trì 3 tiêu chí trên thành thói quen mỗi ngày.
- Sẵn sàng (Shitsuke): Luôn tự giác tuân thủ nội quy an toàn lao động.

2. Tiêu chuẩn chống tĩnh điện (ESD):
- Luôn đeo vòng tay chống tĩnh điện (ESD wrist strap) và kẹp đúng vào đầu dây nối đất (grounding) khi chạm vào bo mạch.
- Tuyệt đối không mang vật dụng cá nhân sinh tĩnh điện cao (áo len, túi nilon ngoài, điện thoại) vào khu vực Cleanroom chưa được phép.
- Giày ESD phải được đo kiểm tra tại máy đo tĩnh điện cổng vào mỗi đầu ca.''',
      author: 'Bộ phận Quản lý An toàn & Môi trường EHS',
      publishedAt: DateTime.now().subtract(const Duration(days: 18)),
      helpfulCount: 340,
    ),
    HandbookArticle(
      id: '9',
      title: 'Thang đo Y khoa PHQ-4: Sàng lọc nhanh trầm cảm & lo âu cho công nhân ca kíp (PMC8038412)',
      category: 'Tâm lý',
      content: '''Nghiên cứu lâm sàng quốc tế PMC8038412 (PubMed Central - National Institutes of Health):
"The Patient Health Questionnaire-4 (PHQ-4): A valid screening tool for depression and anxiety in high-stress and shift workers".

1. Vì sao sinh viên thực tập & công nhân ca kíp cần sàng lọc PHQ-4?
- Môi trường nhà máy công nghiệp với tiếng ồn, ca kíp đảo lộn (ngày/đêm), đứng line chuyền 8-12 tiếng làm gia tăng 300% nguy cơ rối loạn nhịp sinh học và căng thẳng thần kinh so với làm việc văn phòng thông thường.
- PHQ-4 là bộ công cụ siêu ngắn (Ultra-brief screener) chỉ gồm 4 câu hỏi chuẩn hóa quốc tế, mất chưa đầy 60 giây để hoàn thành nhưng có độ nhạy (sensitivity) và độ đặc hiệu (specificity) trên 85% trong việc phát hiện sớm lo âu và trầm cảm.

2. Cấu trúc thang đo PHQ-4:
- Phân nhóm GAD-2 (Câu 1 & 2): Đánh giá triệu chứng lo âu cốt lõi (Cảm giác lo lắng, bồn chồn; Không thể ngừng lo lắng).
- Phân nhóm PHQ-2 (Câu 3 & 4): Đánh giá triệu chứng trầm cảm cốt lõi (Mất hứng thú, không còn niềm vui; Cảm thấy chán nản, tuyệt vọng).

3. Ngưỡng cắt lâm sàng (Cut-off Score):
- Điểm mỗi phân nhóm >= 3 (trên thang 6): Cảnh báo dương tính với rối loạn lo âu hoặc trầm cảm tiềm ẩn.
- Thang phân tầng nguy cơ Enigma:
  + 0 - 2 điểm: Bình thường (Áp lực thích nghi thông thường).
  + 3 - 5 điểm: Nhẹ (Cần nghỉ ngơi, tập thở 4-4-4-4 và ngủ đủ giấc).
  + 6 - 8 điểm: Vừa (Cần giảm tải OT, chia sẻ cùng Leader/Giảng viên phụ trách).
  + 9 - 12 điểm: Nặng (Cần liên hệ ngay chuyên gia tâm lý hoặc y tế nhà máy).''',
      author: 'Nghiên cứu Y học Lao động - NCBI PMC8038412',
      publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      helpfulCount: 512,
    ),
    HandbookArticle(
      id: '10',
      title: 'Cẩm nang sử dụng bộ công cụ sàng lọc lâm sàng PHQ Screeners (phqscreeners.com)',
      category: 'Tâm lý',
      content: '''Hướng dẫn chi tiết từ tổ chức PHQ Screeners (phqscreeners.com - Phát triển bởi GS. Robert L. Spitzer, GS. Janet B.W. Williams, GS. Kurt Kroenke):

1. Hệ sinh thái thang đo Patient Health Questionnaire (PHQ):
- PHQ-4: Bộ lọc nhanh ban đầu (4 câu hỏi) - Tích hợp trong tính năng "Đánh giá Y khoa PHQ-4" trên màn hình Điểm danh Enigma.
- GAD-7: Thang đo chuyên sâu 7 câu hỏi về Rối loạn lo âu lan tỏa (Generalized Anxiety Disorder).
- PHQ-9: Thang đo tiêu chuẩn vàng 9 câu hỏi về Trầm cảm theo tiêu chuẩn chẩn đoán DSM-5.

2. Nguyên tắc đánh giá sức khỏe tâm thần khoa học:
- Tự đánh giá trung thực: Hãy trả lời dựa trên cảm xúc thực tế trong 2 tuần qua (14 ngày gần nhất), không phải chỉ riêng ngày hôm nay.
- Công cụ sàng lọc không phải bản án bệnh lý: Điểm số cao cho biết bạn đang chịu quá tải cảm xúc và cơ thể đang phát tín hiệu cầu cứu, không đồng nghĩa với việc bạn mắc bệnh vĩnh viễn.
- Can thiệp sớm tạo khác biệt: Hầu hết các rối loạn tâm lý do ca kíp đều phục hồi hoàn toàn nếu được phát hiện trong 30 ngày đầu thông qua điều chỉnh giấc ngủ, chế độ ăn và giải tỏa áp lực công việc.''',
      author: 'Ban Cố vấn Tâm lý - phqscreeners.com',
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      helpfulCount: 468,
    ),
  ];
}
