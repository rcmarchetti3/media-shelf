# Tabs
Segmented switcher for views within a page (item details, settings sections).

Hand-written from `frontend/src/components/ui/tabs.tsx` (Base UI). Static rendition: `ms-tabs` with `ms-tab[aria-selected]`.

- List: `muted` track, `radius-lg`, 3px inset, height `size-control`, `muted-foreground` text.
- Trigger: `body-medium`, `foreground` at 60%; **active** sits on `background` with `brass` text and a `brass` 30% border — the brass is MediaShelf's change from stock shadcn.
- A `line` variant drops the track and underlines the active tab.
- **Consumer provides:** `value`/`onValueChange`, a `TabsTrigger` per panel and matching `TabsContent`.
