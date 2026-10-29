import json
import time

import anthropic

from app.config import settings

# $ per million tokens (input, output), for the cost line in stats
PRICES = {"claude-opus-5-5": (4.00, 20.00)}

# Keywords Claude's structured outputs may not accept. The builder validates
# counts and indices itself, so dropping them only loses an extra guard.
_UNSUPPORTED = {"minItems", "maxItems", "minimum", "maximum"}


class ClaudeRefused(Exception):
    """Claude (and its fallback) declined the request."""


def _claude_schema(node):
    """Adapt the shared JSON schema for Claude: strip keywords it may reject
    and close every object (structured outputs require additionalProperties: false)."""
    if isinstance(node, list):
        return [_claude_schema(n) for n in node]
    if not isinstance(node, dict):
        return node
    out = {k: _claude_schema(v) for k, v in node.items() if k not in _UNSUPPORTED}
    if out.get("type") == "object":
        out["additionalProperties"] = False
    return out


class ClaudeClient:
    """Same interface as OllamaClient, backed by the Anthropic API."""

    def __init__(self):
        self._client: anthropic.AsyncAnthropic | None = None

    @property
    def is_configured(self) -> bool:
        return bool(settings.ANTHROPIC_API_KEY)

    def _get(self) -> anthropic.AsyncAnthropic:
        if self._client is None:
            self._client = anthropic.AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
        return self._client

    async def chat_json(self, system: str, user: str, schema: dict) -> tuple[dict, dict]:
        started = time.monotonic()
        response = await self._get().beta.messages.create(
            model=settings.CLAUDE_MODEL,
            max_tokens=16000,
            system=system,
            messages=[{"role": "user", "content": user}],
            output_config={
                "effort": settings.CLAUDE_EFFORT,
                "format": {"type": "json_schema", "schema": _claude_schema(schema)},
            },
            # On a safety decline, the API retries on a suitable model in the same call
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
        )
        if response.stop_reason == "refusal":
            raise ClaudeRefused(getattr(response, "stop_details", None))

        # Thinking is always on for this model, so the JSON is the text block, not block 0
        text = next(b.text for b in response.content if b.type == "text")
        usage = response.usage
        price_in, price_out = PRICES.get(settings.CLAUDE_MODEL, (0.0, 0.0))
        stats = {
            "prompt_tokens": usage.input_tokens,
            "output_tokens": usage.output_tokens,
            "seconds": round(time.monotonic() - started, 1),
            "usd": round((usage.input_tokens * price_in + usage.output_tokens * price_out) / 1e6, 4),
        }
        return json.loads(text), stats


claude_client = ClaudeClient()
