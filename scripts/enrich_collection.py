#!/usr/bin/env python3
"""Enrich existing collection items with cover art and metadata from external APIs."""

import asyncio
import json
import sys
import urllib.request

import httpx

API_BASE = "http://localhost:8000/api/v1"
DISCOGS_BASE = "https://api.discogs.com"
TMDB_BASE = "https://api.themoviedb.org/3"
TMDB_IMG = "https://image.tmdb.org/t/p/w500"
OL_BASE = "https://openlibrary.org"
OL_COVER = "https://covers.openlibrary.org/b/id"

# Read from .env
DISCOGS_TOKEN = ""
TMDB_API_KEY = ""

def load_env():
    global DISCOGS_TOKEN, TMDB_API_KEY
    try:
        with open("/Users/richardmarchetti/Documents/media_shelf/.env") as f:
            for line in f:
                line = line.strip()
                if line.startswith("DISCOGS_TOKEN="):
                    DISCOGS_TOKEN = line.split("=", 1)[1]
                elif line.startswith("TMDB_API_KEY="):
                    TMDB_API_KEY = line.split("=", 1)[1]
    except FileNotFoundError:
        pass


def get_token(username: str, password: str) -> str:
    data = json.dumps({"username": username, "password": password}).encode()
    req = urllib.request.Request(
        f"{API_BASE}/auth/login",
        data=data,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())["access_token"]


def get_all_items(token: str) -> list[dict]:
    items = []
    page = 1
    while True:
        req = urllib.request.Request(
            f"{API_BASE}/collection/?page={page}&page_size=100&sort_by=title&sort_order=asc",
            headers={"Authorization": f"Bearer {token}"},
        )
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read())
        items.extend(data["items"])
        if page >= data["total_pages"]:
            break
        page += 1
    return items


def patch_item(token: str, item_id: str, updates: dict):
    data = json.dumps(updates).encode()
    req = urllib.request.Request(
        f"{API_BASE}/collection/{item_id}",
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
        },
        method="PATCH",
    )
    urllib.request.urlopen(req)


async def enrich_vinyl(client: httpx.AsyncClient, item: dict) -> dict | None:
    metadata = item.get("metadata", {})
    artist = metadata.get("artist", "")
    title = item["title"]
    query = f"{artist} {title}".strip()
    if not query:
        return None

    resp = await client.get(
        f"{DISCOGS_BASE}/database/search",
        params={"q": query, "type": "release", "per_page": 5},
        headers={
            "Authorization": f"Discogs token={DISCOGS_TOKEN}",
            "User-Agent": "MediaShelf/1.0",
        },
    )
    if resp.status_code != 200:
        return None

    results = resp.json().get("results", [])
    if not results:
        return None

    # Pick best match — prefer exact title match
    best = results[0]
    for r in results:
        r_title = r.get("title", "").lower()
        if title.lower() in r_title and (not artist or artist.lower() in r_title):
            best = r
            break

    cover = best.get("cover_image", "")
    if not cover or "spacer" in cover:
        return None

    updates = {"image_url": cover}
    # Merge in richer metadata
    new_meta = dict(metadata)
    if best.get("genre"):
        new_meta["genres"] = best["genre"]
    if best.get("style"):
        new_meta["styles"] = best["style"]
    if best.get("label"):
        new_meta["label"] = best["label"][0]
    if best.get("year"):
        new_meta["year"] = best["year"]
    if best.get("country"):
        new_meta["country"] = best["country"]
    new_meta["external_id"] = str(best.get("id", ""))

    return {"image_url": cover, "metadata": new_meta}


async def enrich_movie_or_show(client: httpx.AsyncClient, item: dict) -> dict | None:
    title = item["title"]
    media_type = item["media_type"]

    # Strip season info for better search results
    search_title = title
    for sep in [" - Season", " Season", " Seasons", " -Season"]:
        if sep in search_title:
            search_title = search_title.split(sep)[0].strip()

    endpoint = "/search/movie" if media_type == "movie" else "/search/tv"
    resp = await client.get(
        f"{TMDB_BASE}{endpoint}",
        params={"api_key": TMDB_API_KEY, "query": search_title},
    )
    if resp.status_code != 200:
        return None

    results = resp.json().get("results", [])
    if not results:
        return None

    best = results[0]
    poster = best.get("poster_path", "")
    if not poster:
        return None

    image_url = f"{TMDB_IMG}{poster}"
    metadata = dict(item.get("metadata", {}))
    metadata["tmdb_id"] = best.get("id")
    metadata["overview"] = best.get("overview", "")
    metadata["vote_average"] = best.get("vote_average", 0)

    if media_type == "movie":
        metadata["release_date"] = best.get("release_date", "")
    else:
        metadata["first_air_date"] = best.get("first_air_date", "")

    return {"image_url": image_url, "metadata": metadata}


