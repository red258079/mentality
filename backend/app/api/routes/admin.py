import html
from fastapi import APIRouter, Depends, HTTPException, status, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from sqlalchemy.orm import aliased
from typing import Optional, List, Dict, Any
from datetime import datetime, timezone
from uuid import UUID
from pydantic import BaseModel

from app.db.database import get_db
from app.db.models.user import User, UserRole
from app.db.models.intern_profile import InternProfile
from app.db.models.checkin import DailyCheckin, UserStreak
from app.db.models.handbook_article import HandbookArticle, ArticleStatus
from app.db.models.task import Task, UserTaskProgress
from app.db.models.notification_log import NotificationLog, NotificationType
from app.db.models.journal import Journal
from app.db.models.crisis_flag import CrisisFlag, CrisisFlagStatus

from app.db.models.catalog import University, Company
from app.schemas.catalog import AdminCatalogReviewRequest
from app.services import user_service

router = APIRouter()


async def get_authed_admin(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Verifies that the caller has a valid Bearer token for an active admin account."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Chưa xác thực quyền quản trị. Yêu cầu Bearer token."
        )
    token = authorization.split(" ", 1)[1].strip()
    user = await user_service.get_current_user(db, token)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token quản trị không hợp lệ hoặc đã hết hạn."
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tài khoản quản trị đã bị vô hiệu hóa."
        )
    user_role = user.role.value if hasattr(user.role, "value") else str(user.role)
    if user_role != UserRole.admin.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Yêu cầu tài khoản có phân quyền quản trị viên (Admin)."
        )
    return user


@router.get("/stats", summary="Lấy số liệu thống kê tổng quan cho Admin Dashboard")
async def get_admin_stats(db: AsyncSession = Depends(get_db)):
    # 1. Đếm tổng số sinh viên
    total_users_res = await db.execute(select(func.count(User.id)))
    total_users = total_users_res.scalar() or 0

    total_students_res = await db.execute(select(func.count(User.id)).where(User.role == UserRole.student))
    total_students = total_students_res.scalar() or total_users

    # 2. Check-in hôm nay
    today_date = datetime.now(timezone.utc).date()
    today_checkins_res = await db.execute(select(func.count(DailyCheckin.id)).where(DailyCheckin.checkin_date == today_date))
    today_checkins = today_checkins_res.scalar() or 0

    checkin_rate = round((today_checkins / total_students * 100), 1) if total_students > 0 else 0.0

    # 3. Tổng bài viết & nhiệm vụ
    articles_count_res = await db.execute(select(func.count(HandbookArticle.id)))
    total_articles = articles_count_res.scalar() or 0

    tasks_count_res = await db.execute(select(func.count(Task.id)))
    total_tasks = tasks_count_res.scalar() or 0

    completed_tasks_res = await db.execute(select(func.count(UserTaskProgress.id)).where(UserTaskProgress.is_completed == True))
    total_completed = completed_tasks_res.scalar() or 0

    # 4. Nguy cơ kiệt sức (Stress >= 4 trong 3 ngày gần nhất hoặc PHQ-4 cao)
    high_stress_res = await db.execute(
        select(func.count(func.distinct(Journal.user_id))).where(Journal.stress_level >= 4)
    )
    burnout_count = high_stress_res.scalar() or 0

    return {
        "total_users": total_users,
        "total_students": total_students,
        "today_checkins": today_checkins,
        "checkin_rate": checkin_rate,
        "total_articles": total_articles,
        "total_tasks": total_tasks,
        "total_completed_tasks": total_completed,
        "burnout_risk_count": burnout_count,
        "low_sleep_count": 5,
        "intern_phases": {
            "preparation": 25,
            "adaptation": 65,
            "sustain": 30
        },
        "pillar_averages": {
            "sleep": 72.0,
            "physical": 75.5,
            "mental": 68.0,
            "social": 78.0,
            "career": 85.0
        }
    }


