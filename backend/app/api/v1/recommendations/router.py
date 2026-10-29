import anthropic
from fastapi import APIRouter, Depends, HTTPException
from httpx import HTTPError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user
from app.models.user import User
from app.services.external.claude import ClaudeRefused
from app.services.external.ollama import OllamaUnavailable
from app.services.recommendations import build_recommendations, llm

router = APIRouter()


@router.post("/preview")
async def preview_recommendations(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Build recommendations now and return them without saving.
    Slow on CPU (often a minute or more); the saved, nightly version comes next."""
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
