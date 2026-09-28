from datetime import date
from typing import Optional, List, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.models.journal import Journal
from app.services.ai_agent_service import AIAgentService, RiskAssessmentResult


class JournalService:
    @staticmethod
    async def create_journal_entry(
        db: AsyncSession,
        user_id,
        stress_level: int,
        sleep_hours: float,
        physical_symptoms: Optional[List[str]] = None,
        note: Optional[str] = None
    ) -> Dict[str, Any]:
        today = date.today()
        symptoms = physical_symptoms or []

        # Simple AI Sentiment analysis & Keyword extraction
        note_lower = (note or "").lower()
        if any(w in note_lower for w in ["kiệt sức", "bất an", "tuyệt vọng", "không chịu nổi"]):
            sentiment = "anxious"
        elif any(w in note_lower for w in ["căng thẳng", "mệt", "đau", "áp lực"]):
            sentiment = "negative"
        elif any(w in note_lower for w in ["vui", "tốt", "học được", "ổn"]):
            sentiment = "positive"
        else:
            sentiment = "neutral"

        keywords = symptoms + [w for w in ["ca_dem", "dung_may", "5s", "ngu_it"] if w in note_lower]

        journal = Journal(
            user_id=user_id,
            journal_date=today,
            stress_level=stress_level,
            sleep_hours=sleep_hours,
            physical_symptoms=symptoms,
            note=note,
            ai_sentiment=sentiment,
            ai_keywords=keywords
        )
        db.add(journal)

        # Trigger AI Agent Risk Screening
        risk_res: RiskAssessmentResult = AIAgentService.evaluate_psychological_risk(
            stress_level=stress_level,
            sleep_hours=sleep_hours,
            note_text=note,
            physical_symptoms=symptoms
        )

        await db.commit()
        await db.refresh(journal)

        return {
            "journal": journal,
            "risk_assessment": {
                "level": risk_res.level,
                "reasons": risk_res.reasons,
                "trigger_emergency": risk_res.trigger_emergency,
                "recommended_actions": risk_res.recommended_actions
            }
        }

    @staticmethod
    async def get_journal_history(db: AsyncSession, user_id, limit: int = 14) -> List[Journal]:
        result = await db.execute(
            select(Journal).where(Journal.user_id == user_id).order_by(Journal.journal_date.desc()).limit(limit)
        )
        return list(result.scalars().all())
