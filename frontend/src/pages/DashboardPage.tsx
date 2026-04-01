import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { apiFetch } from "@/lib/api";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { ShelfGrid } from "@/components/ShelfGrid";
import type { CollectionItem, CollectionStats } from "@/lib/types";

export function DashboardPage() {
  const { user } = useAuth();
  const [stats, setStats] = useState<CollectionStats | null>(null);
  const [recent, setRecent] = useState<CollectionItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      apiFetch<CollectionStats>("/collection/stats"),
      apiFetch<{ items: CollectionItem[] }>(
        "/collection/?sort_by=added_at&sort_order=desc&page_size=12"
      ),
    ])
      .then(([statsData, collectionData]) => {
        setStats(statsData);
        setRecent(collectionData.items);
      })
      .catch(() => {})
      .finally(() => setIsLoading(false));
  }, []);

  const mediaTypes = [
    { key: "vinyl", label: "Vinyl", icon: "M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" },
    { key: "book", label: "Books", icon: "M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" },
    { key: "movie", label: "Movies", icon: "M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" },
    { key: "show", label: "Shows", icon: "M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" },
    { key: "documentary", label: "Docs", icon: "M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" },
    { key: "audiobook", label: "Audiobooks", icon: "M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" },
  ];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">
          Welcome back, {user?.display_name?.split(" ")[0]}
        </h1>
        <p className="text-muted-foreground">
          Here's an overview of your collection.
        </p>
      </div>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        {mediaTypes.map((type) => (
          <div key={type.key} className="stat-plaque rounded-lg p-4 text-center">
            <div className="flex items-center justify-between mb-1">
              <p className="text-xs font-semibold uppercase tracking-wider text-primary-foreground/70">
                {type.label}
              </p>
              <svg
                className="h-4 w-4 text-primary-foreground/60"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                strokeWidth={1.5}
              >
                <path strokeLinecap="round" strokeLinejoin="round" d={type.icon} />
              </svg>
            </div>
            {isLoading ? (
              <Skeleton className="h-8 w-12 mx-auto" />
            ) : (
              <p className="text-2xl font-bold text-primary-foreground">
                {stats?.[type.key as keyof CollectionStats] ?? 0}
              </p>
            )}
          </div>
        ))}
      </div>

      <div>
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-xl font-semibold">Recently Added</h2>
          <Link
            to="/collection"
            className="text-sm text-muted-foreground hover:text-primary"
          >
            View all
          </Link>
        </div>
        {isLoading ? (
          <div className="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-6">
            {Array.from({ length: 6 }).map((_, i) => (
              <Skeleton key={i} className="aspect-square rounded-lg" />
            ))}
          </div>
        ) : recent.length === 0 ? (
          <Card>
            <CardContent className="flex flex-col items-center justify-center py-12 text-center">
              <p className="text-muted-foreground">
                Your collection is empty.
              </p>
              <Link
                to="/search"
                className="mt-2 text-sm text-primary hover:underline"
              >
                Start searching to add items
              </Link>
            </CardContent>
          </Card>
        ) : (
          <ShelfGrid items={recent} />
        )}
      </div>
    </div>
  );
}
