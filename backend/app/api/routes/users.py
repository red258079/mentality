import secrets
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete, func, and_, or_
from typing import Optional

from app.db.database import get_db
from app.schemas.auth import UserResponse, UpdateProfileRequest, ChangePasswordRequest
from app.schemas.catalog import (
    UpdateProfileCatalogRequest,
    CatalogEntitySummary,
    ProfileCatalogUpdateResponse,
)
from app.schemas.onboarding import OnboardingStatusResponse, UpdateOnboardingRequest
from app.db.models.feature_onboarding import UserFeatureOnboarding
from app.db.models.user import User
from app.db.models.catalog import University, Company
from app.db.models.intern_profile import InternProfile
from app.services import user_service
from app.core.security import verify_password, hash_password
from app.core.text_utils import normalize_vietnamese_text

router = APIRouter()


async def build_user_profile_response(db: AsyncSession, user: User) -> UserResponse:
    result = await db.execute(
        select(User, University, InternProfile, Company)
        .outerjoin(University, User.university_id == University.id)
        .outerjoin(InternProfile, User.id == InternProfile.user_id)
        .outerjoin(Company, InternProfile.company_id == Company.id)
        .where(User.id == user.id)
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy người dùng.")
    u, uni, prof, comp = row

    uni_pending = bool(uni and not uni.is_approved)
    comp_pending = bool(comp and not comp.is_approved)
    resolved_company_name = (
        comp.name if comp else (prof.company_name if prof and prof.company_name else None)
    )

    return UserResponse(
        id=u.id,
        email=u.email,
        full_name=u.full_name,
        role=u.role.value if hasattr(u.role, 'value') else str(u.role),
        student_id=u.student_id,
        university_id=u.university_id,
        university=u.university,
        university_name=uni.name if uni else None,
        university_is_pending=uni_pending,
        company_id=prof.company_id if prof else None,
        company_name=resolved_company_name,
        company_is_pending=comp_pending,
        is_pending=bool(uni_pending or comp_pending),
        major=u.major,
        avatar_url=u.avatar_url,
        is_active=u.is_active,
        created_at=u.created_at,
    )


async def apply_profile_catalog_updates(
    user: User,
    university_id: Optional[UUID],
    company_id: Optional[UUID],
    other_university_name: Optional[str],
    other_company_name: Optional[str],
    db: AsyncSession,
) -> tuple[Optional[University], Optional[Company]]:
    # Rule: Send at most one of university_id / other_university_name (same for company); both together is a 400.
    if university_id is not None and other_university_name is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Chỉ được gửi một trong hai: university_id hoặc other_university_name.",
        )
    if company_id is not None and other_company_name is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Chỉ được gửi một trong hai: company_id hoặc other_company_name.",
        )

    target_uni: Optional[University] = None
    target_comp: Optional[Company] = None

    # Handle university_id
    if university_id is not None:
        uni_res = await db.execute(select(University).where(University.id == university_id))
        uni = uni_res.scalar_one_or_none()
        if not uni or not uni.is_approved:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="university_id không tồn tại hoặc chưa được phê duyệt.",
            )
        user.university_id = uni.id
        target_uni = uni

    # Handle other_university_name
    elif other_university_name is not None:
        trimmed_uni = other_university_name.strip()
        if len(trimmed_uni) < 2 or len(trimmed_uni) > 255:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="other_university_name phải có độ dài từ 2 đến 255 ký tự.",
            )
        norm_uni = func.lower(func.extensions.unaccent(trimmed_uni))
        # 1. Approved row with same normalized name
        appr_uni_res = await db.execute(
            select(University).where(
                and_(
                    University.is_approved == True,
                    or_(
                        func.lower(func.extensions.unaccent(University.name)) == norm_uni,
                        and_(
                            University.short_name.isnot(None),
                            func.lower(func.extensions.unaccent(University.short_name)) == norm_uni,
                        ),
                    ),
                )
            )
        )
        matched_uni = appr_uni_res.scalars().first()
        if not matched_uni:
            # 2. Pending row (is_approved = false) with same normalized name
            pend_uni_res = await db.execute(
                select(University).where(
                    and_(
                        University.is_approved == False,
                        or_(
                            func.lower(func.extensions.unaccent(University.name)) == norm_uni,
                            and_(
                                University.short_name.isnot(None),
                                func.lower(func.extensions.unaccent(University.short_name)) == norm_uni,
                            ),
                        ),
                    )
                )
            )
            matched_uni = pend_uni_res.scalars().first()
        if not matched_uni:
            # Rate limit: a user may have at most 3 pending rows they submitted per table
            count_res = await db.execute(
                select(func.count(University.id)).where(
                    and_(
                        University.submitted_by_user_id == user.id,
                        University.is_approved == False,
                    )
                )
            )
            pending_count = count_res.scalar() or 0
            if pending_count >= 3:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Bạn đã đề xuất tối đa 3 trường đại học đang chờ duyệt. Vui lòng chờ quản trị viên phê duyệt trước khi đề xuất thêm.",
                )

            # 3. Insert new row
            hex_code = secrets.token_hex(4).upper()
            matched_uni = University(
                code=f"USER-{hex_code}",
                name=trimmed_uni,
                is_approved=False,
                submitted_by_user_id=user.id,
            )
            db.add(matched_uni)
            await db.flush()

        user.university_id = matched_uni.id
        target_uni = matched_uni

    # Handle company_id
    if company_id is not None:
        comp_res = await db.execute(select(Company).where(Company.id == company_id))
        comp = comp_res.scalar_one_or_none()
        if not comp or not comp.is_approved:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="company_id không tồn tại hoặc chưa được phê duyệt.",
            )
        prof_res = await db.execute(select(InternProfile).where(InternProfile.user_id == user.id))
        prof = prof_res.scalar_one_or_none()
        if not prof:
            prof = InternProfile(user_id=user.id)
            db.add(prof)
        prof.company_id = comp.id
        prof.company_name = comp.name
        if comp.latitude is not None:
            prof.company_lat = comp.latitude
        if comp.longitude is not None:
            prof.company_lng = comp.longitude
        if comp.radius_meters is not None:
            prof.company_radius = comp.radius_meters
        if comp.workplace_type:
            prof.workplace_type = comp.workplace_type
        target_comp = comp

    # Handle other_company_name
    elif other_company_name is not None:
        trimmed_comp = other_company_name.strip()
        if len(trimmed_comp) < 2 or len(trimmed_comp) > 255:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="other_company_name phải có độ dài từ 2 đến 255 ký tự.",
            )
        norm_comp = func.lower(func.extensions.unaccent(trimmed_comp))
        # 1. Approved row with same normalized name
        appr_comp_res = await db.execute(
            select(Company).where(
                and_(
                    Company.is_approved == True,
                    or_(
                        func.lower(func.extensions.unaccent(Company.name)) == norm_comp,
                        and_(
                            Company.short_name.isnot(None),
                            func.lower(func.extensions.unaccent(Company.short_name)) == norm_comp,
                        ),
                    ),
                )
            )
        )
        matched_comp = appr_comp_res.scalars().first()
        if not matched_comp:
            # 2. Pending row with same normalized name
            pend_comp_res = await db.execute(
                select(Company).where(
                    and_(
                        Company.is_approved == False,
                        or_(
                            func.lower(func.extensions.unaccent(Company.name)) == norm_comp,
                            and_(
                                Company.short_name.isnot(None),
                                func.lower(func.extensions.unaccent(Company.short_name)) == norm_comp,
                            ),
                        ),
                    )
                )
            )
            matched_comp = pend_comp_res.scalars().first()
        if not matched_comp:
            # Rate limit: a user may have at most 3 pending rows they submitted per table
            count_res = await db.execute(
                select(func.count(Company.id)).where(
                    and_(
                        Company.submitted_by_user_id == user.id,
                        Company.is_approved == False,
                    )
                )
            )
            pending_count = count_res.scalar() or 0
            if pending_count >= 3:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Bạn đã đề xuất tối đa 3 công ty/nơi thực tập đang chờ duyệt. Vui lòng chờ quản trị viên phê duyệt trước khi đề xuất thêm.",
                )

            # 3. Insert new row
            hex_code = secrets.token_hex(4).upper()
            matched_comp = Company(
                code=f"USER-{hex_code}",
                name=trimmed_comp,
                workplace_type="factory_locker",
                radius_meters=500,
                is_approved=False,
                submitted_by_user_id=user.id,
            )
            db.add(matched_comp)
            await db.flush()

        prof_res = await db.execute(select(InternProfile).where(InternProfile.user_id == user.id))
        prof = prof_res.scalar_one_or_none()
        if not prof:
            prof = InternProfile(user_id=user.id)
            db.add(prof)
        prof.company_id = matched_comp.id
        prof.company_name = matched_comp.name
        target_comp = matched_comp

    # Fetch rows if not modified in this request
    if target_uni is None and user.university_id is not None:
        u_res = await db.execute(select(University).where(University.id == user.university_id))
        target_uni = u_res.scalar_one_or_none()

    if target_comp is None:
        prof_res = await db.execute(select(InternProfile).where(InternProfile.user_id == user.id))
        prof = prof_res.scalar_one_or_none()
        if prof and prof.company_id:
            c_res = await db.execute(select(Company).where(Company.id == prof.company_id))
            target_comp = c_res.scalar_one_or_none()

    return target_uni, target_comp


