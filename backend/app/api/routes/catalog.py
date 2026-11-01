from fastapi import APIRouter, Depends, HTTPException, status, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_
from typing import Optional, List
from datetime import datetime, timezone, time
import uuid

from app.db.database import get_db
from app.db.models.user import User
from app.db.models.catalog import University, Company
from app.schemas.catalog import (
    UniversityResponse,
    CompanyResponse,
    CustomCatalogRequest,
    UniversityCatalogItem,
    CompanyCatalogItem,
)
from app.core.text_utils import normalize_vietnamese_text, is_accent_insensitive_match
from app.services import user_service

router = APIRouter()


async def get_authed_user(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Chưa xác thực. Vui lòng gửi kèm Bearer token."
        )
    token = authorization.split(" ", 1)[1]
    user = await user_service.get_current_user(db, token)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token không hợp lệ hoặc đã hết hạn."
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tài khoản đã bị vô hiệu hóa."
        )
    return user


@router.get(
    "/universities",
    response_model=List[UniversityCatalogItem],
    summary="Lấy danh mục các trường đại học/cao đẳng đã được phê duyệt",
)
async def list_approved_universities(
    q: Optional[str] = Query(None, description="Từ khóa tìm kiếm (hỗ trợ tiếng Việt không dấu)"),
    limit: int = Query(20, ge=1, description="Số lượng kết quả tối đa (tối đa 50)"),
    user: User = Depends(get_authed_user),
    db: AsyncSession = Depends(get_db),
):
    clamped_limit = min(max(1, limit), 50)
    query = select(University).where(University.is_approved == True)

    if q and q.strip():
        pattern = f"%{q.strip()}%"
        norm_pattern = func.extensions.unaccent(pattern)
        query = query.where(
            or_(
                func.extensions.unaccent(University.name).ilike(norm_pattern),
                and_(
                    University.short_name.isnot(None),
                    func.extensions.unaccent(University.short_name).ilike(norm_pattern),
                ),
            )
        )

    query = query.order_by(University.name.asc()).limit(clamped_limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.get(
    "/companies",
    response_model=List[CompanyCatalogItem],
    summary="Lấy danh mục các công ty/nơi thực tập đã được phê duyệt",
)
async def list_approved_companies(
    q: Optional[str] = Query(None, description="Từ khóa tìm kiếm (hỗ trợ tiếng Việt không dấu)"),
    limit: int = Query(20, ge=1, description="Số lượng kết quả tối đa (tối đa 50)"),
    user: User = Depends(get_authed_user),
    db: AsyncSession = Depends(get_db),
):
    clamped_limit = min(max(1, limit), 50)
    query = select(Company).where(Company.is_approved == True)

    if q and q.strip():
        pattern = f"%{q.strip()}%"
        norm_pattern = func.extensions.unaccent(pattern)
        query = query.where(
            or_(
                func.extensions.unaccent(Company.name).ilike(norm_pattern),
                and_(
                    Company.short_name.isnot(None),
                    func.extensions.unaccent(Company.short_name).ilike(norm_pattern),
                ),
            )
        )

    query = query.order_by(Company.name.asc()).limit(clamped_limit)
    result = await db.execute(query)
    return result.scalars().all()


@router.post(
    "/custom",
    status_code=status.HTTP_201_CREATED,
    summary="Gửi đề xuất thêm trường học hoặc nơi thực tập mới (chờ duyệt)",
)
async def submit_custom_catalog_entry(
    payload: CustomCatalogRequest,
    user: User = Depends(get_authed_user),
    db: AsyncSession = Depends(get_db),
):
    raw_name = payload.name.strip()
    norm_name = normalize_vietnamese_text(raw_name)

    # 1. Kiểm tra giới hạn tần suất: tối đa 3 yêu cầu / user / ngày
    today_start = datetime.combine(datetime.now(timezone.utc).date(), time.min, tzinfo=timezone.utc)
    
    uni_count_res = await db.execute(
        select(func.count(University.id)).where(
            and_(
                University.submitted_by_user_id == user.id,
                University.created_at >= today_start,
            )
        )
    )
    comp_count_res = await db.execute(
        select(func.count(Company.id)).where(
            and_(
                Company.submitted_by_user_id == user.id,
                Company.created_at >= today_start,
            )
        )
    )
    total_today = (uni_count_res.scalar() or 0) + (comp_count_res.scalar() or 0)
    if total_today >= 3:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Bạn đã gửi tối đa 3 đề xuất đơn vị mới trong ngày hôm nay. Vui lòng quay lại vào ngày mai.",
        )

    # 2. Kiểm tra trùng lặp theo tên chuẩn hóa (cả đã duyệt và đang chờ duyệt)
    if payload.entity_type == "university":
        all_unis_res = await db.execute(select(University))
        existing_unis = all_unis_res.scalars().all()
        for u in existing_unis:
            if normalize_vietnamese_text(u.name) == norm_name or (
                u.short_name and normalize_vietnamese_text(u.short_name) == norm_name
            ):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Trường '{u.name}' đã tồn tại trong danh mục hoặc đang chờ ban quản trị phê duyệt.",
                )

        generated_code = f"custom_uni_{uuid.uuid4().hex[:8]}"
        new_uni = University(
            code=generated_code,
            name=raw_name,
            short_name=payload.short_name,
            city=payload.city,
            is_approved=False,
            submitted_by_user_id=user.id,
        )
        db.add(new_uni)
        await db.commit()
        await db.refresh(new_uni)

        return {
            "message": "Đã gửi đề xuất trường học thành công. Ban quản trị sẽ kiểm duyệt sớm.",
            "entity": UniversityResponse.model_validate(new_uni),
        }

    else:
        all_comps_res = await db.execute(select(Company))
        existing_comps = all_comps_res.scalars().all()
        for c in existing_comps:
            if normalize_vietnamese_text(c.name) == norm_name or (
                c.short_name and normalize_vietnamese_text(c.short_name) == norm_name
            ):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Nơi thực tập '{c.name}' đã tồn tại trong danh mục hoặc đang chờ ban quản trị phê duyệt.",
                )

        generated_code = f"custom_comp_{uuid.uuid4().hex[:8]}"
        new_comp = Company(
            code=generated_code,
            name=raw_name,
            short_name=payload.short_name,
            workplace_type=payload.workplace_type or "factory_locker",
            radius_meters=500,
            is_approved=False,
            submitted_by_user_id=user.id,
        )
        db.add(new_comp)
        await db.commit()
        await db.refresh(new_comp)

        return {
            "message": "Đã gửi đề xuất nơi thực tập thành công. Ban quản trị sẽ kiểm duyệt sớm.",
            "entity": CompanyResponse.model_validate(new_comp),
        }