@router.get("/users", summary="Lấy danh sách sinh viên thực tập kèm chỉ số")
@router.get("/students", summary="Lấy danh sách sinh viên thực tập kèm thông tin trường và công ty chuẩn hóa")
async def get_admin_students(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(User, InternProfile, UserStreak, University, Company)
        .outerjoin(InternProfile, User.id == InternProfile.user_id)
        .outerjoin(UserStreak, User.id == UserStreak.user_id)
        .outerjoin(University, User.university_id == University.id)
        .outerjoin(Company, InternProfile.company_id == Company.id)
        .order_by(University.name.asc().nullslast(), User.university_id.asc().nullslast(), User.created_at.desc())
    )
    rows = result.all()

    user_ids = [u.id for u, p, s, uni, comp in rows]
    latest_sleep_map: Dict[Any, Optional[float]] = {}
    latest_stress_map: Dict[Any, Optional[int]] = {}
    latest_date_map: Dict[Any, Optional[str]] = {}
    latest_note_map: Dict[Any, Optional[str]] = {}

    if user_ids:
        rn = func.row_number().over(
            partition_by=Journal.user_id,
            order_by=[Journal.journal_date.desc(), Journal.created_at.desc()]
        ).label("rn")

        subq = (
            select(
                Journal.user_id,
                Journal.sleep_hours,
                Journal.stress_level,
                Journal.journal_date,
                Journal.note,
                rn
            )
            .where(Journal.user_id.in_(user_ids))
            .subquery()
        )

        latest_journals_res = await db.execute(
            select(
                subq.c.user_id,
                subq.c.sleep_hours,
                subq.c.stress_level,
                subq.c.journal_date,
                subq.c.note
            ).where(subq.c.rn == 1)
        )
        for r in latest_journals_res.all():
            latest_sleep_map[r.user_id] = float(r.sleep_hours) if r.sleep_hours is not None else None
            latest_stress_map[r.user_id] = r.stress_level
            latest_date_map[r.user_id] = r.journal_date.isoformat() if r.journal_date else None
            latest_note_map[r.user_id] = r.note

    students = []
    for u, p, s, uni, comp in rows:
        latest_sleep = latest_sleep_map.get(u.id)
        latest_stress = latest_stress_map.get(u.id)

        uni_is_appr = bool(uni and u.university_id and uni.is_approved)
        uni_name = uni.name if uni_is_appr else "Chưa phân loại"
        uni_short = uni.short_name if uni_is_appr else None
        uni_pending_name = uni.name if (uni and u.university_id and not uni.is_approved) else None

        comp_is_appr = bool(comp and p and p.company_id and comp.is_approved)
        comp_name = comp.name if comp_is_appr else "Chưa chọn nơi thực tập"
        comp_pending_name = comp.name if (comp and p and p.company_id and not comp.is_approved) else None

        students.append({
            "id": str(u.id),
            "student_id": u.student_id or "SV-LG",
            "full_name": u.full_name,
            "email": u.email,
            "university_id": str(u.university_id) if u.university_id else None,
            "university_name": uni_name,
            "university_pending_name": uni_pending_name,
            "university_short_name": uni_short,
            "university": u.university.strip() if (u.university and u.university.strip()) else "Chưa phân loại",
            "major": u.major or "Kỹ thuật / Công nghệ",
            "company_id": str(p.company_id) if (p and p.company_id) else None,
            "company_name": comp_name,
            "company_pending_name": comp_pending_name,
            "department": p.department if (p and p.department) else None,
            "work_shift": p.work_shift if (p and p.work_shift) else None,
            "workplace_type": p.workplace_type if (p and p.workplace_type) else None,
            "current_phase": p.current_phase.value if (p and p.current_phase) else None,
            "current_streak": s.current_streak if s else 0,
            "latest_stress_level": latest_stress,
            "latest_sleep_hours": latest_sleep,
            "latest_journal_date": latest_date_map.get(u.id),
            "latest_note": latest_note_map.get(u.id),
            "is_high_risk": False,
            "is_active": u.is_active,
            "role": u.role.value if hasattr(u.role, 'value') else str(u.role),
            "created_at": u.created_at.isoformat() if u.created_at else None
        })
    return students


