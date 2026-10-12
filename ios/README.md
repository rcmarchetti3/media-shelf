# MediaShelf for iOS

Native SwiftUI client for the MediaShelf backend in this repo. Same API, same accounts, same self-hosted stack. Built for iPhone Duo first, works on any iPhone running iOS 27.

Read `DESIGN-BRIEF.md` before changing any screen. It's the contract for what each screen does and how it folds.

## Build

You need Xcode 27 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd ios
xcodegen generate
open MediaShelf.xcodeproj
```

The `.xcodeproj` is gitignored. `project.yml` is the source of truth; rerun `xcodegen generate` after adding files or changing settings. Xcode will also pick up new files automatically since the target uses a folder reference.

In Xcode, pick your team under Signing & Capabilities once, then run on your phone or the iPhone Duo simulator.

## First launch

The sign-in screen asks for the server URL. That's wherever your `docker compose` stack is reachable from the phone, for example `http://rj-server:8080` on the LAN or your Tailscale address. The app stores it in UserDefaults and tokens in the Keychain.

## Layout

```
MediaShelf/
├── App/            Entry point, auth gate, tab bar
├── Core/
│   ├── Auth/       AuthStore (sign in state), Keychain
│   ├── Config/     ServerConfig (base URL)
│   ├── Models/     Codable types matching backend/app/schemas
│   └── Network/    APIClient (async, JSON, token refresh)
└── Features/       One folder per tab or screen
    ├── Auth/       Sign in, register           (LoginPage, RegisterPage)
    ├── Home/       Stats and recent shelf      (DashboardPage)
    ├── Shelf/      Collection grid and filters (CollectionPage)
    ├── Item/       Item detail and editing     (ItemDetailPage)
    ├── Search/     External search, add        (SearchPage)
    ├── Settings/   Profile, server, household  (SettingsPage)
    └── Recommendations/  On-device ranking, stubbed
```

Each file has a header comment saying what it does and which React page it replaces.

## How a screen works

Every feature follows the same shape:

1. A `Model` class marked `@MainActor @Observable`. It owns the screen's state and calls `APIClient`.
2. A `View` that creates the model with `@State` and reads from it.
3. The view branches on `horizontalSizeClass`: `.compact` for the outer display and regular iPhones, `.regular` for the inner display.

If you've written React, `@Observable` is roughly a store, `@State` is `useState`, and `.task {}` is `useEffect` with an async body that cancels when the view goes away.

## iPhone Duo notes

- Compact width = outer display. Regular width = inner display. Nothing keys off device model or screen size.
- The shelf grid uses an even column count so it splits cleanly across the fold.
- All bars are system bars with icon and title on every item, so iOS can move them to the side.
- `ItemDetailView` uses `ArrangementView` so the cover and the metadata sit on either side of the hinge when the phone is half open.
- Test every pose with Xcode's device hub, not just portrait.

## Not done yet

- Recommendations. `RecommendationEngine.swift` has the types and the availability check, no ranking yet.
- Custom fields (`/custom-fields`). Model and UI both missing.
- Household admin in Settings lists users but doesn't edit them yet.
- Offline cache. Everything fetches live.
