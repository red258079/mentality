import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/handbook_model.dart';
import '../../navigation/student_nav.dart';
import '../chat/ai_chat_screen.dart';

class HandbookDetailScreen extends StatelessWidget {
  final HandbookArticle article;

  const HandbookDetailScreen({super.key, required this.article});

  String _buildPrefilledQuestion() {
    final shortSummary = article.summary.trim();
    if (shortSummary.isEmpty) {
      return 'Cho mình hỏi thêm về bài viết "${article.title}": ';
    }
    return 'Cho mình hỏi thêm về bài viết "${article.title}" ($shortSummary): ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(article.categoryName),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${article.readTimeMinutes} phút đọc • Kinh nghiệm từ Cựu sinh viên LGD',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Key Takeaways Highlight Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bookmark_border, color: AppColors.primaryLight, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'ĐIỂM CỐT LÕI CẦN NHỚ (ACTIONABLE TIPS)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...article.keyTakeaways.map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('💡 ', style: TextStyle(fontSize: 12)),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Full Content
              Text(
                article.content.trim(),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),

              // Chat with AI CTA
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bạn có câu hỏi riêng về tình huống này?',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Trợ lý AI Enigma có thể giải đáp chi tiết hơn dựa trên toàn bộ cơ sở tri thức cẩm nang.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final question = _buildPrefilledQuestion();
                          final navState = StudentNav.of(context);
                          if (navState != null) {
                            Navigator.of(context).pop();
                            navState.askAboutInChat(question);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AiChatScreen(
                                  initialPrompt: question,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.smart_toy_outlined, size: 18),
                        label: const Text('Hỏi Trợ lý AI về bài viết này'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
