from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from datetime import datetime
from uuid import UUID

from app.db.models.notification_log import NotificationType

class NotificationResponse(BaseModel):
    id: UUID
    user_id: Optional[UUID] = None
    type: NotificationType
    title: str
    body: str
    is_sent: bool
    is_read: bool
    sent_at: Optional[datetime] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class NotificationListResponse(BaseModel):
    items: List[NotificationResponse]
    total: int
    unread_count: int

class UnreadCountResponse(BaseModel):
    unread_count: int

class SendNotificationRequest(BaseModel):
    user_id: Optional[UUID] = None  # None = broadcast to all active users
    type: NotificationType = NotificationType.system
    title: str
    body: str

class UpdateFCMTokenRequest(BaseModel):
    fcm_token: str
