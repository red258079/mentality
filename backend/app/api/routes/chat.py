from fastapi import APIRouter, Depends, HTTPException, status, Header
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel, Field
from typing import Optional, List, Any
from uuid import UUID

from app.db.database import get_db
from app.services.user_service import get_current_user
from app.services.chat_service import ChatService
from app.db.models.chat import ChatMessage

router = APIRouter()


class CreateSessionRequest(BaseModel):
    title: Optional[str] = "Tư vấn Enigma AI"


class SendMessageRequest(BaseModel):
    content: str = Field(..., min_length=1, description="Nội dung câu hỏi hoặc tâm sự của sinh viên")
    stress_level: Optional[int] = Field(2, ge=1, le=5, description="Mức độ stress hiện tại (1-5)")
    sleep_hours: Optional[float] = Field(7.0, ge=0, le=24, description="Số giờ ngủ ca gần nhất")
    recent_symptoms: Optional[List[str]] = Field(default=[], description="Triệu chứng thể chất mệt mỏi")


class MessageFeedbackRequest(BaseModel):
    feedback: int = Field(..., description="1 cho Hữu ích / Thích, -1 cho Chưa hữu ích")


async def get_authed_user(authorization: Optional[str] = Header(None), db: AsyncSession = Depends(get_db)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await get_current_user(db, token)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ.")
    return user


@router.post("/sessions", summary="Tạo phiên trò chuyện AI mới")
async def create_session(
    payload: CreateSessionRequest,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    session = await ChatService.create_chat_session(db, user.id, payload.title or "Tư vấn Enigma AI")
    return {
        "id": str(session.id),
        "title": session.title,
        "created_at": session.created_at
    }


@router.get("/sessions", summary="Lấy danh sách phiên trò chuyện của tôi")
async def get_sessions(
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    sessions = await ChatService.get_user_sessions(db, user.id)
    return [
        {
            "id": str(s.id),
            "title": s.title,
            "created_at": s.created_at,
            "updated_at": s.updated_at
        }
        for s in sessions
    ]


@router.get("/sessions/{session_id}/messages", summary="Lấy lịch sử tin nhắn trong phiên")
async def get_messages(
    session_id: UUID,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    messages = await ChatService.get_session_messages(db, session_id)
    return [
        {
            "id": str(m.id),
            "is_user": m.is_user,
            "content": m.content,
            "rag_sources": m.rag_sources,
            "feedback": m.feedback,
            "created_at": m.created_at
        }
        for m in messages
    ]


@router.post("/sessions/{session_id}/messages", summary="Gửi tin nhắn, kích hoạt RAG AI Response")
async def send_message(
    session_id: UUID,
    payload: SendMessageRequest,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    res = await ChatService.send_user_message_and_get_rag_reply(
        db=db,
        user_id=user.id,
        session_id=session_id,
        content=payload.content,
        user_name=user.full_name,
        stress_level=payload.stress_level or 2,
        sleep_hours=payload.sleep_hours or 7.0,
        recent_symptoms=payload.recent_symptoms or []
    )

    ai_msg = res["ai_message"]
    return {
        "user_message_id": str(res["user_message"].id),
        "ai_message": {
            "id": str(ai_msg.id),
            "is_user": False,
            "content": ai_msg.content,
            "rag_sources": res["rag_sources"],
            "created_at": ai_msg.created_at
        },
        "risk_assessment": res["risk_assessment"],
        "crag_status": res.get("crag_status", "CORRECT")
    }


@router.post("/messages/{message_id}/feedback", summary="Gửi đánh giá phản hồi cho câu trả lời của AI")
async def rate_message_feedback(
    message_id: UUID,
    payload: MessageFeedbackRequest,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(ChatMessage).where(ChatMessage.id == message_id))
    msg = result.scalar_one_or_none()
    if not msg:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy tin nhắn.")
    
    msg.feedback = 1 if payload.feedback > 0 else -1
    await db.commit()
    return {"message_id": str(message_id), "feedback": msg.feedback, "status": "recorded"}
