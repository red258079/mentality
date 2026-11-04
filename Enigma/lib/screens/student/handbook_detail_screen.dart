import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/handbook_share_helper.dart';
import '../../models/handbook_article.dart';
import '../../navigation/student_nav.dart';
import '../../theme/app_theme.dart';
import '../../widgets/handbook_share_card.dart';

class HandbookDetailScreen extends StatelessWidget {
  final HandbookArticle article;

  const HandbookDetailScreen({super.key, required this.article});

  // TODO: Map isPublished from backend status (status == 'published') once real article data replaces mockArticles.
  bool get _isShareable => article.isPublished && article.status == 'published';

  String _buildPrefilledQuestion() {
    final singleLine = article.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    const maxSummaryLen = 120;
    final shortSummary = singleLine.length > maxSummaryLen
        ? '${singleLine.substring(0, maxSummaryLen).trimRight()}...'
        : singleLine;
    if (shortSummary.isEmpty) {
      return 'Cho mình hỏi thêm về bài viết "${article.title}": ';
    }
    return 'Cho mình hỏi thêm về bài viết "${article.title}" ($shortSummary): ';
  }

  // ── Share Actions ───────────────────────────────────────────────────────────

  Rect _calculateShareOrigin(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && box.size.width > 0 && box.size.height > 0) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.of(ctx).size;
    return Rect.fromLTWH(0, 0, size.width, size.height / 2);
  }

  Future<void> _shareText(BuildContext ctx) async {
    final messenger = ScaffoldMessenger.of(ctx);
    try {
      final origin = _calculateShareOrigin(ctx);
      final text = buildShareText(article);
      await Share.share(
        text,
        sharePositionOrigin: origin,
      );
    } catch (e, stack) {
      debugPrint('Error sharing handbook text: $e\n$stack');
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Không thể chia sẻ văn bản. Vui lòng thử lại.'),
          backgroundColor: AppTheme.accentCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyText(BuildContext ctx) async {
    final messenger = ScaffoldMessenger.of(ctx);
    try {
      final text = buildShareText(article);
      await Clipboard.setData(ClipboardData(text: text));
      if (ctx.mounted) {
        Navigator.pop(ctx);
      }
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Đã sao chép'),
          backgroundColor: AppTheme.accentMint,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e, stack) {
      debugPrint('Error copying handbook text: $e\n$stack');
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Không thể sao chép nội dung. Vui lòng thử lại.'),
          backgroundColor: AppTheme.accentCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cleanupOldHandbookShareImages() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(const Duration(hours: 1));
      await for (final entity in tempDir.list()) {
        if (entity is File && entity.path.contains('enigma_handbook_')) {
          try {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoff)) {
              await entity.delete();
            }
          } catch (_) {
            // Ignore individual file deletion errors
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up temp handbook images: $e');
    }
  }

  Future<void> _shareImage(BuildContext ctx, GlobalKey cardKey, ValueNotifier<bool> isExporting) async {
    final messenger = ScaffoldMessenger.of(ctx);
    final origin = _calculateShareOrigin(ctx);
    isExporting.value = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Không thể tìm thấy khung hình thẻ chia sẻ.');
      }

      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Lỗi nén dữ liệu ảnh PNG.');
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      await _cleanupOldHandbookShareImages();

      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/enigma_handbook_${article.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(pngBytes, flush: true);

      await Share.shareXFiles(
        [XFile(tempFilePath)],
        text: buildShareText(article),
        sharePositionOrigin: origin,
      );
    } catch (e, stack) {
      debugPrint('Error sharing handbook card image: $e\n$stack');
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Không thể chia sẻ ảnh thẻ. Vui lòng thử lại.'),
          backgroundColor: AppTheme.accentCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      isExporting.value = false;
    }
  }

  // ── Share Bottom Sheet ──────────────────────────────────────────────────────
  void _showShareBottomSheet(BuildContext context) {
    if (!_isShareable) return;

    final GlobalKey cardKey = GlobalKey();
    final isExportingNotifier = ValueNotifier<bool>(false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(sheetCtx),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: AppTheme.borderColor(sheetCtx)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppTheme.onSurfaceMuted(sheetCtx).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.share_rounded, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Chia sẻ Cẩm nang',
                        style: Theme.of(sheetCtx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card Preview
              Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: RepaintBoundary(
                    key: cardKey,
                    child: HandbookShareCard(article: article),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Option 1: Chia sẻ văn bản
              _buildShareOptionTile(
                context: sheetCtx,
                icon: Icons.text_snippet_rounded,
                iconColor: AppTheme.primary,
                title: 'Chia sẻ văn bản',
                subtitle: 'Tiêu đề kèm tóm tắt và lời mời xem trên app Enigma',
                onTap: () => _shareText(sheetCtx),
              ),
              const SizedBox(height: 10),

              // Option 2: Chia sẻ ảnh thẻ
              ValueListenableBuilder<bool>(
                valueListenable: isExportingNotifier,
                builder: (ctx, isExporting, _) {
                  return _buildShareOptionTile(
                    context: sheetCtx,
                    icon: Icons.image_rounded,
                    iconColor: AppTheme.secondary,
                    title: 'Chia sẻ ảnh thẻ',
                    subtitle: 'Xuất ảnh thẻ đẹp để đăng mạng xã hội hoặc gửi tin nhắn',
                    isLoading: isExporting,
                    onTap: () => _shareImage(sheetCtx, cardKey, isExportingNotifier),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Option 3: Sao chép văn bản
              _buildShareOptionTile(
                context: sheetCtx,
                icon: Icons.copy_rounded,
                iconColor: AppTheme.accentMint,
                title: 'Sao chép',
                subtitle: 'Lưu nội dung chia sẻ vào khay nhớ tạm',
                onTap: () => _copyText(sheetCtx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAltColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
                      )
                    : Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: AppTheme.onSurface(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurfaceSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.onSurfaceMuted(context)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Cẩm nang'),
        actions: [
          if (_isShareable)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Chia sẻ cẩm nang',
              onPressed: () => _showShareBottomSheet(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                article.category,
                style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold),
              ),
            ).animate().fade().slideY(),
            const SizedBox(height: 16),
            Text(
              article.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ).animate().fade().slideY(delay: 50.ms),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.surfaceAltColor(context),
                  child: Icon(Icons.person, size: 20, color: AppTheme.onSurfaceSecondary(context)),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.author, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      'Đăng ${article.publishedAt.day}/${article.publishedAt.month}/${article.publishedAt.year}',
                      style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceMuted(context)),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.thumb_up_alt_outlined, size: 16, color: AppTheme.onSurfaceMuted(context)),
                const SizedBox(width: 4),
                Text('${article.helpfulCount}', style: TextStyle(color: AppTheme.onSurfaceMuted(context))),
              ],
            ).animate().fade().slideY(delay: 100.ms),
            const SizedBox(height: 32),
            Divider(color: AppTheme.borderColor(context)),
            const SizedBox(height: 24),
            Text(
              article.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.6,
              ),
            ).animate().fade().slideY(delay: 150.ms),
            
            const SizedBox(height: 48),
            
            // Ask AI button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.cardDecorationFor(context),
              child: Column(
                children: [
                  const Icon(Icons.smart_toy_rounded, size: 40, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Bạn có câu hỏi về nội dung này?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface(context)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hỏi trợ lý AI để được giải đáp cụ thể theo ngữ cảnh của bạn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.onSurfaceSecondary(context)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final navState = StudentNav.of(context);
                      final question = _buildPrefilledQuestion();
                      Navigator.of(context).pop();
                      navState?.askAboutInChat(question);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size(double.infinity, 45),
                    ),
                    child: const Text('Hỏi AI ngay'),
                  ),
                ],
              ),
            ).animate().scale(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}
