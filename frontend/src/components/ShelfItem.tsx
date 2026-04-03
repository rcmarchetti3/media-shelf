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
      return "status-completed";
    case "reading":
    case "watching":
      return "status-in-progress";
    case "wishlist":
    case "want_to_watch":
      return "status-wishlist";
    case "dropped":
      return "status-dropped";
    case "owned":
      return "status-owned";
    default:
      return "";
  }
}

type ShelfItemProps = {
  item: CollectionItem;
  onClick?: () => void;
};

export function ShelfItem({ item, onClick }: ShelfItemProps) {
  const typeClass = `type-${item.media_type}`;
  const statusClass = getStatusClass(item.status);

  return (
    <Link
      to={`/collection/${item.id}`}
      className={`shelf-item ${typeClass} ${statusClass}`}
      onClick={onClick}
    >
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
        {renderStars(item.rating)}
      </div>
    </Link>
  );
}
