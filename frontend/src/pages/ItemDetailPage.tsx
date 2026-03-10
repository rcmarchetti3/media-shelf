import { useEffect, useState, useCallback } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { apiFetch } from "@/lib/api";
import { usePageTitle } from "@/hooks/usePageTitle";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { toast } from "sonner";
import type { CollectionItem, SearchResult, SearchResponse } from "@/lib/types";

function getSearchEndpoint(mediaType: string): string {
  switch (mediaType) {
    case "vinyl":
      return "vinyl";
    case "book":
    case "audiobook":
      return "books";
    case "movie":
    case "documentary":
      return "movies";
    case "show":
      return "shows";
    default:
      return "movies";
  }
}

/** Pretty-print a metadata key into a label */
function formatKey(key: string): string {
  return key
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

/** Format a metadata value for display */
function formatValue(value: unknown): string {
  if (Array.isArray(value)) return value.join(", ");
  if (typeof value === "boolean") return value ? "Yes" : "No";
  return String(value ?? "");
}

const STATUS_LABELS: Record<string, string> = {
  owned: "Owned",
  wishlist: "Wishlist",
  in_progress: "In Progress",
  completed: "Completed",
  dropped: "Dropped",
};

export function ItemDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [item, setItem] = useState<CollectionItem | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [showDelete, setShowDelete] = useState(false);
  const [showArtwork, setShowArtwork] = useState(false);
  const [editFields, setEditFields] = useState({
    rating: "",
    status: "",
    notes: "",
    tags: "",
    is_favorite: false,
  });

  // Artwork / metadata search state
  const [manualUrl, setManualUrl] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<SearchResult[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [isApplying, setIsApplying] = useState(false);

  // All metadata values (editable)
  const [metaValues, setMetaValues] = useState<Record<string, string>>({});

  // New field form
  const [newFieldKey, setNewFieldKey] = useState("");
  const [newFieldValue, setNewFieldValue] = useState("");

  // Dynamic page title
  usePageTitle(item ? item.title : undefined);

  const syncFromItem = useCallback((data: CollectionItem) => {
    setItem(data);
    setEditFields({
      rating: data.rating?.toString() ?? "",
      status: data.status ?? "owned",
      notes: data.notes ?? "",
      tags: data.tags?.join(", ") ?? "",
      is_favorite: data.is_favorite ?? false,
    });
    const meta = data.metadata ?? {};
    const vals: Record<string, string> = {};
    for (const [key, value] of Object.entries(meta)) {
      vals[key] = Array.isArray(value) ? value.join(", ") : String(value ?? "");
    }
    setMetaValues(vals);
  }, []);

  useEffect(() => {
    apiFetch<CollectionItem>(`/collection/${id}`)
      .then(syncFromItem)
      .catch(() => navigate("/collection"))
      .finally(() => setIsLoading(false));
  }, [id, navigate, syncFromItem]);

  const enterEditMode = () => {
    // Re-sync from current item state before editing
    if (item) syncFromItem(item);
    setIsEditing(true);
  };

  const cancelEdit = () => {
    // Reset to saved state
    if (item) syncFromItem(item);
    setNewFieldKey("");
    setNewFieldValue("");
    setIsEditing(false);
  };

  const handleSave = async () => {
    setIsSaving(true);
    try {
      // Build metadata from metaValues
      const mergedMeta: Record<string, unknown> = {};
      for (const [key, val] of Object.entries(metaValues)) {
        if (val === "") continue;
        const orig = item?.metadata?.[key];
        if (Array.isArray(orig)) {
          mergedMeta[key] = val.split(",").map((s) => s.trim()).filter(Boolean);
        } else if (typeof orig === "number") {
          const num = Number(val);
          mergedMeta[key] = isNaN(num) ? val : num;
        } else if (typeof orig === "boolean") {
          mergedMeta[key] = val.toLowerCase() === "true" || val === "1" || val.toLowerCase() === "yes";
        } else {
          mergedMeta[key] = val;
        }
      }

      const updated = await apiFetch<CollectionItem>(`/collection/${id}`, {
        method: "PATCH",
        body: JSON.stringify({
          rating: editFields.rating ? parseInt(editFields.rating) : null,
          status: editFields.status,
          notes: editFields.notes || null,
          tags: editFields.tags
            ? editFields.tags
                .split(",")
                .map((t) => t.trim())
                .filter(Boolean)
            : [],
          is_favorite: editFields.is_favorite,
          metadata: mergedMeta,
        }),
      });
      syncFromItem(updated);
      setNewFieldKey("");
      setNewFieldValue("");
      setIsEditing(false);
      toast.success("Changes saved");
    } catch {
      toast.error("Failed to save changes");
    } finally {
      setIsSaving(false);
    }
  };

  const handleDelete = async () => {
    try {
      await apiFetch(`/collection/${id}`, { method: "DELETE" });
      toast.success("Item removed from collection");
      navigate("/collection");
    } catch {
      toast.error("Failed to remove item");
    }
  };

  const openArtworkDialog = () => {
    setManualUrl(item?.image_url ?? "");
    setSearchQuery(item?.title ?? "");
    setSearchResults([]);
    setShowArtwork(true);
  };

  const handleSearchMetadata = useCallback(async () => {
    if (!searchQuery.trim() || !item) return;
    setIsSearching(true);
    try {
      const endpoint = getSearchEndpoint(item.media_type);
      const data = await apiFetch<SearchResponse>(
        `/search/${endpoint}?q=${encodeURIComponent(searchQuery.trim())}&page=1`
      );
      setSearchResults(data.results);
    } catch {
      toast.error("Search failed. Check that API keys are configured.");
      setSearchResults([]);
    } finally {
      setIsSearching(false);
    }
  }, [searchQuery, item]);

  const applyManualUrl = async () => {
    if (!manualUrl.trim()) return;
    setIsApplying(true);
    try {
      const updated = await apiFetch<CollectionItem>(`/collection/${id}`, {
        method: "PATCH",
        body: JSON.stringify({ image_url: manualUrl.trim() }),
      });
      syncFromItem(updated);
      setShowArtwork(false);
      toast.success("Artwork updated");
    } catch {
      toast.error("Failed to update artwork");
    } finally {
      setIsApplying(false);
    }
  };

  const applySearchResult = async (result: SearchResult) => {
    setIsApplying(true);
    try {
      const existingMeta = item?.metadata ?? {};
      const mergedMeta = { ...existingMeta, ...result.metadata };
      const updated = await apiFetch<CollectionItem>(`/collection/${id}`, {
        method: "PATCH",
        body: JSON.stringify({
          image_url: result.image_url,
          metadata: mergedMeta,
        }),
      });
      syncFromItem(updated);
      setShowArtwork(false);
      toast.success("Artwork and metadata applied (existing data preserved)");
    } catch {
      toast.error("Failed to apply metadata");
    } finally {
      setIsApplying(false);
    }
  };

  const handleAddField = () => {
    const key = newFieldKey.trim().toLowerCase().replace(/\s+/g, "_");
    if (!key) return;
    if (key in metaValues) {
      toast.error("Field already exists");
      return;
    }
    setMetaValues((prev) => ({ ...prev, [key]: newFieldValue }));
    setNewFieldKey("");
    setNewFieldValue("");
  };

  const handleRemoveField = (key: string) => {
    setMetaValues((prev) => {
      const next = { ...prev };
      delete next[key];
      return next;
    });
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <Skeleton className="h-8 w-48" />
        <div className="flex gap-6">
          <Skeleton className="h-64 w-44 rounded-lg" />
          <div className="flex-1 space-y-4">
            <Skeleton className="h-6 w-full" />
            <Skeleton className="h-6 w-3/4" />
            <Skeleton className="h-6 w-1/2" />
          </div>
        </div>
      </div>
    );
  }

  if (!item) return null;

  const metadata = item.metadata ?? {};
  const metaKeys = Object.keys(isEditing ? metaValues : metadata);
  const renderStars = (count: number) =>
    "★".repeat(count) + "☆".repeat(5 - count);

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-2">
        <Button variant="ghost" size="sm" onClick={() => navigate(-1)}>
          <svg
            className="mr-1 h-4 w-4"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
            strokeWidth={1.5}
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M15.75 19.5L8.25 12l7.5-7.5"
            />
          </svg>
          Back
        </Button>
      </div>

      <div className="flex flex-col gap-6 md:flex-row">
        {/* Artwork */}
        <div className="shrink-0">
          <button
            onClick={openArtworkDialog}
            className="group relative h-64 w-44 overflow-hidden rounded-lg bg-muted flex items-center justify-center cursor-pointer border-2 border-transparent hover:border-primary/50 transition-colors"
            title="Edit artwork"
          >
            {item.image_url ? (
              <img
                src={item.image_url}
                alt={item.title}
                className="h-full w-full object-cover"
              />
            ) : (
              <span className="text-5xl text-muted-foreground">
                {item.title[0]}
              </span>
            )}
            <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
              <span className="text-white text-sm font-medium">
                Edit Artwork
              </span>
            </div>
          </button>
        </div>

        {/* Title + badges */}
        <div className="flex-1 space-y-4">
          <div>
            <h1 className="text-2xl font-bold">{item.title}</h1>
            <div className="mt-1 flex items-center gap-2">
              <Badge variant="outline" className="capitalize">
                {item.media_type}
              </Badge>
              {item.is_favorite && (
                <Badge variant="secondary">★ Favorite</Badge>
              )}
              {item.status && (
                <Badge variant="secondary" className="capitalize">
                  {STATUS_LABELS[item.status] ?? item.status}
                </Badge>
              )}
              {item.rating && (
                <span className="text-sm text-yellow-500">
                  {renderStars(item.rating)}
                </span>
              )}
            </div>
            {item.added_by_name && (
              <p className="mt-1 text-xs text-muted-foreground">
                Added by {item.added_by_name}
              </p>
            )}
          </div>

          {/* Read-only metadata summary (visible when not editing) */}
          {!isEditing && metaKeys.length > 0 && (
            <dl className="grid grid-cols-1 gap-x-4 gap-y-2 text-sm sm:grid-cols-2">
              {metaKeys.map((key) => (
                <div key={key}>
                  <dt className="text-muted-foreground">
                    {formatKey(key)}
                  </dt>
                  <dd className="font-medium">
                    {formatValue(metadata[key])}
                  </dd>
                </div>
              ))}
            </dl>
          )}

          {/* Notes (read-only) */}
          {!isEditing && item.notes && (
            <div className="text-sm">
              <p className="text-muted-foreground">Notes</p>
              <p className="mt-0.5 whitespace-pre-wrap">{item.notes}</p>
            </div>
          )}

          {/* Tags (read-only) */}
          {!isEditing && item.tags && item.tags.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {item.tags.map((tag) => (
                <Badge key={tag} variant="outline" className="text-xs">
                  {tag}
                </Badge>
              ))}
            </div>
          )}

          {/* Edit button (view mode) */}
          {!isEditing && (
            <div className="flex gap-2 pt-2">
              <Button variant="outline" size="sm" onClick={enterEditMode}>
                <svg
                  className="mr-1.5 h-3.5 w-3.5"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  strokeWidth={1.5}
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10"
                  />
                </svg>
                Edit
              </Button>
              <Button
                variant="ghost"
                size="sm"
                className="text-destructive hover:text-destructive"
                onClick={() => setShowDelete(true)}
              >
                Remove
              </Button>
            </div>
          )}
        </div>
      </div>

      {/* ─── Edit Mode ─── */}
      {isEditing && (
        <Card>
          <CardContent className="space-y-6 pt-6">
            {/* Status / Rating / Tags / Favorite */}
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
              <div className="space-y-2">
                <Label>Status</Label>
                <Select
                  value={editFields.status}
                  onValueChange={(v) =>
                    setEditFields((prev) => ({ ...prev, status: v ?? "owned" }))
                  }
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="owned">Owned</SelectItem>
                    <SelectItem value="wishlist">Wishlist</SelectItem>
                    {item.media_type !== "vinyl" && (
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
                  value={editFields.rating}
                  onValueChange={(v) =>
                    setEditFields((prev) => ({ ...prev, rating: v ?? "" }))
                  }
                >
                  <SelectTrigger>
                    <SelectValue placeholder="None" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="">None</SelectItem>
                    <SelectItem value="1">★</SelectItem>
                    <SelectItem value="2">★★</SelectItem>
                    <SelectItem value="3">★★★</SelectItem>
                    <SelectItem value="4">★★★★</SelectItem>
                    <SelectItem value="5">★★★★★</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>Tags</Label>
                <Input
                  placeholder="rock, favorite, 2024..."
                  value={editFields.tags}
                  onChange={(e) =>
                    setEditFields((prev) => ({ ...prev, tags: e.target.value }))
                  }
                />
              </div>
              <div className="flex items-end">
                <Button
                  variant={editFields.is_favorite ? "secondary" : "outline"}
                  className="w-full"
                  onClick={() =>
                    setEditFields((prev) => ({
                      ...prev,
                      is_favorite: !prev.is_favorite,
                    }))
                  }
                >
                  {editFields.is_favorite ? "★ Favorite" : "☆ Favorite"}
                </Button>
              </div>
            </div>

            {/* Notes */}
            <div className="space-y-2">
              <Label>Notes</Label>
              <textarea
                className="flex min-h-20 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                placeholder="Add personal notes..."
                value={editFields.notes}
                onChange={(e) =>
                  setEditFields((prev) => ({ ...prev, notes: e.target.value }))
                }
              />
            </div>

            {/* Metadata fields */}
            {metaKeys.length > 0 && (
              <>
                <div className="border-t border-border" />
                <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                  {metaKeys.map((key) => (
                    <div key={key} className="space-y-1">
                      <div className="flex items-center justify-between">
                        <Label className="text-xs text-muted-foreground">
                          {formatKey(key)}
                        </Label>
                        <button
                          type="button"
                          onClick={() => handleRemoveField(key)}
                          className="text-muted-foreground hover:text-destructive transition-colors"
                          title={`Remove ${formatKey(key)}`}
                        >
                          <svg
                            className="h-3.5 w-3.5"
                            fill="none"
                            viewBox="0 0 24 24"
                            stroke="currentColor"
                            strokeWidth={1.5}
                          >
                            <path
                              strokeLinecap="round"
                              strokeLinejoin="round"
                              d="M6 18L18 6M6 6l12 12"
                            />
                          </svg>
                        </button>
                      </div>
                      <Input
                        value={metaValues[key]}
                        onChange={(e) =>
                          setMetaValues((prev) => ({
                            ...prev,
                            [key]: e.target.value,
                          }))
                        }
                        className="h-8 text-sm"
                      />
                    </div>
                  ))}
                </div>
              </>
            )}

            {/* Add new field */}
            <div className="flex items-end gap-2 pt-2 border-t border-border">
              <div className="flex-1 space-y-1">
                <Label className="text-xs">New Field</Label>
                <Input
                  placeholder="Field name (e.g. director)"
                  value={newFieldKey}
                  onChange={(e) => setNewFieldKey(e.target.value)}
                  className="h-8 text-sm"
                />
              </div>
              <div className="flex-1 space-y-1">
                <Label className="text-xs">Value</Label>
                <Input
                  placeholder="Value"
                  value={newFieldValue}
                  onChange={(e) => setNewFieldValue(e.target.value)}
                  className="h-8 text-sm"
                  onKeyDown={(e) => {
                    if (e.key === "Enter") {
                      e.preventDefault();
                      handleAddField();
                    }
                  }}
                />
              </div>
              <Button
                variant="outline"
                size="sm"
                onClick={handleAddField}
                disabled={!newFieldKey.trim()}
                className="h-8"
              >
                Add
              </Button>
            </div>

            {/* Save / Cancel */}
            <div className="flex gap-2 pt-2 border-t border-border">
              <Button onClick={handleSave} disabled={isSaving}>
                {isSaving ? "Saving..." : "Save Changes"}
              </Button>
              <Button variant="outline" onClick={cancelEdit} disabled={isSaving}>
                Cancel
              </Button>
              <div className="flex-1" />
              <Button
                variant="ghost"
                className="text-destructive hover:text-destructive"
                onClick={() => setShowDelete(true)}
              >
                Remove
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Delete confirmation dialog */}
      <Dialog open={showDelete} onOpenChange={setShowDelete}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Remove from collection?</DialogTitle>
          </DialogHeader>
          <p className="text-sm text-muted-foreground">
            This will permanently remove "{item.title}" from your collection.
          </p>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowDelete(false)}>
              Cancel
            </Button>
            <Button variant="destructive" onClick={handleDelete}>
              Remove
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Artwork & Metadata dialog */}
      <Dialog open={showArtwork} onOpenChange={setShowArtwork}>
        <DialogContent className="max-w-2xl max-h-[85vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Update Artwork & Metadata</DialogTitle>
          </DialogHeader>
          <Tabs defaultValue="search">
            <TabsList className="w-full">
              <TabsTrigger value="search" className="flex-1">
                Search & Apply
              </TabsTrigger>
              <TabsTrigger value="manual" className="flex-1">
                Manual URL
              </TabsTrigger>
            </TabsList>

            <TabsContent value="search" className="space-y-4">
              <p className="text-sm text-muted-foreground">
                Search for this item in external databases to apply artwork and
                metadata.
              </p>
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  handleSearchMetadata();
                }}
                className="flex gap-2"
              >
                <Input
                  placeholder="Search title..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="flex-1"
                />
                <Button type="submit" disabled={isSearching}>
                  {isSearching ? "Searching..." : "Search"}
                </Button>
              </form>

              {searchResults.length > 0 && (
                <div className="grid gap-3 sm:grid-cols-2">
                  {searchResults.slice(0, 8).map((result) => (
                    <button
                      key={result.external_id}
                      onClick={() => applySearchResult(result)}
                      disabled={isApplying}
                      className="flex gap-3 rounded-lg border p-2 text-left hover:bg-accent transition-colors disabled:opacity-50"
                    >
                      <div className="h-20 w-14 shrink-0 overflow-hidden rounded bg-muted flex items-center justify-center">
                        {result.image_url ? (
                          <img
                            src={result.image_url}
                            alt={result.title}
                            className="h-full w-full object-cover"
                          />
                        ) : (
                          <span className="text-lg text-muted-foreground">
                            {result.title[0]}
                          </span>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium truncate">
                          {result.title}
                        </p>
                        {result.subtitle && (
                          <p className="text-xs text-muted-foreground truncate">
                            {result.subtitle}
                          </p>
                        )}
                        {result.year && (
                          <Badge variant="secondary" className="mt-1 text-[10px]">
                            {result.year}
                          </Badge>
                        )}
                      </div>
                    </button>
                  ))}
                </div>
              )}

              {isSearching && (
                <div className="grid gap-3 sm:grid-cols-2">
                  {Array.from({ length: 4 }).map((_, i) => (
                    <Skeleton key={i} className="h-24 rounded-lg" />
                  ))}
                </div>
              )}
            </TabsContent>

            <TabsContent value="manual" className="space-y-4">
              <p className="text-sm text-muted-foreground">
                Paste an image URL directly.
              </p>
              <div className="space-y-2">
                <Label>Image URL</Label>
                <Input
                  placeholder="https://example.com/cover.jpg"
                  value={manualUrl}
                  onChange={(e) => setManualUrl(e.target.value)}
                />
              </div>
              {manualUrl && (
                <div className="flex justify-center">
                  <div className="h-40 w-28 overflow-hidden rounded-lg bg-muted">
                    <img
                      src={manualUrl}
                      alt="Preview"
                      className="h-full w-full object-cover"
                      onError={(e) => {
                        (e.target as HTMLImageElement).style.display = "none";
                      }}
                    />
                  </div>
                </div>
              )}
              <Button
                onClick={applyManualUrl}
                disabled={!manualUrl.trim() || isApplying}
                className="w-full"
              >
                {isApplying ? "Saving..." : "Apply Image"}
              </Button>
            </TabsContent>
          </Tabs>
        </DialogContent>
      </Dialog>
    </div>
  );
}
