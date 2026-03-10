import asyncio
from abc import ABC

import httpx


class BaseAPIClient(ABC):
    def __init__(
        self,
        base_url: str,
        headers: dict | None = None,
        rate_limit: float = 1.0,  # min seconds between requests
        timeout: float = 10.0,
    ):
        self.base_url = base_url
        self.headers = headers or {}
        self.rate_limit = rate_limit
        self.timeout = timeout
        self._last_request_time = 0.0
        self._lock = asyncio.Lock()

    async def _throttle(self):
        async with self._lock:
            now = asyncio.get_event_loop().time()
            elapsed = now - self._last_request_time
            if elapsed < self.rate_limit:
                await asyncio.sleep(self.rate_limit - elapsed)
            self._last_request_time = asyncio.get_event_loop().time()

    async def _request(
        self, method: str, path: str, params: dict | None = None
    ) -> dict | list:
        await self._throttle()

        url = f"{self.base_url}{path}"
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.request(
                method, url, params=params, headers=self.headers
            )

            if response.status_code == 429:
                retry_after = int(response.headers.get("Retry-After", "2"))
                await asyncio.sleep(retry_after)
                response = await client.request(
                    method, url, params=params, headers=self.headers
                )

            response.raise_for_status()
            return response.json()

    async def get(self, path: str, params: dict | None = None) -> dict | list:
        return await self._request("GET", path, params)
