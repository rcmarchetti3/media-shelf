from fastapi import APIRouter, Depends, HTTPException, Query
from httpx import HTTPStatusError, RequestError

from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.search import SearchResponse
from app.services.external.discogs import discogs_client
from app.services.external.openlibrary import openlibrary_client
from app.services.external.tmdb import tmdb_client

router = APIRouter()


def _api_not_configured(name: str):
    raise HTTPException(
        status_code=503,
        detail=f"{name} API key is not configured. Add it in Settings.",
    )


async def _handle_external_call(coro, api_name: str):
    try:
        return await coro
    except HTTPStatusError as e:
        raise HTTPException(
            status_code=502,
            detail=f"{api_name} returned an error: {e.response.status_code}",
        )
    except RequestError:
        raise HTTPException(
            status_code=502,
            detail=f"Could not reach {api_name}. Please try again later.",
        )


@router.get("/vinyl", response_model=SearchResponse)
async def search_vinyl(
    q: str = Query(min_length=1),
    page: int = Query(1, ge=1),
    current_user: User = Depends(get_current_user),
):
    if not discogs_client.is_configured:
        _api_not_configured("Discogs")
    return await _handle_external_call(discogs_client.search(q, page), "Discogs")


@router.get("/books", response_model=SearchResponse)
async def search_books(
    q: str = Query(min_length=1),
    page: int = Query(1, ge=1),
    current_user: User = Depends(get_current_user),
):
    return await _handle_external_call(openlibrary_client.search(q, page), "Open Library")


@router.get("/movies", response_model=SearchResponse)
async def search_movies(
    q: str = Query(min_length=1),
    page: int = Query(1, ge=1),
    current_user: User = Depends(get_current_user),
):
    if not tmdb_client.is_configured:
        _api_not_configured("TMDB")
    return await _handle_external_call(tmdb_client.search_movies(q, page), "TMDB")


@router.get("/shows", response_model=SearchResponse)
async def search_shows(
    q: str = Query(min_length=1),
    page: int = Query(1, ge=1),
    current_user: User = Depends(get_current_user),
):
    if not tmdb_client.is_configured:
        _api_not_configured("TMDB")
    return await _handle_external_call(tmdb_client.search_shows(q, page), "TMDB")


@router.get("/{media_type}/{external_id}")
async def get_item_details(
    media_type: str,
    external_id: str,
    current_user: User = Depends(get_current_user),
):
    if media_type == "vinyl":
        if not discogs_client.is_configured:
            _api_not_configured("Discogs")
        return await _handle_external_call(
            discogs_client.get_release(external_id), "Discogs"
        )
    elif media_type == "book":
        return await _handle_external_call(
            openlibrary_client.get_work(external_id), "Open Library"
        )
    elif media_type == "movie":
        if not tmdb_client.is_configured:
            _api_not_configured("TMDB")
        return await _handle_external_call(
            tmdb_client.get_movie(external_id), "TMDB"
        )
    elif media_type == "show":
        if not tmdb_client.is_configured:
            _api_not_configured("TMDB")
        return await _handle_external_call(
            tmdb_client.get_show(external_id), "TMDB"
        )
    else:
        raise HTTPException(status_code=400, detail=f"Unknown media type: {media_type}")
