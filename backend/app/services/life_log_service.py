"""
Life Log Service — API Ghi Nhận Nhật Ký Sinh Hoạt
==================================================
Cung cấp các API để:
  - Ghi nhận nhật ký sinh hoạt hàng ngày (giờ ngủ, mức stress, triệu chứng)
  - Truy vấn lịch sử 7/14/30 ngày với phân tích xu hướng
  - Dashboard tóm tắt sức khỏe tổng quan
  - AI Agent Risk Screening tích hợp Function Calling
"""
from datetime import date, timedelta
from typing import Any, Dict, List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc

from app.db.models.journal import Journal
from app.db.models.checkin import DailyCheckin, UserStreak
from app.services.ai_agent_service import AIAgentService, RiskAssessmentResult


# ─────────────────────────────────────────────────────────────────────────────
# Stress Level Descriptors
# ─────────────────────────────────────────────────────────────────────────────
STRESS_DESCRIPTIONS = {
    1: {"label": "Bình thản", "color": "#10B981", "emoji": "😌"},
    2: {"label": "Nhẹ nhàng", "color": "#34D399", "emoji": "🙂"},
    3: {"label": "Trung bình", "color": "#F59E0B", "emoji": "😐"},
    4: {"label": "Căng thẳng", "color": "#F97316", "emoji": "😟"},
    5: {"label": "Rất căng thẳng", "color": "#EF4444", "emoji": "😰"},
}

SLEEP_QUALITY_DESCRIPTORS = {
    "excellent": {"min_hours": 8.0, "label": "Tuyệt vời", "color": "#10B981"},
    "good": {"min_hours": 7.0, "label": "Tốt", "color": "#34D399"},
    "fair": {"min_hours": 6.0, "label": "Tạm ổn", "color": "#F59E0B"},
    "poor": {"min_hours": 5.0, "label": "Thiếu ngủ", "color": "#F97316"},
    "critical": {"min_hours": 0.0, "label": "Rất thiếu ngủ", "color": "#EF4444"},
}


def _classify_sleep_quality(sleep_hours: float) -> Dict[str, str]:
    for key, desc in SLEEP_QUALITY_DESCRIPTORS.items():
        if sleep_hours >= desc["min_hours"]:
            return {"quality": key, "label": desc["label"], "color": desc["color"]}
    return {"quality": "critical", "label": "Rất thiếu ngủ", "color": "#EF4444"}


def _calculate_wellbeing_score(
    stress_level: int,
    sleep_hours: float,
    streak: int,
    has_symptoms: bool
) -> int:
    """Tính điểm sức khỏe tổng hợp 0-100 từ các chỉ số."""
    score = 100

    # Stress deduction (0-40 points)
    stress_penalty = (stress_level - 1) * 8  # max -32
    score -= stress_penalty

    # Sleep deduction (0-30 points)
    if sleep_hours < 5:
        score -= 30
    elif sleep_hours < 6:
        score -= 20
    elif sleep_hours < 7:
        score -= 10
    elif sleep_hours >= 8:
        score += 5  # bonus for great sleep

    # Symptoms deduction (0-15 points)
    if has_symptoms:
        score -= 15

    # Streak bonus (0-10 points)
    streak_bonus = min(streak * 2, 10)
    score += streak_bonus

    return max(0, min(100, score))


