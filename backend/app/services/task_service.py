from typing import List, Dict, Any, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timezone
from uuid import UUID

from app.db.models.task import Task, UserTaskProgress, PillarType
from app.db.models.intern_profile import InternPhase


class TaskService:
    @staticmethod
    async def get_tasks_for_user(
        db: AsyncSession,
        user_id: UUID,
        phase: Optional[InternPhase] = None
    ) -> List[Dict[str, Any]]:
        query = select(Task).where(Task.is_active == True)
        if phase:
            query = query.where(Task.phase == phase)
        query = query.order_by(Task.phase.asc(), Task.sort_order.asc())
        
        result = await db.execute(query)
        tasks = result.scalars().all()

        # Fetch completion status for user
        progress_res = await db.execute(
            select(UserTaskProgress).where(UserTaskProgress.user_id == user_id)
        )
        progress_map = {p.task_id: p.is_completed for p in progress_res.scalars().all()}

        output = []
        for t in tasks:
            output.append({
                "id": str(t.id),
                "phase": t.phase.value if hasattr(t.phase, "value") else str(t.phase),
                "pillar": t.pillar.value if hasattr(t.pillar, "value") else str(t.pillar),
                "title": t.title,
                "description": t.description,
                "duration_minutes": t.duration_minutes,
                "unlock_day": t.unlock_day,
                "sort_order": t.sort_order,
                "is_completed": progress_map.get(t.id, False)
            })

        return output

    @staticmethod
    async def get_tasks_summary(db: AsyncSession, user_id: UUID) -> Dict[str, Any]:
        """Thống kê tổng thể tiến độ hoàn thành theo từng chặng thực tập."""
        result = await db.execute(select(Task).where(Task.is_active == True))
        all_tasks = result.scalars().all()

        progress_res = await db.execute(
            select(UserTaskProgress).where(
                UserTaskProgress.user_id == user_id,
                UserTaskProgress.is_completed == True
            )
        )
        completed_task_ids = {p.task_id for p in progress_res.scalars().all()}

        phase_stats = {
            "preparation": {"total": 0, "completed": 0, "percentage": 0.0},
            "adaptation":  {"total": 0, "completed": 0, "percentage": 0.0},
            "sustain":     {"total": 0, "completed": 0, "percentage": 0.0},
        }

        total_tasks = len(all_tasks)
        total_completed = 0

        for t in all_tasks:
            ph = t.phase.value if hasattr(t.phase, "value") else str(t.phase)
            if ph in phase_stats:
                phase_stats[ph]["total"] += 1
                if t.id in completed_task_ids:
                    phase_stats[ph]["completed"] += 1
                    total_completed += 1

        for ph, data in phase_stats.items():
            if data["total"] > 0:
                data["percentage"] = round((data["completed"] / data["total"]) * 100, 1)

        overall_percentage = round((total_completed / total_tasks * 100), 1) if total_tasks > 0 else 0.0

        return {
            "total_tasks": total_tasks,
            "total_completed": total_completed,
            "overall_percentage": overall_percentage,
            "phases": phase_stats
        }

    @staticmethod
    async def toggle_task_completion(db: AsyncSession, user_id: UUID, task_id: UUID) -> bool:
        result = await db.execute(
            select(UserTaskProgress).where(
                UserTaskProgress.user_id == user_id,
                UserTaskProgress.task_id == task_id
            )
        )
        progress = result.scalar_one_or_none()
        if not progress:
            progress = UserTaskProgress(
                user_id=user_id,
                task_id=task_id,
                is_completed=True,
                completed_at=datetime.now(timezone.utc)
            )
            db.add(progress)
        else:
            progress.is_completed = not progress.is_completed
            progress.completed_at = datetime.now(timezone.utc) if progress.is_completed else None

        await db.commit()
        return progress.is_completed

    @staticmethod
    async def create_task(
        db: AsyncSession,
        phase: InternPhase,
        pillar: PillarType,
        title: str,
        description: str,
        duration_minutes: int = 10,
        unlock_day: int = 0,
        sort_order: int = 0
    ) -> Task:
        task = Task(
            phase=phase,
            pillar=pillar,
            title=title,
            description=description,
            duration_minutes=duration_minutes,
            unlock_day=unlock_day,
            sort_order=sort_order
        )
        db.add(task)
        await db.commit()
        await db.refresh(task)
        return task