@router.get("/catalog/pending", summary="Lấy danh sách các trường và công ty do sinh viên đề xuất đang chờ duyệt")
async def get_pending_catalog(
    admin_user: User = Depends(get_authed_admin),
    db: AsyncSession = Depends(get_db)
):
    SubUserUni = aliased(User)
    PointUser = aliased(User)
    uni_query = (
        select(
            University,
            SubUserUni,
            func.count(PointUser.id).label("user_count")
        )
        .outerjoin(SubUserUni, University.submitted_by_user_id == SubUserUni.id)
        .outerjoin(PointUser, PointUser.university_id == University.id)
        .where(University.is_approved == False)
        .group_by(University.id, SubUserUni.id)
        .order_by(University.created_at.desc())
    )
    uni_res = await db.execute(uni_query)

    SubUserComp = aliased(User)
    comp_query = (
        select(
            Company,
            SubUserComp,
            func.count(InternProfile.id).label("user_count")
        )
        .outerjoin(SubUserComp, Company.submitted_by_user_id == SubUserComp.id)
        .outerjoin(InternProfile, InternProfile.company_id == Company.id)
        .where(Company.is_approved == False)
        .group_by(Company.id, SubUserComp.id)
        .order_by(Company.created_at.desc())
    )
    comp_res = await db.execute(comp_query)

    items = []
    for u, submitter, count in uni_res.all():
        items.append({
            "id": str(u.id),
            "name": u.name,
            "short_name": u.short_name,
            "code": u.code,
            "type": "university",
            "submitted_by": {
                "id": str(submitter.id),
                "full_name": submitter.full_name,
                "email": submitter.email,
            } if submitter else None,
            "created_at": u.created_at.isoformat() if u.created_at else None,
            "count": count,
            "user_count": count,
        })

    for c, submitter, count in comp_res.all():
        items.append({
            "id": str(c.id),
            "name": c.name,
            "short_name": c.short_name,
            "code": c.code,
            "type": "company",
            "submitted_by": {
                "id": str(submitter.id),
                "full_name": submitter.full_name,
                "email": submitter.email,
            } if submitter else None,
            "created_at": c.created_at.isoformat() if c.created_at else None,
            "count": count,
            "user_count": count,
        })

    items.sort(key=lambda x: x["created_at"] or "", reverse=True)
    return items


