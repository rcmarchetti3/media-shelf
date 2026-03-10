from .base import BaseAPIClient


class OpenLibraryClient(BaseAPIClient):
    def __init__(self):
        super().__init__(
            base_url="https://openlibrary.org",
            rate_limit=0.5,  # Be reasonable with public API
        )

    @property
    def is_configured(self) -> bool:
        return True  # No auth needed

    async def search(self, query: str, page: int = 1) -> dict:
        data = await self.get(
            "/search.json",
            params={"q": query, "page": page, "limit": 20},
        )

        results = []
        for doc in data.get("docs", []):
            cover_id = doc.get("cover_i")
            cover_url = (
                f"https://covers.openlibrary.org/b/id/{cover_id}-M.jpg"
                if cover_id
                else ""
            )

            results.append(
                {
                    "external_id": doc.get("key", ""),
                    "title": doc.get("title", ""),
                    "subtitle": ", ".join(doc.get("author_name", [])[:3]),
                    "image_url": cover_url,
                    "media_type": "book",
                    "year": str(doc.get("first_publish_year", "")),
                    "metadata": {
                        "authors": doc.get("author_name", []),
                        "isbn_13": (doc.get("isbn", [None])[0])
                        if doc.get("isbn")
                        else None,
                        "publisher": (doc.get("publisher", [""])[0])
                        if doc.get("publisher")
                        else "",
                        "publish_year": doc.get("first_publish_year"),
                        "subjects": doc.get("subject", [])[:10],
                        "edition_count": doc.get("edition_count", 0),
                    },
                }
            )

        return {
            "results": results,
            "total": data.get("numFound", 0),
            "page": page,
            "total_pages": (data.get("numFound", 0) + 19) // 20 if data.get("numFound", 0) > 0 else 0,
        }

    async def get_work(self, work_key: str) -> dict:
        # work_key is like "/works/OL12345W"
        data = await self.get(f"{work_key}.json")

        # Get edition data if available
        editions_data = await self.get(f"{work_key}/editions.json", params={"limit": 1})
        edition = (editions_data.get("entries", [{}])[0]) if editions_data.get("entries") else {}

        description = data.get("description", "")
        if isinstance(description, dict):
            description = description.get("value", "")

        cover_id = data.get("covers", [None])[0] if data.get("covers") else None
        cover_url = (
            f"https://covers.openlibrary.org/b/id/{cover_id}-L.jpg"
            if cover_id
            else ""
        )

        authors = []
        for author_ref in data.get("authors", []):
            author_key = author_ref.get("author", {}).get("key", "")
            if author_key:
                try:
                    author_data = await self.get(f"{author_key}.json")
                    authors.append(author_data.get("name", ""))
                except Exception:
                    pass

        return {
            "external_id": work_key,
            "title": data.get("title", ""),
            "image_url": cover_url,
            "media_type": "book",
            "metadata": {
                "authors": authors,
                "description": description,
                "subjects": [s for s in data.get("subjects", [])[:15]],
                "isbn_13": edition.get("isbn_13", [None])[0] if edition.get("isbn_13") else None,
                "isbn_10": edition.get("isbn_10", [None])[0] if edition.get("isbn_10") else None,
                "publisher": (edition.get("publishers", [""])[0]) if edition.get("publishers") else "",
                "publish_date": edition.get("publish_date", ""),
                "page_count": edition.get("number_of_pages"),
                "open_library_key": work_key,
            },
        }


openlibrary_client = OpenLibraryClient()
