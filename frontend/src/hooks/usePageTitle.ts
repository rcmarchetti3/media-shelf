import { useEffect } from "react";
import { useLocation, useSearchParams } from "react-router-dom";

const ROUTE_TITLES: Record<string, string> = {
  "/": "Dashboard",
  "/search": "Search",
  "/collection": "Collection",
  "/settings": "Settings",
  "/login": "Login",
  "/register": "Register",
};

const MEDIA_TYPE_LABELS: Record<string, string> = {
  vinyl: "Vinyl",
  book: "Books",
  movie: "Movies",
  show: "TV Shows",
  documentary: "Documentaries",
  audiobook: "Audiobooks",
};

/**
 * Sets the document title based on the current route.
 * Optionally accepts a custom suffix (e.g. item title for detail pages).
 */
export function usePageTitle(customTitle?: string) {
  const location = useLocation();
  const [searchParams] = useSearchParams();

  useEffect(() => {
    let title: string;

    if (customTitle) {
      title = customTitle;
    } else if (location.pathname.startsWith("/collection/") && location.pathname !== "/collection") {
      // Item detail page — will be set by the detail page with customTitle
      title = "Item Details";
    } else if (location.pathname === "/collection") {
      const type = searchParams.get("type");
      if (type && MEDIA_TYPE_LABELS[type]) {
        title = MEDIA_TYPE_LABELS[type];
      } else {
        title = "Collection";
      }
    } else {
      title = ROUTE_TITLES[location.pathname] || "MediaShelf";
    }

    document.title = title === "MediaShelf" ? "MediaShelf" : `${title} — MediaShelf`;
  }, [location.pathname, searchParams, customTitle]);
}
