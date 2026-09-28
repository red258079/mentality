import uuid
from sqlalchemy import Column, String, Text, Date, Integer, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func

from app.db.database import Base


class DailyCheckin(Base):
    __tablename__ = "daily_checkins"

    id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id        = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    checkin_date   = Column(Date, nullable=False)
    gacha_message  = Column(Text, nullable=False)
    gacha_category = Column(String(50), nullable=True)
    created_at     = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class UserStreak(Base):
    __tablename__ = "user_streaks"

    id                = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id           = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    current_streak    = Column(Integer, nullable=False, default=0)
    longest_streak    = Column(Integer, nullable=False, default=0)
    last_checkin_date = Column(Date, nullable=True)
    updated_at        = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
