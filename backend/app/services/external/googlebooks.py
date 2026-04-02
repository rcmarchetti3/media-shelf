from app.config import settings

from .base import BaseAPIClient

API_BASE = "https://www.googleapis.com/books/v1"


class GoogleBooksClient(BaseAPIClient):
    def __init__(self):
        super().__init__(
            base_url=API_BASE,
            rate_limit=0.1,
        )

    @property
    def is_configured(self) -> bool:
        return bool(settings.GOOGLE_BOOKS_API_KEY)

    def _params(self, extra: dict | None = None) -> dict:
        params = {"key": settings.GOOGLE_BOOKS_API_KEY}
        if extra:
            params.update(extra)
        return params

    def _parse_volume(self, item: dict) -> dict:
        info = item.get("volumeInfo", {})
        images = info.get("imageLinks", {})
        # Prefer larger thumbnail; strip edge=curl param that adds a page-curl effect
        image_url = images.get("thumbnail", "").replace("&edge=curl", "").replace("zoom=1", "zoom=2")

        isbn_13 = None
        isbn_10 = None
        for identifier in info.get("industryIdentifiers", []):
            if identifier.get("type") == "ISBN_13":
                isbn_13 = identifier.get("identifier")
            elif identifier.get("type") == "ISBN_10":
                isbn_10 = identifier.get("identifier")

        published = info.get("publishedDate", "")
        year = published[:4] if published else None

        authors = info.get("authors", [])

        return {
            "external_id": item.get("id", ""),
            "title": info.get("title", ""),
            "subtitle": ", ".join(authors[:3]) if authors else None,
            "image_url": image_url or None,
            "media_type": "book",
            "year": year,
            "metadata": {
                "authors": authors,
                "publisher": info.get("publisher", ""),
                "publish_date": published,
                "page_count": info.get("pageCount"),
                "description": info.get("description", ""),
                "subjects": info.get("categories", []),
                "isbn_13": isbn_13,
                "isbn_10": isbn_10,
                "google_books_id": item.get("id", ""),
            },
        }

    async def search(self, query: str, page: int = 1) -> dict:
        start_index = (page - 1) * 20
        data = await self.get(
            "/volumes",
            params=self._params({
                "q": query,
                "startIndex": start_index,
                "maxResults": 20,
                "printType": "books",
            }),
        )

        items = data.get("items", [])
        total = data.get("totalItems", 0)
        # Google Books caps accessible results at ~1000
        capped_total = min(total, 1000)
        total_pages = (capped_total + 19) // 20 if capped_total > 0 else 0

        return {
            "results": [self._parse_volume(item) for item in items],
            "total": total,
            "page": page,
            "total_pages": total_pages,
        }

    async def get_volume(self, volume_id: str) -> dict:
        item = await self.get(f"/volumes/{volume_id}", params=self._params())
        return self._parse_volume(item)


googlebooks_client = GoogleBooksClient()
