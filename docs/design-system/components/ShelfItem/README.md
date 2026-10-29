# ShelfItem
One collection item drawn as its physical object — sleeve, book, case or jewel case — standing on a shelf.

Hand-written from `frontend/src/components/ShelfItem.tsx` and the `.shelf-item` rules in `index.css`. Classes: `shelf-item type-<media_type> status-<group>`, children `.item-cover` (image or the title's first letter) and `.item-info` (`.item-title`, `.item-meta`, `.item-stars`).

- **Types:** `vinyl` 1:1 sleeve + disc · `book` 105:150 with spine and page edges · `movie`, `show`, `documentary` 92:136 case with spine and sheen · `audiobook` 1:1 jewel case with CD.
- **Status → glow:** completed/watched → `glow-completed`; reading/watching → `glow-in-progress`; wishlist/want_to_watch → `glow-wishlist`; dropped → `glow-dropped`; owned → `glow-owned`. The glow also lands on the spine pseudo-element.
- **Hover:** lift 12px, brightness 1.08, overlay fades in with title, type and ★ rating in `brass`.
- **Consumer provides:** a `CollectionItem` (`id`, `title`, `media_type`, `status`, `image_url`, `rating` 1–5) and an optional `onClick`; it renders as a link to `/collection/:id`. Must live inside a ShelfGrid row (the stagger and plank come from the row).
- **Accessibility:** the glow is color only. Where status matters, also show its glyph (✓ ▶ ● ♡ ✕ from `getStatusIcon`).
- **Source quirk:** `.item-cover` sets `overflow: hidden`, which clips the vinyl disc and book page-edge pseudo-elements that are positioned outside the cover; this rendition keeps that behavior exactly.
