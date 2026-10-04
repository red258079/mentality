from fastapi import APIRouter, Depends, HTTPException, status, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from typing import Optional, List
from uuid import UUID

from app.db.database import get_db
from app.services.user_service import get_current_user
from app.services.handbook_service import HandbookService
from app.services.situation_accumulator_service import SituationAccumulatorService
from app.db.models.handbook_article import ArticleStatus

router = APIRouter()


class CreateArticleRequest(BaseModel):
    title: str = Field(..., min_length=5, max_length=500, description="Tiêu đề bài viết cẩm nang")
    content: str = Field(..., min_length=20, description="Nội dung bài viết")
    category: str = Field(default="career", description="Danh mục: sleep, physical, mental, social, career")
    summary: Optional[str] = Field(None, description="Tóm tắt ngắn")
    tags: Optional[List[str]] = Field(default=[], description="Thẻ tags")


class AccumulateSituationRequest(BaseModel):
    situation_description: str = Field(..., min_length=10, description="Mô tả tình huống thực tế hoặc câu hỏi sinh viên")
    recommended_solution: str = Field(..., min_length=10, description="Giải pháp hoặc tư vấn tương ứng")
    category_hint: Optional[str] = Field(None, description="Gợi ý danh mục")


async def get_authed_user(authorization: Optional[str] = Header(None), db: AsyncSession = Depends(get_db)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await get_current_user(db, token)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ.")
    return user


@router.get("", summary="Tra cứu danh sách cẩm nang kinh nghiệm")
async def get_handbook_articles(
    category: Optional[str] = Query(None, description="Lọc theo danh mục"),
    search: Optional[str] = Query(None, description="Từ khóa tìm kiếm"),
    status: Optional[str] = Query("published", description="Trạng thái bài viết"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db)
):
    articles = await HandbookService.get_articles(
        db=db,
        category=category,
        search_keyword=search,
        status=status,
        skip=skip,
        limit=limit
    )
    return [
        {
            "id": str(a.id),
            "title": a.title,
            "summary": a.summary,
            "category": a.category,
            "author_name": a.author_name,
            "helpful_count": a.helpful_count,
            "view_count": a.view_count,
            "tags": a.tags,
            "status": a.status.value,
            "created_at": a.created_at,
            "updated_at": a.updated_at
        }
        for a in articles
    ]


@router.get("/categories", summary="Lấy danh sách các danh mục cẩm nang")
async def get_categories(db: AsyncSession = Depends(get_db)):
    return await HandbookService.get_categories(db)


@router.get("/search", summary="Tìm kiếm ngữ nghĩa Cẩm nang bằng Vector Store (ChromaDB)")
async def search_semantic_handbook(
    q: str = Query(..., min_length=2, description="Nội dung hoặc câu hỏi tìm kiếm"),
    top_k: int = Query(5, ge=1, le=10),
    db: AsyncSession = Depends(get_db)
):
    return await HandbookService.search_vector_handbook(db=db, query=q, top_k=top_k)


@router.get("/{article_id}", summary="Lấy chi tiết một bài cẩm nang / tình huống")
async def get_article_detail(
    article_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    article = await HandbookService.get_article_by_id(db, article_id)
    if not article:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bài viết cẩm nang không tồn tại.")
    return {
        "id": str(article.id),
        "title": article.title,
        "summary": article.summary,
        "content": article.content,
        "category": article.category,
        "author_name": article.author_name,
        "helpful_count": article.helpful_count,
        "view_count": article.view_count,
        "tags": article.tags,
        "status": article.status.value,
        "created_at": article.created_at,
        "updated_at": article.updated_at
    }


@router.post("", summary="Đóng góp bài viết cẩm nang mới")
async def create_article(
    payload: CreateArticleRequest,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    article = await HandbookService.create_article(
        db=db,
        title=payload.title,
        content=payload.content,
        category=payload.category,
        summary=payload.summary,
        author_name=user.full_name,
        author_id=user.id,
        tags=payload.tags,
        status=ArticleStatus.published if user.role == "admin" else ArticleStatus.published
    )
    return {
        "id": str(article.id),
        "title": article.title,
        "category": article.category,
        "status": article.status.value,
        "message": "Đã thêm bài viết cẩm nang và lập chỉ mục Vector Store thành công!"
    }


@router.post("/{article_id}/helpful", summary="Đánh giá hữu ích cho bài cẩm nang")
async def vote_helpful(
    article_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    count = await HandbookService.vote_helpful(db, article_id)
    return {"article_id": str(article_id), "helpful_count": count}


@router.post("/accumulate", summary="Tích lũy tình huống thực tế mới vào cơ sở tri thức & Vector Store")
async def accumulate_situation(
    payload: AccumulateSituationRequest,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    result = await SituationAccumulatorService.extract_and_accumulate_situation(
        db=db,
        user_query=payload.situation_description,
        ai_solution=payload.recommended_solution,
        user_id=user.id,
        author_name=user.full_name,
        category_hint=payload.category_hint
    )
    return {
        "status": "success",
        "message": "Đã tích lũy tình huống mới vào CSDL và đồng bộ hóa ChromaDB!",
        "data": result
    }
