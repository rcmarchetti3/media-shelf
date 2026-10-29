import { Link } from "react-router-dom";
import type { CollectionItem } from "@/lib/types";

function renderStars(rating: number | null) {
  if (!rating) return null;
  return (
    <span className="item-stars">
      {"★".repeat(rating)}{"☆".repeat(5 - rating)}
    </span>
  );
}

function getStatusClass(status: string | null): string {
  switch (status) {
    case "completed":
    case "watched":
    case "beat":
      return "status-completed";
    case "reading":
    case "watching":
    case "playing":
      return "status-in-progress";
    case "wishlist":
    case "want_to_watch":
    case "want_to_play":
      return "status-wishlist";
    case "dropped":
      return "status-dropped";
    case "owned":
      return "status-owned";
    default:
      return "";
  }
}

/** Anything that can sit on a shelf: a collection item, or a recommendation not owned yet. */
export type ShelfEntry = Pick<CollectionItem, "id" | "title" | "image_url" | "media_type"> &
  Partial<Pick<CollectionItem, "status" | "rating">>;

type ShelfItemProps = {
  item: ShelfEntry;
  onClick?: () => void;
  /** When set, the item is a button (e.g. opens a dialog) instead of a link to its detail page. */
  onSelect?: (item: ShelfEntry) => void;
};

export function ShelfItem({ item, onClick, onSelect }: ShelfItemProps) {
  const className = `shelf-item type-${item.media_type} ${getStatusClass(item.status ?? null)}`;
  const contents = (
    <>
      <div className="item-cover">
        {item.image_url ? (
          <img src={item.image_url} alt={item.title} />
        ) : (
          item.title[0]
        )}
      </div>
      <div className="item-info">
        <div className="item-title">{item.title}</div>
        <div className="item-meta capitalize">{item.media_type}</div>
        {renderStars(item.rating ?? null)}
      </div>
    </>
  );

  if (onSelect) {
    return (
      <button type="button" className={`${className} text-left`} onClick={() => onSelect(item)}>
        {contents}
      </button>
    );
  }
  return (
    <Link to={`/collection/${item.id}`} className={className} onClick={onClick}>
      {contents}
    </Link>
  );
}
