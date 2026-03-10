import { useState, useEffect, useCallback } from "react";
import { apiFetch, ApiError } from "@/lib/api";
import { Input } from "@/components/ui/input";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { Badge } from "@/components/ui/badge";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { toast } from "sonner";
import type { SearchResult, SearchResponse, MediaType } from "@/lib/types";

const MEDIA_TABS: { value: MediaType; label: string }[] = [
  { value: "vinyl", label: "Vinyl" },
  { value: "book", label: "Books" },
  { value: "movie", label: "Movies" },
  { value: "show", label: "Shows" },
];

function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);
  return debounced;
}

export function SearchPage() {
  const [query, setQuery] = useState("");
  const [tab, setTab] = useState<MediaType>("vinyl");
  const [results, setResults] = useState<SearchResult[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(0);
  const [selected, setSelected] = useState<SearchResult | null>(null);
  const [addForm, setAddForm] = useState({ status: "owned", rating: "" });
  const [isAdding, setIsAdding] = useState(false);

  const debouncedQuery = useDebounce(query, 300);

  const search = useCallback(async () => {
    if (!debouncedQuery.trim()) {
      setResults([]);
      setTotalPages(0);
      return;
    }
    setIsLoading(true);
    try {
      const endpoint =
        tab === "book" ? "books" :
        tab === "vinyl" ? "vinyl" :
        tab === "movie" ? "movies" : "shows";
      const data = await apiFetch<SearchResponse>(
        `/search/${endpoint}?q=${encodeURIComponent(debouncedQuery)}&page=${page}`
      );
      setResults(data.results);
      setTotalPages(data.total_pages);
    } catch (err) {
      if (err instanceof ApiError && err.status === 503) {
        toast.error("API key not configured for this media type");
      }
      setResults([]);
    } finally {
      setIsLoading(false);
    }
  }, [debouncedQuery, tab, page]);

  useEffect(() => {
    search();
  }, [search]);

  useEffect(() => {
    setPage(1);
    setResults([]);
  }, [tab, debouncedQuery]);

  const handleAdd = async () => {
    if (!selected) return;
    setIsAdding(true);
    try {
      await apiFetch("/collection/", {
        method: "POST",
        body: JSON.stringify({
          media_type: tab,
          external_id: selected.external_id,
          title: selected.title,
          image_url: selected.image_url,
          metadata: selected.metadata,
          status: addForm.status,
          rating: addForm.rating ? parseInt(addForm.rating) : null,
        }),
      });
      toast.success(`Added "${selected.title}" to your collection`);
      setSelected(null);
      setAddForm({ status: "owned", rating: "" });
    } catch (err) {
      toast.error(
        err instanceof ApiError && err.status === 409
          ? "Already in your collection"
          : "Failed to add item"
      );
    } finally {
      setIsAdding(false);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Search</h1>
        <p className="text-muted-foreground">
          Find media to add to your collection.
        </p>
      </div>

      <div className="max-w-md">
        <Input
          placeholder="Search for titles, artists, authors..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          autoFocus
        />
      </div>

      <Tabs value={tab} onValueChange={(v) => setTab(v as MediaType)}>
        <TabsList>
          {MEDIA_TABS.map((t) => (
            <TabsTrigger key={t.value} value={t.value}>
              {t.label}
            </TabsTrigger>
          ))}
        </TabsList>

        {MEDIA_TABS.map((t) => (
          <TabsContent key={t.value} value={t.value}>
            {isLoading ? (
              <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
                {Array.from({ length: 10 }).map((_, i) => (
                  <Skeleton key={i} className="aspect-[3/4] rounded-lg" />
                ))}
              </div>
            ) : results.length === 0 ? (
              <div className="py-12 text-center text-muted-foreground">
                {debouncedQuery
                  ? "No results found."
                  : "Type something to search."}
              </div>
            ) : (
              <>
                <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
                  {results.map((result) => (
                    <Card
                      key={result.external_id}
                      className="cursor-pointer overflow-hidden transition-colors hover:bg-accent"
                      onClick={() => setSelected(result)}
                    >
                      <div className="aspect-[3/4] bg-muted flex items-center justify-center">
                        {result.image_url ? (
                          <img
                            src={result.image_url}
                            alt={result.title}
                            className="h-full w-full object-cover"
                          />
                        ) : (
                          <span className="text-4xl text-muted-foreground">
                            {result.title[0]}
                          </span>
                        )}
                      </div>
                      <CardContent className="p-3">
                        <p className="truncate text-sm font-medium">
                          {result.title}
                        </p>
                        {result.subtitle && (
                          <p className="truncate text-xs text-muted-foreground">
                            {result.subtitle}
                          </p>
                        )}
                      </CardContent>
                    </Card>
                  ))}
                </div>

                {totalPages > 1 && (
                  <div className="flex items-center justify-center gap-2 pt-6">
                    <Button
                      variant="outline"
                      size="sm"
                      disabled={page <= 1}
                      onClick={() => setPage((p) => p - 1)}
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
                      onClick={() => setPage((p) => p + 1)}
                    >
                      Next
                    </Button>
                  </div>
                )}
              </>
            )}
          </TabsContent>
        ))}
      </Tabs>

      <Dialog open={!!selected} onOpenChange={() => setSelected(null)}>
        <DialogContent className="max-w-lg">
          {selected && (
            <>
              <DialogHeader>
                <DialogTitle>{selected.title}</DialogTitle>
              </DialogHeader>
              <div className="flex gap-4">
                {selected.image_url && (
                  <img
                    src={selected.image_url}
                    alt={selected.title}
                    className="h-40 w-28 rounded-md object-cover"
                  />
                )}
                <div className="flex-1 space-y-2">
                  {selected.subtitle && (
                    <p className="text-sm text-muted-foreground">
                      {selected.subtitle}
                    </p>
                  )}
                  {selected.year && (
                    <Badge variant="secondary">{selected.year}</Badge>
                  )}
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4 pt-2">
                <div className="space-y-2">
                  <Label>Status</Label>
                  <Select
                    value={addForm.status}
                    onValueChange={(v) =>
                      setAddForm((prev) => ({ ...prev, status: v ?? "owned" }))
                    }
                  >
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="owned">Owned</SelectItem>
                      <SelectItem value="wishlist">Wishlist</SelectItem>
                      {tab !== "vinyl" && (
                        <>
                          <SelectItem value="in_progress">In Progress</SelectItem>
                          <SelectItem value="completed">Completed</SelectItem>
                          <SelectItem value="dropped">Dropped</SelectItem>
                        </>
                      )}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>Rating</Label>
                  <Select
                    value={addForm.rating}
                    onValueChange={(v) =>
                      setAddForm((prev) => ({ ...prev, rating: v ?? "" }))
                    }
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="None" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="">None</SelectItem>
                      <SelectItem value="1">1</SelectItem>
                      <SelectItem value="2">2</SelectItem>
                      <SelectItem value="3">3</SelectItem>
                      <SelectItem value="4">4</SelectItem>
                      <SelectItem value="5">5</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
              <Button
                className="w-full"
                onClick={handleAdd}
                disabled={isAdding}
              >
                {isAdding ? "Adding..." : "Add to Collection"}
              </Button>
            </>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
