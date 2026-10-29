from fastapi import APIRouter, Depends, HTTPException, Query
from httpx import HTTPStatusError, RequestError

from app.dependencies import get_current_user
from app.models.user import User
from app.schemas.search import SearchResponse
from app.services.external.discogs import discogs_client
from app.services.external.googlebooks import googlebooks_client
from app.services.external.igdb import igdb_client
from app.services.external.rawg import rawg_client
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
    if not googlebooks_client.is_configured:
        _api_not_configured("Google Books")
    return await _handle_external_call(googlebooks_client.search(q, page), "Google Books")


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


GAME_PROVIDERS = {"igdb": (igdb_client, "IGDB"), "rawg": (rawg_client, "RAWG")}


async def _search_games(q: str, page: int) -> dict:
    """Search games with whichever provider(s) are configured.

    igdb_client and rawg_client both expose .is_configured and
    .search(q, page) -> SearchResponse dict. External IDs come back
    prefixed ("igdb:1942" / "rawg:3328") so details can be routed later.
    """
    # Prefer IGDB (real portrait box art); RAWG covers for it if IGDB is
    # unconfigured or down. RAWG images are landscape screenshots.
    providers = [p for p in GAME_PROVIDERS.values() if p[0].is_configured]
    for i, (client, name) in enumerate(providers):
        try:
            return await _handle_external_call(client.search(q, page), name)
        except HTTPException:
            if i == len(providers) - 1:
                raise


@router.get("/games", response_model=SearchResponse)
async def search_games(
    q: str = Query(min_length=1),
    page: int = Query(1, ge=1),
    current_user: User = Depends(get_current_user),
):
    if not igdb_client.is_configured and not rawg_client.is_configured:
        _api_not_configured("IGDB or RAWG")
    return await _search_games(q, page)


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
        if not googlebooks_client.is_configured:
            _api_not_configured("Google Books")
        return await _handle_external_call(
            googlebooks_client.get_volume(external_id), "Google Books"
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
    elif media_type == "game":
        # external_id is "<provider>:<id>"; the prefix picks the API
        provider, _, game_id = external_id.partition(":")
        if provider not in GAME_PROVIDERS or not game_id:
            raise HTTPException(status_code=400, detail=f"Bad game id: {external_id}")
        client, name = GAME_PROVIDERS[provider]
        if not client.is_configured:
            _api_not_configured(name)
        return await _handle_external_call(client.get_game(game_id), name)
    else:
        raise HTTPException(status_code=400, detail=f"Unknown media type: {media_type}")
