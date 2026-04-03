export type MediaType =
  | "vinyl"
  | "book"
  | "audiobook"
  | "movie"
  | "documentary"
  | "show";

export interface StatusOption {
  value: string;
  label: string;
}

const VINYL_STATUSES: StatusOption[] = [
  { value: "owned", label: "Owned" },
  { value: "wishlist", label: "Wishlist" },
];

const BOOK_STATUSES: StatusOption[] = [
  { value: "reading", label: "Reading" },
  { value: "completed", label: "Completed" },
  { value: "wishlist", label: "Wishlist" },
  { value: "dropped", label: "Dropped" },
];

const MOVIE_STATUSES: StatusOption[] = [
  { value: "watched", label: "Watched" },
  { value: "want_to_watch", label: "Want to Watch" },
];

const SHOW_STATUSES: StatusOption[] = [
  { value: "watching", label: "Watching" },
  { value: "completed", label: "Completed" },
  { value: "want_to_watch", label: "Want to Watch" },
  { value: "dropped", label: "Dropped" },
];

export function getStatusesForType(mediaType: string): StatusOption[] {
  switch (mediaType) {
    case "vinyl":
      return VINYL_STATUSES;
    case "book":
    case "audiobook":
      return BOOK_STATUSES;
    case "movie":
    case "documentary":
      return MOVIE_STATUSES;
    case "show":
      return SHOW_STATUSES;
    default:
      return VINYL_STATUSES;
  }
}

export function getDefaultStatusForType(mediaType: string): string {
  switch (mediaType) {
    case "vinyl":
      return "owned";
    case "book":
    case "audiobook":
      return "wishlist";
    case "movie":
    case "documentary":
      return "want_to_watch";
    case "show":
      return "want_to_watch";
    default:
      return "owned";
  }
}

/** All statuses across every type, for collection-wide filtering */
export const ALL_STATUSES: StatusOption[] = [
  { value: "owned", label: "Owned" },
  { value: "wishlist", label: "Wishlist" },
  { value: "reading", label: "Reading" },
  { value: "in_progress", label: "In Progress" },
  { value: "completed", label: "Completed" },
  { value: "dropped", label: "Dropped" },
  { value: "watched", label: "Watched" },
  { value: "want_to_watch", label: "Want to Watch" },
  { value: "watching", label: "Watching" },
];

/** Human-readable label for any status value */
export function getStatusLabel(status: string): string {
  return ALL_STATUSES.find((s) => s.value === status)?.label ?? status;
}

/** Status icon symbol for shelf display */
export function getStatusIcon(status: string | null): string | null {
  switch (status) {
    case "completed":
    case "watched":
      return "✓";
    case "reading":
    case "watching":
      return "▶";
    case "owned":
      return "●";
    case "wishlist":
    case "want_to_watch":
      return "♡";
    case "dropped":
      return "✕";
    default:
      return null;
  }
}

/** Metadata keys reserved for the season UI — hidden from generic metadata fields */
export const SEASON_KEYS = ["current_season", "total_seasons"];
