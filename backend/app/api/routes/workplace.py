from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional, List, Dict, Any
from pydantic import BaseModel

from app.db.database import get_db
from app.db.models.user import User
from app.db.models.intern_profile import InternProfile
from app.services.user_service import get_current_user
from app.core.companies import DEFAULT_COMPANIES, find_company_by_name

router = APIRouter()


async def get_authed_user(authorization: Optional[str] = Header(None), db: AsyncSession = Depends(get_db)) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await get_current_user(db, token)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ hoặc đã hết hạn.")
    return user


from uuid import UUID
from app.db.models.catalog import Company
from app.core.text_utils import normalize_vietnamese_text


class UpdateWorkplaceRequest(BaseModel):
    company_id: Optional[UUID] = None
    company_name: Optional[str] = None
    company_lat: Optional[float] = None
    company_lng: Optional[float] = None
    company_radius: Optional[int] = 500
    workplace_type: Optional[str] = "factory_locker"
    work_shift: Optional[str] = "day_12h"
    department: Optional[str] = None
    dorm_lat: Optional[float] = None
    dorm_lng: Optional[float] = None


@router.get("/companies", summary="Lấy danh mục công ty thực tập mẫu kèm tọa độ GPS")
async def get_companies():
    return DEFAULT_COMPANIES


@router.get("/profile", summary="Lấy thông tin công ty và ca làm việc hiện tại của sinh viên")
async def get_workplace_profile(
    user: User = Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(InternProfile).where(InternProfile.user_id == user.id))
    profile = result.scalar_one_or_none()

    if not profile:
        # Tự động tạo hồ sơ mặc định nếu chưa có
        matched_comp = find_company_by_name("LG Display")
        profile = InternProfile(
            user_id=user.id,
            company_name=matched_comp["name"],
            company_lat=matched_comp["latitude"],
            company_lng=matched_comp["longitude"],
            company_radius=matched_comp["radius_meters"],
            workplace_type=matched_comp["workplace_type"],
            work_shift="day_12h",
        )
        db.add(profile)
        await db.commit()
        await db.refresh(profile)

    return {
        "user_id": str(user.id),
        "full_name": user.full_name,
        "company_id": str(profile.company_id) if profile.company_id else None,
        "company_name": profile.company_name or "LG Display Hải Phòng",
        "department": profile.department or "Khối Sản xuất Module",
        "company_lat": profile.company_lat,
        "company_lng": profile.company_lng,
        "company_radius": profile.company_radius or 500,
        "workplace_type": profile.workplace_type or "factory_locker",
        "work_shift": profile.work_shift or "day_12h",
        "dorm_lat": profile.dorm_lat,
        "dorm_lng": profile.dorm_lng,
        "current_phase": profile.current_phase.value if hasattr(profile.current_phase, 'value') else str(profile.current_phase),
    }


@router.put("/profile", summary="Cập nhật công ty thực tập, tọa độ GPS và ca làm việc")
async def update_workplace_profile(
    payload: UpdateWorkplaceRequest,
    user: User = Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(InternProfile).where(InternProfile.user_id == user.id))
    profile = result.scalar_one_or_none()

    comp_lat = payload.company_lat
    comp_lng = payload.company_lng
    comp_radius = payload.company_radius
    wp_type = payload.workplace_type

    resolved_company_id = None
    resolved_company_name = None

    if payload.company_id is not None:
        c_res = await db.execute(select(Company).where(Company.id == payload.company_id))
        db_comp = c_res.scalar_one_or_none()
        if not db_comp:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy công ty/nơi thực tập trong danh mục."
            )
        resolved_company_id = db_comp.id
        resolved_company_name = db_comp.name
        if comp_lat is None:
            comp_lat = db_comp.latitude
        if comp_lng is None:
            comp_lng = db_comp.longitude
        if comp_radius is None:
            comp_radius = db_comp.radius_meters
        if wp_type is None or wp_type == "factory_locker":
            wp_type = db_comp.workplace_type
    elif payload.company_name is not None:
        cname = payload.company_name.strip()
        if cname:
            norm_cname = normalize_vietnamese_text(cname)
            all_comps_res = await db.execute(select(Company).where(Company.is_approved == True))
            matched = None
            for c in all_comps_res.scalars().all():
                if normalize_vietnamese_text(c.name) == norm_cname or (
                    c.short_name and normalize_vietnamese_text(c.short_name) == norm_cname
                ):
                    matched = c
                    break
            if matched:
                resolved_company_id = matched.id
                resolved_company_name = matched.name
                if comp_lat is None:
                    comp_lat = matched.latitude
                if comp_lng is None:
                    comp_lng = matched.longitude
                if comp_radius is None:
                    comp_radius = matched.radius_meters
                if wp_type is None or wp_type == "factory_locker":
                    wp_type = matched.workplace_type
            else:
                resolved_company_name = cname
                matched_sample = find_company_by_name(cname)
                if matched_sample and matched_sample["latitude"] is not None:
                    if comp_lat is None:
                        comp_lat = matched_sample["latitude"]
                    if comp_lng is None:
                        comp_lng = matched_sample["longitude"]
                    if comp_radius is None:
                        comp_radius = matched_sample["radius_meters"]
                    if wp_type is None or wp_type == "factory_locker":
                        wp_type = matched_sample["workplace_type"]

    if not profile:
        profile = InternProfile(
            user_id=user.id,
            company_id=resolved_company_id,
            company_name=resolved_company_name or "LG Display Hải Phòng",
            department=payload.department.strip() if payload.department else None,
            company_lat=comp_lat,
            company_lng=comp_lng,
            company_radius=comp_radius or 500,
            workplace_type=wp_type or "factory_locker",
            work_shift=payload.work_shift or "day_12h",
            dorm_lat=payload.dorm_lat,
            dorm_lng=payload.dorm_lng,
        )
        db.add(profile)
    else:
        if resolved_company_id is not None or payload.company_id is not None:
            profile.company_id = resolved_company_id
        if resolved_company_name is not None:
            profile.company_name = resolved_company_name
        if payload.department is not None:
            profile.department = payload.department.strip()
        profile.company_lat = comp_lat
        profile.company_lng = comp_lng
        profile.company_radius = comp_radius or profile.company_radius or 500
        profile.workplace_type = wp_type or profile.workplace_type or "factory_locker"
        profile.work_shift = payload.work_shift or profile.work_shift or "day_12h"
        if payload.dorm_lat is not None:
            profile.dorm_lat = payload.dorm_lat
        if payload.dorm_lng is not None:
            profile.dorm_lng = payload.dorm_lng

    await db.commit()
    await db.refresh(profile)

    return {
        "message": "Cập nhật hồ sơ thực tập và vị trí công ty thành công!",
        "company_id": str(profile.company_id) if profile.company_id else None,
        "company_name": profile.company_name,
        "work_shift": profile.work_shift,
        "workplace_type": profile.workplace_type,
        "company_lat": profile.company_lat,
        "company_lng": profile.company_lng,
        "dorm_lat": profile.dorm_lat,
        "dorm_lng": profile.dorm_lng,
    }
