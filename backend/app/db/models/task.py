import uuid
import enum
from sqlalchemy import Column, String, Text, Integer, Boolean, Enum, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func

from app.db.database import Base
from app.db.models.intern_profile import InternPhase


class PillarType(str, enum.Enum):
    sleep    = "sleep"
    physical = "physical"
    mental   = "mental"
    social   = "social"
    career   = "career"


class Task(Base):
    __tablename__ = "tasks"

    id               = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    phase            = Column(
        Enum(InternPhase, name="intern_phase", create_type=False, values_callable=lambda x: [e.value for e in x]),
        nullable=False
    )
    pillar           = Column(
        Enum(PillarType, name="pillar_type", create_type=False, values_callable=lambda x: [e.value for e in x]),
        nullable=False
    )
    title            = Column(String(500), nullable=False)
    description      = Column(Text, nullable=False)
    duration_minutes = Column(Integer, default=0)
    unlock_day       = Column(Integer, nullable=False, default=0)
    is_active        = Column(Boolean, default=True)
    sort_order       = Column(Integer, default=0)
    created_at       = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class UserTaskProgress(Base):
    __tablename__ = "user_task_progress"

    id           = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id      = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    task_id      = Column(UUID(as_uuid=True), ForeignKey("tasks.id", ondelete="CASCADE"), nullable=False)
    is_completed = Column(Boolean, nullable=False, default=False)
    is_locked    = Column(Boolean, nullable=False, default=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