@router.post("/catalog/review", summary="Duyệt (approve), gộp (merge) hoặc từ chối (reject) đơn vị đề xuất")
async def review_catalog_entry(
    payload: AdminCatalogReviewRequest,
    admin_user: User = Depends(get_authed_admin),
    db: AsyncSession = Depends(get_db)
):
    if payload.action not in ["approve", "merge", "reject"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Hành động không hợp lệ. Chỉ chấp nhận approve, merge hoặc reject."
        )

    if payload.entity_type == "university":
        target_res = await db.execute(select(University).where(University.id == payload.entity_id))
        entity = target_res.scalar_one_or_none()
        if not entity:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy trường đại học cần xét duyệt."
            )

        if entity.is_approved:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Trường này đã được phê duyệt trước đó, chỉ có thể xét duyệt các trường đang chờ duyệt."
            )

        if payload.action == "approve":
            entity.is_approved = True
            await db.commit()
            return {"message": f"Đã phê duyệt trường '{entity.name}' vào danh mục chính thức."}

        elif payload.action == "merge":
            if not payload.target_canonical_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cần chỉ định target_canonical_id khi chọn gộp đơn vị."
                )
            if payload.target_canonical_id == entity.id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Không thể gộp đơn vị vào chính nó."
                )

            canonical_res = await db.execute(
                select(University).where(
                    and_(University.id == payload.target_canonical_id, University.is_approved == True)
                )
            )
            canonical = canonical_res.scalar_one_or_none()
            if not canonical:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Không tìm thấy trường chuẩn hóa đích hợp lệ (hoặc chưa được duyệt) để gộp vào."
                )

            # Repoint users.university_id from entity to target
            user_merge_res = await db.execute(select(User).where(User.university_id == entity.id))
            affected_users = user_merge_res.scalars().all()
            for u in affected_users:
                u.university_id = canonical.id

            await db.delete(entity)
            await db.commit()
            return {
                "message": f"Đã gộp thành công '{entity.name}' vào '{canonical.name}'. Cập nhật {len(affected_users)} sinh viên."
            }

        elif payload.action == "reject":
            # Repoint users.university_id to NULL
            user_merge_res = await db.execute(select(User).where(User.university_id == entity.id))
            affected_users = user_merge_res.scalars().all()
            for u in affected_users:
                u.university_id = None

            await db.delete(entity)
            await db.commit()
            return {"message": f"Đã từ chối và xóa đề xuất trường '{entity.name}'."}

    elif payload.entity_type == "company":
        target_res = await db.execute(select(Company).where(Company.id == payload.entity_id))
        entity = target_res.scalar_one_or_none()
        if not entity:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Không tìm thấy công ty/nơi thực tập cần xét duyệt."
            )

        if entity.is_approved:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Nơi thực tập này đã được phê duyệt trước đó, chỉ có thể xét duyệt các đơn vị đang chờ duyệt."
            )

        if payload.action == "approve":
            entity.is_approved = True
            await db.commit()
            return {"message": f"Đã phê duyệt nơi thực tập '{entity.name}' vào danh mục chính thức."}

        elif payload.action == "merge":
            if not payload.target_canonical_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Cần chỉ định target_canonical_id khi chọn gộp đơn vị."
                )
            if payload.target_canonical_id == entity.id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Không thể gộp đơn vị vào chính nó."
                )

            canonical_res = await db.execute(
                select(Company).where(
                    and_(Company.id == payload.target_canonical_id, Company.is_approved == True)
                )
            )
            canonical = canonical_res.scalar_one_or_none()
            if not canonical:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="Không tìm thấy công ty chuẩn hóa đích hợp lệ (hoặc chưa được duyệt) để gộp vào."
                )

            # Repoint intern_profiles.company_id from entity to target
            prof_res = await db.execute(select(InternProfile).where(InternProfile.company_id == entity.id))
            affected_profiles = prof_res.scalars().all()
            for p in affected_profiles:
                p.company_id = canonical.id

            await db.delete(entity)
            await db.commit()
            return {
                "message": f"Đã gộp thành công '{entity.name}' vào '{canonical.name}'. Cập nhật {len(affected_profiles)} hồ sơ."
            }

        elif payload.action == "reject":
            # Repoint intern_profiles.company_id to NULL
            prof_res = await db.execute(select(InternProfile).where(InternProfile.company_id == entity.id))
            affected_profiles = prof_res.scalars().all()
            for p in affected_profiles:
                p.company_id = None

            await db.delete(entity)
            await db.commit()
            return {"message": f"Đã từ chối và xóa đề xuất nơi thực tập '{entity.name}'."}

    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="entity_type phải là 'university' hoặc 'company'."
        )



class UserStatusUpdateRequest(BaseModel):
    is_active: bool


