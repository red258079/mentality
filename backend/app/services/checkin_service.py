import random
from datetime import date, timedelta
from typing import Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.models.checkin import DailyCheckin, UserStreak


GACHA_MESSAGES = [
    {
        "category": "motivation",
        "message": "🌟 Mỗi ngày thực tập là một bước tiến nhỏ hướng tới mục tiêu sự nghiệp của bạn. Cố lên nhé!"
    },
    {
        "category": "sleep_recovery",
        "message": "🌙 Giấc ngủ chất lượng hôm nay là năng lượng cho ca làm ngày mai. Hãy tắt điện thoại 30p trước khi ngủ!"
    },
    {
        "category": "physical_stretch",
        "message": " Uống đủ 2L nước và tranh thủ 3 phút giãn cơ cổ vai gáy giữa ca làm bạn nhé!"
    },
    {
        "category": "social_connect",
        "message": "🤝 Đừng ngại ngần trao đổi với Anh/Chị Leader khi gặp vướng mắc. Mọi người luôn sẵn sàng hỗ trợ bạn."
    },
    {
        "category": "mental_peace",
        "message": "🧘 Hãy dành 3 phút hít thở sâu Box Breathing 4-4-4-4 để cân bằng cảm xúc sau ca đứng dài."
    }
]


class CheckinService:
    @staticmethod
    async def get_today_checkin(db: AsyncSession, user_id) -> Optional[DailyCheckin]:
        today = date.today()
        result = await db.execute(
            select(DailyCheckin).where(
                DailyCheckin.user_id == user_id,
                DailyCheckin.checkin_date == today
            )
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def perform_daily_checkin(
        db: AsyncSession,
        user_id,
        mood: str,
        stress_factors: Optional[list] = None,
        note: Optional[str] = None
    ) -> Dict[str, Any]:
        today = date.today()

        # Check if already checked in today
        existing = await CheckinService.get_today_checkin(db, user_id)
        if existing:
            streak = await CheckinService.get_user_streak(db, user_id)
            return {
                "checkin": existing,
                "streak": streak,
                "gacha_message": existing.gacha_message,
                "already_checked_in": True
            }

        # Select random gacha message
        gacha = random.choice(GACHA_MESSAGES)
        checkin = DailyCheckin(
            user_id=user_id,
            checkin_date=today,
            gacha_message=gacha["message"],
            gacha_category=gacha["category"]
        )
        db.add(checkin)

        # Update streak
        streak = await CheckinService._update_streak(db, user_id, today)

        await db.commit()
        await db.refresh(checkin)

        return {
            "checkin": checkin,
            "streak": streak,
            "gacha_message": gacha["message"],
            "already_checked_in": False
        }

    @staticmethod
    async def get_user_streak(db: AsyncSession, user_id) -> UserStreak:
        result = await db.execute(
            select(UserStreak).where(UserStreak.user_id == user_id)
        )
        streak = result.scalar_one_or_none()
        if not streak:
            streak = UserStreak(user_id=user_id, current_streak=0, longest_streak=0)
            db.add(streak)
            await db.commit()
            await db.refresh(streak)
        return streak

    @staticmethod
    async def _update_streak(db: AsyncSession, user_id, today: date) -> UserStreak:
        streak = await CheckinService.get_user_streak(db, user_id)

        if streak.last_checkin_date == today:
            return streak

        if streak.last_checkin_date == today - timedelta(days=1):
            streak.current_streak += 1
        else:
            streak.current_streak = 1

        if streak.current_streak > streak.longest_streak:
            streak.longest_streak = streak.current_streak

        streak.last_checkin_date = today
        return streak
