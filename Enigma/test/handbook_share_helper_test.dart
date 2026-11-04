import 'package:flutter_test/flutter_test.dart';
import 'package:enigma/models/handbook_article.dart';
import 'package:enigma/core/utils/handbook_share_helper.dart';

void main() {
  group('buildShareText unit tests', () {
    test('handles long content with truncation to ~120 characters and suffix', () {
      final longContent = 'Đây là một đoạn nội dung rất dài về kinh nghiệm thực tập tại nhà máy sản xuất linh kiện điện tử nhằm kiểm tra xem hàm buildShareText có cắt ngắn chính xác khoảng 120 ký tự hay không.';
      final article = HandbookArticle(
        id: 'test-1',
        title: 'Mẹo thích nghi tuần đầu',
        category: 'Thích nghi',
        content: longContent,
        author: 'Nguyễn Văn A - Cựu SV',
        helpfulCount: 999,
        publishedAt: DateTime(2026, 1, 1),
      );

      final result = buildShareText(article);

      // Verify Title and App promotion
      expect(result.startsWith('Mẹo thích nghi tuần đầu\n\n'), isTrue);
      expect(result.endsWith('\n\nXem thêm trong app Enigma'), isTrue);

      // Verify neither author nor like count is leaked into share text
      expect(result.contains('Nguyễn Văn A'), isFalse);
      expect(result.contains('999'), isFalse);

      // Extract the summary portion between the two double-newlines
      final parts = result.split('\n\n');
      expect(parts.length, 3);
      final summary = parts[1];

      // Summary must end with ellipsis and be bounded
      expect(summary.endsWith('...'), isTrue);
      // 120 chars + 3 chars of '...' = 123 max
      expect(summary.length, lessThanOrEqualTo(123));
    });

    test('handles empty summary and empty content gracefully', () {
      final article = HandbookArticle(
        id: 'test-2',
        title: 'Quy định bảo hộ lao động',
        category: 'An toàn',
        summary: '',
        content: '   \n\t  ',
        author: 'Phòng HSE',
        helpfulCount: 50,
        publishedAt: DateTime(2026, 2, 1),
      );

      final result = buildShareText(article);

      // Must only contain Title and CTA, no orphan empty lines
      expect(result, 'Quy định bảo hộ lao động\n\nXem thêm trong app Enigma');
    });

    test('handles explicit empty summary with fallback to content when summary is null', () {
      final article = HandbookArticle(
        id: 'test-3',
        title: 'Hướng dẫn chấm công',
        category: 'Quy chế',
        content: 'Chấm công vân tay trước 7h45 mỗi sáng tại sảnh chính.',
        author: 'HR Dept',
        publishedAt: DateTime(2026, 3, 1),
      );

      final result = buildShareText(article);

      expect(
        result,
        'Hướng dẫn chấm công\n\nChấm công vân tay trước 7h45 mỗi sáng tại sảnh chính.\n\nXem thêm trong app Enigma',
      );
    });

    test('handles special characters, multiline whitespace, html tags and emojis', () {
      final specialContent = '''
        Kinh nghiệm 5S: "Sàng lọc" & <Sắp xếp>!
        - \t 💡 Lưu ý: Tránh chạm tay vào hoá chất ⚠️!
      ''';

      final article = HandbookArticle(
        id: 'test-4',
        title: 'Thực hành 5S & An toàn hoá chất [KCN Tràng Duệ]',
        category: 'An toàn',
        content: specialContent,
        author: 'Kỹ sư an toàn',
        helpfulCount: 120,
        publishedAt: DateTime(2026, 4, 1),
      );

      final result = buildShareText(article);

      // Verify Title with brackets preserved
      expect(result.contains('Thực hành 5S & An toàn hoá chất [KCN Tràng Duệ]'), isTrue);

      // Verify special symbols, quotes, tags and emojis preserved
      expect(result.contains('"Sàng lọc"'), isTrue);
      expect(result.contains('<Sắp xếp>'), isTrue);
      expect(result.contains('💡 Lưu ý:'), isTrue);
      expect(result.contains('⚠️!'), isTrue);

      // Verify consecutive tabs and newlines collapsed into single spaces
      expect(result.contains('\t'), isFalse);
      expect(result.contains('   '), isFalse);
      expect(result.endsWith('\n\nXem thêm trong app Enigma'), isTrue);
    });

    test('extractPlainSummary handles length bounds and trimming', () {
      final article = HandbookArticle(
        id: 'test-5',
        title: 'Tiêu đề ngắn',
        category: 'Khác',
        content: 'Nội dung ngắn gọn.',
        author: 'Admin',
        publishedAt: DateTime.now(),
      );

      expect(extractPlainSummary(article, maxLen: 50), 'Nội dung ngắn gọn.');
      expect(extractPlainSummary(article, maxLen: 8), 'Nội dung...');
    });
  });
}
