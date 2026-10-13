// MediaShelf component props — documentation only (no bundle is shipped; previews are static).
import type * as React from "react";

export type MediaType = "vinyl" | "book" | "audiobook" | "movie" | "documentary" | "show";
export type ItemStatus = "owned" | "wishlist" | "reading" | "in_progress" | "completed" | "dropped" | "watched" | "want_to_watch" | "watching";

export interface CollectionItem {
  id: string;
  title: string;
  media_type: MediaType;
  status: ItemStatus | null;
  image_url: string | null;
  /** 1–5 */
  rating: number | null;
}

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "default" | "outline" | "secondary" | "ghost" | "destructive" | "link";
  size?: "default" | "xs" | "sm" | "lg" | "icon" | "icon-xs" | "icon-sm" | "icon-lg";
}
export interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: "default" | "secondary" | "destructive" | "outline" | "ghost" | "link";
  render?: React.ReactElement;
}
export interface CardProps extends React.HTMLAttributes<HTMLDivElement> { size?: "default" | "sm"; }
export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {}
export interface TabsProps { value?: string; defaultValue?: string; onValueChange?: (v: string) => void; orientation?: "horizontal" | "vertical"; children?: React.ReactNode; }
export interface TabsListProps { variant?: "default" | "line"; children?: React.ReactNode; }
export interface ShelfItemProps { item: CollectionItem; onClick?: () => void; }
export interface ShelfGridProps { items: CollectionItem[]; onItemClick?: () => void; }
export interface StatPlaqueProps { label: string; icon: string; value: number; loading?: boolean; }
export interface SidebarNavProps {}
