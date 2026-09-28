from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from uuid import UUID

from app.db.database import get_db
from app.services.user_service import get_current_user
from app.services.task_service import TaskService
from app.db.models.intern_profile import InternPhase

router = APIRouter()


async def get_authed_user(authorization: Optional[str] = Header(None), db: AsyncSession = Depends(get_db)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await get_current_user(db, token)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ.")
    return user


@router.get("", summary="Lấy danh sách nhiệm vụ phục hồi theo giai đoạn")
async def get_tasks(
    phase: Optional[str] = "preparation",
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    enum_phase = InternPhase.preparation
    if phase == "adaptation":
        enum_phase = InternPhase.adaptation
    elif phase == "sustain":
        enum_phase = InternPhase.sustain

    tasks = await TaskService.get_tasks_for_user(db, user.id, enum_phase)
    return tasks


@router.post("/{task_id}/toggle", summary="Bật/Tắt trạng thái hoàn tất nhiệm vụ")
async def toggle_task(
    task_id: UUID,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    is_completed = await TaskService.toggle_task_completion(db, user.id, task_id)
    return {"task_id": str(task_id), "is_completed": is_completed}
