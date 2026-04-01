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

type ShelfItemProps = {
  item: CollectionItem;
  onClick?: () => void;
};

export function ShelfItem({ item, onClick }: ShelfItemProps) {
  const typeClass = `type-${item.media_type}`;

  return (
    <Link
      to={`/collection/${item.id}`}
      className={`shelf-item ${typeClass}`}
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
