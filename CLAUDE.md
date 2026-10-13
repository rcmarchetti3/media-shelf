# CLAUDE.md — MediaShelf

## Design system

UI work follows the MediaShelf design system (warm walnut ground, brass accents, wooden shelves, media drawn as physical objects).

- **Source of truth (live):** https://claude.ai/artifact/N9TGmVzKix5xo16HpWgURk
  Read it with the Artifact tool (`action: "read"`, `path: "project/README.md"`), then `project/tokens.json` and the relevant `project/components/<Name>/README.md`.
- **Local snapshot:** `docs/design-system/` — same files, no login needed. Can lag behind the artifact; if they disagree, the artifact wins.

Before building or restyling any UI:
1. Read the design system README first: voice, color, type, shelf rules, iconography.
2. Use token names (`--primary`, `--shelf-plank`, `--glow-completed`…), not raw `oklch()` values. Tokens that aren't yet CSS variables in `frontend/src/index.css` should be added there rather than hardcoded.
3. Headings in Bitter (`font-heading`), everything else in Geist. Brass (`primary`) is the only accent hue; put `primary-foreground` on brass fills, never white.
4. Collection items always render on a shelf (`ShelfGrid` → `ShelfItem`), never inside cards.
5. Status is a glow ring on the cover; pair it with its glyph (✓ ▶ ● ♡ ✕) wherever status is named. No emoji.
6. Don't drop below WCAG contrast. Known failing pairs are flagged in `tokens.json` usage notes; don't add new ones.
