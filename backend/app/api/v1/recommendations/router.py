import asyncio

import anthropic
from fastapi import APIRouter, Depends, HTTPException
from httpx import HTTPError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.collection_item import CollectionItem
from app.models.recommendation import Recommendation
from app.models.user import User
from app.services.external.claude import ClaudeRefused
from app.services.external.ollama import OllamaUnavailable
from app.services.recommendation_store import is_refreshing, refresh_user
from app.services.recommendations import build_recommendations, llm

router = APIRouter()

# Keep references so running refreshes aren't garbage-collected mid-flight
_background: set[asyncio.Task] = set()


async def _refresh_quietly(user_id) -> None:
    try:
        await refresh_user(user_id)
    except Exception:
        pass  # already recorded as last_error on the saved row


@router.get("/")
async def get_recommendations(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """The saved picks, minus anything added to the library since they were built."""
    row = await db.get(Recommendation, current_user.id)
    items = row.items if row else []
    if items:
        owned = set(
            (
                await db.execute(
                    select(CollectionItem.media_type, CollectionItem.external_id).where(
                        CollectionItem.user_id == current_user.id
                    )
                )
            ).tuples()
        )
        items = [i for i in items if (i["media_type"], i["external_id"]) not in owned]
    return {
        "enabled": llm().is_configured,
        "refreshing": is_refreshing(),
        "recommendations": items,
        "generated_at": row.generated_at if row else None,
        "last_attempt_at": row.last_attempt_at if row else None,
        "last_error": row.last_error if row else None,
        "provider": row.provider if row else None,
    }


@router.post("/refresh", status_code=202)
async def refresh_recommendations(current_user: User = Depends(get_current_user)):
    """Start a rebuild in the background; poll GET / until refreshing is false.
    A run takes 30s or more, longer than the proxy and tunnel will hold a request."""
    if not llm().is_configured:
        raise HTTPException(status_code=503, detail="AI recommendations are not configured.")
    if is_refreshing():
        raise HTTPException(status_code=409, detail="Recommendations are already being built.")
    task = asyncio.create_task(_refresh_quietly(current_user.id))
    _background.add(task)
    task.add_done_callback(_background.discard)
    return {"refreshing": True}


@router.post("/preview")
async def preview_recommendations(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Build recommendations now and return them without saving (for testing prompts)."""
    if not llm().is_configured:
        raise HTTPException(status_code=503, detail="AI recommendations are not configured.")
    try:
        return await build_recommendations(db, current_user.id)
    except OllamaUnavailable:
        raise HTTPException(
            status_code=503,
            detail="The AI model is offline. Is the computer running Ollama awake?",
        )
    except ClaudeRefused:
        raise HTTPException(status_code=502, detail="Claude declined to build recommendations.")
    except (HTTPError, anthropic.APIError):
        raise HTTPException(status_code=502, detail="Could not reach the AI model.")