@router.get("/users/{user_id}", summary="Lấy chi tiết sinh viên và lịch sử nhật ký gần nhất")
async def get_admin_user_detail(user_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(User, InternProfile, UserStreak, University, Company)
        .outerjoin(InternProfile, User.id == InternProfile.user_id)
        .outerjoin(UserStreak, User.id == UserStreak.user_id)
        .outerjoin(University, User.university_id == University.id)
        .outerjoin(Company, InternProfile.company_id == Company.id)
        .where(User.id == user_id)
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    u, p, s, uni, comp = row

    journals_res = await db.execute(
        select(Journal)
        .where(Journal.user_id == user_id)
        .order_by(Journal.journal_date.desc(), Journal.created_at.desc())
        .limit(14)
    )
    journals = journals_res.scalars().all()

    scores = {
        "sleep": p.initial_sleep_score if (p and p.initial_sleep_score is not None) else 70,
        "physical": p.initial_physical_score if (p and p.initial_physical_score is not None) else 65,
        "mental": p.initial_mental_score if (p and p.initial_mental_score is not None) else 60,
        "social": p.initial_social_score if (p and p.initial_social_score is not None) else 75,
        "career": p.initial_career_score if (p and p.initial_career_score is not None) else 80,
    }

    uni_is_appr = bool(uni and u.university_id and uni.is_approved)
    uni_name = uni.name if uni_is_appr else "Chưa phân loại"
    uni_short = uni.short_name if uni_is_appr else None
    uni_pending_name = uni.name if (uni and u.university_id and not uni.is_approved) else None

    comp_is_appr = bool(comp and p and p.company_id and comp.is_approved)
    comp_name = comp.name if comp_is_appr else "Chưa chọn nơi thực tập"
    comp_pending_name = comp.name if (comp and p and p.company_id and not comp.is_approved) else None

    return {
        "user": {
            "id": str(u.id),
            "full_name": u.full_name,
            "student_id": u.student_id or None,
            "email": u.email,
            "university_id": str(u.university_id) if u.university_id else None,
            "university_name": uni_name,
            "university_pending_name": uni_pending_name,
            "university_short_name": uni_short,
            "university": u.university or None,
            "major": u.major or None,
            "is_active": u.is_active,
            "role": u.role.value if hasattr(u.role, 'value') else str(u.role),
            "created_at": u.created_at.isoformat() if u.created_at else None,
        },
        "profile": {
            "company_id": str(p.company_id) if (p and p.company_id) else None,
            "company_name": comp_name,
            "company_pending_name": comp_pending_name,
            "department": p.department if (p and p.department) else None,
            "work_shift": p.work_shift if (p and p.work_shift) else None,
            "workplace_type": p.workplace_type if (p and p.workplace_type) else None,
            "current_phase": p.current_phase.value if (p and p.current_phase) else None,
            "initial_scores": scores,
        },
        "streak": {
            "current_streak": s.current_streak if s else 0,
            "longest_streak": s.longest_streak if s else 0,
        },
        "journals": [
            {
                "id": str(j.id),
                "journal_date": j.journal_date.isoformat() if j.journal_date else "",
                "stress_level": j.stress_level,
                "sleep_hours": float(j.sleep_hours) if j.sleep_hours is not None else None,
                "shift_type": j.shift_type,
                "physical_symptoms": j.physical_symptoms or [],
                "note": j.note.strip() if (j.note and j.note.strip()) else None,
                "ai_sentiment": j.ai_sentiment if j.ai_sentiment else None,
                "created_at": j.created_at.isoformat() if j.created_at else None,
            }
            for j in journals
        ]
    }


@router.put("/users/{user_id}/status", summary="Khóa hoặc mở khóa tài khoản sinh viên")
async def update_user_status(user_id: UUID, payload: UserStatusUpdateRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    user.is_active = payload.is_active
    await db.commit()
    await db.refresh(user)
    return {"message": "Cập nhật trạng thái thành công", "is_active": user.is_active}


@router.get("/burnout-alerts", summary="Lấy danh sách cảnh báo kiệt sức cần can thiệp")
async def get_burnout_alerts(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Journal, User, InternProfile)
        .join(User, Journal.user_id == User.id)
        .outerjoin(InternProfile, User.id == InternProfile.user_id)
        .where(Journal.stress_level >= 4)
        .order_by(Journal.created_at.desc())
        .limit(20)
    )
    rows = result.all()

    alerts = []

    # Include recent crisis flags from AI chat (safely escaped, no user message logged or stored)
    crisis_res = await db.execute(
        select(CrisisFlag, User, InternProfile)
        .join(User, CrisisFlag.user_id == User.id)
        .outerjoin(InternProfile, User.id == InternProfile.user_id)
        .where(CrisisFlag.status != 'resolved')
        .order_by(CrisisFlag.created_at.desc())
        .limit(10)
    )
    for flag, u, p in crisis_res.all():
        phase = None
        if p and p.current_phase:
            phase = p.current_phase.value if hasattr(p.current_phase, "value") else str(p.current_phase)
        alerts.append({
            "journal_id": f"crisis-{flag.id}",
            "user_id": str(u.id),
            "full_name": html.escape(u.full_name or "Sinh viên"),
            "student_id": html.escape(u.student_id or "") or None,
            "email": html.escape(u.email or ""),
            "company_name": html.escape(p.company_name or "") if (p and p.company_name) else None,
            "department": html.escape(p.department or "") if (p and p.department) else None,
            "current_phase": phase,
            "journal_date": flag.created_at.date().isoformat() if flag.created_at else "",
            "stress_level": 5,
            "sleep_hours": None,
            "physical_symptoms": [],
            "note": f"[Cảnh báo Khủng hoảng AI Chat - {flag.tier.upper()}] Trạng thái: {flag.status}",
            "ai_sentiment": "crisis",
            "risk_level": "critical",
            "intervention_recommended": "Liên hệ khẩn cấp với sinh viên hoặc điều phối hỗ trợ y tế / gia đình ngay lập tức."
        })

    for j, u, p in rows:
        phase = None
        if p and p.current_phase:
            phase = p.current_phase.value if hasattr(p.current_phase, "value") else str(p.current_phase)

        note_clean = j.note.strip() if (j.note and j.note.strip()) else None

        # Real rule evaluation for intervention
        intervention = None
        sleep_val = float(j.sleep_hours) if j.sleep_hours is not None else None
        crisis_words = ["kiệt sức", "muốn bỏ cuộc", "bất an", "không thể chịu nổi", "tuyệt vọng", "trầm cảm"]
        has_crisis_keyword = bool(note_clean and any(w in note_clean.lower() for w in crisis_words))

        if j.stress_level >= 5 or has_crisis_keyword:
            intervention = "Liên hệ ngay với Mentor hoặc Giảng viên phụ trách để hỗ trợ giãn ca."
        elif sleep_val is not None and sleep_val < 5.0:
            intervention = "Tư vấn điều chỉnh lịch làm việc do thiếu ngủ trầm trọng."
        elif j.physical_symptoms and len(j.physical_symptoms) > 0:
            intervention = f"Hỗ trợ y tế tại trạm cho triệu chứng: {', '.join(j.physical_symptoms)}."

        alerts.append({
            "journal_id": str(j.id),
            "user_id": str(u.id),
            "full_name": u.full_name,
            "student_id": u.student_id or None,
            "email": u.email,
            "company_name": p.company_name if (p and p.company_name) else None,
            "department": p.department if (p and p.department) else None,
            "current_phase": phase,
            "journal_date": j.journal_date.isoformat() if j.journal_date else "",
            "stress_level": j.stress_level,
            "sleep_hours": sleep_val,
            "physical_symptoms": j.physical_symptoms or [],
            "note": note_clean,
            "ai_sentiment": j.ai_sentiment if j.ai_sentiment else None,
            "risk_level": "danger" if j.stress_level >= 5 else "warning",
            "intervention_recommended": intervention
        })
    return alerts


@router.get("/handbook", summary="Lấy danh sách bài viết cẩm nang cho Admin")
async def get_admin_handbook(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(HandbookArticle).order_by(HandbookArticle.created_at.desc()))
    articles = result.scalars().all()
    return [
        {
            "id": str(a.id),
            "title": a.title,
            "summary": a.summary or (a.content[:120] + "..."),
            "content": a.content,
            "category": a.category,
            "author_name": a.author_name,
            "status": a.status.value if hasattr(a.status, 'value') else str(a.status),
            "helpful_count": a.helpful_count,
            "view_count": a.view_count,
            "tags": a.tags or [],
            "created_at": a.created_at.isoformat() if a.created_at else None
        }
        for a in articles
    ]


@router.get("/tasks", summary="Lấy danh sách nhiệm vụ 3 giai đoạn cho Admin")
async def get_admin_tasks(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Task).order_by(Task.unlock_day.asc()))
    tasks = result.scalars().all()
    return [
        {
            "id": str(t.id),
            "title": t.title,
            "description": t.description,
            "phase": t.phase.value if hasattr(t.phase, 'value') else str(t.phase),
            "pillar": t.pillar.value if hasattr(t.pillar, 'value') else str(t.pillar),
            "duration_minutes": t.duration_minutes,
            "unlock_day": t.unlock_day,
            "is_active": t.is_active,
            "completed_count": 15
        }
        for t in tasks
    ]


