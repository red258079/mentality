from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Optional, List

from app.db.database import get_db
from app.services.user_service import get_current_user
from app.services.checkin_service import CheckinService

router = APIRouter()


class PerformCheckinRequest(BaseModel):
    mood: str
    stress_factors: Optional[List[str]] = []
    note: Optional[str] = None


async def get_authed_user(authorization: Optional[str] = Header(None), db: AsyncSession = Depends(get_db)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await get_current_user(db, token)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ.")
    return user


@router.get("/today", summary="Kiểm tra trạng thái checkin hôm nay")
async def get_today_status(user=Depends(get_authed_user), db: AsyncSession = Depends(get_db)):
    checkin = await CheckinService.get_today_checkin(db, user.id)
    streak = await CheckinService.get_user_streak(db, user.id)
    return {
        "has_checked_in": checkin is not None,
        "gacha_message": checkin.gacha_message if checkin else None,
        "current_streak": streak.current_streak,
        "longest_streak": streak.longest_streak
    }


@router.post("", summary="Điểm danh cảm xúc & Nhận thông điệp Gacha ngẫu nhiên")
async def perform_checkin(
    payload: PerformCheckinRequest,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    res = await CheckinService.perform_daily_checkin(
        db=db,
        user_id=user.id,
        mood=payload.mood,
        stress_factors=payload.stress_factors,
        note=payload.note
    )

    streak = res["streak"]
    return {
        "already_checked_in": res["already_checked_in"],
        "gacha_message": res["gacha_message"],
        "current_streak": streak.current_streak,
        "longest_streak": streak.longest_streak,
        "checkin_id": str(res["checkin"].id)
    }
