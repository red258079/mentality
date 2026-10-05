import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, Boolean, DateTime, Enum, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.database import Base

class NotificationType(str, enum.Enum):
    reminder_checkin = "reminder_checkin"
    reminder_journal = "reminder_journal"
    new_article      = "new_article"
    task_unlock      = "task_unlock"
    streak_warning   = "streak_warning"
    system           = "system"

class NotificationLog(Base):
    __tablename__ = "notification_logs"

    id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id        = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    type           = Column(Enum(NotificationType, name="notification_type"), nullable=False)
    title          = Column(String(255), nullable=False)
    body           = Column(Text, nullable=False)
    is_sent        = Column(Boolean, default=False)
    is_read        = Column(Boolean, default=False, nullable=False)
    sent_at        = Column(DateTime(timezone=True), nullable=True)
    fcm_message_id = Column(Text, nullable=True)
    created_at     = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    user = relationship("User", backref="notifications")