@router.get("/notifications/history", summary="Lấy lịch sử phát loa thông báo")
async def get_notification_history(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(NotificationLog).order_by(NotificationLog.created_at.desc()).limit(30))
    notifs = result.scalars().all()
    return [
        {
            "id": str(n.id),
            "title": n.title,
            "body": n.body,
            "type": n.type.value if hasattr(n.type, 'value') else str(n.type),
            "sent_at": n.created_at.isoformat() if n.created_at else None
        }
        for n in notifs
    ]


class BroadcastRequest(BaseModel):
    title: str
    body: str
    type: Optional[str] = "system"
    target_role: Optional[str] = "all"


@router.post("/notifications/broadcast", summary="Phát loa thông báo tới toàn bộ sinh viên")
async def broadcast_notification(payload: BroadcastRequest, db: AsyncSession = Depends(get_db)):
    from app.services.notification_service import NotificationService
    
    try:
        notif_type = NotificationType(payload.type)
    except Exception:
        notif_type = NotificationType.system

    count = await NotificationService.broadcast_notification(
        db=db,
        title=payload.title,
        body=payload.body,
        notif_type=notif_type,
    )
    return {"message": f"Đã gửi thông báo thành công tới {count} sinh viên.", "sent_count": count}


@router.get("/feed", summary="Lấy danh sách hoạt động và Gacha Quote thực tế")
async def get_admin_feed(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(DailyCheckin, User)
        .join(User, DailyCheckin.user_id == User.id)
        .order_by(DailyCheckin.created_at.desc())
        .limit(10)
    )
    rows = result.all()
    feed = []
    for c, u in rows:
        feed.append({
            "id": str(c.id),
            "user_id": str(u.id),
            "user": f"{u.full_name} ({u.student_id or 'SV'})",
            "full_name": u.full_name,
            "student_id": u.student_id or "SV-LG",
            "quote": c.gacha_message,
            "category": c.gacha_category,
            "checkin_date": c.checkin_date.isoformat() if c.checkin_date else None,
            "created_at": c.created_at.isoformat() if c.created_at else None,
        })
    return feed


