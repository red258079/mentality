import uuid
from sqlalchemy import (
    Column, String, Boolean, DateTime, Integer, Float, ForeignKey
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.db.database import Base


class University(Base):
    __tablename__ = "universities"

    id                   = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code                 = Column(String(50), unique=True, nullable=False, index=True)
    name                 = Column(String(255), nullable=False)
    short_name           = Column(String(100), nullable=True)
    city                 = Column(String(100), nullable=True)
    is_approved          = Column(Boolean, default=True, nullable=False, index=True)
    submitted_by_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at           = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relationships
    users                = relationship("User", back_populates="university_rel", foreign_keys="User.university_id")


class Company(Base):
    __tablename__ = "companies"

    id                   = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code                 = Column(String(50), unique=True, nullable=False, index=True)
    name                 = Column(String(255), nullable=False)
    short_name           = Column(String(100), nullable=True)
    latitude             = Column(Float, nullable=True)
    longitude            = Column(Float, nullable=True)
    radius_meters        = Column(Integer, default=500, nullable=False)
    workplace_type       = Column(String(50), default="factory_locker", nullable=False)
    is_approved          = Column(Boolean, default=True, nullable=False, index=True)
    submitted_by_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at           = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # Relationships
    intern_profiles      = relationship("InternProfile", back_populates="company_rel", foreign_keys="InternProfile.company_id")
