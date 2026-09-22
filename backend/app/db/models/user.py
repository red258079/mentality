import uuid
import enum
from datetime import datetime
from sqlalchemy import (
    Column, String, Boolean, Enum, DateTime, Text
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.db.database import Base


class UserRole(str, enum.Enum):
    student = "student"
    admin   = "admin"


class User(Base):
    __tablename__ = "users"

    id            = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email         = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(Text, nullable=False)
    role          = Column(
        Enum(UserRole, name="user_role", create_type=False, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=UserRole.student
    )
    full_name     = Column(String(255), nullable=False)
    student_id    = Column(String(20), unique=True, nullable=True, index=True)
    university    = Column(String(255), nullable=True)
    major         = Column(String(255), nullable=True)
    avatar_url    = Column(Text, nullable=True)
    fcm_token     = Column(Text, nullable=True)
    is_active     = Column(Boolean, nullable=False, default=True)
    created_at    = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at    = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
    last_login_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    intern_profile  = relationship("InternProfile",  back_populates="user", uselist=False, cascade="all, delete-orphan")
    refresh_tokens  = relationship("RefreshToken",   back_populates="user", cascade="all, delete-orphan")
