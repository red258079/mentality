import os
import logging
from typing import Optional, List
from datetime import datetime, timezone
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, update, and_

import firebase_admin
from firebase_admin import credentials, messaging

from app.core.config import settings
from app.db.models.user import User
from app.db.models.notification_log import NotificationLog, NotificationType

logger = logging.getLogger(__name__)

# ── Initialize Firebase Admin SDK (Singleton) ──────────────────────────────
_firebase_initialized = False

def _init_firebase():
    global _firebase_initialized
    if _firebase_initialized:
        return True

    cred_path = settings.FIREBASE_CREDENTIALS_PATH
    if cred_path and os.path.exists(cred_path):
        try:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info(f"[FCM] Firebase Admin SDK initialized with: {cred_path}")
            return True
        except Exception as e:
            logger.warning(f"[FCM] Failed to initialize Firebase Admin with credentials: {e}")
            return False
    else:
        logger.info("[FCM] Firebase credentials not found – running in local/simulated push mode.")
        return False

# Try initializing on module load
_init_firebase()


class NotificationService:
    @staticmethod
    async def send_push_to_user(
        db: AsyncSession,
        user_id: UUID,
        title: str,
        body: str,
        notif_type: NotificationType = NotificationType.system,
        data_payload: Optional[dict] = None,
    ) -> NotificationLog:
        """Gửi FCM push notification tới 1 sinh viên cụ thể và lưu log vào DB."""
        user_result = await db.execute(select(User).where(User.id == user_id))
        user = user_result.scalar_one_or_none()

        log = NotificationLog(
            user_id    = user_id,
            type       = notif_type,
            title      = title,
            body       = body,
            is_sent    = False,
            is_read    = False,
            created_at = datetime.now(timezone.utc),
        )

        fcm_token = user.fcm_token if user else None
        if fcm_token and _firebase_initialized:
            try:
                message = messaging.Message(
                    notification=messaging.Notification(title=title, body=body),
                    data={str(k): str(v) for k, v in (data_payload or {}).items()},
                    token=fcm_token,
                )
                fcm_id = messaging.send(message)
                log.is_sent = True
                log.sent_at = datetime.now(timezone.utc)
                log.fcm_message_id = fcm_id
                logger.info(f"[FCM] Push sent to user {user_id}: {fcm_id}")
            except Exception as e:
                logger.error(f"[FCM] Push failed for user {user_id}: {e}")
        else:
            # Simulated push mode (dev environment / unconfigured FCM)
            log.is_sent = True
            log.sent_at = datetime.now(timezone.utc)
            log.fcm_message_id = "simulated_fcm_" + str(datetime.now(timezone.utc).timestamp())
            print(f"\n🔔 [PUSH NOTIFICATION SIMULATED]\n  To User : {user.email if user else user_id}\n  Title   : {title}\n  Body    : {body}\n  Type    : {notif_type.value}\n")

        db.add(log)
        await db.commit()
        await db.refresh(log)
        return log

    @staticmethod
    async def broadcast_notification(
        db: AsyncSession,
        title: str,
        body: str,
        notif_type: NotificationType = NotificationType.system,
    ) -> int:
        """Gửi thông báo tới toàn bộ sinh viên đang hoạt động."""
        result = await db.execute(select(User.id).where(User.is_active == True))
        user_ids = [row[0] for row in result.all()]

        count = 0
        for uid in user_ids:
            await NotificationService.send_push_to_user(
                db=db,
                user_id=uid,
                title=title,
                body=body,
                notif_type=notif_type,
            )
            count += 1
        return count

    @staticmethod
    async def get_user_notifications(
        db: AsyncSession,
        user_id: UUID,
        unread_only: bool = False,
        limit: int = 50,
        offset: int = 0,
    ):
        """Lấy danh sách thông báo của user + đếm số chưa đọc."""
        conditions = [NotificationLog.user_id == user_id]
        if unread_only:
            conditions.append(NotificationLog.is_read == False)

        query = (
            select(NotificationLog)
            .where(and_(*conditions))
            .order_by(NotificationLog.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        result = await db.execute(query)
        items = result.scalars().all()

        # Count total
        count_q = select(func.count(NotificationLog.id)).where(NotificationLog.user_id == user_id)
        total = (await db.execute(count_q)).scalar() or 0

        # Count unread
        unread_q = select(func.count(NotificationLog.id)).where(
            NotificationLog.user_id == user_id,
            NotificationLog.is_read == False,
        )
        unread_count = (await db.execute(unread_q)).scalar() or 0

        return items, total, unread_count

    @staticmethod
    async def mark_as_read(db: AsyncSession, user_id: UUID, notif_id: UUID) -> bool:
        """Đánh dấu 1 thông báo đã đọc."""
        result = await db.execute(
            select(NotificationLog).where(
                NotificationLog.id == notif_id,
                NotificationLog.user_id == user_id,
            )
        )
        notif = result.scalar_one_or_none()
        if notif:
            notif.is_read = True
            await db.commit()
            return True
        return False

    @staticmethod
    async def mark_all_as_read(db: AsyncSession, user_id: UUID) -> int:
        """Đánh dấu tất cả thông báo của user đã đọc."""
        result = await db.execute(
            update(NotificationLog)
            .where(NotificationLog.user_id == user_id, NotificationLog.is_read == False)
            .values(is_read=True)
        )
        await db.commit()
        return result.rowcount or 0

    @staticmethod
    async def update_fcm_token(db: AsyncSession, user_id: UUID, fcm_token: str) -> bool:
        """Lưu hoặc cập nhật FCM device token của user."""
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user:
            user.fcm_token = fcm_token
            await db.commit()
            return True
        return False
