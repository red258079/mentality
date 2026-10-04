import logging
from typing import Dict, Any, List, Optional
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_
import google.generativeai as genai

from app.core.config import settings
from app.db.models.handbook_article import HandbookArticle, ArticleStatus
from app.services.vector_store_service import VectorStoreService

logger = logging.getLogger(__name__)

if settings.GEMINI_API_KEY:
    genai.configure(api_key=settings.GEMINI_API_KEY)


class SituationAccumulatorService:
    @staticmethod
    async def extract_and_accumulate_situation(
        db: AsyncSession,
        user_query: str,
        ai_solution: str,
        user_id: Optional[UUID] = None,
        author_name: str = "Thực tập sinh LG Display",
        category_hint: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Tự động phân tích tình huống thực tế từ hội thoại/chia sẻ của sinh viên,
        tổng hợp thành một bài cẩm nang kinh nghiệm thực chiến và lưu vào PostgreSQL + ChromaDB.
        """
        title = "Kinh nghiệm xử lý tình huống thực tập"
        summary = "Tình huống thực tế tích lũy từ kinh nghiệm thực tập sinh."
        content = f"TÌNH HUỐNG THỰC TẾ:\n{user_query}\n\nGIẢI PHÁP ĐỀ XUẤT:\n{ai_solution}"
        category = category_hint or "general"
        tags = ["kinh-nghiem-thuc-te", "lg-display", "tich-luy-ai"]

        if settings.GEMINI_API_KEY:
            try:
                model = genai.GenerativeModel("gemini-3.8-flash")
                prompt = f"""
Bạn là chuyên gia quản trị tri thức thực tập sinh. Hãy phân tích tình huống và giải pháp sau đây để tạo thành một bài cẩm nang kinh nghiệm ngắn gọn, súc tích:

CÂU HỎI / TÌNH HUỐNG:
{user_query}

GIẢI PHÁP / TƯ VẤN:
{ai_solution}

Hãy trả về định dạng JSON thuần túy (không kèm markdown ```json):
{{
  "title": "Tiêu đề bài viết hấp dẫn (dưới 80 ký tự)",
  "summary": "Tóm tắt ngắn gọn trong 1-2 câu",
  "content": "Nội dung hướng dẫn chi tiết gồm: 1. Mô tả tình huống, 2. Nguyên nhân thường gặp, 3. Các bước xử lý thực tế",
  "category": "Một trong các danh mục: sleep / physical / mental / social / career",
  "tags": ["tag1", "tag2", "tag3"]
}}
"""
                res = model.generate_content(prompt)
                text = res.text.strip()
                if text.startswith("```"):
                    text = text.strip("`")
                    if text.startswith("json"):
                        text = text[4:].strip()
                import json
                data = json.loads(text)
                title = data.get("title", title)
                summary = data.get("summary", summary)
                content = data.get("content", content)
                category = data.get("category", category)
                tags = data.get("tags", tags)
            except Exception as e:
                logger.warning(f"Gemini situation synthesis fallback: {e}")

        # Save to PostgreSQL
        new_article = HandbookArticle(
            title=title,
            summary=summary,
            content=content,
            category=category,
            author_name=author_name,
            author_id=user_id,
            status=ArticleStatus.published,
            tags=tags,
            helpful_count=1,
            view_count=1
        )
        db.add(new_article)
        await db.commit()
        await db.refresh(new_article)

        # Index to ChromaDB Vector Store
        try:
            VectorStoreService.add_or_update_article(
                article_id=str(new_article.id),
                title=new_article.title,
                content=new_article.content,
                category=new_article.category
            )
            new_article.chroma_id = f"{new_article.id}_chunk_0"
            await db.commit()
        except Exception as e:
            logger.error(f"Error indexing new situation to ChromaDB: {e}")

        return {
            "id": str(new_article.id),
            "title": new_article.title,
            "summary": new_article.summary,
            "category": new_article.category,
            "tags": new_article.tags,
            "status": new_article.status.value,
            "created_at": new_article.created_at
        }
