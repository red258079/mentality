from fastapi import APIRouter, Depends, HTTPException, status, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from typing import Optional, List
from uuid import UUID

from app.db.database import get_db
from app.services.user_service import get_current_user
from app.services.task_service import TaskService
from app.db.models.intern_profile import InternPhase
from app.db.models.task import PillarType

router = APIRouter()


class CreateTaskRequest(BaseModel):
    phase: str = Field(..., description="Chặng: preparation, adaptation, sustain")
    pillar: str = Field(..., description="Trụ cột: sleep, physical, mental, social, career")
    title: str = Field(..., min_length=3, max_length=500, description="Tên nhiệm vụ")
    description: str = Field(..., min_length=5, description="Hướng dẫn chi tiết")
    duration_minutes: Optional[int] = Field(10, ge=0, description="Thời gian thực hiện (phút)")
    unlock_day: Optional[int] = Field(0, ge=0, description="Mở khóa ở ngày thứ bao nhiêu")
    sort_order: Optional[int] = Field(0, description="Thứ tự hiển thị")


async def get_authed_user(authorization: Optional[str] = Header(None), db: AsyncSession = Depends(get_db)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await get_current_user(db, token)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ.")
    return user


@router.get("", summary="Lấy danh sách nhiệm vụ theo chặng thực tập (hoặc tất cả)")
async def get_tasks(
    phase: Optional[str] = Query(None, description="preparation, adaptation, sustain hoặc để trống để lấy tất cả"),
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    enum_phase = None
    if phase:
        if phase == "preparation":
            enum_phase = InternPhase.preparation
        elif phase == "adaptation":
            enum_phase = InternPhase.adaptation
        elif phase == "sustain":
            enum_phase = InternPhase.sustain

    tasks = await TaskService.get_tasks_for_user(db, user.id, enum_phase)
    return tasks


@router.get("/summary", summary="Thống kê tổng quan tiến độ hoàn thành các chặng")
async def get_tasks_summary(
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    return await TaskService.get_tasks_summary(db, user.id)


@router.post("/{task_id}/toggle", summary="Bật/Tắt trạng thái hoàn tất nhiệm vụ")
async def toggle_task(
    task_id: UUID,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    is_completed = await TaskService.toggle_task_completion(db, user.id, task_id)
    return {
        "task_id": str(task_id),
        "is_completed": is_completed,
        "message": "Đã cập nhật trạng thái nhiệm vụ thành công"
    }


@router.post("", summary="Tạo nhiệm vụ mới")
async def create_task(
    payload: CreateTaskRequest,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    try:
        enum_phase = InternPhase(payload.phase)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Chặng '{payload.phase}' không hợp lệ.")

    try:
        enum_pillar = PillarType(payload.pillar)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Trụ cột '{payload.pillar}' không hợp lệ.")

    task = await TaskService.create_task(
        db=db,
        phase=enum_phase,
        pillar=enum_pillar,
        title=payload.title,
        description=payload.description,
        duration_minutes=payload.duration_minutes or 10,
        unlock_day=payload.unlock_day or 0,
        sort_order=payload.sort_order or 0
    )
    return {
        "id": str(task.id),
        "title": task.title,
        "phase": task.phase.value,
        "pillar": task.pillar.value,
        "message": "Đã tạo nhiệm vụ thành công"
    }
