# Button
The compact action control; brass `default` for the one main action per view, quieter variants for everything else.

Hand-written from `frontend/src/components/ui/button.tsx` (shadcn base-nova on Base UI). Static rendition: classes `ms-btn ms-btn--<variant> ms-btn--<size>`.

- **Variants:** `default` (`primary` fill, `primary-foreground` text, brightness 1.1 on hover) · `outline` (`border` on `background`, `muted` hover) · `secondary` · `ghost` (no fill until hover) · `destructive` (10% `destructive` tint, `destructive` text) · `link` (`primary` text, underline on hover).
- **Sizes:** `xs` 24px · `sm` 28px · `default` 32px · `lg` 36px, plus square `icon`, `icon-xs`, `icon-sm`, `icon-lg`. Padding `space-2.5`, gap `space-1.5`, radius `radius-lg`, text `body-medium`.
- **Consumer provides:** label text and/or a 16px icon child; `onClick`; `disabled`. Put `data-icon="inline-start|inline-end"` on an icon to tighten that side's padding.
- **Do:** one `default` per view ("Add Items" on Collection). **Don't:** use `destructive` for the main CTA — it's a tint for secondary destructive actions, and its text is only 3.1:1.
