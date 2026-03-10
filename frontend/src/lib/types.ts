export interface User {
  id: string;
  username: string;
  email: string;
  display_name: string;
  role: "admin" | "member";
  is_active: boolean;
  created_at: string;
}

export interface TokenResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
}

export type MediaType =
  | "vinyl"
  | "book"
  | "show"
  | "movie"
  | "documentary"
  | "audiobook";

export type ItemStatus =
  | "completed"
  | "in_progress"
  | "want_to_watch_read"
  | "dropped"
  | "owned"
  | "wishlist";

export interface CollectionItem {
  id: string;
  user_id: string;
  media_type: MediaType;
  external_id: string | null;
  title: string;
  image_url: string | null;
  metadata: Record<string, unknown>;
  rating: number | null;
  status: string | null;
  notes: string | null;
  tags: string[];
  is_favorite: boolean;
  added_at: string;
  updated_at: string;
  added_by_name: string | null;
}

export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
  total_pages: number;
}

export interface CollectionStats {
  total: number;
  vinyl: number;
  book: number;
  movie: number;
  show: number;
  documentary: number;
  audiobook: number;
  [key: string]: number;
}

export interface SearchResult {
  external_id: string;
  title: string;
  subtitle: string | null;
  image_url: string | null;
  media_type: MediaType;
  year: string | null;
  metadata: Record<string, unknown>;
}

export interface SearchResponse {
  results: SearchResult[];
  total: number;
  page: number;
  total_pages: number;
}

export interface CustomField {
  id: string;
  name: string;
  field_key: string;
  field_type: "text" | "number" | "select";
  options: string[];
  media_types: string[];
  created_at: string;
}
