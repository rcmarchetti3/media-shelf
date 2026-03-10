"""
Sync vinyl collection from the '6J Vinyl.xlsx' spreadsheet (Owned sheet only).

For each row:
  - If a matching vinyl item exists in the DB, MERGE spreadsheet fields into
    existing metadata (preserving Discogs/API-enriched fields).
  - If no match exists, create a new collection item.

Matching strategy:
  1. Exact match on album title (case-insensitive)
  2. Match on "Artist - Album" combined title format
  3. Match on artist + title in metadata
"""

import asyncio
import os
import sys
import uuid

import openpyxl
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

# Add parent so we can import app modules
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))

from app.models.collection_item import CollectionItem


DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql+asyncpg://mediashelf:mediashelf@localhost:5432/mediashelf",
)

engine = create_async_engine(DATABASE_URL)
async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


def parse_spreadsheet(path: str) -> list[dict]:
    """Read only the first sheet (Owned) and return a list of dicts."""
    wb = openpyxl.load_workbook(path, read_only=True)
    ws = wb.worksheets[0]  # First sheet only

    headers = [cell.value for cell in next(ws.iter_rows(min_row=1, max_row=1))]
    # Find column indices for the fields we care about
    col_map = {}
    for i, h in enumerate(headers):
        if h and isinstance(h, str):
            col_map[h.strip()] = i

    records = []
    for row in ws.iter_rows(min_row=2, values_only=True):
        artist = str(row[col_map.get("Artist Name", 0)] or "").strip()
        genre = str(row[col_map.get("Artist Genre", 1)] or "").strip()
        album = str(row[col_map.get("Album Title", 2)] or "").strip()
        year_raw = row[col_map.get("Album Year", 3)]
        decade = str(row[col_map.get("Decade", 4)] or "").strip()
        vinyl_color = str(row[col_map.get("Vinyl Color", 5)] or "").strip()
        instrumental_raw = str(row[col_map.get("Instrumental", 6)] or "").strip()
        apple_raw = str(row[col_map.get("Apple Music", 7)] or "").strip()

        if not album:
            continue

        year = None
        if year_raw:
            try:
                year = int(float(year_raw))
            except (ValueError, TypeError):
                pass

        instrumental = instrumental_raw.lower() in ("yes", "true", "1")
        apple_music = apple_raw.lower() in ("yes", "true", "1")

        records.append({
            "artist": artist,
            "genre": genre,
            "album": album,
            "year": year,
            "decade": decade,
            "vinyl_color": vinyl_color,
            "instrumental": instrumental,
            "apple_music": apple_music,
        })

    wb.close()
    return records


def build_spreadsheet_metadata(rec: dict) -> dict:
    """Build the metadata dict from a spreadsheet record."""
    meta = {}
    if rec["artist"]:
        meta["artist"] = rec["artist"]
    if rec["genre"]:
        meta["genre"] = rec["genre"]
    if rec["year"]:
        meta["year"] = rec["year"]
    if rec["decade"]:
        meta["decade"] = rec["decade"]
    if rec["vinyl_color"]:
        meta["vinyl_color"] = rec["vinyl_color"]
    meta["instrumental"] = rec["instrumental"]
    meta["apple_music"] = rec["apple_music"]
    return meta


async def find_existing_item(
    db: AsyncSession, user_id: uuid.UUID, album: str, artist: str
) -> CollectionItem | None:
    """Try to find an existing vinyl item by title/artist matching."""
    album_lower = album.lower().strip()
    artist_lower = artist.lower().strip()

    # Strategy 1: exact title match (case-insensitive)
    result = await db.execute(
        select(CollectionItem).where(
            CollectionItem.user_id == user_id,
            CollectionItem.media_type == "vinyl",
            func.lower(CollectionItem.title) == album_lower,
        )
    )
    item = result.scalars().first()
    if item:
        return item

    # Strategy 2: "Artist - Album" combined format
    if artist_lower:
        combined = f"{artist_lower} - {album_lower}"
        result = await db.execute(
            select(CollectionItem).where(
                CollectionItem.user_id == user_id,
                CollectionItem.media_type == "vinyl",
                func.lower(CollectionItem.title) == combined,
            )
        )
        item = result.scalars().first()
        if item:
            return item

        # Also try "Artist* - Album" (Discogs format with asterisk)
        result = await db.execute(
            select(CollectionItem).where(
                CollectionItem.user_id == user_id,
                CollectionItem.media_type == "vinyl",
                func.lower(CollectionItem.title).like(f"%{artist_lower}%{album_lower}%"),
            )
        )
        item = result.scalars().first()
        if item:
            return item

    return None


async def sync_vinyl(spreadsheet_path: str):
    records = parse_spreadsheet(spreadsheet_path)
    print(f"Parsed {len(records)} records from spreadsheet (Owned sheet)")

    async with async_session() as db:
        # Get the admin user (first user)
        result = await db.execute(
            text("SELECT id FROM users WHERE role = 'admin' LIMIT 1")
        )
        user_row = result.first()
        if not user_row:
            print("ERROR: No admin user found")
            return
        user_id = user_row[0]
        print(f"Using user ID: {user_id}")

        updated = 0
        created = 0
        skipped = 0

        for i, rec in enumerate(records):
            album = rec["album"]
            artist = rec["artist"]
            spreadsheet_meta = build_spreadsheet_metadata(rec)

            existing = await find_existing_item(db, user_id, album, artist)

            if existing:
                # MERGE: preserve existing metadata, layer spreadsheet fields on top
                current_meta = dict(existing.metadata_) if existing.metadata_ else {}
                merged = {**current_meta, **spreadsheet_meta}

                # Only update if something actually changed
                if merged != current_meta:
                    existing.metadata_ = merged
                    updated += 1
                else:
                    skipped += 1
            else:
                # CREATE new item
                title = album  # Use album title as the item title
                new_item = CollectionItem(
                    id=uuid.uuid4(),
                    user_id=user_id,
                    media_type="vinyl",
                    title=title,
                    status="owned",
                    metadata_=spreadsheet_meta,
                    tags=[],
                    is_favorite=False,
                )
                db.add(new_item)
                created += 1

            # Commit in batches of 50
            if (i + 1) % 50 == 0:
                await db.commit()
                print(f"  Processed {i + 1}/{len(records)}...")

        await db.commit()
        print(f"\nDone!")
        print(f"  Updated: {updated}")
        print(f"  Created: {created}")
        print(f"  Skipped (no changes): {skipped}")
        print(f"  Total processed: {updated + created + skipped}")

        # Final count
        result = await db.execute(
            select(func.count(CollectionItem.id)).where(
                CollectionItem.media_type == "vinyl",
                CollectionItem.user_id == user_id,
            )
        )
        total = result.scalar()
        print(f"  Total vinyl items in DB: {total}")


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "/data/6J Vinyl.xlsx"
    asyncio.run(sync_vinyl(path))
