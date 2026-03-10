import uuid
from datetime import datetime

from sqlalchemy import String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class CustomField(Base):
    __tablename__ = "custom_fields"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    name: Mapped[str] = mapped_column(String(100))  # Display name, e.g. "Vinyl Color"
    field_key: Mapped[str] = mapped_column(String(100), unique=True)  # Key in metadata, e.g. "vinyl_color"
    field_type: Mapped[str] = mapped_column(String(20), default="text")  # text, number, select
    options: Mapped[list] = mapped_column(JSONB, default=list)  # For select type: list of option strings
    media_types: Mapped[list] = mapped_column(JSONB, default=list)  # Which media types this applies to, empty = all
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
