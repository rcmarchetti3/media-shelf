import { useEffect, useState, useRef } from "react";
import { ShelfItem, type ShelfEntry } from "./ShelfItem";

type ShelfGridProps<T extends ShelfEntry> = {
  items: T[];
  onItemClick?: () => void;
  onSelect?: (item: T) => void;
};

function useColumns(containerRef: React.RefObject<HTMLDivElement | null>): number {
  const [cols, setCols] = useState(5);

  useEffect(() => {
    function update() {
      const w = containerRef.current?.offsetWidth ?? window.innerWidth;
      if (w < 400) setCols(2);
      else if (w < 600) setCols(3);
      else if (w < 900) setCols(4);
      else if (w < 1200) setCols(5);
      else setCols(6);
    }
    update();
    const ro = new ResizeObserver(update);
    if (containerRef.current) ro.observe(containerRef.current);
    return () => ro.disconnect();
  }, [containerRef]);

  return cols;
}

export function ShelfGrid<T extends ShelfEntry>({ items, onItemClick, onSelect }: ShelfGridProps<T>) {
  const containerRef = useRef<HTMLDivElement>(null);
  const cols = useColumns(containerRef);

  // Chunk items into rows
  const rows: T[][] = [];
  for (let i = 0; i < items.length; i += cols) {
    rows.push(items.slice(i, i + cols));
  }

  return (
    <div ref={containerRef} className="space-y-0">
      {rows.map((row, rowIdx) => (
        <div key={rowIdx} className="shelf-row" style={{ '--cols': cols } as React.CSSProperties}>
          {row.map((item) => (
            <ShelfItem
              key={item.id}
              item={item}
              onClick={onItemClick}
              onSelect={onSelect && ((entry) => onSelect(entry as T))}
            />
          ))}
        </div>
      ))}
    </div>
  );
}
