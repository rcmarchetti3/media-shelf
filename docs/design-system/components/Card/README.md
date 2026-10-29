# Card
The raised panel for forms, settings groups and empty states.

Hand-written from `frontend/src/components/ui/card.tsx`. Parts: `Card`, `CardHeader`, `CardTitle`, `CardDescription`, `CardAction`, `CardContent`, `CardFooter`. Static rendition: `ms-card`, `ms-card__header|title|description|content|footer`.

- `card` fill, `radius-xl`, 1px ring of `foreground` at 10%, padding `space-4`, gap `space-4`. `size="sm"` tightens to `space-3`.
- Title in `card-title`; description in `muted-foreground` (note: 4.0:1 on `card` — keep descriptions ≥ 14px).
- Footer: `border` top rule on `muted` at 50%.
- **Consumer provides:** the parts as children. The auth screens put a `brass` `page-title-sm` title in the header and sit the card on `auth-bg`.
- **Don't** put shelf items inside a card; shelves sit directly on `background`.