class LifeLogService:
    """
    Service ghi nhận và phân tích nhật ký sinh hoạt toàn diện.
    Tích hợp AI Agent Risk Screening và Function Calling.
    """

    # ─── Create / Update ───────────────────────────────────────────────────────

    @staticmethod
    async def create_life_log(
        db: AsyncSession,
        user_id,
        stress_level: int,
        sleep_hours: float,
        shift_type: Optional[str] = None,        # "day" | "night"
        physical_symptoms: Optional[List[str]] = None,
        mood_note: Optional[str] = None,
        activities_done: Optional[List[str]] = None,
        water_intake_ml: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Ghi nhận nhật ký sinh hoạt tích hợp với bảng Journal.
        Thực hiện AI Agent Risk Screening sau khi lưu.
        """
        today = date.today()
        symptoms = physical_symptoms or []
        activities = activities_done or []

        # Sentiment analysis mở rộng
        note_lower = (mood_note or "").lower()
        if any(w in note_lower for w in ["kiệt sức", "bất an", "tuyệt vọng", "không chịu nổi", "muốn bỏ cuộc"]):
            sentiment = "anxious"
        elif any(w in note_lower for w in ["căng thẳng", "mệt", "đau", "áp lực", "lo lắng"]):
            sentiment = "negative"
        elif any(w in note_lower for w in ["vui", "tốt", "học được", "ổn", "tích cực", "năng lượng"]):
            sentiment = "positive"
        elif any(w in note_lower for w in ["bình thường", "không có gì"]):
            sentiment = "neutral"
        else:
            sentiment = "neutral"

        # Enhanced keyword extraction
        extracted_keywords = list(symptoms)
        shift_keywords = {
            "ca_dem": ["ca đêm", "ca tối", "đêm"],
            "ca_ngay": ["ca ngày", "ca sáng", "sáng"],
            "over_time": ["tăng ca", "làm thêm", "overtime"],
        }
        for kw_key, patterns in shift_keywords.items():
            if any(p in note_lower for p in patterns):
                extracted_keywords.append(kw_key)

        if shift_type:
            extracted_keywords.append(f"shift_{shift_type}")

        # Create Journal entry (reuse existing Journal model)
        journal = Journal(
            user_id=user_id,
            journal_date=today,
            stress_level=stress_level,
            sleep_hours=sleep_hours,
            physical_symptoms=symptoms,
            note=mood_note,
            ai_sentiment=sentiment,
            ai_keywords=extracted_keywords
        )
        db.add(journal)

        # AI Agent Risk Screening
        risk_res: RiskAssessmentResult = AIAgentService.evaluate_psychological_risk(
            stress_level=stress_level,
            sleep_hours=sleep_hours,
            note_text=mood_note,
            physical_symptoms=symptoms
        )

        # Calculate wellbeing score
        streak_res = await db.execute(
            select(UserStreak).where(UserStreak.user_id == user_id)
        )
        streak_obj = streak_res.scalar_one_or_none()
        current_streak = streak_obj.current_streak if streak_obj else 0

        wellbeing_score = _calculate_wellbeing_score(
            stress_level=stress_level,
            sleep_hours=sleep_hours,
            streak=current_streak,
            has_symptoms=len(symptoms) > 0
        )

        await db.commit()
        await db.refresh(journal)

        sleep_quality = _classify_sleep_quality(sleep_hours)
        stress_desc = STRESS_DESCRIPTIONS.get(stress_level, STRESS_DESCRIPTIONS[3])

        # Function Calling trigger flag: CRAG-like decision for missing data
        needs_function_calling = (
            risk_res.level in ["YELLOW", "RED"] and
            len(symptoms) == 0 and
            not mood_note
        )

        return {
            "journal": journal,
            "wellbeing_score": wellbeing_score,
            "sleep_quality": sleep_quality,
            "stress_description": stress_desc,
            "risk_assessment": {
                "level": risk_res.level,
                "reasons": risk_res.reasons,
                "trigger_emergency": risk_res.trigger_emergency,
                "recommended_actions": risk_res.recommended_actions
            },
            "needs_function_calling": needs_function_calling,
            "function_calling_reason": (
                "Thiếu chi tiết triệu chứng/ghi chú mặc dù có dấu hiệu stress cao. "
                "AI Agent cần thu thập thêm dữ liệu."
                if needs_function_calling else None
            )
        }

    # ─── Query & Analytics ────────────────────────────────────────────────────

    @staticmethod
    async def get_life_log_history(
        db: AsyncSession,
        user_id,
        days: int = 14
    ) -> List[Dict[str, Any]]:
        """Lấy lịch sử nhật ký sinh hoạt với metadata phân tích."""
        since_date = date.today() - timedelta(days=days)

        result = await db.execute(
            select(Journal)
            .where(Journal.user_id == user_id, Journal.journal_date >= since_date)
            .order_by(desc(Journal.journal_date))
        )
        journals = list(result.scalars().all())

        enriched = []
        for j in journals:
            sleep_q = _classify_sleep_quality(float(j.sleep_hours))
            stress_d = STRESS_DESCRIPTIONS.get(j.stress_level, STRESS_DESCRIPTIONS[3])
            enriched.append({
                "id": str(j.id),
                "date": str(j.journal_date),
                "stress_level": j.stress_level,
                "stress_label": stress_d["label"],
                "stress_color": stress_d["color"],
                "stress_emoji": stress_d["emoji"],
                "sleep_hours": float(j.sleep_hours),
                "sleep_quality": sleep_q["quality"],
                "sleep_label": sleep_q["label"],
                "sleep_color": sleep_q["color"],
                "physical_symptoms": j.physical_symptoms or [],
                "note": j.note,
                "ai_sentiment": j.ai_sentiment,
                "ai_keywords": j.ai_keywords or [],
                "created_at": j.created_at.isoformat() if j.created_at else None
            })

        return enriched

    @staticmethod
    async def get_life_log_analytics(
        db: AsyncSession,
        user_id,
        days: int = 7
    ) -> Dict[str, Any]:
        """
        Analytics tổng hợp xu hướng sinh hoạt.
        Trả về: avg_stress, avg_sleep, trend, phân bố cảm xúc, etc.
        """
        since_date = date.today() - timedelta(days=days)

        result = await db.execute(
            select(Journal)
            .where(Journal.user_id == user_id, Journal.journal_date >= since_date)
            .order_by(Journal.journal_date.asc())
        )
        journals = list(result.scalars().all())

        if not journals:
            return {
                "period_days": days,
                "total_entries": 0,
                "avg_stress": None,
                "avg_sleep": None,
                "stress_trend": "no_data",
                "sleep_trend": "no_data",
                "sentiment_distribution": {},
                "common_symptoms": [],
                "daily_scores": []
            }

        stress_values = [j.stress_level for j in journals]
        sleep_values = [float(j.sleep_hours) for j in journals]

        avg_stress = sum(stress_values) / len(stress_values)
        avg_sleep = sum(sleep_values) / len(sleep_values)

        # Trend analysis (compare first half vs second half)
        mid = len(stress_values) // 2
        first_half_stress = stress_values[:mid] if mid > 0 else stress_values
        second_half_stress = stress_values[mid:] if mid > 0 else stress_values

        stress_trend = "stable"
        if len(first_half_stress) >= 2 and len(second_half_stress) >= 2:
            avg1 = sum(first_half_stress) / len(first_half_stress)
            avg2 = sum(second_half_stress) / len(second_half_stress)
            if avg2 > avg1 + 0.5:
                stress_trend = "worsening"
            elif avg2 < avg1 - 0.5:
                stress_trend = "improving"

        # Sleep trend
        first_half_sleep = sleep_values[:mid] if mid > 0 else sleep_values
        second_half_sleep = sleep_values[mid:] if mid > 0 else sleep_values
        sleep_trend = "stable"
        if len(first_half_sleep) >= 2 and len(second_half_sleep) >= 2:
            avg_s1 = sum(first_half_sleep) / len(first_half_sleep)
            avg_s2 = sum(second_half_sleep) / len(second_half_sleep)
            if avg_s2 > avg_s1 + 0.5:
                sleep_trend = "improving"
            elif avg_s2 < avg_s1 - 0.5:
                sleep_trend = "worsening"

        # Sentiment distribution
        sentiment_dist: Dict[str, int] = {}
        for j in journals:
            s = j.ai_sentiment or "neutral"
            sentiment_dist[s] = sentiment_dist.get(s, 0) + 1

        # Common symptoms
        all_symptoms: List[str] = []
        for j in journals:
            if j.physical_symptoms:
                all_symptoms.extend(j.physical_symptoms)
        from collections import Counter
        symptom_freq = Counter(all_symptoms).most_common(5)

        # Daily scores for chart
        daily_scores = []
        for j in journals:
            score = _calculate_wellbeing_score(
                stress_level=j.stress_level,
                sleep_hours=float(j.sleep_hours),
                streak=1,
                has_symptoms=bool(j.physical_symptoms)
            )
            daily_scores.append({
                "date": str(j.journal_date),
                "score": score,
                "stress": j.stress_level,
                "sleep": float(j.sleep_hours)
            })

        # Overall risk assessment
        risk_res: RiskAssessmentResult = AIAgentService.evaluate_psychological_risk(
            stress_level=round(avg_stress),
            sleep_hours=avg_sleep,
            stress_history_last_3_days=stress_values[-3:]
        )

        return {
            "period_days": days,
            "total_entries": len(journals),
            "avg_stress": round(avg_stress, 2),
            "avg_sleep_hours": round(avg_sleep, 2),
            "avg_wellbeing_score": round(sum(d["score"] for d in daily_scores) / len(daily_scores)),
            "stress_trend": stress_trend,
            "sleep_trend": sleep_trend,
            "overall_risk_level": risk_res.level,
            "sentiment_distribution": sentiment_dist,
            "common_symptoms": [{"symptom": s, "count": c} for s, c in symptom_freq],
            "daily_scores": daily_scores
        }

    @staticmethod
    async def get_dashboard_summary(
        db: AsyncSession,
        user_id
    ) -> Dict[str, Any]:
        """
        Dashboard summary: checkin streak + today's life log + 7-day analytics.
        Endpoint chính cho màn hình Dashboard Flutter.
        """
        today = date.today()

        # Today's checkin
        checkin_res = await db.execute(
            select(DailyCheckin).where(
                DailyCheckin.user_id == user_id,
                DailyCheckin.checkin_date == today
            )
        )
        checkin_today = checkin_res.scalar_one_or_none()

        # Streak
        streak_res = await db.execute(
            select(UserStreak).where(UserStreak.user_id == user_id)
        )
        streak = streak_res.scalar_one_or_none()

        # Today's journal/life log
        journal_res = await db.execute(
            select(Journal).where(
                Journal.user_id == user_id,
                Journal.journal_date == today
            )
        )
        journal_today = journal_res.scalar_one_or_none()

        # 7-day analytics
        analytics = await LifeLogService.get_life_log_analytics(db, user_id, days=7)

        # Wellbeing score
        if journal_today:
            wellbeing_score = _calculate_wellbeing_score(
                stress_level=journal_today.stress_level,
                sleep_hours=float(journal_today.sleep_hours),
                streak=streak.current_streak if streak else 0,
                has_symptoms=bool(journal_today.physical_symptoms)
            )
            sleep_quality = _classify_sleep_quality(float(journal_today.sleep_hours))
            stress_desc = STRESS_DESCRIPTIONS.get(journal_today.stress_level, STRESS_DESCRIPTIONS[3])
        else:
            wellbeing_score = None
            sleep_quality = None
            stress_desc = None

        return {
            "today": {
                "date": str(today),
                "has_checked_in": checkin_today is not None,
                "gacha_message": checkin_today.gacha_message if checkin_today else None,
                "gacha_category": checkin_today.gacha_category if checkin_today else None,
                "has_life_log": journal_today is not None,
                "stress_level": journal_today.stress_level if journal_today else None,
                "sleep_hours": float(journal_today.sleep_hours) if journal_today else None,
                "wellbeing_score": wellbeing_score,
                "sleep_quality": sleep_quality,
                "stress_description": stress_desc,
                "ai_sentiment": journal_today.ai_sentiment if journal_today else None,
            },
            "streak": {
                "current_streak": streak.current_streak if streak else 0,
                "longest_streak": streak.longest_streak if streak else 0,
                "last_checkin": str(streak.last_checkin_date) if streak and streak.last_checkin_date else None
            },
            "weekly_analytics": analytics
        }
