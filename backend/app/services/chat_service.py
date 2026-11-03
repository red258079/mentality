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
    async def delete_session(db: AsyncSession, user_id, session_id) -> bool:
        from uuid import UUID as PyUUID
        try:
            sess_uuid = PyUUID(str(session_id))
        except Exception:
            sess_uuid = session_id

        result = await db.execute(
            select(ChatSession).where(ChatSession.id == sess_uuid)
        )
        session = result.scalar_one_or_none()
        if session:
            # So sánh user_id an toàn (chuỗi hoặc UUID không phân biệt dấu gạch nối)
            uid_str = str(user_id).replace("-", "").lower()
            sess_uid_str = str(session.user_id).replace("-", "").lower()
            if uid_str == sess_uid_str:
                session.is_active = False
                await db.commit()
                return True
        return False

    @staticmethod
    async def get_recent_sleep_hours(db: AsyncSession, user_id) -> Optional[float]:
        """
        Lấy số giờ ngủ từ bản ghi journal gần nhất của user trong vòng 36 giờ qua.
        - user_id được lấy từ authenticated token, không bao giờ lấy từ client/request body.
        - Chỉ lấy bản ghi trong vòng 36 giờ gần nhất; quá thời gian này trả về None (unknown).
        """
        from datetime import datetime, timezone, timedelta
        from sqlalchemy import select, desc
        from app.db.models.journal import Journal

        cutoff = datetime.now(timezone.utc) - timedelta(hours=36)
        stmt = (
            select(Journal.sleep_hours)
            .where(
                Journal.user_id == user_id,
                Journal.created_at >= cutoff
            )
            .order_by(desc(Journal.created_at))
            .limit(1)
        )
        result = await db.execute(stmt)
        val = result.scalar_one_or_none()
        return float(val) if val is not None else None

    @staticmethod
    async def send_user_message_and_get_rag_reply(
        db: AsyncSession,
        user_id,
        session_id,
        content: str,
        user_name: str = "Sinh viên",
        intern_phase: str = "adaptation",
        stress_level: int = 2,
        recent_symptoms: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        # Cập nhật tiêu đề phiên theo câu hỏi đầu tiên của sinh viên
        sess_res = await db.execute(select(ChatSession).where(ChatSession.id == session_id))
        sess = sess_res.scalar_one_or_none()
        if sess and (sess.title == "Tư vấn Enigma AI" or sess.title == "Tư vấn Thích nghi & Tâm lý" or not sess.title):
            clean_title = content.strip().replace("\n", " ")
            sess.title = clean_title[:45] + ("..." if len(clean_title) > 45 else "")

        # 1. Save user message
        user_msg = ChatMessage(session_id=session_id, is_user=True, content=content)
        db.add(user_msg)
        await db.flush()

        # 2. Luôn đọc giờ ngủ thực tế từ DB của user trong 36h qua (bỏ qua giá trị client gửi)
        actual_sleep_hours = await ChatService.get_recent_sleep_hours(db, user_id)

        # 3. Call Advanced RAG Engine Service (with Function Calling support)
        rag_res = await AdvancedRAGService.generate_advanced_rag_response(
            query=content,
            user_name=user_name,
            intern_phase=intern_phase,
            stress_level=stress_level,
            sleep_hours=actual_sleep_hours,
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


    @staticmethod
    async def cleanup_expired_chat_history(db: AsyncSession, retention_days: Optional[int] = None) -> int:
        """
        Dọn dẹp lịch sử trò chuyện đã hết hạn (mặc định quá CHAT_RETENTION_DAYS ngày).
        Xóa tin nhắn (ChatMessage) và các phiên (ChatSession) cũ.
        Không chạy trên từng request; được gọi qua startup task hoặc scheduled admin endpoint.
        """
        from datetime import datetime, timezone, timedelta
        from app.core.config import settings
        from sqlalchemy import delete
        from app.db.models.chat import ChatSession, ChatMessage

        days = retention_days if retention_days is not None else settings.CHAT_RETENTION_DAYS
        cutoff = datetime.now(timezone.utc) - timedelta(days=days)

        # Xóa các tin nhắn quá hạn
        stmt_msg = delete(ChatMessage).where(ChatMessage.created_at < cutoff)
        res_msg = await db.execute(stmt_msg)
        deleted_count = res_msg.rowcount or 0

        # Xóa các phiên rỗng hoặc quá hạn cập nhật
        stmt_sess = delete(ChatSession).where(ChatSession.updated_at < cutoff)
        await db.execute(stmt_sess)

        await db.commit()
        return deleted_count

    @staticmethod
    async def delete_user_entire_chat_history(db: AsyncSession, user_id) -> int:
        """
        Quyền riêng tư: Xóa toàn bộ lịch sử trò chuyện của chính người dùng.
        user_id ĐƯỢC LẤY DUY NHẤT TỪ AUTHENTICATED TOKEN.
        """
        from sqlalchemy import delete
        from app.db.models.chat import ChatSession, ChatMessage

        # Tìm các session của user
        sess_res = await db.execute(select(ChatSession.id).where(ChatSession.user_id == user_id))
        session_ids = [s for s in sess_res.scalars().all()]

        if not session_ids:
            return 0

        # Xóa toàn bộ tin nhắn thuộc các session này
        msg_stmt = delete(ChatMessage).where(ChatMessage.session_id.in_(session_ids))
        res_msg = await db.execute(msg_stmt)
        deleted_msgs = res_msg.rowcount or 0

        # Xóa các session
        sess_stmt = delete(ChatSession).where(ChatSession.id.in_(session_ids))
        await db.execute(sess_stmt)

        await db.commit()
        return deleted_msgs
