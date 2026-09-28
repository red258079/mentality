import uuid
from sqlalchemy import Column, String, Text, Date, SmallInteger, Numeric, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.db.database import Base


class Journal(Base):
    __tablename__ = "journals"

    id                = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id           = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    journal_date      = Column(Date, nullable=False)
    stress_level      = Column(SmallInteger, nullable=False)
    sleep_hours       = Column(Numeric(3, 1), nullable=False)
    physical_symptoms = Column(ARRAY(Text), server_default="{}")
    note              = Column(Text, nullable=True)
    ai_sentiment      = Column(String(20), nullable=True)
    ai_keywords       = Column(ARRAY(Text), server_default="{}")
    created_at        = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
