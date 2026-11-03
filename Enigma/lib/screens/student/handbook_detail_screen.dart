import 'package:flutter/material.dart';
import '../../models/handbook_article.dart';
import '../../navigation/student_nav.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HandbookDetailScreen extends StatelessWidget {
  final HandbookArticle article;

  const HandbookDetailScreen({super.key, required this.article});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Cẩm nang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {},
          )
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
