from pydantic import BaseModel


class SearchResult(BaseModel):
    external_id: str
    title: str
    subtitle: str | None = None
    image_url: str | None = None
    media_type: str
    year: str | None = None
    metadata: dict = {}


class SearchResponse(BaseModel):
    results: list[SearchResult]
    total: int
    page: int
    total_pages: int
