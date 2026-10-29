# StatPlaque
A brushed-brass nameplate showing one collection count on the dashboard.

Hand-written from the stat grid in `frontend/src/pages/DashboardPage.tsx` and `.stat-plaque` in `index.css` (a page pattern, not an exported component).

- Fill: 145° gradient over `plaque-1` … `plaque-5`, 1px `plaque-border`, `shadow-plaque`, `radius-lg`, padding `space-4`.
- Label in `overline`, `primary-foreground` at 70%, with a 16px stroke icon at 60%; value in `stat-number`, `primary-foreground` (≈5.8:1 on the plaque).
- Grid: 1 → 2 (sm) → 3 (lg) → 6 (xl) columns, gap `space-3`. Show a Skeleton in place of the number while loading.
- **Consumer provides:** label, icon path, count. One plaque per media type; don't use plaques for anything that isn't a count.
