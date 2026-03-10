import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class CollectionItemCreate(BaseModel):
    media_type: str = Field(pattern="^(vinyl|book|show|movie|documentary|audiobook)$")
    external_id: str | None = None  # Optional for manually added items
    title: str = Field(max_length=500)
    image_url: str | None = None
    metadata: dict = Field(default_factory=dict)
    rating: int | None = Field(None, ge=1, le=5)
    status: str | None = None
    notes: str | None = None
    tags: list[str] = Field(default_factory=list)
    is_favorite: bool = False


class CollectionItemUpdate(BaseModel):
    image_url: str | None = None
    metadata: dict | None = None
    rating: int | None = Field(None, ge=1, le=5)
    status: str | None = None
    notes: str | None = None
    tags: list[str] | None = None
    is_favorite: bool | None = None


class CollectionItemResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    media_type: str
    external_id: str | None
    title: str
    image_url: str | None
    metadata: dict = Field(validation_alias="metadata_")
    rating: int | None
    status: str | None
    notes: str | None
    tags: list[str]
    is_favorite: bool
    added_at: datetime
    updated_at: datetime
    added_by_name: str | None = None

    model_config = {"from_attributes": True, "populate_by_name": True}


class CollectionListResponse(BaseModel):
    items: list[CollectionItemResponse]
    total: int
    page: int
    page_size: int
    total_pages: int


class CollectionStatsResponse(BaseModel):
    total: int
    vinyl: int = 0
    book: int = 0
    movie: int = 0
    show: int = 0
    documentary: int = 0
    audiobook: int = 0