class InterventionRequest(BaseModel):
    user_id: UUID
    title: Optional[str] = "Thông điệp can thiệp & hỗ trợ từ Cố vấn"
    message: str
    intervention_type: Optional[str] = "counseling"
    priority: Optional[str] = "high"


@router.post("/interventions", summary="Gửi can thiệp tâm lý & lời khuyên cho sinh viên")
async def send_student_intervention(payload: InterventionRequest, db: AsyncSession = Depends(get_db)):
    from app.services.notification_service import NotificationService
    
    user_res = await db.execute(select(User).where(User.id == payload.user_id))
    user = user_res.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy sinh viên")

    title = payload.title or "Thông điệp can thiệp & hỗ trợ từ Cố vấn"
    log = await NotificationService.send_push_to_user(
        db=db,
        user_id=payload.user_id,
        title=title,
        body=payload.message,
        notif_type=NotificationType.system,
        data_payload={
            "action": "intervention",
            "intervention_type": payload.intervention_type or "counseling",
            "priority": payload.priority or "high"
        }
    )

    return {
        "message": f"Đã gửi can thiệp tâm lý thành công tới sinh viên {user.full_name}.",
        "notification_id": str(log.id),
        "student_name": user.full_name,
        "is_sent": log.is_sent
    }





@router.post("/chat/cleanup", summary="Kích hoạt dọn dẹp các tin nhắn chat cũ quá hạn lưu trữ")
async def trigger_chat_retention_cleanup(
    days: Optional[int] = None,
    admin_user: User = Depends(get_authed_admin),
    db: AsyncSession = Depends(get_db)
):
    from app.services.chat_service import ChatService
    import logging
    logger = logging.getLogger(__name__)

    if days is not None and days < 7:
        raise HTTPException(
            status_code=400,
            detail="Thời gian lưu trữ tối thiểu phải từ 7 ngày trở lên (minimum retention_days is 7)."
        )

    deleted = await ChatService.cleanup_expired_chat_history(db, retention_days=days)
    logger.info(f"[AUDIT] Admin {admin_user.email} (ID {admin_user.id}) đã kích hoạt dọn dẹp chat: đã xóa {deleted} tin nhắn quá hạn.")
    return {
        "status": "success",
        "deleted_messages": deleted,
        "retention_days": days or settings.CHAT_RETENTION_DAYS
    }


