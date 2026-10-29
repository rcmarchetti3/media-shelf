from app.config import settings

from .base import BaseAPIClient

PAGE_SIZE = 20


class RAWGClient(BaseAPIClient):
    """RAWG. Static API key; the free tier requires an attribution link to
    rawg.io wherever its data is shown."""

    def __init__(self):
        super().__init__(
            base_url="https://api.rawg.io/api",
            rate_limit=0.25,
        )

    @property
    def is_configured(self) -> bool:
        return bool(settings.RAWG_API_KEY)

    def _params(self, extra: dict | None = None) -> dict:
        params = {"key": settings.RAWG_API_KEY}
        if extra:
            params.update(extra)
        return params

    def _to_result(self, item: dict) -> dict:
        platforms = [
            p.get("platform", {}).get("name", "") for p in item.get("platforms") or []
        ]
        year = (item.get("released") or "")[:4]
        return {
            "external_id": f"rawg:{item.get('id')}",
            "title": item.get("name", ""),
            "subtitle": ", ".join(p for p in [year, ", ".join(platforms[:3])] if p),
            # RAWG has no box art — this is a landscape screenshot
            "image_url": item.get("background_image") or "",
            "media_type": "game",
            "year": year,
            "metadata": {
                "source": "rawg",
                "rawg_id": item.get("id"),
                "rawg_slug": item.get("slug", ""),
                "platforms": platforms,
                "genres": [g.get("name", "") for g in item.get("genres") or []],
                "metacritic": item.get("metacritic"),
                "release_date": item.get("released") or "",
            },
        }

    async def search(self, query: str, page: int = 1) -> dict:
        data = await self.get(
            "/games",
            params=self._params({"search": query, "page": page, "page_size": PAGE_SIZE}),
        )
        total = data.get("count", 0)
        return {
            "results": [self._to_result(item) for item in data.get("results", [])],
            "total": total,
            "page": page,
            "total_pages": max(1, -(-total // PAGE_SIZE)),
        }

    async def get_game(self, game_id: str) -> dict:
        data = await self.get(f"/games/{game_id}", params=self._params())
        result = self._to_result(data)
        result["metadata"].update(
            {
                "overview": data.get("description_raw", ""),
                "developer": ", ".join(d.get("name", "") for d in data.get("developers") or []),
                "publisher": ", ".join(p.get("name", "") for p in data.get("publishers") or []),
                "esrb_rating": (data.get("esrb_rating") or {}).get("name", ""),
                "website": data.get("website", ""),
            }
        )
        return result


rawg_client = RAWGClient()
