from typing import List, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.models.task import Task, UserTaskProgress
from app.db.models.intern_profile import InternPhase


class TaskService:
    @staticmethod
    async def get_tasks_for_user(db: AsyncSession, user_id, phase: InternPhase = InternPhase.preparation) -> List[Dict[str, Any]]:
        # Fetch tasks for current phase
        result = await db.execute(
            select(Task).where(Task.phase == phase, Task.is_active == True).order_by(Task.sort_order.asc())
        )
        tasks = result.scalars().all()

        # Fetch completion status
        progress_res = await db.execute(
            select(UserTaskProgress).where(UserTaskProgress.user_id == user_id)
        )
        progress_map = {p.task_id: p.is_completed for p in progress_res.scalars().all()}

        output = []
        for t in tasks:
            output.append({
                "id": str(t.id),
                "phase": t.phase,
                "pillar": t.pillar,
                "title": t.title,
                "description": t.description,
                "duration_minutes": t.duration_minutes,
                "unlock_day": t.unlock_day,
                "is_completed": progress_map.get(t.id, False)
            })

        return output

    @staticmethod
    async def toggle_task_completion(db: AsyncSession, user_id, task_id) -> bool:
        result = await db.execute(
            select(UserTaskProgress).where(
                UserTaskProgress.user_id == user_id,
                UserTaskProgress.task_id == task_id
            )
        )
        progress = result.scalar_one_or_none()
        if not progress:
            progress = UserTaskProgress(user_id=user_id, task_id=task_id, is_completed=True)
            db.add(progress)
        else:
            progress.is_completed = not progress.is_completed

        await db.commit()
        return progress.is_completed
