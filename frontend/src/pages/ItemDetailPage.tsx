import { useEffect, useState, useCallback, useRef } from "react";
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
import { getStatusesForType, getStatusIcon, getStatusLabel, SEASON_KEYS } from "@/lib/statuses";
import { RawgCredit } from "@/components/RawgCredit";
import { getStatusClass } from "@/components/ShelfItem";

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
    case "game":
      return "games";
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

/**
 * The short "17 Feb 2022 · Drama · 2 seasons" line under the hero title.
 * Each string becomes one part, joined with " · "; return [] to hide the line.
 */
function heroMetaLine(item: CollectionItem): string[] {
  const m = item.metadata ?? {};
  const year = (v: unknown) => String(v ?? "").slice(0, 4);
  // At most two genres, so the line stays on one row on a phone. A genre that
  // just names the media type ("Documentary") repeats the overline, so it's dropped.
  const genres = (v: unknown) =>
    (Array.isArray(v) ? v.map(String) : String(v ?? "").split(","))
      .map((g) => g.trim())
      .filter((g) => g && g.toLowerCase() !== item.media_type)
      .slice(0, 2)
      .join(", ");

  let parts: string[];
  switch (item.media_type) {
    case "movie":
      parts = [year(m.release_date), genres(m.genre)];
      break;
    case "show": {
      const seasons = Number(m.total_seasons);
      parts = [
        year(m.first_air_date),
        genres(m.genre),
        seasons > 0 ? `${seasons} ${seasons === 1 ? "season" : "seasons"}` : "",
      ];
      break;
    }
    case "book":
    case "audiobook":
      // Author leads, the way a jacket reads
      parts = [formatValue(m.authors), year(m.publish_year)];
      break;
    case "documentary":
      parts = [genres(m.genre)];
      break;
    case "vinyl":
      parts = [formatValue(m.label), genres(m.genres)];
      break;
    default:
      parts = [genres(m.genre)];
  }
  // TMDB's vote_average is left out on purpose: your own stars sit right below
  return parts.filter(Boolean);
}

/** Season numbers from metadata, tolerating junk from hand-edited fields */
function readSeasons(value: unknown): number[] {
  if (!Array.isArray(value)) return [];
  return value.map(Number).filter((n) => Number.isInteger(n) && n > 0);
}

/**
 * Status to suggest after the season checklist changes. Returning `current`
 * leaves the status alone; the user can still override it before saving.
 */
