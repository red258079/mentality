import uuid
import enum
from sqlalchemy import (
    Column, String, Date, SmallInteger, Enum, DateTime, ForeignKey
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.db.database import Base


class InternPhase(str, enum.Enum):
    preparation = "preparation"
    adaptation  = "adaptation"
    sustain     = "sustain"


class InternProfile(Base):
    __tablename__ = "intern_profiles"

    id                     = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id                = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    company_name           = Column(String(255), default="LG Display")
    department             = Column(String(255), nullable=True)
    intern_start_date      = Column(Date, nullable=True)
    intern_end_date        = Column(Date, nullable=True)
    current_phase          = Column(
        Enum(InternPhase, name="intern_phase", create_type=False, values_callable=lambda x: [e.value for e in x]),
        default=InternPhase.preparation
    )
    initial_sleep_score    = Column(SmallInteger, nullable=True)
    initial_physical_score = Column(SmallInteger, nullable=True)
    initial_mental_score   = Column(SmallInteger, nullable=True)
    initial_social_score   = Column(SmallInteger, nullable=True)
    initial_career_score   = Column(SmallInteger, nullable=True)
    created_at             = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at             = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)

    # Relationships
    user = relationship("User", back_populates="intern_profile")
