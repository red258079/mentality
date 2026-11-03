import uuid
import enum
from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, DateTime, Enum, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.database import Base


class CrisisFlagTier(str, enum.Enum):
    explicit = "explicit"
    ambiguous = "ambiguous"


class CrisisFlagStatus(str, enum.Enum):
    new = "new"
    contacted = "contacted"
    resolved = "resolved"


class CrisisFlag(Base):
    __tablename__ = "crisis_flags"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    tier = Column(String(20), nullable=False)
    source = Column(String(50), nullable=False, default="chat")
    status = Column(String(20), nullable=False, default="new", index=True)
    admin_note = Column(Text, nullable=True)
    handled_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    handled_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False, index=True)

    # Relationships
    user = relationship("User", foreign_keys=[user_id], backref="crisis_flags")
    handler = relationship("User", foreign_keys=[handled_by])
