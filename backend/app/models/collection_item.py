import uuid
from datetime import datetime

from sqlalchemy import (
    ARRAY,
    Boolean,
    ForeignKey,
    Index,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class CollectionItem(Base):
    __tablename__ = "collection_items"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    media_type: Mapped[str] = mapped_column(String(20))
    external_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    title: Mapped[str] = mapped_column(String(500))
    image_url: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    metadata_: Mapped[dict] = mapped_column("metadata", JSONB, default=dict)
    rating: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    status: Mapped[str | None] = mapped_column(String(30), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    tags: Mapped[list[str]] = mapped_column(ARRAY(String), default=list)
    is_favorite: Mapped[bool] = mapped_column(Boolean, default=False)
    added_at: Mapped[datetime] = mapped_column(server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(), onupdate=func.now()
    )

    user = relationship("User", back_populates="collection_items", lazy="selectin")

    @property
    def added_by_name(self) -> str | None:
        if self.user:
            return self.user.display_name
        return None

    __table_args__ = (
        Index("ix_collection_user_media", "user_id", "media_type"),
        Index("ix_collection_metadata", "metadata", postgresql_using="gin"),
        Index("ix_collection_tags", "tags", postgresql_using="gin"),
        UniqueConstraint(
            "user_id", "media_type", "external_id", name="uq_user_media_external"
        ),
        Index("ix_collection_added_at", "added_at"),
    )
