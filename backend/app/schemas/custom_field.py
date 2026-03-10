import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class CustomFieldCreate(BaseModel):
    name: str = Field(max_length=100)
    field_key: str = Field(max_length=100, pattern=r"^[a-z][a-z0-9_]*$")
    field_type: str = Field(default="text", pattern=r"^(text|number|select)$")
    options: list[str] = Field(default_factory=list)
    media_types: list[str] = Field(default_factory=list)


class CustomFieldUpdate(BaseModel):
    name: str | None = Field(None, max_length=100)
    field_type: str | None = Field(None, pattern=r"^(text|number|select)$")
    options: list[str] | None = None
    media_types: list[str] | None = None


class CustomFieldResponse(BaseModel):
    id: uuid.UUID
    name: str
    field_key: str
    field_type: str
    options: list[str]
    media_types: list[str]
    created_at: datetime

    model_config = {"from_attributes": True}
