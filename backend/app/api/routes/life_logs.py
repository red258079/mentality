"""
Life Log API Routes — Nhật ký Sinh hoạt, Giờ ngủ, Trạng thái Căng thẳng
=========================================================================
Endpoints:
  POST   /life-logs                  - Ghi nhận nhật ký sinh hoạt hàng ngày
  GET    /life-logs/history          - Lịch sử nhật ký (14 ngày)
  GET    /life-logs/analytics        - Phân tích xu hướng 7/14/30 ngày
  GET    /life-logs/dashboard        - Dashboard tổng quan cho màn hình Home
  GET    /life-logs/today            - Nhật ký hôm nay
"""
from fastapi import APIRouter, Depends, HTTPException, status, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from typing import Optional, List

from app.db.database import get_db
from app.services.user_service import get_current_user
from app.services.life_log_service import LifeLogService

router = APIRouter()


# ─── Request / Response Models ────────────────────────────────────────────────

class CreateLifeLogRequest(BaseModel):
    stress_level: int = Field(..., ge=1, le=5, description="Mức độ căng thẳng 1-5")
    sleep_hours: float = Field(..., ge=0.0, le=24.0, description="Số giờ ngủ")
    shift_type: Optional[str] = Field(None, description="Loại ca: 'day' hoặc 'night'")
    physical_symptoms: Optional[List[str]] = Field(default=[], description="Danh sách triệu chứng thể chất")
    mood_note: Optional[str] = Field(None, max_length=1000, description="Ghi chú tâm trạng (tối đa 1000 ký tự)")
    activities_done: Optional[List[str]] = Field(default=[], description="Hoạt động đã làm trong ca")
    water_intake_ml: Optional[int] = Field(None, ge=0, le=5000, description="Lượng nước uống (ml)")


# ─── Auth Dependency ──────────────────────────────────────────────────────────

async def get_authed_user(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db)
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await get_current_user(db, token)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ.")
    return user


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.post("", summary="Ghi nhận nhật ký sinh hoạt hôm nay (stress, ngủ, triệu chứng)")
async def create_life_log(
    payload: CreateLifeLogRequest,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Tạo bản ghi nhật ký sinh hoạt cho ngày hôm nay.
    AI Agent tự động đánh giá rủi ro tâm lý và trả về kết quả ngay lập tức.
    Nếu cần thêm dữ liệu (needs_function_calling=true), client có thể gọi endpoint
    /chat để AI Agent thu thập thêm thông tin qua Function Calling.
    """
    result = await LifeLogService.create_life_log(
        db=db,
        user_id=user.id,
        stress_level=payload.stress_level,
        sleep_hours=payload.sleep_hours,
        shift_type=payload.shift_type,
        physical_symptoms=payload.physical_symptoms or [],
        mood_note=payload.mood_note,
        activities_done=payload.activities_done or [],
        water_intake_ml=payload.water_intake_ml
    )

    j = result["journal"]
    return {
        "id": str(j.id),
        "date": str(j.journal_date),
        "stress_level": j.stress_level,
        "stress_description": result["stress_description"],
        "sleep_hours": float(j.sleep_hours),
        "sleep_quality": result["sleep_quality"],
        "physical_symptoms": j.physical_symptoms or [],
        "mood_note": j.note,
        "ai_sentiment": j.ai_sentiment,
        "ai_keywords": j.ai_keywords or [],
        "wellbeing_score": result["wellbeing_score"],
        "risk_assessment": result["risk_assessment"],
        "needs_function_calling": result["needs_function_calling"],
        "function_calling_reason": result["function_calling_reason"]
    }


@router.get("/today", summary="Lấy nhật ký sinh hoạt hôm nay")
async def get_today_life_log(
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    """Trả về nhật ký sinh hoạt của ngày hôm nay nếu đã có."""
    history = await LifeLogService.get_life_log_history(db, user.id, days=1)
    if not history:
        return {"has_log_today": False, "data": None}
    return {"has_log_today": True, "data": history[0]}


@router.get("/history", summary="Lịch sử nhật ký sinh hoạt")
async def get_life_log_history(
    days: int = Query(default=14, ge=1, le=90, description="Số ngày lịch sử (1-90)"),
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    """Trả về lịch sử nhật ký sinh hoạt theo số ngày yêu cầu."""
    history = await LifeLogService.get_life_log_history(db, user.id, days=days)
    return {
        "total_entries": len(history),
        "period_days": days,
        "entries": history
    }


@router.get("/analytics", summary="Phân tích xu hướng sinh hoạt (stress, ngủ, wellbeing)")
async def get_life_log_analytics(
    days: int = Query(default=7, ge=3, le=30, description="Số ngày phân tích (3-30)"),
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Phân tích xu hướng sức khỏe theo khoảng thời gian.
    Trả về: avg_stress, avg_sleep, stress_trend, sleep_trend, wellbeing_score chart,
    sentiment_distribution, common_symptoms, và overall_risk_level từ AI Agent.
    """
    analytics = await LifeLogService.get_life_log_analytics(db, user.id, days=days)
    return analytics


@router.get("/dashboard", summary="Dashboard tổng quan sức khỏe sinh viên")
async def get_dashboard_summary(
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Endpoint dashboard tích hợp: checkin streak + today's summary + 7-day analytics.
    Được gọi mỗi khi màn hình Home Flutter khởi động.
    """
    summary = await LifeLogService.get_dashboard_summary(db, user.id)
    return summary
