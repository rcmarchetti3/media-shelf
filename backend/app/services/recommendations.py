"""AI recommendations from the owner's library.

The model never gets the last word on what exists. Candidates come from real
catalogs (TMDB's own recommendations, plus model suggestions that must match a
real search result), and the model only picks from that list and explains why.
That keeps a small local model from recommending things that don't exist.
"""

import re
import time
import uuid

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.collection_item import CollectionItem
from app.services.external.claude import claude_client
from app.services.external.discogs import discogs_client
from app.services.external.googlebooks import googlebooks_client
from app.services.external.igdb import igdb_client
from app.services.external.ollama import ollama_client
from app.services.external.rawg import rawg_client
from app.services.external.tmdb import tmdb_client

PROFILE_PER_TYPE = 6
TMDB_SEEDS_PER_TYPE = 3
TMDB_RECS_PER_SEED = 4
MAX_CANDIDATES = 40
MAX_PICKS = 10

# How much a status says "I liked this", on top of the star rating
STATUS_WEIGHT = {
    "completed": 2, "beat": 2, "watched": 2,
    "watching": 1, "playing": 1, "reading": 1, "owned": 1,
}
SUGGESTABLE_TYPES = ["vinyl", "book", "game", "audiobook"]


def llm():
    """The configured model provider; both expose is_configured and chat_json()."""
    return claude_client if settings.AI_PROVIDER == "claude" else ollama_client


def _norm(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


def _creator(item: CollectionItem) -> str:
    meta = item.metadata_ or {}
    for key in ("artist", "author", "developer", "director"):
        if meta.get(key):
            return str(meta[key])
    for key in ("artists", "authors"):
        if isinstance(meta.get(key), list) and meta[key]:
            return ", ".join(meta[key][:2])
    return ""


def _score(item: CollectionItem) -> int:
    return (item.rating or 0) * 2 + (3 if item.is_favorite else 0) + STATUS_WEIGHT.get(item.status or "", 0)


def build_profile(items: list[CollectionItem]) -> dict[str, list[CollectionItem]]:
    """Top items per media type: what the owner rated, favorited or finished,
    newest first among ties. A few per type keeps the prompt small enough for
    CPU inference while still covering every kind of media they collect."""
    by_type: dict[str, list[CollectionItem]] = {}
    for item in items:
        if item.status == "dropped":
            continue
        by_type.setdefault(item.media_type, []).append(item)
    return {
        media_type: sorted(group, key=lambda i: (_score(i), i.added_at), reverse=True)[:PROFILE_PER_TYPE]
        for media_type, group in by_type.items()
    }


def _profile_text(profile: dict[str, list[CollectionItem]]) -> str:
    lines = []
    for media_type, group in profile.items():
        for item in group:
            creator = _creator(item)
            stars = f" {item.rating}/5" if item.rating else ""
            lines.append(f"- [{media_type}] {item.title}{f' by {creator}' if creator else ''}{stars}")
    return "\n".join(lines)


def _candidate_line(n: int, c: dict) -> str:
    line = f"{n}. [{c['media_type']}] {c['title']}"
    if c.get("year"):
        line += f" ({c['year']})"
    if c.get("because"):
        line += f" — similar to {c['because']}"
    return line


async def _search_one(media_type: str, title: str, creator: str) -> dict | None:
    """First real catalog hit whose title matches the suggestion, else None."""
    query = f"{title} {creator}".strip()
    try:
        if media_type == "vinyl" and discogs_client.is_configured:
            data = await discogs_client.search(query)
        elif media_type in ("book", "audiobook") and googlebooks_client.is_configured:
            data = await googlebooks_client.search(query)
        elif media_type == "game" and igdb_client.is_configured:
            data = await igdb_client.search(title)
        elif media_type == "game" and rawg_client.is_configured:
            data = await rawg_client.search(title)
        else:
            return None
    except (httpx.HTTPError, KeyError):
        return None

    wanted = _norm(title)
    for result in data.get("results", [])[:5]:
        # Discogs titles are "Artist - Album"; a substring match covers both shapes
        if wanted and wanted in _norm(result.get("title", "")):
            return {**result, "media_type": media_type}
    return None


async def _tmdb_candidates(profile: dict[str, list[CollectionItem]]) -> list[dict]:
    if not tmdb_client.is_configured:
        return []
    candidates = []
    for media_type in ("movie", "show"):
        seeds = [i for i in profile.get(media_type, []) if (i.metadata_ or {}).get("tmdb_id")]
        for seed in seeds[:TMDB_SEEDS_PER_TYPE]:
            try:
                recs = await tmdb_client.recommendations(media_type, seed.metadata_["tmdb_id"])
            except httpx.HTTPError:
                continue
            candidates += [{**r, "because": seed.title} for r in recs[:TMDB_RECS_PER_SEED]]
    return candidates


SUGGESTIONS_PER_TYPE = 4

# minItems matters: without it an empty list is valid output, and the model
# takes that shortcut. Ollama enforces these bounds while generating.
SUGGEST_SCHEMA = {
    "type": "object",
    "properties": {
        "suggestions": {
            "type": "array",
            "minItems": SUGGESTIONS_PER_TYPE,
            "maxItems": SUGGESTIONS_PER_TYPE,
            "items": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "creator": {"type": "string"},
                },
                "required": ["title", "creator"],
            },
        }
    },
    "required": ["suggestions"],
}

