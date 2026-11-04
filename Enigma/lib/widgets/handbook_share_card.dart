import 'package:flutter/material.dart';
import '../core/utils/handbook_share_helper.dart';
import '../models/handbook_article.dart';

/// Clean, beautifully styled card widget rendered for social sharing & image export.
/// Contains ONLY: Title, Summary, App Name & Logo.
/// NEVER includes author names, likes count, or user-specific data.
class HandbookShareCard extends StatelessWidget {
  final HandbookArticle article;
  final double width;

  const HandbookShareCard({
    super.key,
    required this.article,
    this.width = 360.0,
  });

  @override
  Widget build(BuildContext context) {
    final summary = extractPlainSummary(article, maxLen: 160);

    return Container(
      width: width,
      padding: const EdgeInsets.all(22.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Deep Midnight Slate
            Color(0xFF1E293B), // Elevated Charcoal
          ],
        ),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: const Color(0xFFDA6556).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Category Chip & Brand Badge ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDA6556).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFDA6556).withValues(alpha: 0.4),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  article.category,
                  style: const TextStyle(
                    color: Color(0xFFFF8A7A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8ACFF8).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 14,
                      color: Color(0xFF8ACFF8),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ENIGMA',
                    style: TextStyle(
                      color: Color(0xFF8ACFF8),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ── Article Title ──────────────────────────────────────────────────
          Text(
            article.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: -0.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 14),

          // ── Subtle Gradient Divider ─────────────────────────────────────────
          Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFDA6556).withValues(alpha: 0.5),
                  const Color(0xFF8ACFF8).withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.05),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Article Summary ────────────────────────────────────────────────
          if (summary.isNotEmpty) ...[
            Text(
              summary,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 13.5,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
          ],

          // ── Footer CTA ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.phone_iphone_rounded,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cẩm nang thực tập • Xem thêm trong app Enigma',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