@router.get("/me", response_model=UserResponse, summary="Lấy thông tin tài khoản")
async def get_my_profile(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await user_service.get_current_user(db, token)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ hoặc đã hết hạn.")
    return await build_user_profile_response(db, user)


@router.put("/me/profile", response_model=ProfileCatalogUpdateResponse, summary="Cập nhật trường học và công ty thực tập theo Catalog")
@router.put("/profile", response_model=ProfileCatalogUpdateResponse, summary="Cập nhật trường học và công ty thực tập theo Catalog (alias)")
async def update_my_catalog_profile(
    payload: UpdateProfileCatalogRequest,
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await user_service.get_current_user(db, token)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ hoặc đã hết hạn.")

    target_uni, target_comp = await apply_profile_catalog_updates(
        user=user,
        university_id=payload.university_id,
        company_id=payload.company_id,
        other_university_name=payload.other_university_name,
        other_company_name=payload.other_company_name,
        db=db,
    )
    response = ProfileCatalogUpdateResponse(
        university=CatalogEntitySummary(
            id=target_uni.id,
            name=target_uni.name,
            is_pending=not target_uni.is_approved,
        ) if target_uni else None,
        company=CatalogEntitySummary(
            id=target_comp.id,
            name=target_comp.name,
            is_pending=not target_comp.is_approved,
        ) if target_comp else None,
    )
    await db.commit()
    return response


@router.put("/me", response_model=UserResponse, summary="Cập nhật thông tin tài khoản")
async def update_my_profile(
    payload: UpdateProfileRequest,
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await user_service.get_current_user(db, token)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ hoặc đã hết hạn.")

    if payload.full_name is not None and payload.full_name.strip():
        user.full_name = payload.full_name.strip()
    if payload.student_id is not None:
        user.student_id = payload.student_id.strip() if payload.student_id.strip() else None

    # Handle catalog profile updates if provided
    has_catalog_updates = any([
        payload.university_id is not None,
        payload.company_id is not None,
        payload.other_university_name is not None,
        payload.other_company_name is not None,
    ])

    if has_catalog_updates:
        await apply_profile_catalog_updates(
            user=user,
            university_id=payload.university_id,
            company_id=payload.company_id,
            other_university_name=payload.other_university_name,
            other_company_name=payload.other_company_name,
            db=db,
        )
    elif payload.university is not None:
        clean_uni_str = payload.university.strip()
        if clean_uni_str:
            norm_target = normalize_vietnamese_text(clean_uni_str)
            all_unis_res = await db.execute(select(University).where(University.is_approved == True))
            matched = None
            for u in all_unis_res.scalars().all():
                if normalize_vietnamese_text(u.name) == norm_target or (
                    u.short_name and normalize_vietnamese_text(u.short_name) == norm_target
                ):
                    matched = u
                    break
            if matched:
                user.university_id = matched.id
                user.university = matched.name
            else:
                user.university = clean_uni_str
        else:
            user.university = None
            user.university_id = None

    if payload.major is not None:
        user.major = payload.major.strip() if payload.major.strip() else None
    if payload.avatar_url is not None:
        user.avatar_url = payload.avatar_url

    await db.commit()
    await db.refresh(user)
    return await build_user_profile_response(db, user)


@router.post("/change-password", summary="Đổi mật khẩu tài khoản")
async def change_password(
    payload: ChangePasswordRequest,
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await user_service.get_current_user(db, token)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ hoặc đã hết hạn.")

    if user.password_hash and not verify_password(payload.old_password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Mật khẩu hiện tại không chính xác.")

    user.password_hash = hash_password(payload.new_password)
    await db.commit()
    return {"message": "Đổi mật khẩu thành công."}


@router.get("/onboarding-status", response_model=OnboardingStatusResponse, summary="Lấy danh sách các tính năng đã xem hướng dẫn")
async def get_onboarding_status(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await user_service.get_current_user(db, token)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ hoặc đã hết hạn.")

    result = await db.execute(
        select(UserFeatureOnboarding.feature_key).where(
            UserFeatureOnboarding.user_id == user.id,
            UserFeatureOnboarding.completed == True,
        )
    )
    completed_features = [row[0] for row in result.all()]
    return OnboardingStatusResponse(completed_features=completed_features)


@router.post("/onboarding-status", summary="Lưu trạng thái hoàn thành hướng dẫn tính năng")
async def update_onboarding_status(
    payload: UpdateOnboardingRequest,
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await user_service.get_current_user(db, token)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ hoặc đã hết hạn.")

    result = await db.execute(
        select(UserFeatureOnboarding).where(
            UserFeatureOnboarding.user_id == user.id,
            UserFeatureOnboarding.feature_key == payload.feature_key,
        )
    )
    existing = result.scalar_one_or_none()
    if existing:
        existing.completed = payload.completed
    else:
        new_record = UserFeatureOnboarding(
            user_id=user.id,
            feature_key=payload.feature_key,
            completed=payload.completed,
        )
        db.add(new_record)

    await db.commit()
    return {"message": "Cập nhật trạng thái hướng dẫn thành công.", "feature_key": payload.feature_key}


@router.post("/onboarding-status/reset", summary="Đặt lại trạng thái hướng dẫn (cho phép xem lại)")
async def reset_onboarding_status(
    feature_key: Optional[str] = None,
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await user_service.get_current_user(db, token)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ hoặc đã hết hạn.")

    if feature_key:
        await db.execute(
            delete(UserFeatureOnboarding).where(
                UserFeatureOnboarding.user_id == user.id,
                UserFeatureOnboarding.feature_key == feature_key,
            )
        )
    else:
        await db.execute(
            delete(UserFeatureOnboarding).where(UserFeatureOnboarding.user_id == user.id)
        )

    await db.commit()
    return {"message": "Đã đặt lại trạng thái hướng dẫn thành công."}
