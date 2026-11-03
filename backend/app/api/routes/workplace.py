from typing import Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Header
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.companies import DEFAULT_COMPANIES, find_company_by_name
from app.core.text_utils import normalize_vietnamese_text
from app.db.database import get_db
from app.db.models.catalog import Company
from app.db.models.intern_profile import InternProfile
from app.db.models.user import User
from app.services.user_service import get_current_user

router = APIRouter()

_CUSTOM_PLACEHOLDERS = {
    "custom",
    "cong ty khac",
    "cong ty khac (tu dinh vi / van phong)",
}


async def get_authed_user(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await get_current_user(db, token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token không hợp lệ hoặc đã hết hạn.",
        )
    return user


class UpdateWorkplaceRequest(BaseModel):
    company_id: Optional[str] = None
    company_name: Optional[str] = None
    company_lat: Optional[float] = None
    company_lng: Optional[float] = None
    company_radius: Optional[int] = None
    workplace_type: Optional[str] = None
    work_shift: Optional[str] = "day_12h"
    department: Optional[str] = None
    dorm_lat: Optional[float] = None
    dorm_lng: Optional[float] = None


async def _find_approved_company_in_db(
    db: AsyncSession,
    *,
    name: Optional[str] = None,
    code: Optional[str] = None,
) -> Optional[Company]:
    all_comps_res = await db.execute(select(Company).where(Company.is_approved == True))
    approved_companies = all_comps_res.scalars().all()
    norm_name = normalize_vietnamese_text(name) if name else None
    code_clean = code.strip().lower() if code else None

    for c in approved_companies:
        if code_clean and c.code and c.code.strip().lower() == code_clean:
            return c
        if norm_name:
            if normalize_vietnamese_text(c.name) == norm_name or (
                c.short_name and normalize_vietnamese_text(c.short_name) == norm_name
            ):
                return c
    return None


@router.get("/companies", summary="Lấy danh mục công ty thực tập mẫu kèm tọa độ GPS")
async def get_companies():
    return DEFAULT_COMPANIES


@router.get("/profile", summary="Lấy thông tin công ty và ca làm việc hiện tại của sinh viên")
async def get_workplace_profile(
    user: User = Depends(get_authed_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(InternProfile, Company)
        .outerjoin(Company, InternProfile.company_id == Company.id)
        .where(InternProfile.user_id == user.id)
    )
    row = result.first()
    profile = row[0] if row else None
    comp = row[1] if row else None

    if not profile:
        matched_comp = find_company_by_name("LG Display") or DEFAULT_COMPANIES[0]
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

    effective_company_name = profile.company_name
    if comp and (not effective_company_name or effective_company_name == "LG Display"):
        effective_company_name = comp.name

    return {
        "user_id": str(user.id),
        "full_name": user.full_name,
        "company_id": str(profile.company_id) if profile.company_id else None,
        "company_name": effective_company_name or "LG Display Hải Phòng",
        "department": profile.department or "Khối Sản xuất Module",
        "company_lat": profile.company_lat,
        "company_lng": profile.company_lng,
        "company_radius": profile.company_radius or 500,
        "workplace_type": profile.workplace_type or "factory_locker",
        "work_shift": profile.work_shift or "day_12h",
        "dorm_lat": profile.dorm_lat,
        "dorm_lng": profile.dorm_lng,
        "current_phase": (
            profile.current_phase.value
            if hasattr(profile.current_phase, "value")
            else str(profile.current_phase)
        ),
    }


@router.put("/profile", summary="Cập nhật công ty thực tập, tọa độ GPS và ca làm việc")
async def update_workplace_profile(
    payload: UpdateWorkplaceRequest,
    user: User = Depends(get_authed_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(InternProfile).where(InternProfile.user_id == user.id))
    profile = result.scalar_one_or_none()

    comp_lat = payload.company_lat
    comp_lng = payload.company_lng
    comp_radius = payload.company_radius
    wp_type = payload.workplace_type

    raw_id = payload.company_id.strip() if payload.company_id else None
    raw_name = payload.company_name.strip() if payload.company_name else None
    norm_raw_name = normalize_vietnamese_text(raw_name) if raw_name else ""

    is_custom_request = (
        (raw_id is not None and raw_id.lower() == "custom")
        or wp_type == "custom"
        or (norm_raw_name in _CUSTOM_PLACEHOLDERS)
    )

    resolved_company_id = None
    resolved_company_name = None

    if is_custom_request:
        if not raw_name or norm_raw_name in _CUSTOM_PLACEHOLDERS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Vui lòng nhập tên công ty cụ thể khi chọn 'Công ty khác'.",
            )
        resolved_company_name = raw_name
        db_comp = await _find_approved_company_in_db(db, name=raw_name)
        resolved_company_id = db_comp.id if db_comp else None
        custom_template = find_company_by_name("custom")
        if comp_radius is None:
            comp_radius = custom_template["radius_meters"] if custom_template else 300
        wp_type = "custom"
    elif raw_id is not None:
        db_comp = None
        try:
            parsed_uuid = UUID(raw_id)
            c_res = await db.execute(select(Company).where(Company.id == parsed_uuid))
            db_comp = c_res.scalar_one_or_none()
        except ValueError:
            db_comp = await _find_approved_company_in_db(db, code=raw_id)

        matched_sample = find_company_by_name(raw_id)
        if not db_comp and matched_sample:
            db_comp = await _find_approved_company_in_db(
                db,
                name=matched_sample["name"],
                code=matched_sample["id"],
            )

        if not db_comp and not matched_sample:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy công ty/nơi thực tập trong danh mục.",
            )

        if db_comp:
            resolved_company_id = db_comp.id
            resolved_company_name = db_comp.name
            if comp_lat is None:
                comp_lat = db_comp.latitude
            if comp_lng is None:
                comp_lng = db_comp.longitude
            if comp_radius is None:
                comp_radius = db_comp.radius_meters
            if wp_type is None:
                wp_type = db_comp.workplace_type
        if matched_sample:
            if resolved_company_name is None:
                resolved_company_name = matched_sample["name"]
            if comp_lat is None:
                comp_lat = matched_sample["latitude"]
            if comp_lng is None:
                comp_lng = matched_sample["longitude"]
            if comp_radius is None:
                comp_radius = matched_sample["radius_meters"]
            if wp_type is None:
                wp_type = matched_sample["workplace_type"]
    elif raw_name is not None and raw_name != "":
        matched_sample = find_company_by_name(raw_name)
        db_comp = await _find_approved_company_in_db(
            db,
            name=matched_sample["name"] if matched_sample else raw_name,
            code=matched_sample["id"] if matched_sample else None,
        )

        if not db_comp and not matched_sample:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Không tìm thấy công ty '{raw_name}' trong danh mục.",
            )

        if db_comp:
            resolved_company_id = db_comp.id
            resolved_company_name = db_comp.name
            if comp_lat is None:
                comp_lat = db_comp.latitude
            if comp_lng is None:
                comp_lng = db_comp.longitude
            if comp_radius is None:
                comp_radius = db_comp.radius_meters
            if wp_type is None:
                wp_type = db_comp.workplace_type
        if matched_sample:
            if resolved_company_name is None:
                resolved_company_name = matched_sample["name"]
            if comp_lat is None:
                comp_lat = matched_sample["latitude"]
            if comp_lng is None:
                comp_lng = matched_sample["longitude"]
            if comp_radius is None:
                comp_radius = matched_sample["radius_meters"]
            if wp_type is None:
                wp_type = matched_sample["workplace_type"]
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vui lòng chọn hoặc nhập tên công ty thực tập.",
        )

    if not profile:
        profile = InternProfile(
            user_id=user.id,
            company_id=resolved_company_id,
            company_name=resolved_company_name,
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
        profile.company_id = resolved_company_id
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
        "company_radius": profile.company_radius,
        "dorm_lat": profile.dorm_lat,
        "dorm_lng": profile.dorm_lng,
    }
