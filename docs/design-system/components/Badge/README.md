# Badge
A small pill label for media type, counts and metadata chips.

Hand-written from `frontend/src/components/ui/badge.tsx`. Static rendition: `ms-badge ms-badge--<variant>`.

- **Variants:** `default` (brass) · `secondary` · `destructive` · `outline` (used for media type in the collection table, often at 10px and `capitalize`) · `ghost` · `link`.
- Height `size-badge` (20px), padding `space-0.5` × `space-2`, `radius-4xl` pill, text `badge`.
- **Consumer provides:** a short label, optionally a 12px icon. Render as a link via `render` when it navigates.
- **Don't** use badges for status on covers — status is the glow ring (see ShelfItem).
