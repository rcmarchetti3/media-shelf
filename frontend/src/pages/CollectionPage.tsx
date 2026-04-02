import { useEffect, useState, useCallback } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { apiFetch } from "@/lib/api";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { ShelfGrid } from "@/components/ShelfGrid";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import type { CollectionItem, PaginatedResponse } from "@/lib/types";
import { ALL_STATUSES as STATUS_LIST, getStatusLabel } from "@/lib/statuses";

const MEDIA_TYPES: { value: string; label: string }[] = [
  { value: "all", label: "All Types" },
  { value: "vinyl", label: "Vinyl" },
  { value: "book", label: "Books" },
  { value: "movie", label: "Movies" },
  { value: "show", label: "Shows" },
  { value: "documentary", label: "Documentaries" },
  { value: "audiobook", label: "Audiobooks" },
];

// Prepend "All Statuses" option for collection-wide filter
const ALL_STATUSES = [
  { value: "all", label: "All Statuses" },
  ...STATUS_LIST,
];

const SORT_OPTIONS = [
  { value: "added_at", label: "Date Added" },
  { value: "title", label: "Title" },
  { value: "rating", label: "Rating" },
];

function findLabel(options: { value: string; label: string }[], value: string): string {
  return options.find((o) => o.value === value)?.label ?? value;
}


