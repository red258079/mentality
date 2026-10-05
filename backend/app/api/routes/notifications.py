from fastapi import APIRouter, Depends, HTTPException, status, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from uuid import UUID

from app.db.database import get_db
from app.services.user_service import get_current_user
from app.services.notification_service import NotificationService
from app.schemas.notification import (
    NotificationResponse,
    NotificationListResponse,
    UnreadCountResponse,
    SendNotificationRequest,
    UpdateFCMTokenRequest,
)

router = APIRouter()


async def get_authed_user(authorization: Optional[str] = Header(None), db: AsyncSession = Depends(get_db)):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Chưa xác thực.")
    token = authorization.split(" ", 1)[1]
    user = await get_current_user(db, token)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token không hợp lệ.")
    return user


# ── GET /notifications ────────────────────────────────────────────────────────
@router.get("", response_model=NotificationListResponse, summary="Lấy danh sách thông báo của sinh viên")
async def get_my_notifications(
    unread_only: bool = Query(False, description="Chỉ lấy thông báo chưa đọc"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db),
):
    items, total, unread_count = await NotificationService.get_user_notifications(
        db=db,
        user_id=user.id,
        unread_only=unread_only,
        limit=limit,
        offset=offset,
    )
    return NotificationListResponse(
        items=[NotificationResponse.model_validate(n) for n in items],
        total=total,
        unread_count=unread_count,
    )


# ── GET /notifications/unread-count ───────────────────────────────────────────
@router.get("/unread-count", response_model=UnreadCountResponse, summary="Đếm số lượng thông báo chưa đọc")
async def get_unread_count(
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db),
):
    _, _, unread_count = await NotificationService.get_user_notifications(
        db=db,
        user_id=user.id,
        unread_only=True,
        limit=1,
    )
    return UnreadCountResponse(unread_count=unread_count)


# ── PUT /notifications/{id}/read ──────────────────────────────────────────────
@router.put("/{notif_id}/read", summary="Đánh dấu 1 thông báo là đã đọc")
async def mark_notification_read(
    notif_id: UUID,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db),
):
    success = await NotificationService.mark_as_read(db=db, user_id=user.id, notif_id=notif_id)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Không tìm thấy thông báo.")
    return {"message": "Đã đánh dấu đã đọc."}


# ── PUT /notifications/read-all ───────────────────────────────────────────────
@router.put("/read-all", summary="Đánh dấu tất cả thông báo là đã đọc")
async def mark_all_read(
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db),
):
    count = await NotificationService.mark_all_as_read(db=db, user_id=user.id)
    return {"message": f"Đã đánh dấu {count} thông báo là đã đọc."}


# ── POST /notifications/fcm-token ─────────────────────────────────────────────
@router.post("/fcm-token", summary="Cập nhật FCM device token của thiết bị")
async def update_fcm_token(
    payload: UpdateFCMTokenRequest,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db),
):
    await NotificationService.update_fcm_token(db=db, user_id=user.id, fcm_token=payload.fcm_token)
    return {"message": "FCM token đã được cập nhật thành công."}


# ── POST /notifications/send ──────────────────────────────────────────────────
@router.post("/send", response_model=NotificationResponse, summary="Gửi thông báo đẩy (Admin/System)")
async def send_notification(
    payload: SendNotificationRequest,
    user=Depends(get_authed_user),
    db: AsyncSession = Depends(get_db),
):
    target_user_id = payload.user_id or user.id
    log = await NotificationService.send_push_to_user(
        db=db,
        user_id=target_user_id,
        title=payload.title,
        body=payload.body,
        notif_type=payload.type,
    )
    return NotificationResponse.model_validate(log)
