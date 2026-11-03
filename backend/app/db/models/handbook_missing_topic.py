import uuid
from datetime import date, datetime, timezone
from sqlalchemy import Column, String, Integer, Date, DateTime, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID

from app.db.database import Base


class HandbookMissingTopic(Base):
    __tablename__ = "handbook_missing_topics"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    topic = Column(String(50), nullable=False, index=True)
    recorded_date = Column(Date, default=date.today, nullable=False, index=True)
    count = Column(Integer, nullable=False, default=1)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc), nullable=False)

    __table_args__ = (
        UniqueConstraint('topic', 'recorded_date', name='uq_topic_date'),
    )