export function CollectionPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [items, setItems] = useState<CollectionItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [totalPages, setTotalPages] = useState(0);

  // Derive all filter state from URL params
  const page = parseInt(searchParams.get("page") || "1");
  const mediaType = searchParams.get("type") || "all";
  const statusFilter = searchParams.get("status") || "all";
  const sortBy = searchParams.get("sort") || "added_at";
  const sortOrder = (searchParams.get("order") || "desc") as "asc" | "desc";
  const q = searchParams.get("q") || "";
  const isFav = searchParams.get("fav") === "true";
  const viewMode = searchParams.get("view") || "grid";

  const [searchInput, setSearchInput] = useState(q);

  // Sync search input when q changes (e.g. on back navigation)
  useEffect(() => {
    setSearchInput(q);
  }, [q]);

  const updateParams = useCallback(
    (updates: Record<string, string>, resetPage = true) => {
      setSearchParams(
        (prev) => {
          const newParams = new URLSearchParams(prev);
          for (const [key, value] of Object.entries(updates)) {
            if (value && value !== "all" && value !== "false" && value !== "grid") {
              newParams.set(key, value);
            } else {
              newParams.delete(key);
            }
          }
          if (resetPage && !("page" in updates)) {
            newParams.delete("page");
          }
          return newParams;
        },
        { replace: true }
      );
    },
    [setSearchParams]
  );

  const fetchItems = useCallback(async () => {
    setIsLoading(true);
    const params = new URLSearchParams();
    params.set("page", String(page));
    params.set("page_size", "24");
    params.set("sort_by", sortBy);
    params.set("sort_order", sortOrder);
    if (mediaType !== "all") params.set("media_type", mediaType);
    if (statusFilter !== "all") params.set("status", statusFilter);
    if (q) params.set("q", q);
    if (isFav) params.set("is_favorite", "true");

    try {
      const data = await apiFetch<PaginatedResponse<CollectionItem>>(
        `/collection/?${params}`
      );
      setItems(data.items);
      setTotalPages(data.total_pages);
    } catch {
      setItems([]);
    } finally {
      setIsLoading(false);
    }
  }, [page, mediaType, statusFilter, sortBy, sortOrder, q, isFav]);

  useEffect(() => {
    fetchItems();
  }, [fetchItems]);

  // Scroll restoration: restore after data loads
  useEffect(() => {
    if (!isLoading && items.length > 0) {
      const saved = sessionStorage.getItem("collection-scroll");
      if (saved) {
        requestAnimationFrame(() => {
          window.scrollTo(0, parseInt(saved));
          sessionStorage.removeItem("collection-scroll");
        });
      }
    }
  }, [isLoading, items.length]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    sessionStorage.removeItem("collection-scroll");
    updateParams({ q: searchInput });
  };

  const handlePageChange = (newPage: number) => {
    sessionStorage.removeItem("collection-scroll");
    window.scrollTo(0, 0);
    updateParams({ page: String(newPage) }, false);
  };

  const updateFilter = (key: string, value: string | boolean | null) => {
    sessionStorage.removeItem("collection-scroll");
    const paramMap: Record<string, string> = {
      media_type: "type",
      status: "status",
      sort_by: "sort",
      sort_order: "order",
      is_favorite: "fav",
    };
    updateParams({ [paramMap[key] || key]: String(value ?? "") });
  };

  // Save scroll position before navigating to an item
  const saveScroll = () => {
    sessionStorage.setItem("collection-scroll", String(window.scrollY));
  };

  const renderStars = (rating: number | null) => {
    if (!rating) return null;
    return (
      <span className="text-xs text-yellow-500">
        {"★".repeat(rating)}
        {"☆".repeat(5 - rating)}
      </span>
    );
  };

  const getSubtitle = (item: CollectionItem): string => {
    const meta = item.metadata ?? {};
    if (item.media_type === "vinyl") return String(meta.artist ?? "");
    if (item.media_type === "book" || item.media_type === "audiobook")
      return String(meta.author ?? (Array.isArray(meta.authors) ? meta.authors.join(", ") : ""));
    if (item.media_type === "movie" || item.media_type === "documentary")
      return String(meta.genre ?? "");
    if (item.media_type === "show") return String(meta.genre ?? "");
    return "";
  };

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString(undefined, {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  };

  const statuses = ALL_STATUSES;

  return (
    <div className="space-y-6">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">Collection</h1>
          <p className="text-muted-foreground">
            Browse and manage your media collection.
          </p>
        </div>
        <Link to={`/search${mediaType !== "all" ? `?type=${mediaType}` : ""}`}>
          <Button className="w-full sm:w-auto">Add Items</Button>
        </Link>
      </div>

      <div className="flex flex-wrap items-center gap-2 sm:gap-3">
        <form onSubmit={handleSearch} className="flex gap-2 w-full sm:w-auto">
          <Input
            placeholder="Search collection..."
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            className="w-full sm:w-48"
          />
        </form>
        <Select
          value={mediaType}
          onValueChange={(v) => updateFilter("media_type", v)}
        >
          <SelectTrigger className="w-[calc(50%-0.25rem)] sm:w-36">
            <SelectValue placeholder="All Types">{findLabel(MEDIA_TYPES, mediaType)}</SelectValue>
          </SelectTrigger>
          <SelectContent>
            {MEDIA_TYPES.map((t) => (
              <SelectItem key={t.value} value={t.value}>
                {t.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Select
          value={statusFilter}
          onValueChange={(v) => updateFilter("status", v)}
        >
          <SelectTrigger className="w-[calc(50%-0.25rem)] sm:w-36">
            <SelectValue placeholder="All Statuses">{findLabel(statuses, statusFilter)}</SelectValue>
          </SelectTrigger>
          <SelectContent>
            {statuses.map((s) => (
              <SelectItem key={s.value} value={s.value}>
                {s.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Select
          value={sortBy}
          onValueChange={(v) => updateFilter("sort_by", v)}
        >
          <SelectTrigger className="w-[calc(50%-0.25rem)] sm:w-36">
            <SelectValue placeholder="Date Added">{findLabel(SORT_OPTIONS, sortBy)}</SelectValue>
          </SelectTrigger>
          <SelectContent>
            {SORT_OPTIONS.map((s) => (
              <SelectItem key={s.value} value={s.value}>
                {s.label}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Button
          variant={sortOrder === "asc" ? "secondary" : "outline"}
          size="icon"
          onClick={() =>
            updateFilter("sort_order", sortOrder === "asc" ? "desc" : "asc")
          }
          title={sortOrder === "asc" ? "Ascending" : "Descending"}
        >
          <svg
            className="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={1.5}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d={
                sortOrder === "asc"
                  ? "M3 4h13M3 8h9m-9 4h6m4 0l4-4m0 0l4 4m-4-4v12"
                  : "M3 4h13M3 8h9m-9 4h9m5-4v12m0 0l-4-4m4 4l4-4"
              }
            />
          </svg>
        </Button>
        <Button
          variant={isFav ? "secondary" : "outline"}
          size="icon"
          onClick={() => updateFilter("is_favorite", !isFav)}
          title="Favorites"
        >
          <svg
            className="h-4 w-4"
            fill={isFav ? "currentColor" : "none"}
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={1.5}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"
            />
          </svg>
        </Button>

        {/* View mode toggle */}
        <Button
          variant={viewMode === "grid" ? "secondary" : "outline"}
          size="icon"
          onClick={() => updateParams({ view: "grid" })}
          title="Grid view"
        >
          <svg
            className="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={1.5}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z"
            />
          </svg>
        </Button>
        <Button
          variant={viewMode === "list" ? "secondary" : "outline"}
          size="icon"
          onClick={() => updateParams({ view: "list" })}
          title="List view"
        >
          <svg
            className="h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={1.5}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M8.25 6.75h12M8.25 12h12m-12 5.25h12M3.75 6.75h.007v.008H3.75V6.75zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zM3.75 12h.007v.008H3.75V12zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm-.375 5.25h.007v.008H3.75v-.008zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z"
            />
          </svg>
        </Button>
      </div>

      {isLoading ? (
        viewMode === "grid" ? (
          <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6">
            {Array.from({ length: 12 }).map((_, i) => (
              <Skeleton key={i} className="aspect-[3/4] rounded-lg" />
            ))}
          </div>
        ) : (
          <div className="space-y-2">
            {Array.from({ length: 8 }).map((_, i) => (
              <Skeleton key={i} className="h-14 w-full rounded-lg" />
            ))}
          </div>
        )
      ) : items.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12 text-center">
            <p className="text-muted-foreground">No items found.</p>
            <Link
              to={`/search${mediaType !== "all" ? `?type=${mediaType}` : ""}`}
              className="mt-2 text-sm text-primary hover:underline"
            >
              Search for something to add
            </Link>
          </CardContent>
        </Card>
      ) : (
        <>
          {viewMode === "grid" ? (
            <ShelfGrid items={items} onItemClick={saveScroll} />
          ) : (
            /* List / Table view */
            <Card className="overflow-hidden">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-12"></TableHead>
                    <TableHead>Title</TableHead>
                    <TableHead className="hidden sm:table-cell">Details</TableHead>
                    <TableHead className="hidden md:table-cell">Type</TableHead>
                    <TableHead className="hidden md:table-cell">Status</TableHead>
                    <TableHead className="hidden lg:table-cell">Rating</TableHead>
                    <TableHead className="hidden lg:table-cell">Added</TableHead>
                    <TableHead className="hidden xl:table-cell">By</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {items.map((item) => (
                    <TableRow key={item.id} className="cursor-pointer">
                      <TableCell className="p-2">
                        <Link
                          to={`/collection/${item.id}`}
                          onClick={saveScroll}
                          className="block"
                        >
                          <div className="h-10 w-10 flex-shrink-0 overflow-hidden rounded bg-muted">
                            {item.image_url ? (
                              <img
                                src={item.image_url}
                                alt={item.title}
                                className="h-full w-full object-cover"
                              />
                            ) : (
                              <span className="flex h-full w-full items-center justify-center text-xs text-muted-foreground">
                                {item.title[0]}
                              </span>
                            )}
                          </div>
                        </Link>
                      </TableCell>
                      <TableCell>
                        <Link
                          to={`/collection/${item.id}`}
                          onClick={saveScroll}
                          className="block"
                        >
                          <div className="flex items-center gap-2">
                            <span className="font-medium truncate max-w-[200px] sm:max-w-[300px]">
                              {item.title}
                            </span>
                            {item.is_favorite && (
                              <span className="text-yellow-500 text-xs flex-shrink-0">★</span>
                            )}
                          </div>
                          {/* Show subtitle on mobile since artist column is hidden */}
                          <p className="text-xs text-muted-foreground truncate sm:hidden">
                            {getSubtitle(item)}
                          </p>
                        </Link>
                      </TableCell>
                      <TableCell className="hidden sm:table-cell">
                        <Link
                          to={`/collection/${item.id}`}
                          onClick={saveScroll}
                          className="block text-muted-foreground truncate max-w-[180px]"
                        >
                          {getSubtitle(item) || "—"}
                        </Link>
                      </TableCell>
                      <TableCell className="hidden md:table-cell">
                        <Link to={`/collection/${item.id}`} onClick={saveScroll}>
                          <Badge variant="outline" className="text-[10px] capitalize">
                            {item.media_type}
                          </Badge>
                        </Link>
                      </TableCell>
                      <TableCell className="hidden md:table-cell">
                        <Link
                          to={`/collection/${item.id}`}
                          onClick={saveScroll}
                          className="block capitalize text-muted-foreground text-xs"
                        >
                          {item.status ? getStatusLabel(item.status) : "—"}
                        </Link>
                      </TableCell>
                      <TableCell className="hidden lg:table-cell">
                        <Link to={`/collection/${item.id}`} onClick={saveScroll}>
                          {renderStars(item.rating) || (
                            <span className="text-xs text-muted-foreground">—</span>
                          )}
                        </Link>
                      </TableCell>
                      <TableCell className="hidden lg:table-cell">
                        <Link
                          to={`/collection/${item.id}`}
                          onClick={saveScroll}
                          className="block text-xs text-muted-foreground"
                        >
                          {formatDate(item.added_at)}
                        </Link>
                      </TableCell>
                      <TableCell className="hidden xl:table-cell">
                        <Link
                          to={`/collection/${item.id}`}
                          onClick={saveScroll}
                          className="block text-xs text-muted-foreground"
                        >
                          {item.added_by_name || "—"}
                        </Link>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </Card>
          )}

          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-2">
              <Button
                variant="outline"
                size="sm"
                disabled={page <= 1}
                onClick={() => handlePageChange(page - 1)}
              >
                Previous
              </Button>
              <span className="text-sm text-muted-foreground">
                Page {page} of {totalPages}
              </span>
              <Button
                variant="outline"
                size="sm"
                disabled={page >= totalPages}
                onClick={() => handlePageChange(page + 1)}
              >
                Next
              </Button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