function suggestShowStatus(current: string, watchedCount: number, totalSeasons: number): string {
  // Dropping a show is a deliberate call; logging old seasons shouldn't undo it
  if (current === "dropped" || watchedCount === 0) return current;
  if (totalSeasons > 0 && watchedCount >= totalSeasons) return "completed";
  // Partway through: a want-list or finished show is now in progress
  if (current === "want_to_watch" || current === "completed" || current === "") return "watching";
  return current;
}

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
  const [seasonFields, setSeasonFields] = useState({
    current_season: "",
    total_seasons: "",
  });
  const [seasonsWatched, setSeasonsWatched] = useState<number[]>([]);
  // Live season count from TMDB; a ref too, so re-syncing the form keeps it
  const [tmdbSeasons, setTmdbSeasons] = useState<number | null>(null);
  const tmdbSeasonsRef = useRef<number | null>(null);

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
      status: data.status ?? "",
      notes: data.notes ?? "",
      tags: data.tags?.join(", ") ?? "",
      is_favorite: data.is_favorite ?? false,
    });
    const meta = data.metadata ?? {};
    // Take whichever is higher: what's saved, or TMDB's count (new seasons air)
    const stored = Number(meta.total_seasons ?? meta.seasons_count) || 0;
    const totalSeasons = Math.max(stored, tmdbSeasonsRef.current ?? 0);
    setSeasonFields({
      current_season: meta.current_season != null ? String(meta.current_season) : "",
      total_seasons: totalSeasons > 0 ? String(totalSeasons) : "",
    });
    setSeasonsWatched(readSeasons(meta.seasons_watched));
    const vals: Record<string, string> = {};
    for (const [key, value] of Object.entries(meta)) {
      if (SEASON_KEYS.includes(key)) continue; // handled separately
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

  // Shows: look up how many seasons exist so nobody has to type it in
  const showLookupId =
    item?.media_type === "show" ? String(item.metadata?.tmdb_id ?? item.external_id ?? "") : "";
  useEffect(() => {
    if (!showLookupId) return;
    apiFetch<{ metadata: Record<string, unknown> }>(`/search/show/${encodeURIComponent(showLookupId)}`)
      .then((d) => {
        const n = Number(d.metadata?.seasons_count);
        if (!Number.isInteger(n) || n <= 0) return;
        tmdbSeasonsRef.current = n;
        setTmdbSeasons(n);
        setSeasonFields((prev) => ({
          ...prev,
          total_seasons: String(Math.max(parseInt(prev.total_seasons) || 0, n)),
        }));
      })
      .catch(() => {}); // offline or no TMDB key: the manual field still works
  }, [showLookupId]);

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

      // Merge season fields into metadata (as numbers, omit if empty)
      if (seasonFields.current_season !== "") {
        const n = parseInt(seasonFields.current_season);
        if (!isNaN(n)) mergedMeta.current_season = n;
      }
      if (seasonFields.total_seasons !== "") {
        const n = parseInt(seasonFields.total_seasons);
        if (!isNaN(n)) mergedMeta.total_seasons = n;
      }
      if (seasonsWatched.length > 0) {
        mergedMeta.seasons_watched = [...seasonsWatched].sort((a, b) => a - b);
      }

      const updated = await apiFetch<CollectionItem>(`/collection/${id}`, {
        method: "PATCH",
        body: JSON.stringify({
          rating: editFields.rating ? parseInt(editFields.rating) : null,
          status: editFields.status || null,
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

  const toggleSeason = (season: number) => {
    const total = parseInt(seasonFields.total_seasons) || 0;
    const next = seasonsWatched.includes(season)
      ? seasonsWatched.filter((s) => s !== season)
      : [...seasonsWatched, season];
    setSeasonsWatched(next);
    setEditFields((prev) => ({
      ...prev,
      status: suggestShowStatus(prev.status, next.length, total),
    }));
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
  // Season fields have their own badge and checklist, so keep them out of the generic list
  const metaKeys = Object.keys(isEditing ? metaValues : metadata).filter((k) => !SEASON_KEYS.includes(k));
  const renderStars = (count: number) =>
    "★".repeat(count) + "☆".repeat(5 - count);
  const metaLine = heroMetaLine(item);
  const statusIcon = getStatusIcon(item.status);
  const watchedSeasons = readSeasons(metadata.seasons_watched);
  // The overview leads the details panel as prose, so it skips the field grid
  const overview = typeof metadata.overview === "string" ? metadata.overview : "";
  const detailKeys = metaKeys.filter((k) => k !== "overview" && formatValue(metadata[k]).trim() !== "");
  const hasDetails = overview || detailKeys.length > 0 || item.notes || (item.tags?.length ?? 0) > 0;

  return (
    <div className="item-page -mx-4 -mt-4 md:-mx-6 md:-mt-6" data-backdrop={item.image_url ? "" : undefined}>
      {item.image_url && (
        <div
          aria-hidden
          className="item-page-backdrop"
          style={{ backgroundImage: `url(${JSON.stringify(item.image_url)})` }}
        />
      )}
      <div className="space-y-6 px-4 pt-4 pb-10 md:px-6 md:pt-6">
      <section className="item-hero flex flex-col gap-8">
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

        <div className="flex flex-col gap-6 sm:flex-row sm:items-end">
          {/* The item as its physical object, with its status glow, like on the shelf */}
          <button
            type="button"
            onClick={openArtworkDialog}
            className={`hero-object shelf-item type-${item.media_type} ${getStatusClass(item.status)} w-40 shrink-0 md:w-52`}
            title="Edit artwork"
          >
            <div className="item-cover">
              {item.image_url ? (
                <img src={item.image_url} alt={item.title} />
              ) : (
                item.title[0]
              )}
              <span className="hero-object-hint">Edit artwork</span>
            </div>
          </button>

          <div className="min-w-0 flex-1 space-y-3">
            <p className="hero-overline">{item.media_type}</p>
            <h1 className="text-4xl font-bold tracking-tight text-balance md:text-5xl">
              {item.title}
            </h1>
            {metaLine.length > 0 && (
              <p className="hero-meta">{metaLine.join(" · ")}</p>
            )}

            <div className="flex flex-wrap items-center gap-2 pt-1">
              {item.status && (
                <span className="glass-pill">
                  {statusIcon && <span aria-hidden>{statusIcon}</span>}
                  {getStatusLabel(item.status)}
                </span>
              )}
              {item.media_type === "show" && watchedSeasons.length > 0 ? (
                <span className="glass-pill">
                  {watchedSeasons.length}
                  {seasonFields.total_seasons ? ` of ${seasonFields.total_seasons}` : ""} seasons watched
                </span>
              ) : item.media_type === "show" && (metadata.current_season != null || seasonFields.total_seasons !== "") && (
                <span className="glass-pill">
                  Season {String(metadata.current_season ?? "?")}
                  {seasonFields.total_seasons ? ` of ${seasonFields.total_seasons}` : ""}
                </span>
              )}
              {item.is_favorite && <span className="glass-pill">★ Favorite</span>}
              {item.rating && (
                <span className="px-1 text-primary" aria-label={`${item.rating} of 5 stars`}>
                  {renderStars(item.rating)}
                </span>
              )}
            </div>

            {!isEditing && (
              <div className="flex flex-wrap items-center gap-2 pt-1">
                <button type="button" className="glass-pill glass-pill-action" onClick={enterEditMode}>
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
                      d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10"
                    />
                  </svg>
                  Edit
                </button>
                {/* Foreground, not destructive: small red text can't hold contrast over the art */}
                <button type="button" className="glass-pill glass-pill-action" onClick={() => setShowDelete(true)}>
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
                      d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"
                    />
                  </svg>
                  Remove
                </button>
              </div>
            )}
            {item.added_by_name && (
              <p className="text-xs text-muted-foreground">
                Added by {item.added_by_name}
              </p>
            )}
          </div>
        </div>
      </section>

      {/* ─── Details (view mode) ─── */}
      {!isEditing && hasDetails && (
        <section className="glass-panel space-y-5 p-4 md:p-6">
          {overview && (
            <p className="max-w-prose text-sm leading-relaxed md:text-base">{overview}</p>
          )}

          {detailKeys.length > 0 && (
            <dl className="grid grid-cols-1 gap-x-6 gap-y-3 text-sm sm:grid-cols-2 lg:grid-cols-3">
              {detailKeys.map((key) => (
                <div key={key}>
                  <dt className="glass-label">{formatKey(key)}</dt>
                  <dd className="font-medium">{formatValue(metadata[key])}</dd>
                </div>
              ))}
            </dl>
          )}

          {item.notes && (
            <div className="text-sm">
              <p className="glass-label">Notes</p>
              <p className="mt-0.5 whitespace-pre-wrap">{item.notes}</p>
            </div>
          )}

          {item.tags && item.tags.length > 0 && (
            <div className="flex flex-wrap gap-1.5">
              {item.tags.map((tag) => (
                <Badge key={tag} variant="outline" className="text-xs">
                  {tag}
                </Badge>
              ))}
            </div>
          )}
        </section>
      )}

      {metadata.source === "rawg" && <RawgCredit />}

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
                    setEditFields((prev) => ({ ...prev, status: v ?? "" }))
                  }
                >
                  <SelectTrigger>
                    <SelectValue placeholder="None">
                      {(getStatusesForType(item.media_type).find((s) => s.value === editFields.status)?.label ?? editFields.status) || "None"}
                    </SelectValue>
                  </SelectTrigger>
                  <SelectContent>
                    {getStatusesForType(item.media_type).map((s) => (
                      <SelectItem key={s.value} value={s.value}>
                        {s.label}
                      </SelectItem>
                    ))}
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
                    <SelectValue placeholder="None">
                      {editFields.rating ? "★".repeat(parseInt(editFields.rating)) : "None"}
                    </SelectValue>
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

            {/* Season tracking — shows only */}
            {item.media_type === "show" && (
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>Current Season</Label>
                  <Input
                    type="number"
                    min={1}
                    placeholder="e.g. 3"
                    value={seasonFields.current_season}
                    onChange={(e) =>
                      setSeasonFields((prev) => ({ ...prev, current_season: e.target.value }))
                    }
                  />
                </div>
                <div className="space-y-2">
                  <Label>Total Seasons</Label>
                  {tmdbSeasons ? (
                    <p className="flex h-9 items-center text-sm">
                      {seasonFields.total_seasons}
                      <span className="ml-1.5 text-muted-foreground">from TMDB</span>
                    </p>
                  ) : (
                    <Input
                      type="number"
                      min={1}
                      placeholder="e.g. 5"
                      value={seasonFields.total_seasons}
                      onChange={(e) =>
                        setSeasonFields((prev) => ({ ...prev, total_seasons: e.target.value }))
                      }
                    />
                  )}
                </div>
                <div className="col-span-2 space-y-2">
                  <Label>Seasons Watched</Label>
                  {parseInt(seasonFields.total_seasons) > 0 ? (
                    <div className="flex flex-wrap gap-1.5">
                      {Array.from({ length: Math.min(parseInt(seasonFields.total_seasons), 60) }, (_, i) => i + 1).map((n) => {
                        const watched = seasonsWatched.includes(n);
                        return (
                          <Button
                            key={n}
                            type="button"
                            size="sm"
                            variant={watched ? "default" : "outline"}
                            aria-pressed={watched}
                            onClick={() => toggleSeason(n)}
                            className="min-w-12"
                          >
                            {watched && "✓ "}S{n}
                          </Button>
                        );
                      })}
                    </div>
                  ) : (
                    <p className="text-sm text-muted-foreground">
                      Couldn't find a season count for this show. Set Total Seasons to tick off the ones you've watched.
                    </p>
                  )}
                </div>
              </div>
            )}

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
    </div>
  );
}
