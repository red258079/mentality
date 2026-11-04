import '../../models/handbook_article.dart';

/// Pure function to build standard share text for a handbook article.
/// Formats: Title + ~120-char plain summary + "Xem thêm trong app Enigma".
/// Collapses repeated whitespace/newlines into clean plain text.
/// Strips external/mock author and like count data.
String buildShareText(HandbookArticle article) {
  final title = article.title.trim();

  // If article has explicit summary, use it (even if empty string for test cases).
  // Otherwise, extract summary from content.
  final String rawSource = article.summary != null ? article.summary! : article.content;
  final clean = rawSource.replaceAll(RegExp(r'\s+'), ' ').trim();

  const maxLen = 120;
  final summary = clean.length > maxLen
      ? '${clean.substring(0, maxLen).trimRight()}...'
      : clean;

  if (summary.isEmpty) {
    return '$title\n\nXem thêm trong app Enigma';
  }
  return '$title\n\n$summary\n\nXem thêm trong app Enigma';
}

/// Helper function to extract a clean plain summary of specified length.
/// Useful for cards, push notifications, and preview snippets.
String extractPlainSummary(HandbookArticle article, {int maxLen = 120}) {
  final String rawSource = article.summary != null ? article.summary! : article.content;
  final clean = rawSource.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.length > maxLen) {
    return '${clean.substring(0, maxLen).trimRight()}...';
  }
  return clean;
}

