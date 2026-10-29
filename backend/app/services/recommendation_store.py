"""Saved recommendations and the daily refresh loop.

The model may run on a laptop that sleeps, so there's no fixed nightly time:
every hour the loop refreshes anyone whose picks are older than
RECOMMENDATIONS_REFRESH_HOURS. If the model is unreachable it tries again the
next hour, and the last good picks stay in place until then.
"""

import asyncio
import logging
import uuid
from datetime import datetime, timedelta, timezone

import anthropic
import httpx
from sqlalchemy import or_, select

from app.config import settings
from app.database import async_session
from app.models.collection_item import CollectionItem
from app.models.recommendation import Recommendation
from app.services.external.claude import ClaudeRefused
from app.services.external.ollama import OllamaUnavailable
from app.services.recommendations import build_recommendations, llm

log = logging.getLogger(__name__)

CHECK_INTERVAL_SECONDS = 3600
STARTUP_DELAY_SECONDS = 60

# One model run at a time: Ollama serves a single request at once anyway,
# and this keeps a button press from racing the hourly loop.
_lock = asyncio.Lock()


def is_refreshing() -> bool:
    return _lock.locked()


def _provider_label() -> str:
    if settings.AI_PROVIDER == "claude":
        return f"claude:{settings.CLAUDE_MODEL}"
    return f"ollama:{settings.OLLAMA_MODEL}"


def _error_message(e: Exception) -> str:
    if isinstance(e, OllamaUnavailable):
        return "The AI model is offline. Is the computer running Ollama awake?"
    if isinstance(e, ClaudeRefused):
        return "Claude declined to build recommendations."
    return "Could not reach the AI model."


async def refresh_user(user_id: uuid.UUID) -> None:
    """Build and save one user's picks. Raises the model's error after recording it."""
    async with _lock, async_session() as db:
        row = await db.get(Recommendation, user_id) or Recommendation(user_id=user_id)
        row.last_attempt_at = datetime.now(timezone.utc)
        try:
            result = await build_recommendations(db, user_id)
        except (OllamaUnavailable, ClaudeRefused, httpx.HTTPError, anthropic.APIError) as e:
            row.last_error = _error_message(e)
            db.add(row)
            await db.commit()
            raise
        row.items = result["recommendations"]
        row.stats = result["stats"]
        row.provider = _provider_label()
        row.generated_at = row.last_attempt_at
        row.last_error = None
        db.add(row)
        await db.commit()


async def _stale_user_ids() -> list[uuid.UUID]:
    """Users with something in their library whose picks are missing or old."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=settings.RECOMMENDATIONS_REFRESH_HOURS)
    async with async_session() as db:
        query = (
            select(CollectionItem.user_id)
            .distinct()
            .outerjoin(Recommendation, Recommendation.user_id == CollectionItem.user_id)
            .where(or_(Recommendation.generated_at.is_(None), Recommendation.generated_at < cutoff))
        )
        return list((await db.execute(query)).scalars())


async def refresh_loop() -> None:
    """Started at app startup; runs for the life of the process."""
    await asyncio.sleep(STARTUP_DELAY_SECONDS)
    while True:
        if llm().is_configured:
            try:
                for user_id in await _stale_user_ids():
                    try:
                        await refresh_user(user_id)
                    except OllamaUnavailable:
                        break  # the Mac is asleep; no point trying the other users
                    except Exception:
                        log.exception("Recommendation refresh failed for %s", user_id)
            except Exception:
                log.exception("Recommendation refresh loop error")
        await asyncio.sleep(CHECK_INTERVAL_SECONDS)
