import uuid
import enum
from sqlalchemy import Column, String, Text, Integer, Enum, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.db.database import Base


class ArticleStatus(str, enum.Enum):
    draft          = "draft"
    pending_review = "pending_review"
    published      = "published"
    rejected       = "rejected"


class HandbookArticle(Base):
    __tablename__ = "handbook_articles"

    id               = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title            = Column(String(500), nullable=False)
    summary          = Column(Text, nullable=True)
    content          = Column(Text, nullable=False)
    category         = Column(String(100), nullable=False)
    author_name      = Column(String(255), nullable=True)
    author_id        = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    status           = Column(
        Enum(ArticleStatus, name="article_status", create_type=False, values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=ArticleStatus.published,
    )
    reviewed_by      = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    reviewed_at      = Column(DateTime(timezone=True), nullable=True)
    rejection_reason = Column(Text, nullable=True)
    helpful_count    = Column(Integer, nullable=False, default=0)
    view_count       = Column(Integer, nullable=False, default=0)
    tags             = Column(ARRAY(Text), server_default="{}")
    chroma_id        = Column(Text, unique=True, nullable=True)
    created_at       = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at       = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
