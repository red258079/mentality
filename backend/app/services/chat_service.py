from typing import List, Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.models.chat import ChatSession, ChatMessage
from app.services.advanced_rag_service import AdvancedRAGService


class ChatService:
    @staticmethod
    async def create_chat_session(db: AsyncSession, user_id, title: str = "Tư vấn Enigma AI") -> ChatSession:
        session = ChatSession(user_id=user_id, title=title)
        db.add(session)
        await db.commit()
        await db.refresh(session)
        return session

    @staticmethod
    async def get_user_sessions(db: AsyncSession, user_id) -> List[ChatSession]:
        result = await db.execute(
            select(ChatSession).where(ChatSession.user_id == user_id, ChatSession.is_active == True).order_by(ChatSession.updated_at.desc())
        )
        return list(result.scalars().all())

    @staticmethod
    async def get_session_messages(db: AsyncSession, session_id) -> List[ChatMessage]:
        result = await db.execute(
            select(ChatMessage).where(ChatMessage.session_id == session_id).order_by(ChatMessage.created_at.asc())
        )
        return list(result.scalars().all())

    @staticmethod
    async def send_user_message_and_get_rag_reply(
        db: AsyncSession,
        user_id,
        session_id,
        content: str,
        user_name: str = "Sinh viên",
        intern_phase: str = "adaptation",
        stress_level: int = 2,
        sleep_hours: float = 7.0,
        recent_symptoms: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        # 1. Save user message
        user_msg = ChatMessage(session_id=session_id, is_user=True, content=content)
        db.add(user_msg)
        await db.flush()

        # 2. Call Advanced RAG Engine Service (with Function Calling support)
        rag_res = await AdvancedRAGService.generate_advanced_rag_response(
            query=content,
            user_name=user_name,
            intern_phase=intern_phase,
            stress_level=stress_level,
            sleep_hours=sleep_hours,
            recent_symptoms=recent_symptoms,
            user_id=str(user_id),
            db=db,
            enable_function_calling=True
        )

        # 3. Save AI message with rag_sources metadata
        ai_msg = ChatMessage(
            session_id=session_id,
            is_user=False,
            content=rag_res["content"],
            rag_sources=rag_res["rag_sources"]
        )
        db.add(ai_msg)
        await db.commit()
        await db.refresh(ai_msg)

        return {
            "user_message": user_msg,
            "ai_message": ai_msg,
            "rag_sources": rag_res["rag_sources"],
            "risk_assessment": rag_res["risk_assessment"]
        }
