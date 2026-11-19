# GitHub Repository List

A Flutter app for Android and iOS that searches public GitHub repositories, shows repository details and keeps a list of favorite ("starred") repositories that persists across restarts.

| Search tab | Detail | Star tab |
| --- | --- | --- |
| Search box, Home / Empty / Error / Loading states, infinite scroll, star toggle per row | `full_name`, owner avatar, `subscribers_count` (plus stars, forks, issues) and a star toggle | Favorites (newest first), star toggle removes with **Undo** |

## Requirements

- Flutter **3.47 or higher** (developed and tested with Flutter 3.50.0 / Dart 3.14.0, the current stable release)
  - The assignment asks for Flutter 3.41.x or higher *and* the latest stable packages. The latest packages raise the floor: `flutter_riverpod` 3.5 needs Dart 3.12 (Flutter 3.44), and `material_ui`, where the Material widgets live since Flutter 3.47, needs Flutter 3.47. Run `flutter upgrade` if `flutter pub get` reports an SDK version error.
- Android 10 (API 29) or higher recommended, or iOS 15+
- Xcode (for iOS) and/or Android Studio / Android SDK (for Android)

## Build and run

```bash
flutter pub get
flutter run                 # on a connected device or running emulator/simulator
```

Release builds:

```bash
flutter build apk --release # Android → build/app/outputs/flutter-apk/app-release.apk
flutter build ios --release # iOS (requires a signing team set in Xcode)
```

Quality checks:

```bash
flutter analyze             # static analysis (strict casts / raw types + extra lints)
flutter test                # 41 unit and widget tests
```

No API token is needed. The app calls the GitHub REST API without an `Authorization` header, as the assignment requires.

## Packages

| Package | Why |
| --- | --- |
| `http` | HTTP client for the GitHub REST API (required). `package:http/testing.dart` provides `MockClient` for tests. |
| `shared_preferences` | Persists favorites (required). |
| `flutter_riverpod` | State management and dependency injection (required). |
| `material_ui` | Material widgets. Since Flutter 3.50, `flutter create` adds this package, which is where the Material library now lives. It is the official Material library published by the Flutter team (flutter/packages), not an extra third-party library. |

No other third-party packages are used. Avatar images use `Image.network` with a loading placeholder and an `errorBuilder`, and they request a size-appropriate image from GitHub's avatar CDN (`?s=`) and decode at display size (`cacheWidth`). A disk image cache package was not worth the extra dependency for this scope.

## Architecture

Feature-first folders, each split into **data → application → presentation** layers:

```
lib/
├── main.dart                      # loads SharedPreferences, ProviderScope, disables auto-retry
├── app.dart                       # MaterialApp + light/dark Material 3 theme
├── core/
│   ├── providers.dart             # dependency graph (http client, API, storage) as providers
│   ├── network/
│   │   ├── github_http_client.dart  # URIs, headers, timeout, JSON, error mapping
│   │   └── api_exception.dart       # sealed exception hierarchy
│   └── widgets/                   # StatusView (home/empty/error), OwnerAvatar, error messages
└── features/
    ├── home/home_shell.dart       # BottomNavigationBar + IndexedStack (Search, Star)
    ├── repositories/
    │   ├── data/                  # GitHubRepository interface + impl, models
    │   ├── application/           # RepositorySearchController (Notifier), detail FutureProvider
    │   └── presentation/          # SearchScreen, RepositoryDetailScreen, RepositoryTile
    └── favorites/
        ├── data/                  # FavoritesStorage interface + shared_preferences impl
        ├── application/           # FavoritesController (Notifier), isFavoriteProvider
        └── presentation/          # FavoritesScreen, FavoriteButton
```

```
 UI widgets ──watch──▶ Notifiers / FutureProviders ──▶ GitHubRepository ──▶ GitHubHttpClient ──▶ api.github.com
      │                        │
      └───── toggle ─────▶ FavoritesController ──▶ FavoritesStorage ──▶ shared_preferences
```

- **Repository pattern.** `GitHubRepository` and `FavoritesStorage` are interfaces. The application layer depends on them, and tests override them with fakes through Riverpod (`overrideWithValue`), with no mocking library.
- **Typed errors.** Every network failure becomes a case of a `sealed` `ApiException` (`NetworkException`, `RateLimitException`, `NotFoundException`, `ValidationException`, `ServerException`, `ParseException`). The UI turns them into messages with one exhaustive `switch` (`userMessageFor`).
- **Immutable state.** `SearchState` is immutable, and the screen derives exactly one view from it: Home, Loading, Error, Empty or Results.

## Key implementation points

### Favorites stay in sync everywhere

- `favoritesProvider` (a `Notifier<List<RepositorySummary>>`) is the **single source of truth**. The search list, the detail screen and the star list all read from it, so starring on any screen updates every other screen on the next frame, including the list behind the detail screen when you go back.
- Each star button watches `isFavoriteProvider(id)`, which uses `select`, so a row rebuilds only when **its own** star state changes.
- Updates are optimistic: the UI changes immediately and is rolled back (with a snackbar) if the write to disk fails, so the UI never shows something that was not saved.

### Persistence (`shared_preferences`)

- Exactly the fields the assignment asks for are stored: `id`, `full_name` and `owner.avatar_url`. They are stored as one JSON array under the versioned key `favorite_repositories_v1`, which keeps writes atomic, preserves order and leaves room to migrate the format later.
- `SharedPreferences` is loaded in `main()` before `runApp`, so favorites are available synchronously on the first frame and stars never flicker from off to on at launch.
- Corrupt data cannot crash the app. Unreadable JSON is ignored, invalid or duplicate entries are skipped individually, and the remaining favorites are kept.

