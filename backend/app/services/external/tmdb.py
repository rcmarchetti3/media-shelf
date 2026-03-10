from app.config import settings

from .base import BaseAPIClient

IMAGE_BASE = "https://image.tmdb.org/t/p/w500"


class TMDBClient(BaseAPIClient):
    def __init__(self):
        super().__init__(
            base_url="https://api.themoviedb.org/3",
            rate_limit=0.25,  # ~40 req/10sec
        )

    @property
    def is_configured(self) -> bool:
        return bool(settings.TMDB_API_KEY)

    def _params(self, extra: dict | None = None) -> dict:
        params = {"api_key": settings.TMDB_API_KEY}
        if extra:
            params.update(extra)
        return params

    async def search_movies(self, query: str, page: int = 1) -> dict:
        data = await self.get(
            "/search/movie",
            params=self._params({"query": query, "page": page}),
        )

        results = []
        for item in data.get("results", []):
            poster = item.get("poster_path", "")
            results.append(
                {
                    "external_id": str(item.get("id", "")),
                    "title": item.get("title", ""),
                    "subtitle": (item.get("release_date", ""))[:4],
                    "image_url": f"{IMAGE_BASE}{poster}" if poster else "",
                    "media_type": "movie",
                    "year": (item.get("release_date", ""))[:4],
                    "metadata": {
                        "tmdb_id": item.get("id"),
                        "overview": item.get("overview", ""),
                        "release_date": item.get("release_date", ""),
                        "vote_average": item.get("vote_average", 0),
                        "genre_ids": item.get("genre_ids", []),
                    },
                }
            )

        return {
            "results": results,
            "total": data.get("total_results", 0),
            "page": data.get("page", 1),
            "total_pages": data.get("total_pages", 1),
        }

    async def search_shows(self, query: str, page: int = 1) -> dict:
        data = await self.get(
            "/search/tv",
            params=self._params({"query": query, "page": page}),
        )

        results = []
        for item in data.get("results", []):
            poster = item.get("poster_path", "")
            results.append(
                {
                    "external_id": str(item.get("id", "")),
                    "title": item.get("name", ""),
                    "subtitle": (item.get("first_air_date", ""))[:4],
                    "image_url": f"{IMAGE_BASE}{poster}" if poster else "",
                    "media_type": "show",
                    "year": (item.get("first_air_date", ""))[:4],
                    "metadata": {
                        "tmdb_id": item.get("id"),
                        "overview": item.get("overview", ""),
                        "first_air_date": item.get("first_air_date", ""),
                        "vote_average": item.get("vote_average", 0),
                        "genre_ids": item.get("genre_ids", []),
                    },
                }
            )

        return {
            "results": results,
            "total": data.get("total_results", 0),
            "page": data.get("page", 1),
            "total_pages": data.get("total_pages", 1),
        }

    async def get_movie(self, movie_id: str) -> dict:
        data = await self.get(
            f"/movie/{movie_id}",
            params=self._params({"append_to_response": "credits"}),
        )

        poster = data.get("poster_path", "")
        backdrop = data.get("backdrop_path", "")
        credits = data.get("credits", {})

        director = next(
            (c.get("name", "") for c in credits.get("crew", []) if c.get("job") == "Director"),
            "",
        )
        cast = [
            {"name": c.get("name", ""), "character": c.get("character", "")}
            for c in credits.get("cast", [])[:10]
        ]
        genres = [g.get("name", "") for g in data.get("genres", [])]

        return {
            "external_id": str(data.get("id", "")),
            "title": data.get("title", ""),
            "image_url": f"{IMAGE_BASE}{poster}" if poster else "",
            "media_type": "movie",
            "metadata": {
                "tmdb_id": data.get("id"),
                "overview": data.get("overview", ""),
                "release_date": data.get("release_date", ""),
                "runtime": data.get("runtime"),
                "genres": genres,
                "director": director,
                "cast": cast,
                "vote_average": data.get("vote_average", 0),
                "backdrop_url": f"{IMAGE_BASE}{backdrop}" if backdrop else "",
                "budget": data.get("budget", 0),
                "revenue": data.get("revenue", 0),
                "tagline": data.get("tagline", ""),
            },
        }

    async def get_show(self, show_id: str) -> dict:
        data = await self.get(
            f"/tv/{show_id}",
            params=self._params({"append_to_response": "credits"}),
        )

        poster = data.get("poster_path", "")
        backdrop = data.get("backdrop_path", "")
        genres = [g.get("name", "") for g in data.get("genres", [])]
        networks = [n.get("name", "") for n in data.get("networks", [])]
        credits = data.get("credits", {})
        cast = [
            {"name": c.get("name", ""), "character": c.get("character", "")}
            for c in credits.get("cast", [])[:10]
        ]

        return {
            "external_id": str(data.get("id", "")),
            "title": data.get("name", ""),
            "image_url": f"{IMAGE_BASE}{poster}" if poster else "",
            "media_type": "show",
            "metadata": {
                "tmdb_id": data.get("id"),
                "overview": data.get("overview", ""),
                "first_air_date": data.get("first_air_date", ""),
                "status": data.get("status", ""),
                "genres": genres,
                "networks": networks,
                "seasons_count": data.get("number_of_seasons", 0),
                "episodes_count": data.get("number_of_episodes", 0),
                "vote_average": data.get("vote_average", 0),
                "backdrop_url": f"{IMAGE_BASE}{backdrop}" if backdrop else "",
                "cast": cast,
            },
        }


tmdb_client = TMDBClient()
