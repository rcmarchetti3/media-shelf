from app.config import settings

from .base import BaseAPIClient


class DiscogsClient(BaseAPIClient):
    def __init__(self):
        super().__init__(
            base_url="https://api.discogs.com",
            headers={
                "Authorization": f"Discogs token={settings.DISCOGS_TOKEN}",
                "User-Agent": "MediaShelf/1.0",
            },
            rate_limit=1.0,  # 60 req/min = 1 req/sec
        )

    @property
    def is_configured(self) -> bool:
        return bool(settings.DISCOGS_TOKEN)

    async def search(self, query: str, page: int = 1) -> dict:
        data = await self.get(
            "/database/search",
            params={"q": query, "type": "release", "page": page, "per_page": 20},
        )

        results = []
        for item in data.get("results", []):
            results.append(
                {
                    "external_id": str(item.get("id", "")),
                    "title": item.get("title", ""),
                    "subtitle": ", ".join(item.get("format", [])),
                    "image_url": item.get("cover_image", ""),
                    "media_type": "vinyl",
                    "year": str(item.get("year", "")),
                    "metadata": {
                        "genres": item.get("genre", []),
                        "styles": item.get("style", []),
                        "label": (item.get("label", [""]))[0] if item.get("label") else "",
                        "catalog_number": item.get("catno", ""),
                        "format_details": ", ".join(item.get("format", [])),
                        "country": item.get("country", ""),
                    },
                }
            )

        pagination = data.get("pagination", {})
        return {
            "results": results,
            "total": pagination.get("items", 0),
            "page": pagination.get("page", 1),
            "total_pages": pagination.get("pages", 1),
        }

    async def get_release(self, release_id: str) -> dict:
        data = await self.get(f"/releases/{release_id}")

        artists = [a.get("name", "") for a in data.get("artists", [])]
        tracklist = [
            {
                "position": t.get("position", ""),
                "title": t.get("title", ""),
                "duration": t.get("duration", ""),
            }
            for t in data.get("tracklist", [])
        ]

        return {
            "external_id": str(data.get("id", "")),
            "title": data.get("title", ""),
            "image_url": (data.get("images", [{}])[0].get("uri", ""))
            if data.get("images")
            else "",
            "media_type": "vinyl",
            "metadata": {
                "artists": artists,
                "year": data.get("year", 0),
                "genres": data.get("genres", []),
                "styles": data.get("styles", []),
                "label": (data.get("labels", [{}])[0].get("name", ""))
                if data.get("labels")
                else "",
                "catalog_number": (data.get("labels", [{}])[0].get("catno", ""))
                if data.get("labels")
                else "",
                "format_details": ", ".join(
                    f.get("name", "")
                    for f in data.get("formats", [])
                ),
                "country": data.get("country", ""),
                "tracklist": tracklist,
                "discogs_url": data.get("uri", ""),
                "barcode": next(
                    (
                        i.get("value", "")
                        for i in data.get("identifiers", [])
                        if i.get("type") == "Barcode"
                    ),
                    "",
                ),
            },
        }


discogs_client = DiscogsClient()
