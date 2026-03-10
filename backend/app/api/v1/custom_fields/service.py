import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.custom_field import CustomField
from app.schemas.custom_field import CustomFieldCreate, CustomFieldUpdate


async def get_all_fields(db: AsyncSession) -> list[CustomField]:
    result = await db.execute(
        select(CustomField).order_by(CustomField.created_at.asc())
    )
    return list(result.scalars().all())


async def create_field(db: AsyncSession, data: CustomFieldCreate) -> CustomField | None:
    # Check for duplicate field_key
    existing = await db.execute(
        select(CustomField).where(CustomField.field_key == data.field_key)
    )
    if existing.scalar_one_or_none():
        return None

    field = CustomField(
        name=data.name,
        field_key=data.field_key,
        field_type=data.field_type,
        options=data.options,
        media_types=data.media_types,
    )
    db.add(field)
    await db.commit()
    await db.refresh(field)
    return field


async def update_field(
    db: AsyncSession, field_id: uuid.UUID, data: CustomFieldUpdate
) -> CustomField | None:
    result = await db.execute(
        select(CustomField).where(CustomField.id == field_id)
    )
    field = result.scalar_one_or_none()
    if not field:
        return None

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(field, key, value)

    await db.commit()
    await db.refresh(field)
    return field


async def delete_field(db: AsyncSession, field_id: uuid.UUID) -> bool:
    result = await db.execute(
        select(CustomField).where(CustomField.id == field_id)
    )
    field = result.scalar_one_or_none()
    if not field:
        return False

    await db.delete(field)
    await db.commit()
    return True
