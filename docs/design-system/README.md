MediaShelf is a personal library for vinyl, books, audiobooks, movies, TV and documentaries. The interface is a **warm home library at night**: walnut ground, brass fittings, wooden shelf planks, and every item shown as the physical object it is. Build anything new so it feels like it belongs in that room.

## Content fundamentals

- **Voice: a friendly host, never a system.** Speak to the owner in second person, briefly. Real copy: "Welcome back, Rich", "Here's an overview of your collection.", "Your collection is empty.", "Start searching to add items".
- **Sentence case** for headings, descriptions and buttons ("Recently Added" is the one Title Case section head; keep new ones sentence case unless they name a shelf). **Title Case** for status labels and nav items: "Want to Watch", "TV Shows", "Audiobooks".
- **Short toasts, one clause:** "Account created!", "Passwords do not match". Errors pass the server's message through, else "Login failed".
- **No emoji.** Status and rating use typographic glyphs: ✓ completed/watched, ▶ reading/watching, ● owned, ♡ wishlist/want to watch, ✕ dropped; ratings as ★★★☆☆ in `brass`.
- Media types are lowercase in data (`vinyl`, `book`, `show`) and capitalized on display.

## Visual foundations

### Color
- One dark theme, `library`. Ground is `background`; raised panels are `card`; menus `popover`; the sidebar is the darker `sidebar` with the `sidebar-wood` grain.
- **Brass is the one hue.** `primary` (= `brass`) marks the wordmark, primary buttons, active tab text, the sidebar's active rule, links and rating stars. Put `primary-foreground` on any brass fill — never white.
- Wood tokens (`shelf-plank`, `shelf-dark`, `shelf-light`, `shelf-edge-top`, `shelf-edge-bottom`) are only for shelves. `leather`, `leather-light` and `parchment` are reserved accents.
- Body text is `foreground`; supporting text `muted-foreground` on `background` or `sidebar` only — on `card` it drops to 4.0:1, so use `foreground` at reduced weight or keep the line ≥ 14px.
- `destructive` is text-safe only at 24px+; for small error text pair it with an icon and put it on `background`.
- **Status lives on the cover, as a glow** (`glow-completed`, `glow-in-progress`, `glow-wishlist`, `glow-dropped`, `glow-owned`). Never rely on hue alone: show the matching glyph wherever the status is named, because `status-completed` and `status-dropped` differ mostly by hue.

### Type
- Headings in **Bitter** (`heading` family, slab serif, bold, tracking −0.025em): `page-title` per page, `section-title` within it, `wordmark` in `brass`.
- Everything else in **Geist** (`sans`): `body` for UI text, `body-medium` for buttons and tabs, `caption` for secondary lines, `overline` (uppercase, +0.05em) for group labels.
- Covers with no artwork show the title's first letter in `cover-initial` (Bitter 700).
- Both are variable fonts on Google Fonts; the app self-hosts them via `@fontsource-variable`.

### Shelves — the signature
- Items always sit on a **shelf row**: a grid of 2–6 columns (container < 400px: 2, < 600: 3, < 900: 4, < 1200: 5, else 6) above a wood plank (`shadow-plank`) with a front edge (`shadow-shelf-edge`).
- Items are **staggered** 2px / 0 / 4px down in a repeating rhythm so the row looks hand-placed.
- Each media type has a real silhouette: **vinyl** square sleeve with the disc peeking up-right (`vinyl-label` center); **book** 105:150 with a dark spine left and striped page edges right (`page-edge-light`, `page-edge-dark`); **movie/show/documentary** 92:136 case with spine and a 7% plastic sheen; **audiobook** square jewel case with a CD peeking bottom-right.
- Covers cast `shadow-cover` to the right; corners stay at `radius-cover` (2px). Media objects are never rounded like cards.
- Hover lifts an item 12px with brightness 1.08 and fades in the title overlay (`overlay`, `shelf-title`, `shelf-meta`).

### Surfaces, borders, shadows
- Cards: `card` fill, `radius-xl`, a 1px ring of `foreground` at 10% — not a border token, and no drop shadow.
- Hairlines are `border` (header rule, card footer). Shadows are reserved for physical things: covers, planks, the sidebar's inner shade (`shadow-sidebar`), plaques (`shadow-plaque`), and recessed inputs (`shadow-input`).
- **Stat plaques** are brushed brass (`plaque-1`…`plaque-5` at 145°, `plaque-border`) with `primary-foreground` text — engraved nameplates for counts.
- The login/register screen sits on `auth-bg`: `auth-ground` with faint shelf bands every 210px.

### Spacing, radius, layout
- Tailwind's 4px scale: `space-2.5` inside controls, `space-4` inside cards, `space-8` between page sections.
- Controls are compact: `size-control` (32px) for buttons, inputs and tab lists.
- `radius-lg` is the base for controls; `radius-xl` for cards; `radius-4xl` pills for badges.
- App shell: `size-sidebar` wood sidebar (desktop ≥ 768px) + `size-header` top bar; below 768px the sidebar becomes a left sheet behind a menu button.

### Motion and states
- Transitions are short and physical: 0.18s ease for lift, brightness and overlay.
- Focus: `ring` at 50%, 3px, plus a `ring`-colored border. Disabled: 50% opacity, no pointer events.
- Hover on primary buttons is brightness 1.1, not a color swap; outline/ghost buttons fill with `muted`.

## Iconography

- Stroke icons in the **Heroicons outline** style: 24×24 viewBox, 1.5 stroke, round caps and joins, `currentColor`. The sidebar set lives in `assets/Icons/` (home, search, library, vinyl, film, tv, book, headphones, documentary, settings).
- The shadcn layer is configured for **lucide**; use lucide only inside ui primitives (chevrons, checks) where it's already used.
- Icons are 20px in navigation, 16px in buttons and plaques.
- The logo mark (`assets/Logos/mediashelf-mark.svg`) is a shelf holding a book, a record and a film-strip book — always `brass`, with the wordmark in `wordmark` beside it.

## Not synced

- Values that are `calc()` or `clamp()` in source were turned into their resolved steps (radius scale) or described in usage notes (fluid shelf gaps `clamp(8px, 2vw, 20px)`, shelf title sizes). Composite corner radii (`1px 3px 3px 1px` on cases, `0 2px 2px 0` on books) and the multi-stop wood, disc and sheen gradients live in `components/bundle.css`, not tokens.
- Font files were not copied (node_modules not installed); Geist and Bitter load from Google Fonts.
- Components were **not built**: previews are static HTML/CSS renditions styled by `bundle.css`, hand-written from the source paths in each component's README.
- The dashboard stat plaques use a second, older icon set (inline paths in `DashboardPage.tsx`) not included here.
