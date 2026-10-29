# Input
The single-line text field, slightly recessed into the walnut.

Hand-written from `frontend/src/components/ui/input.tsx`. Static rendition: `ms-input` (+ `ms-label`).

- Height `size-control` (32px), padding `space-1` × `space-2.5`, `radius-lg`, 1px `input` border, `background` at 30% fill, `shadow-input`, text `body`, placeholder `muted-foreground`.
- Focus: `ring` border + 3px `ring` at 50%. Invalid (`aria-invalid`): `destructive` border.
- **Consumer provides:** `type`, `value`/`onChange`, `placeholder`, and a `Label` above it. Collection search uses placeholder "Search collection…".