SUGGEST_HINTS = {
    "vinyl": "albums on vinyl; title is the album, creator is the artist",
    "book": "books; creator is the author",
    "audiobook": "audiobooks; creator is the author",
    "game": "video games; creator is the developer",
}


def _rank_schema(pool_size: int) -> dict:
    picks = min(MAX_PICKS, pool_size)
    return {
        "type": "object",
        "properties": {
            "picks": {
                "type": "array",
                "minItems": picks,
                "maxItems": picks,
                "items": {
                    "type": "object",
                    "properties": {
                        "candidate": {"type": "integer", "minimum": 0, "maximum": pool_size - 1},
                        "reason": {"type": "string"},
                    },
                    "required": ["candidate", "reason"],
                },
            }
        },
        "required": ["picks"],
    }


async def build_recommendations(db: AsyncSession, user_id: uuid.UUID) -> dict:
    started = time.monotonic()
    items = list(
        (await db.execute(select(CollectionItem).where(CollectionItem.user_id == user_id))).scalars()
    )
    profile = build_profile(items)
    profile_text = _profile_text(profile)
    owned_ids = {(i.media_type, i.external_id) for i in items if i.external_id}
    owned_titles = {_norm(i.title) for i in items}
    llm_stats = []

    # 1. Model suggests music/books/games, one type per call (asked for all at
    #    once, it fills up on the first type), each verified against a real catalog.
    #    These go first so the candidate cap below can't crowd them out.
    candidates, suggested_count = [], 0
    for media_type in (t for t in SUGGESTABLE_TYPES if t in profile):
        suggested, stats = await llm().chat_json(
            system=(
                "You recommend media to a collector. Suggest real, well-known titles "
                "that are NOT in their library. Use exact official titles."
            ),
            user=(
                f"Their favorites:\n{profile_text}\n\n"
                f"Suggest {SUGGESTIONS_PER_TYPE} {SUGGEST_HINTS[media_type]}, "
                "matched to the tastes above."
            ),
            schema=SUGGEST_SCHEMA,
        )
        llm_stats.append({"step": f"suggest:{media_type}", **stats})
        for s in suggested.get("suggestions", []):
            suggested_count += 1
            match = await _search_one(media_type, s["title"], s.get("creator", ""))
            if match:
                candidates.append({**match, "because": None})
    verified_count = len(candidates)

    # 2. Real candidates for film/TV straight from TMDB
    candidates += await _tmdb_candidates(profile)

    # 3. Drop owned and duplicate candidates
    seen, pool = set(), []
    for c in candidates:
        key = (c["media_type"], c["external_id"])
        if key in owned_ids or key in seen or _norm(c["title"]) in owned_titles:
            continue
        seen.add(key)
        pool.append(c)
    pool = pool[:MAX_CANDIDATES]
    if not pool:
        return {"recommendations": [], "stats": {"candidates": 0, "llm": llm_stats}}

    # 4. Model picks the best and explains each pick against the library
    listing = "\n".join(_candidate_line(n, c) for n, c in enumerate(pool))
    ranked, stats = await llm().chat_json(
        system=(
            "You pick recommendations for a collector from a numbered candidate list. "
            "Only use candidate numbers from the list. Each reason is one short sentence "
            "that names a specific title from their library."
        ),
        user=(
            f"Their favorites:\n{profile_text}\n\nCandidates:\n{listing}\n\n"
            f"Pick the {MAX_PICKS} best matches, varied across media types."
        ),
        schema=_rank_schema(len(pool)),
    )
    llm_stats.append({"step": "rank", **stats})

    picks, used = [], set()
    for p in ranked.get("picks", []):
        n = p.get("candidate")
        if isinstance(n, int) and 0 <= n < len(pool) and n not in used:
            used.add(n)
            picks.append({**pool[n], "reason": p.get("reason", "").strip()})

    return {
        "recommendations": picks,
        "stats": {
            "library_items": len(items),
            "profile_items": sum(len(g) for g in profile.values()),
            "suggested": suggested_count,
            "verified": verified_count,
            "candidates": len(pool),
            "llm": llm_stats,
            "total_seconds": round(time.monotonic() - started, 1),
        },
    }
