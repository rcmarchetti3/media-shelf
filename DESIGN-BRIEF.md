# MediaShelf for iOS: design brief

This is the handoff for designing the native iPhone app. It describes what each screen does, how it behaves on iPhone Duo, and where the design has room to move. Hand this to Claude Design along with the web screenshots in `docs/screenshots/`.

## What we're building

A native SwiftUI client for the existing self-hosted MediaShelf backend. Same accounts, same data, same household. The phone talks to the same `/api/v1` the web app uses. Nothing moves to the cloud.

Target: iOS 27, iPhone Duo first, but it has to work on any iPhone. Deployed by Xcode onto the household's phones, not the App Store, so there's no review ceremony and no need for onboarding fluff.

## Design principles

**Glass chrome, wood content.** Navigation bars, tab bars, toolbars, sheets, and lists are all system components, so they get Liquid Glass and Duo behavior for free. Don't restyle them. The shelf itself is the brand: items sit on wooden shelves with a status glow. That survives the translation and should be the one place the app feels like itself rather than like Settings.

**Two sizes, not six poses.** The outer display is compact width. The inner display is regular width. Every screen needs those two layouts and nothing else. The system handles partial folding, rotation, and Split View if we use the right containers.

**Show one more level when open.** Closed: a list or grid. Open: that same list on the left, the selected item on the right. Mail's pattern. State doesn't change when the phone opens or closes, only how much of it is visible.

**Controls live on the side.** On the outer display and in landscape, iOS 27 moves toolbars and tab bars to the trailing edge, vertically. That's not something we design around. Every toolbar item gets both a symbol and a title so the system can render it as an icon on the side or as text in an overflow menu.

**Even columns.** The shelf grid uses 2, 4, or 6 columns so it splits cleanly across the fold when the phone is half open.

## Navigation model

Tab bar with four tabs:

| Tab | Symbol | What it is |
|---|---|---|
| Home | `house` | Dashboard: stats and recently added |
| Shelf | `books.vertical` | The collection, filterable by media type |
| Search | `magnifyingglass` | Search external sources and add to shelf |
| Settings | `gear` | Profile, server, household admin |

Search uses the system search tab role, so it becomes a search field in the tab bar on iOS 26 and later.

The web app's sidebar media type list (All, Vinyl, Movies, TV Shows, Books, Audiobooks, Documentaries) becomes a filter inside the Shelf tab, not its own navigation. One level less.

## Screens

### 1. Sign in and register

Replaces `LoginPage.tsx` and `RegisterPage.tsx`.

Needs a server URL field the first time (the user's own Tailscale or tunnel address), then username and password. Register asks for username, email, display name, password. First user to register becomes admin, same as the web.

Compact and regular layouts are the same: a centered form. Keep it short. Logo, three fields, one button.

### 2. Home

Replaces `DashboardPage.tsx`.

Data: collection stats (total plus a count per media type) and the most recently added items.

Compact: stat tiles in a 2-column grid, then a horizontal "Recently added" shelf row.

Regular: stat tiles in a row of 3 or 6, then the recent shelf with more items visible.

This is the screen with the most design freedom. The stat tiles could be glass. The recent shelf should look like the shelf on the Shelf tab so the two feel related.

### 3. Shelf

Replaces `CollectionPage.tsx`. This is the main screen.

Data: paged collection items (24 per page on the web, pull to refresh and infinite scroll on the phone).

Filters, all in the toolbar:
- Media type: All, Vinyl, Movies, TV Shows, Books, Audiobooks, Documentaries
- Status: depends on media type (see Status values below)
- Favorites toggle
- Sort: date added, title, rating, year; ascending or descending
- Search within the shelf (text)

Compact: a 2-column grid of covers on wooden shelves. Tap a cover to push the item detail.

Regular: `NavigationSplitView`. The grid on the left at 4 columns, the selected item's detail on the right. Nothing is pushed; it's side by side.

Each shelf item shows: cover image, title under it, a small status mark (check for completed or watched, play for reading or watching, dot for owned, heart for wishlist, x for dropped), and a favorite heart if favorited. The status also tints the glow around the cover. Keep the glow; it's the one bit of color-coding people use at a glance.

### 4. Item detail

Replaces `ItemDetailPage.tsx`.

Data: one collection item. Title, cover, media type, status, rating (1 to 5), favorite, tags, notes, who added it, when, and a metadata dictionary from the source API (artist, year, label, author, pages, runtime, director, seasons, and so on). TV shows also track current season and total seasons.

Actions: edit status, rating, favorite, tags, notes, season progress. Delete with confirmation.

Compact: cover on top, metadata below, edit controls in a sheet.

Regular, and this is the interesting one: an `ArrangementView` in split style. Cover art is the primary view, metadata and controls the secondary. Fully open, cover on the left and details on the right. Half folded like a book, cover on the top half and details on the bottom half. The cover should feel like holding the record sleeve.

### 5. Search

Replaces `SearchPage.tsx`.

Data: a media type picker, then results from Discogs, TMDB, or Google Books. Each result has a cover, title, subtitle (artist or author or director), and year. One tap adds to the shelf with the default status for that type. Already-owned items should show as owned, not offer "Add" again.

Compact: results as a list with thumbnails. The media type picker is a segmented control or a menu above the results.

Regular: results on the left, a preview of the selected result on the right (cover large, metadata, Add button). Same split pattern as Shelf.

### 6. Settings

Replaces `SettingsPage.tsx`.

Sections: Profile (display name, email), Server (URL, connection status), Appearance (follows system; no custom theme toggle on iOS), Account (sign out), and for admins, Household (list users, change role, deactivate).

Plain system `Form`. No design needed beyond grouping.

### 7. Recommendations (later)

Not in the first pass. When it lands it'll be a section on Home: "You might like," a horizontal row of candidates with a one-line reason under each. Reserve the space in the Home layout but don't design it yet.

## Status values

Statuses depend on media type. Labels as the web shows them.

| Type | Statuses |
|---|---|
| Vinyl | Owned, Wishlist |
| Book, Audiobook | Reading, Completed, Wishlist, Dropped |
| Movie, Documentary | Watched, Want to Watch |
| TV Show | Watching, Completed, Want to Watch, Dropped |

Glow colors on the web: completed and watched are green, reading and watching are blue, owned is neutral, wishlist and want to watch are amber, dropped is red. Keep the semantics; the exact hues can change to fit the system palette.

## What not to carry over

- The sidebar. iOS has a tab bar.
- The dark/light toggle. iOS follows the system setting.
- Custom top and bottom bars of any kind. The system draws them and moves them to the side on Duo.
- Fixed widths. Everything sizes to its container.
- The dashboard's "add media" shortcut. That's what the Search tab is.

## What to improve

- The shelf glow is subtle on the web. On OLED with glass chrome it can be more confident.
- The web search page makes you pick a type before typing. On the phone, let people type first and show the type picker as a scope bar.
- Item detail on the web is a long scroll. The split arrangement on the inner display fixes that for free; the compact layout should put status and rating controls near the top, not after the metadata.

## Assets available

- Logo: `frontend/public/favicon.svg`
- Screenshots of the current web app: `docs/screenshots/`
- Media type symbols: use SF Symbols (`opticaldisc`, `film`, `tv`, `book`, `headphones`, `video`), not the web icon set

## Open questions for the design pass

1. Does the wooden shelf stay literal (wood texture) or become a glass ledge with a wood tint? Both are defensible.
2. Stat tiles on Home: glass cards or a plain `Grid` of numbers?
3. On the inner display, should the Shelf grid be 4 columns or 6? 4 reads better; 6 shows more.
