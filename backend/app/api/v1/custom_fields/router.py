import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_admin
from app.models.user import User
from app.schemas.custom_field import (
    CustomFieldCreate,
    CustomFieldResponse,
    CustomFieldUpdate,
)

from .service import create_field, delete_field, get_all_fields, update_field

router = APIRouter()


@router.get("/", response_model=list[CustomFieldResponse])
async def list_custom_fields(
    db: AsyncSession = Depends(get_db),
    _current_user: User = Depends(get_current_user),
):
    """List all custom fields. Any authenticated user can read."""
    return await get_all_fields(db)


@router.post("/", response_model=CustomFieldResponse, status_code=201)
async def add_custom_field(
    data: CustomFieldCreate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    """Create a new custom field. Admin only."""
    field = await create_field(db, data)
    if field is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Field key '{data.field_key}' already exists",
        )
    return field


@router.patch("/{field_id}", response_model=CustomFieldResponse)
async def update_custom_field(
    field_id: uuid.UUID,
    data: CustomFieldUpdate,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    """Update a custom field. Admin only."""
    field = await update_field(db, field_id, data)
    if not field:
        raise HTTPException(status_code=404, detail="Custom field not found")
    return field


@router.delete("/{field_id}", status_code=204)
async def remove_custom_field(
    field_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    _admin: User = Depends(require_admin),
):
    """Delete a custom field. Admin only."""
    deleted = await delete_field(db, field_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Custom field not found")
