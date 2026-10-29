import json

import httpx

from app.config import settings


class OllamaUnavailable(Exception):
    """The Ollama host didn't answer: usually the Mac running it is asleep or away."""


class OllamaClient:
    """Thin client for an Ollama server, often on another machine on the LAN.
    Every call asks for structured output: Ollama constrains generation to the
    given JSON schema, so the model can't wander into prose or malformed JSON."""

    def __init__(self):
        # Connecting should be instant on a LAN, so give up fast when the host
        # is asleep; generating can take minutes on CPU, so reading waits long.
        self.timeout = httpx.Timeout(600.0, connect=5.0)

    @property
    def is_configured(self) -> bool:
        return bool(settings.OLLAMA_URL)

    async def chat_json(self, system: str, user: str, schema: dict) -> tuple[dict, dict]:
        """Returns (parsed JSON matching schema, timing stats)."""
        payload = {
            "model": settings.OLLAMA_MODEL,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "format": schema,
            "stream": False,
            "think": False,  # qwen3 reasons out loud by default; we only want the answer
            "options": {"temperature": 0.3, "num_ctx": 8192},
        }
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(f"{settings.OLLAMA_URL}/api/chat", json=payload)
                # Models without a thinking mode (e.g. gemma3) reject the flag outright
                if response.status_code == 400 and "think" in response.text:
                    del payload["think"]
                    response = await client.post(f"{settings.OLLAMA_URL}/api/chat", json=payload)
        except (httpx.ConnectError, httpx.ConnectTimeout) as e:
            raise OllamaUnavailable(settings.OLLAMA_URL) from e
        response.raise_for_status()
        data = response.json()

        stats = {
            "prompt_tokens": data.get("prompt_eval_count", 0),
            "output_tokens": data.get("eval_count", 0),
            "seconds": round(data.get("total_duration", 0) / 1e9, 1),
        }
        return json.loads(data["message"]["content"]), stats


ollama_client = OllamaClient()
