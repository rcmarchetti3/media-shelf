import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Recommendation(Base):
    """The latest saved recommendations for one user (one row per user).

    A failed run only touches last_attempt_at/last_error, so the previous
    picks stay on the dashboard while the model's computer is asleep.
    """

    __tablename__ = "recommendations"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    items: Mapped[list] = mapped_column(JSONB, default=list)
    stats: Mapped[dict] = mapped_column(JSONB, default=dict)
    provider: Mapped[str | None] = mapped_column(String(100), nullable=True)  # e.g. "ollama:gemma3:12b"
    generated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_attempt_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_error: Mapped[str | None] = mapped_column(String(300), nullable=True)