async def enrich_book(client: httpx.AsyncClient, item: dict) -> dict | None:
    title = item["title"]
    resp = await client.get(
        f"{OL_BASE}/search.json",
        params={"q": title, "limit": 5},
    )
    if resp.status_code != 200:
        return None

    docs = resp.json().get("docs", [])
    if not docs:
        return None

    best = docs[0]
    cover_id = best.get("cover_i")
    if not cover_id:
        return None

    image_url = f"{OL_COVER}/{cover_id}-M.jpg"
    metadata = dict(item.get("metadata", {}))
    metadata["authors"] = best.get("author_name", [])
    metadata["publish_year"] = best.get("first_publish_year")
    if best.get("isbn"):
        metadata["isbn"] = best["isbn"][0]

    return {"image_url": image_url, "metadata": metadata}


async def enrich_documentary(client: httpx.AsyncClient, item: dict) -> dict | None:
    # Try TMDB movies first, then TV
    title = item["title"]
    for endpoint in ["/search/movie", "/search/tv"]:
        resp = await client.get(
            f"{TMDB_BASE}{endpoint}",
            params={"api_key": TMDB_API_KEY, "query": title},
        )
        if resp.status_code != 200:
            continue
        results = resp.json().get("results", [])
        if not results:
            continue

        best = results[0]
        poster = best.get("poster_path", "")
        if not poster:
            continue

        metadata = dict(item.get("metadata", {}))
        metadata["tmdb_id"] = best.get("id")
        metadata["overview"] = best.get("overview", "")
        return {
            "image_url": f"{TMDB_IMG}{poster}",
            "metadata": metadata,
        }
    return None


async def run(token: str):
    print("Fetching collection items...")
    items = get_all_items(token)
    print(f"Found {len(items)} items")

    needs_enrichment = [i for i in items if not i.get("image_url")]
    print(f"{len(needs_enrichment)} items need cover art\n")

    if not needs_enrichment:
        print("All items already have images!")
        return

    enriched = 0
    skipped = 0
    errors = 0

    async with httpx.AsyncClient(timeout=15.0) as client:
        for i, item in enumerate(needs_enrichment):
            media_type = item["media_type"]
            title = item["title"]
            progress = f"[{i+1}/{len(needs_enrichment)}]"

            try:
                if media_type == "vinyl":
                    result = await enrich_vinyl(client, item)
                    await asyncio.sleep(1.1)  # Discogs rate limit: 60/min
                elif media_type in ("movie", "show"):
                    result = await enrich_movie_or_show(client, item)
                    await asyncio.sleep(0.3)  # TMDB rate limit
                elif media_type == "book":
                    result = await enrich_book(client, item)
                    await asyncio.sleep(0.5)  # Be nice to OL
                elif media_type == "documentary":
                    result = await enrich_documentary(client, item)
                    await asyncio.sleep(0.3)
                elif media_type == "audiobook":
                    result = await enrich_book(client, item)  # Try Open Library
                    await asyncio.sleep(0.5)
                else:
                    result = None

                if result:
                    # Need to update via direct DB since PATCH doesn't support image_url
                    # Use a custom endpoint or update the patch schema
                    # For now, update via SQL
                    patch_item(token, item["id"], result)
                    enriched += 1
                    print(f"  {progress} {media_type}: {title}")
                else:
                    skipped += 1
                    print(f"  {progress} SKIP {media_type}: {title} (no match)")

            except Exception as e:
                errors += 1
                print(f"  {progress} ERROR {media_type}: {title} - {e}")

    print(f"\nDone! {enriched} enriched, {skipped} no match, {errors} errors")


def main():
    load_env()
    username = sys.argv[1] if len(sys.argv) > 1 else input("Username: ")
    password = sys.argv[2] if len(sys.argv) > 2 else input("Password: ")

    print(f"Logging in as {username}...")
    token = get_token(username, password)

    asyncio.run(run(token))


if __name__ == "__main__":
    main()
