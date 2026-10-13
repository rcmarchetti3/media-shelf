# ShelfGrid
Lays collection items out as wooden shelves — rows of 2–6 items, each on a plank.

Hand-written from `frontend/src/components/ShelfGrid.tsx` and `.shelf-row` in `index.css`.

- Columns follow the container width (ResizeObserver): < 400px → 2, < 600 → 3, < 900 → 4, < 1200 → 5, else 6; items are chunked into rows of that size, each a `.shelf-row` with `--cols`.
- Row gap `clamp(8px, 2vw, 20px)`, bottom padding `clamp(28px, 5vw, 40px)` for the plank; the plank (`::after`) is the wood-grain gradient of `shelf-dark` / `shelf-plank` / `shelf-light` with `shadow-plank`, and the front edge (`::before`) runs `shelf-edge-top` → `shelf-edge-bottom` with `shadow-shelf-edge`. Both bleed 8px past the row.
- Items stagger 2px / 0 / 4px by `nth-child(3n…)`.
- **Consumer provides:** `items: CollectionItem[]` and an optional `onItemClick`. Use it for Dashboard "Recently Added" and the Collection grid view; the list view is a Table instead.
