import { useCallback, useEffect, useState } from "react";
import { toast } from "sonner";
import { apiFetch, ApiError } from "@/lib/api";
import { getStatusLabel, getWantStatusForType } from "@/lib/statuses";
import type { Recommendation, RecommendationsResponse } from "@/lib/types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Skeleton } from "@/components/ui/skeleton";
import { ShelfGrid } from "@/components/ShelfGrid";

const POLL_MS = 5000;

type ShelfRec = Recommendation & { id: string };

function timeAgo(iso: string): string {
  const hours = Math.round((Date.now() - new Date(iso).getTime()) / 3_600_000);
  if (hours < 1) return "just now";
  if (hours < 24) return `${hours}h ago`;
  return `${Math.round(hours / 24)}d ago`;
}

function modelName(provider: string | null): string {
  // "ollama:gemma3:12b" -> "gemma3:12b"; "claude:claude-opus-5-5" -> "claude-opus-5-5"
  return provider ? provider.slice(provider.indexOf(":") + 1) : "AI";
}

export function RecommendedShelf() {
  const [data, setData] = useState<RecommendationsResponse | null>(null);
  const [selected, setSelected] = useState<ShelfRec | null>(null);
  const [isAdding, setIsAdding] = useState(false);

  const load = useCallback(
    () =>
      apiFetch<RecommendationsResponse>("/recommendations/")
        .then(setData)
        .catch(() => {}),
    []
  );

  useEffect(() => {
    load();
  }, [load]);

  // While a rebuild runs in the background, check back until it finishes
  useEffect(() => {
    if (!data?.refreshing) return;
    const timer = setInterval(load, POLL_MS);
    return () => clearInterval(timer);
  }, [data?.refreshing, load]);

  const refresh = async () => {
    try {
      await apiFetch("/recommendations/refresh", { method: "POST" });
      setData((prev) => prev && { ...prev, refreshing: true });
    } catch (err) {
      toast.error(err instanceof ApiError ? err.message : "Couldn't start a refresh");
    }
  };

  const handleAdd = async () => {
    if (!selected) return;
    setIsAdding(true);
    try {
      await apiFetch("/collection/", {
        method: "POST",
        body: JSON.stringify({
          media_type: selected.media_type,
          external_id: selected.external_id,
          title: selected.title,
          image_url: selected.image_url,
          metadata: selected.metadata ?? {},
          status: getWantStatusForType(selected.media_type),
        }),
      });
      toast.success(`Added "${selected.title}" to your collection`);
      setSelected(null);
      load(); // the server drops picks you now own
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

  if (!data?.enabled) return null;

  const picks: ShelfRec[] = data.recommendations.map((r) => ({
    ...r,
    id: `${r.media_type}:${r.external_id}`,
  }));

  return (
    <div>
      <div className="mb-4 flex items-end justify-between gap-4">
        <div>
          <h2 className="text-xl font-semibold">Recommended for You</h2>
          <p className="text-sm text-muted-foreground">
            {data.refreshing
              ? "Picking from your library… this takes about a minute."
              : data.generated_at
                ? `Picked by ${modelName(data.provider)} · ${timeAgo(data.generated_at)}`
                : "Picked from what you rate highly and finish."}
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={refresh} disabled={data.refreshing}>
          {data.refreshing ? "Refreshing…" : "Refresh"}
        </Button>
      </div>

      {data.last_error && !data.refreshing && (
        <p className="mb-3 text-sm text-muted-foreground">
          {data.last_error}
          {picks.length > 0 && " Showing your last picks."}
        </p>
      )}

      {picks.length > 0 ? (
        <ShelfGrid items={picks} onSelect={setSelected} />
      ) : data.refreshing ? (
        <div className="grid grid-cols-3 gap-4 md:grid-cols-6">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="aspect-square rounded-lg" />
          ))}
        </div>
      ) : (
        !data.last_error && (
          <p className="text-sm text-muted-foreground">
            No picks yet. Refresh to build your first set.
          </p>
        )
      )}

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
                  {selected.subtitle && selected.subtitle !== selected.year && (
                    <p className="text-sm text-muted-foreground">{selected.subtitle}</p>
                  )}
                  <div className="flex flex-wrap gap-2">
                    <Badge variant="secondary" className="capitalize">
                      {selected.media_type}
                    </Badge>
                    {selected.year && <Badge variant="secondary">{selected.year}</Badge>}
                  </div>
                  {selected.reason && <p className="text-sm">{selected.reason}</p>}
                </div>
              </div>
              <Button className="w-full" onClick={handleAdd} disabled={isAdding}>
                {isAdding
                  ? "Adding..."
                  : `Add as ${getStatusLabel(getWantStatusForType(selected.media_type))}`}
              </Button>
            </>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