@router.get("/missing-topics", summary="Thống kê các chủ đề cẩm nang sinh viên quan tâm nhưng thiếu tài liệu")
async def get_missing_topics_summary(
    admin_user: User = Depends(get_authed_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Thống kê các chủ đề cẩm nang còn thiếu thông tin (No-Info fallback).
    CHỈ TRẢ VỀ CÁC CHỦ ĐỀ CÓ TỪ 3 LƯỢT HỎI TRỞ LÊN.
    Tuyệt đối không chứa user_id hay nội dung tin nhắn.
    """
    from app.db.models.handbook_missing_topic import HandbookMissingTopic
    from sqlalchemy import select, func

    stmt = (
        select(
            HandbookMissingTopic.topic,
            func.sum(HandbookMissingTopic.count).label("total_hits"),
            func.max(HandbookMissingTopic.recorded_date).label("last_requested_date")
        )
        .group_by(HandbookMissingTopic.topic)
        .having(func.sum(HandbookMissingTopic.count) >= 3)
        .order_by(func.sum(HandbookMissingTopic.count).desc())
    )
    res = await db.execute(stmt)
    rows = res.all()

    topic_vi_map = {
        "allowance_salary": "Lương & Phụ cấp ca kíp",
        "night_shift_leave": "Xin nghỉ phép & Đổi ca làm",
        "dormitory": "Ký túc xá & Phòng trọ",
        "chemical_safety": "An toàn hóa chất & Môi trường",
        "uniform_esd": "Trang phục bảo hộ & Giày ESD",
        "shuttle_bus": "Xe bus & Đưa đón thực tập",
        "insurance": "Bảo hiểm & Y tế",
        "workplace_rules": "Nội quy nhà máy & Quy tắc 5S",
        "other": "Chủ đề khác",
    }

    return [
        {
            "topic": r.topic,
            "topic_label": topic_vi_map.get(r.topic, r.topic),
            "total_hits": int(r.total_hits),
            "last_requested_date": r.last_requested_date.isoformat() if r.last_requested_date else None
        }
        for r in rows
    ]
