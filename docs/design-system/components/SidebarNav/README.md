# SidebarNav
The wood-paneled app navigation: logo, top links, the Collection group by media type, and Settings.

Hand-written from `frontend/src/components/layout/Sidebar.tsx` (desktop, ≥ 768px) and the mobile Sheet in `Header.tsx`.

- Panel: `sidebar-wood` (`sidebar` + faint grain + `shadow-sidebar`), width `size-sidebar`, right rule `sidebar-border`. Logo block padded `space-6`.
- Links: 20px stroke icon + `body`, padding `space-2` × `space-3`, gap `space-3`, `radius-lg`.
  - Top links (Dashboard, Search): inactive `sidebar-foreground` at 70%; **active** `sidebar-accent` fill, `sidebar-accent-foreground`, 2px `brass` left rule.
  - Collection and Settings links: inactive `muted-foreground`; active/hover `accent` fill. (The source styles the two groups differently; the mobile sheet swaps them.)
- Group label "Collection" in `overline`, `brass-dark` (4.1:1 — flagged).
- **Consumer provides:** nothing — items come from `nav-items.ts` (paths, labels, icon names) and the current route.
