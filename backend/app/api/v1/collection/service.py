import uuid

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.collection_item import CollectionItem
from app.schemas.collection import CollectionItemCreate, CollectionItemUpdate


async def create_item(
    db: AsyncSession, user_id: uuid.UUID, data: CollectionItemCreate
) -> CollectionItem:
    # Check for duplicates (only when external_id is provided)
    if data.external_id:
        existing = await db.execute(
            select(CollectionItem).where(
                CollectionItem.user_id == user_id,
                CollectionItem.media_type == data.media_type,
                CollectionItem.external_id == data.external_id,
            )
        )
        if existing.scalar_one_or_none():
            return None  # Caller handles the 409

    item = CollectionItem(
        user_id=user_id,
        media_type=data.media_type,
        external_id=data.external_id,
        title=data.title,
        image_url=data.image_url,
        metadata_=data.metadata,
        rating=data.rating,
        status=data.status,
        notes=data.notes,
        tags=data.tags,
        is_favorite=data.is_favorite,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)
    return item


async def get_items(
    db: AsyncSession,
    user_id: uuid.UUID,
    media_type: str | None = None,
    status: str | None = None,
    is_favorite: bool | None = None,
    tags: list[str] | None = None,
    q: str | None = None,
    sort_by: str = "added_at",
    sort_order: str = "desc",
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[CollectionItem], int]:
    query = select(CollectionItem).where(CollectionItem.user_id == user_id)
    count_query = select(func.count(CollectionItem.id)).where(
        CollectionItem.user_id == user_id
    )

    if media_type:
        query = query.where(CollectionItem.media_type == media_type)
        count_query = count_query.where(CollectionItem.media_type == media_type)

    if status:
        query = query.where(CollectionItem.status == status)
        count_query = count_query.where(CollectionItem.status == status)

    if is_favorite is not None:
        query = query.where(CollectionItem.is_favorite == is_favorite)
        count_query = count_query.where(CollectionItem.is_favorite == is_favorite)

    if tags:
        query = query.where(CollectionItem.tags.overlap(tags))
        count_query = count_query.where(CollectionItem.tags.overlap(tags))

    if q:
        query = query.where(CollectionItem.title.ilike(f"%{q}%"))
        count_query = count_query.where(CollectionItem.title.ilike(f"%{q}%"))

    # Sorting
    sort_column = getattr(CollectionItem, sort_by, CollectionItem.added_at)
    if sort_order == "asc":
        query = query.order_by(sort_column.asc())
    else:
        query = query.order_by(sort_column.desc())

    # Pagination
    offset = (page - 1) * page_size
    query = query.offset(offset).limit(page_size)

    result = await db.execute(query)
    items = list(result.scalars().all())

    total_result = await db.execute(count_query)
    total = total_result.scalar()

    return items, total


async def get_item(
    db: AsyncSession, user_id: uuid.UUID, item_id: uuid.UUID
) -> CollectionItem | None:
    result = await db.execute(
        select(CollectionItem).where(
            CollectionItem.id == item_id, CollectionItem.user_id == user_id
        )
    )
    return result.scalar_one_or_none()


async def update_item(
    db: AsyncSession,
    user_id: uuid.UUID,
    item_id: uuid.UUID,
    data: CollectionItemUpdate,
) -> CollectionItem | None:
    item = await get_item(db, user_id, item_id)
    if not item:
        return None

    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        attr = "metadata_" if key == "metadata" else key
        setattr(item, attr, value)

    await db.commit()
    await db.refresh(item)
    return item


async def delete_item(
    db: AsyncSession, user_id: uuid.UUID, item_id: uuid.UUID
) -> bool:
    item = await get_item(db, user_id, item_id)
    if not item:
        return False

    await db.delete(item)
    await db.commit()
    return True


async def get_stats(
    db: AsyncSession, user_id: uuid.UUID
) -> dict:
    # Total count
    total_result = await db.execute(
        select(func.count(CollectionItem.id)).where(
            CollectionItem.user_id == user_id
        )
    )
    total = total_result.scalar()

    # Count by type
    type_counts = await db.execute(
        select(CollectionItem.media_type, func.count(CollectionItem.id))
        .where(CollectionItem.user_id == user_id)
        .group_by(CollectionItem.media_type)
    )
    counts = {row[0]: row[1] for row in type_counts.all()}

    return {
        "total": total,
        "vinyl": counts.get("vinyl", 0),
        "book": counts.get("book", 0),
        "movie": counts.get("movie", 0),
        "show": counts.get("show", 0),
        "documentary": counts.get("documentary", 0),
        "audiobook": counts.get("audiobook", 0),
    }
