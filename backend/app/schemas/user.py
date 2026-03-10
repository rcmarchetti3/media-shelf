import uuid
from datetime import datetime

from pydantic import BaseModel, Field


class UserListItem(BaseModel):
    id: uuid.UUID
    username: str
    display_name: str
    role: str

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    display_name: str | None = Field(None, max_length=100)
    email: str | None = Field(None, max_length=255)


class AdminUserUpdate(BaseModel):
    role: str | None = Field(None, pattern="^(admin|member)$")
    is_active: bool | None = None
