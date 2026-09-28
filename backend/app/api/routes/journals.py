from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from typing import Optional, List

from app.db.database import get_db
from app.services.user_service import get_current_user
from app.services.journal_service import JournalService

router = APIRouter()


class CreateJournalRequest(BaseModel):
    stress_level: int = Field(..., ge=1, le=5)
    sleep_hours: float = Field(..., ge=0.0, le=24.0)
    physical_symptoms: Optional[List[str]] = []
    note: Optional[str] = None


async def get_authed_user(authorization: Optional[str] = Header(None), db: AsyncSession = Depends(get_db)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await get_current_user(db, token)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ.")
    return user


@router.post("", summary="Tạo bản ghi nhật ký cảm xúc & AI phân tích rủi ro")
async def create_journal(
    payload: CreateJournalRequest,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    res = await JournalService.create_journal_entry(
        db=db,
        user_id=user.id,
        stress_level=payload.stress_level,
        sleep_hours=payload.sleep_hours,
        physical_symptoms=payload.physical_symptoms,
        note=payload.note
    )
    j = res["journal"]
    return {
        "id": str(j.id),
        "journal_date": j.journal_date,
        "stress_level": j.stress_level,
        "sleep_hours": float(j.sleep_hours),
        "physical_symptoms": j.physical_symptoms,
        "note": j.note,
        "ai_sentiment": j.ai_sentiment,
        "ai_keywords": j.ai_keywords,
        "risk_assessment": res["risk_assessment"]
    }


@router.get("/history", summary="Lấy lịch sử nhật ký tâm lý")
async def get_journal_history(
    limit: int = 14,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    history = await JournalService.get_journal_history(db, user.id, limit=limit)
    return [
        {
            "id": str(j.id),
            "journal_date": j.journal_date,
            "stress_level": j.stress_level,
            "sleep_hours": float(j.sleep_hours),
            "physical_symptoms": j.physical_symptoms,
            "note": j.note,
            "ai_sentiment": j.ai_sentiment,
            "created_at": j.created_at
        }
        for j in history
    ]
