import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

FEEDBACK_KINDS = ("seen", "not_interested")


class RecommendationFeedback(Base):
    """A pick the user waved off. Never recommended again, and fed to the model
    on later runs ("not interested" as a dislike, both as "don't suggest")."""

    __tablename__ = "recommendation_feedback"
    __table_args__ = (
        UniqueConstraint("user_id", "media_type", "external_id", name="uq_feedback_user_media_external"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    media_type: Mapped[str] = mapped_column(String(20))
    external_id: Mapped[str] = mapped_column(String(255))
    title: Mapped[str] = mapped_column(String(500))
    kind: Mapped[str] = mapped_column(String(20))  # "seen" or "not_interested"
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
