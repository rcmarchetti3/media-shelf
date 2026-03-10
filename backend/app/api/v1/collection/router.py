import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.collection import (
    CollectionItemCreate,
    CollectionItemResponse,
    CollectionItemUpdate,
    CollectionListResponse,
    CollectionStatsResponse,
)

from .service import create_item, delete_item, get_item, get_items, get_stats, update_item

router = APIRouter()


@router.post("/", response_model=CollectionItemResponse, status_code=201)
async def add_to_collection(
    data: CollectionItemCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = await create_item(db, current_user.id, data)
    if item is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Item already in your collection",
        )
    return item


@router.get("/", response_model=CollectionListResponse)
async def list_collection(
    media_type: str | None = None,
    item_status: str | None = Query(None, alias="status"),
    is_favorite: bool | None = None,
    tags: list[str] | None = Query(None),
    q: str | None = None,
    sort_by: str = "added_at",
    sort_order: str = "desc",
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    items, total = await get_items(
        db,
        current_user.id,
        media_type=media_type,
        status=item_status,
        is_favorite=is_favorite,
        tags=tags,
        q=q,
        sort_by=sort_by,
        sort_order=sort_order,
        page=page,
        page_size=page_size,
    )
    total_pages = (total + page_size - 1) // page_size if total > 0 else 0
    return CollectionListResponse(
        items=items, total=total, page=page, page_size=page_size, total_pages=total_pages
    )


@router.get("/stats", response_model=CollectionStatsResponse)
async def collection_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    stats = await get_stats(db, current_user.id)
    return stats


@router.get("/{item_id}", response_model=CollectionItemResponse)
async def get_collection_item(
    item_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = await get_item(db, current_user.id, item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@router.patch("/{item_id}", response_model=CollectionItemResponse)
async def update_collection_item(
    item_id: uuid.UUID,
    data: CollectionItemUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = await update_item(db, current_user.id, item_id, data)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@router.delete("/{item_id}", status_code=204)
async def delete_collection_item(
    item_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    deleted = await delete_item(db, current_user.id, item_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Item not found")
