import time
from datetime import datetime, timezone

import httpx

from app.config import settings

from .base import BaseAPIClient

IMAGE_BASE = "https://images.igdb.com/igdb/image/upload/t_cover_big"
TOKEN_URL = "https://id.twitch.tv/oauth2/token"
PAGE_SIZE = 20

SEARCH_FIELDS = (
    "name, first_release_date, cover.image_id, platforms.name, genres.name, "
    "involved_companies.company.name, involved_companies.developer, "
    "summary, total_rating"
)
DETAIL_FIELDS = SEARCH_FIELDS + (
    ", involved_companies.publisher, game_modes.name, franchises.name, "
    "storyline, url, aggregated_rating"
)


def _year(ts: int | None) -> str:
    if not ts:
        return ""
    return str(datetime.fromtimestamp(ts, tz=timezone.utc).year)


def _companies(item: dict, role: str) -> list[str]:
    return [
        c.get("company", {}).get("name", "")
        for c in item.get("involved_companies", [])
        if c.get(role)
    ]


class IGDBClient(BaseAPIClient):
    """IGDB (Twitch). Auth is an app access token from the client-credentials
    flow, cached in memory and refreshed shortly before it expires."""

    def __init__(self):
        super().__init__(
            base_url="https://api.igdb.com/v4",
            rate_limit=0.25,  # 4 req/sec
        )
        self._token: str | None = None
        self._token_expires_at = 0.0

    @property
    def is_configured(self) -> bool:
        return bool(settings.IGDB_CLIENT_ID and settings.IGDB_CLIENT_SECRET)

    async def _ensure_token(self, force: bool = False):
        # Refresh a minute early so a request never goes out with a dying token
        if not force and self._token and time.time() < self._token_expires_at - 60:
            return
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                TOKEN_URL,
                params={
                    "client_id": settings.IGDB_CLIENT_ID,
                    "client_secret": settings.IGDB_CLIENT_SECRET,
                    "grant_type": "client_credentials",
                },
            )
            response.raise_for_status()
            data = response.json()
        self._token = data["access_token"]
        self._token_expires_at = time.time() + data.get("expires_in", 0)
        self.headers = {
            "Client-ID": settings.IGDB_CLIENT_ID,
            "Authorization": f"Bearer {self._token}",
            "Accept": "application/json",
        }

    async def _query(self, endpoint: str, body: str) -> dict | list:
        await self._ensure_token()
        try:
            return await self.post(endpoint, body)
        except httpx.HTTPStatusError as e:
            # Token revoked or rotated server-side: refresh once and retry
            if e.response.status_code != 401:
                raise
            await self._ensure_token(force=True)
            return await self.post(endpoint, body)

    @staticmethod
    def _escape(query: str) -> str:
        return query.replace("\\", "\\\\").replace('"', '\\"')

    def _to_result(self, item: dict) -> dict:
        cover = item.get("cover", {}).get("image_id")
        platforms = [p.get("name", "") for p in item.get("platforms", [])]
        year = _year(item.get("first_release_date"))
        return {
            "external_id": f"igdb:{item.get('id')}",
            "title": item.get("name", ""),
            "subtitle": ", ".join(p for p in [year, ", ".join(platforms[:3])] if p),
            "image_url": f"{IMAGE_BASE}/{cover}.jpg" if cover else "",
            "media_type": "game",
            "year": year,
            "metadata": {
                "source": "igdb",
                "igdb_id": item.get("id"),
                "overview": item.get("summary", ""),
                "platforms": platforms,
                "genres": [g.get("name", "") for g in item.get("genres", [])],
                "developer": ", ".join(_companies(item, "developer")),
                "rating": round(item.get("total_rating") or 0),
            },
        }

    async def search(self, query: str, page: int = 1) -> dict:
        q = self._escape(query)
        # Editions/remasters bundles have a version_parent; skip them to keep results clean
        where = "where version_parent = null;"
        data = await self._query(
            "/games",
            f'search "{q}"; fields {SEARCH_FIELDS}; {where} '
            f"limit {PAGE_SIZE}; offset {(page - 1) * PAGE_SIZE};",
        )
        count = await self._query("/games/count", f'search "{q}"; {where}')
        total = count.get("count", 0) if isinstance(count, dict) else 0

        return {
            "results": [self._to_result(item) for item in data],
            "total": total,
            "page": page,
            "total_pages": max(1, -(-total // PAGE_SIZE)),
        }

    async def get_game(self, game_id: str) -> dict:
        data = await self._query(
            "/games", f"fields {DETAIL_FIELDS}; where id = {int(game_id)};"
        )
        if not data:
            raise httpx.HTTPStatusError(
                "Game not found",
                request=httpx.Request("POST", f"{self.base_url}/games"),
                response=httpx.Response(404),
            )
        item = data[0]
        result = self._to_result(item)
        result["metadata"].update(
            {
                "publisher": ", ".join(_companies(item, "publisher")),
                "game_modes": [m.get("name", "") for m in item.get("game_modes", [])],
                "franchises": [f.get("name", "") for f in item.get("franchises", [])],
                "storyline": item.get("storyline", ""),
                "critic_rating": round(item.get("aggregated_rating") or 0),
                "igdb_url": item.get("url", ""),
            }
        )
        return result


igdb_client = IGDBClient()