### Search and infinite scroll

- **Debounce (450 ms).** GitHub allows only 10 unauthenticated search requests per minute, so a request is sent only after typing pauses. Pressing the keyboard's search action searches immediately.
- **No stale results.** Each search increments a generation counter, and a response is applied only if its generation is still current. A slow response for "flut" can never overwrite the results for "flutter", and clearing the box cancels anything in flight.
- **Pagination.** Pages are requested with `page` and `per_page=30`. The last row of the list is a load-more trigger that fires when it is built, which happens as it comes within the list's cache extent. This also handles a first page too short to scroll, where a scroll listener would never fire. The controller ignores `loadMore` while a page is loading, after an error and at the end, so pages are never requested twice.
- **End of results.** Loading stops at `total_count`, on an empty page, or at **GitHub's 1,000 result cap** for search (a 422 past the cap also ends pagination quietly). The footer then shows "N of M repositories".
- **Duplicates.** GitHub's ranking can shift between page requests, so rows already in the list are dropped by `id`.
- **Errors.** A first-page failure shows a full-screen error with **Retry**. A later-page failure keeps the loaded results and shows an inline Retry in the footer. Pull to refresh reloads while keeping the current results on screen.
- The search tab keeps its query, results and scroll position when you switch tabs (`IndexedStack` plus a kept-alive notifier).

### Detail screen

- The screen opens with the data already known from the list (name, avatar, star), so the header renders instantly. Only the statistics wait for `GET /repos/{owner}/{repo}`.
- `repositoryDetailProvider` is `autoDispose`, so reopening a repository fetches fresh numbers.
- Riverpod 3 retries failed providers automatically. That is disabled in `ProviderScope` (`retry: (_, _) => null`) so a 404 or rate-limit error appears right away with a Retry button instead of silently using up the rate limit.

### Edge cases handled

Empty or whitespace-only queries (shown as Home), queries over 256 characters (blocked by the field's `maxLength`), no results, offline and timeouts (15 s), rate limiting (with the time until reset taken from `x-ratelimit-reset` / `retry-after`), 404 for deleted or renamed repositories, 422 past the 1,000 result cap, HTML error pages from proxies, malformed JSON, missing avatars and broken image URLs, rapid repeated taps, and corrupt saved data.

### Platform setup

- Android: the `INTERNET` permission is declared in the main manifest, so release builds can reach the API (Flutter only adds it to debug builds by default).
- The app label is "GitHub Repos" on both platforms. Light and dark themes follow the system setting.

## API reference

Base URL `https://api.github.com`. Every request sends `Accept: application/vnd.github+json` and `X-GitHub-Api-Version: 2022-11-28`, and **no** `Authorization` header.

### Search repositories

`GET /search/repositories?q={keyword}&page={page}&per_page=30` ([docs](https://docs.github.com/en/rest/search/search?apiVersion=2022-11-28#search-repositories))

Fields used: `total_count`, `items[].id`, `items[].full_name`, `items[].owner.avatar_url`, and optionally `items[].description`, `items[].language` and `items[].stargazers_count`.

Limits: 10 requests per minute without authentication, and only the first 1,000 results can be paged through.

### Get a repository

`GET /repos/{owner}/{repo}` ([docs](https://docs.github.com/en/rest/repos/repos?apiVersion=2022-11-28#get-a-repository))

Fields used: `id`, `full_name`, `owner.avatar_url` and `subscribers_count` (the watcher count; note that the API's `watchers_count` is actually the star count), plus `stargazers_count`, `forks_count`, `open_issues_count`, `language` and `description`.

Limit: 60 requests per hour without authentication.

### Error mapping

| Response | Exception | Shown to the user |
| --- | --- | --- |
| 403 with `x-ratelimit-remaining: 0`, or 429 | `RateLimitException` | "Request limit reached. Try again in N minutes." |
| 404 | `NotFoundException` | "Repository could not be found…" |
| 422 | `ValidationException` | First page: "Try a different keyword". Later pages: end of list. |
| Other non-2xx | `ServerException` | "GitHub returned an error (code)…" |
| Socket, client or TLS error, timeout | `NetworkException` | "You appear to be offline…" / "The request timed out…" |
| Invalid JSON or unexpected shape | `ParseException` | "Unexpected response…" |

## Tests

41 tests, run with `flutter test`:

- `test/unit/github_repository_test.dart` covers request building (path, query encoding, headers, no auth), JSON parsing, and mapping each HTTP and network failure to its exception (using `MockClient`).
- `test/unit/search_controller_test.dart` covers the first page, the Empty state, pagination to the end, the 1,000 result cap, 422 handling, concurrent `loadMore` calls sending a single request, stale responses being dropped, de-duplication, error and retry for both the first and later pages, clearing, and the debounce.
- `test/unit/favorites_controller_test.dart` covers toggle, the persisted JSON shape, ordering and undo, restoring after a restart, corrupt data, and rollback when a save fails.
- `test/widget/app_test.dart` runs the full app with a fake API and covers Home → Loading → Results, Empty, Error and Retry, clear, infinite scroll, **star sync between the list, detail, Star tab and storage**, favorites loaded at launch, Undo, and the detail error with Retry.
