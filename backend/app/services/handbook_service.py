import logging
from typing import List, Dict, Any, Optional
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, update

from app.db.models.handbook_article import HandbookArticle, ArticleStatus
from app.services.vector_store_service import VectorStoreService

logger = logging.getLogger(__name__)


class HandbookService:
    @staticmethod
    async def get_articles(
        db: AsyncSession,
        category: Optional[str] = None,
        search_keyword: Optional[str] = None,
        status: Optional[str] = "published",
        skip: int = 0,
        limit: int = 50
    ) -> List[HandbookArticle]:
        query = select(HandbookArticle)
        
        if status:
            try:
                enum_status = ArticleStatus(status)
                query = query.where(HandbookArticle.status == enum_status)
            except ValueError:
                pass
                
        if category and category.lower() != "tất cả" and category.lower() != "all":
            query = query.where(HandbookArticle.category.ilike(f"%{category}%"))
            
        if search_keyword and search_keyword.strip():
            kw = f"%{search_keyword.strip()}%"
            query = query.where(
                or_(
                    HandbookArticle.title.ilike(kw),
                    HandbookArticle.summary.ilike(kw),
                    HandbookArticle.content.ilike(kw)
                )
            )
            
        query = query.order_by(HandbookArticle.helpful_count.desc(), HandbookArticle.created_at.desc())
        query = query.offset(skip).limit(limit)
        
        result = await db.execute(query)
        return list(result.scalars().all())

    @staticmethod
    async def get_article_by_id(db: AsyncSession, article_id: UUID) -> Optional[HandbookArticle]:
        result = await db.execute(select(HandbookArticle).where(HandbookArticle.id == article_id))
        article = result.scalar_one_or_none()
        if article:
            # Increment view count
            article.view_count = (article.view_count or 0) + 1
            await db.commit()
            await db.refresh(article)
        return article

    @staticmethod
    async def get_categories(db: AsyncSession) -> List[Dict[str, Any]]:
        result = await db.execute(
            select(HandbookArticle.category, func.count(HandbookArticle.id).label("count"))
            .where(HandbookArticle.status == ArticleStatus.published)
            .group_by(HandbookArticle.category)
        )
        rows = result.all()
        categories = [{"name": "Tất cả", "code": "all", "count": sum(r[1] for r in rows)}]
        for r in rows:
            categories.append({"name": r[0].capitalize(), "code": r[0], "count": r[1]})
        return categories

    @staticmethod
    async def search_vector_handbook(
        db: AsyncSession,
        query: str,
        top_k: int = 5
    ) -> List[Dict[str, Any]]:
        """Tìm kiếm ngữ nghĩa (Semantic Vector Search) qua ChromaDB và làm giàu với DB."""
        vector_results = VectorStoreService.search_similar_chunks(query=query, top_k=top_k)
        
        enriched = []
        for item in vector_results:
            meta = item.get("metadata", {})
            article_id_str = meta.get("article_id", "")
            title = meta.get("title", "")
            category = meta.get("category", "general")
            chunk = item.get("chunk", "")
            similarity = item.get("similarity", 0.0)
            
            # Find in DB if it's a UUID
            article_obj = None
            try:
                article_uuid = UUID(article_id_str)
                result = await db.execute(select(HandbookArticle).where(HandbookArticle.id == article_uuid))
                article_obj = result.scalar_one_or_none()
            except Exception:
                pass
                
            enriched.append({
                "article_id": article_id_str,
                "title": article_obj.title if article_obj else title,
                "summary": article_obj.summary if article_obj else chunk[:150] + "...",
                "content_snippet": chunk,
                "category": article_obj.category if article_obj else category,
                "similarity_score": similarity,
                "helpful_count": article_obj.helpful_count if article_obj else 0,
                "view_count": article_obj.view_count if article_obj else 0
            })
        return enriched

    @staticmethod
    async def create_article(
        db: AsyncSession,
        title: str,
        content: str,
        category: str,
        summary: Optional[str] = None,
        author_name: Optional[str] = None,
        author_id: Optional[UUID] = None,
        tags: Optional[List[str]] = None,
        status: ArticleStatus = ArticleStatus.published
    ) -> HandbookArticle:
        article = HandbookArticle(
            title=title,
            summary=summary or (content[:200] + "..."),
            content=content,
            category=category,
            author_name=author_name or "Thực tập sinh",
            author_id=author_id,
            status=status,
            tags=tags or []
        )
        db.add(article)
        await db.commit()
        await db.refresh(article)

        # Sync to ChromaDB
        try:
            VectorStoreService.add_or_update_article(
                article_id=str(article.id),
                title=article.title,
                content=article.content,
                category=article.category
            )
            article.chroma_id = f"{article.id}_chunk_0"
            await db.commit()
        except Exception as e:
            logger.error(f"Error indexing to ChromaDB: {e}")

        return article

    @staticmethod
    async def vote_helpful(db: AsyncSession, article_id: UUID) -> int:
        result = await db.execute(select(HandbookArticle).where(HandbookArticle.id == article_id))
        article = result.scalar_one_or_none()
        if not article:
            return 0
        article.helpful_count = (article.helpful_count or 0) + 1
        await db.commit()
        return article.helpful_count
