# GitHub Explorer

An iOS app for browsing public GitHub repositories, built with SwiftUI and modern Swift concurrency.

## Features

- **Browse public repositories** from the GitHub API with infinite scroll pagination
- **Group repositories** by owner type, fork status, language, or stargazer band
- **Search** repositories by name, owner, or description (client-side filtering)
- **Bookmark favorites** with local persistence via SwiftData
- **Repository details** including stars, forks, watchers, issues, language, and creation date
- **Graceful error handling** for network failures, decoding errors, and API rate limits
- **Loading states** with contextual retry actions
- **Animated splash screen** with compass branding
- **Accessibility** support with VoiceOver labels and hints, and adaptive layouts for larger accessibility text sizes
- **Localization-ready** with String Catalog (`Localizable.xcstrings`)

## Screenshots

| List | Detail | Splash |
|------|--------|--------|
| Grouped repository list with avatars, language, and star counts | Full repository stats, metadata, and actions | Compass-themed animated launch screen |

## Architecture

```
GitHubExplorer/
├── Models/
│   ├── DTOs/
│   │   ├── RepositoryDTO.swift             # Public repo API model
│   │   ├── RepositoryDetailDTO.swift       # Detailed repo API model
│   │   └── RepositoryOwnerDTO.swift        # Repo owner API model
│   └── FavoriteRepo.swift                  # SwiftData model for bookmarks
├── Services/
│   ├── GitHubAPI/
│   │   ├── GitHubService.swift             # Stateless GitHub API client
│   │   ├── GitHubServiceError.swift        # Error types with localized messages
│   │   ├── GitHubServiceProtocol.swift     # Service protocol for DI / testing
│   │   └── RepositoryPage.swift            # Paginated response (repos + next URL)
│   └── Cache/
│       ├── RepositoryDetailCache.swift     # In-memory cache with throttling
│       └── RepositoryDetailCacheProtocol.swift # Cache protocol for DI / testing
├── ViewModels/
│   ├── RepositoryListViewModel.swift       # @Observable ViewModel (MVVM)
│   └── Grouping/
│       ├── GroupingOption.swift             # Grouping strategy enum
│       ├── RepositoryGroup.swift           # Titled section of repos
│       ├── RepositoryGrouper.swift         # Groups repos by selected option
│       └── RepositoryDetailDTO+StargazerBand.swift
├── Views/
│   ├── ListView/
│   │   ├── ContentView.swift               # Main list screen
│   │   └── RepositoryRowView.swift         # List row
│   ├── DetailView/
│   │   ├── RepositoryDetailView.swift      # Detail screen
│   │   ├── StatCard.swift                  # Stats grid card
│   │   └── CapsuleLabel.swift              # Capsule badge
│   └── Components/
│       ├── AvatarPlaceholder.swift          # Colored circle with initial
│       ├── SplashScreenView.swift          # Animated launch screen
│       └── Triangle.swift                  # Compass needle shape
├── Helpers/
│   ├── CGFloat+Layout.swift               # Reusable spacing / sizing constants
│   ├── String+dateFormatter.swift         # ISO 8601 date formatting
│   └── AppConstants.swift                 # SF Symbol image names
├── GitHubExplorerApp.swift                 # App entry point
└── Localizable.xcstrings                   # String Catalog for localization
```

### Patterns

| Pattern | Usage |
|---------|-------|
| **MVVM** | `RepositoryListViewModel` manages state; views observe via `@Observable` |
| **@MainActor** | ViewModel, service, and cache all share the same isolation domain |
| **Protocol-based DI** | `GitHubServiceProtocol` and `RepositoryDetailCacheProtocol` enable mock injection for ViewModel tests |
| **async/await** | All network and cache operations use structured concurrency |
| **SwiftData** | Persistent local storage for favorited repositories |

## How It Works

**How does the list load content?**

On launch, the ViewModel calls `GET /repositories`, which returns the first page of public repos. GitHub uses Link header pagination — the response includes a URL for the next page. When the user scrolls to the bottom, the app follows that URL to load more. It never guesses page numbers — it only uses the URL GitHub provides.

**What happens when you tap a cell?**

Each row is wrapped in a `NavigationLink` with the repo's `id` as the value. When tapped, SwiftUI's `NavigationStack` matches that id via `.navigationDestination(for: Int.self)` and pushes the `RepositoryDetailView`. The detail view also kicks off a fetch for extended stats (stars, forks, watchers) if they haven't been loaded yet.

**How does grouping by stars and language work?**

The app fetches a flat list of repositories from the GitHub API. When the user picks "Group by Language" or "Group by Stars," a `RepositoryGrouper` takes that flat list and buckets each repo into a titled section. For language, it reads the `language` field from the detail response. For stars, it maps the star count into bands like "0," "1–10," "11–100," etc. The result is an array of `RepositoryGroup` objects — each with a title and its repos — which the `List` renders as sections.

**How is rate limiting handled?**

GitHub returns a `403` status with `x-ratelimit-remaining: 0` when the limit is hit. The app reads the `x-ratelimit-reset` header to know when the limit resets. It then shows a user-facing error with a relative time ("resets in 45 minutes"), stops all further detail fetches immediately (the cache tracks rate-limit state), and lets the user retry manually once the window passes. Without a token, the limit is 60 requests/hour. With a personal access token, it's 5,000.

## API & Pagination

The app fetches from `https://api.github.com/repositories` and follows **stream-style pagination** via the HTTP `Link` header (`rel="next"`). Page numbers are never guessed — only the URL provided by GitHub is used.

Repository details (stars, forks, language, etc.) are fetched individually from `https://api.github.com/repos/{owner}/{repo}` and cached in-memory with:
- Request coalescing (deduplicates concurrent fetches for the same repo)
- Throttling (max 3 concurrent detail requests)
- Rate-limit awareness (stops fetching when rate-limited)
- Failure tracking (failed repos are not re-fetched unless retried manually)

## Configuration

### GitHub Token (optional but recommended)

Without a token, the GitHub API allows **60 requests/hour**. With a personal access token, the limit increases to **5,000 requests/hour**.

To configure:

1. [Create a personal access token](https://github.com/settings/tokens) (no scopes needed for public repos)
2. In Xcode: **Product → Scheme → Edit Scheme → Run → Environment Variables**
3. Add `GITHUB_TOKEN` with your token value

## Requirements

| Requirement | Version |
|-------------|---------|
| Xcode | 16.0+ |
| iOS | 18.0+ |
| Swift | 6 |

## Testing

### Unit Tests

Unit tests use **Swift Testing** (`@Test`, `#expect`) with three mocking strategies:
- **`MockURLProtocol`** — intercepts network requests for `GitHubService` integration tests
- **`MockGitHubService`** — protocol-based mock for isolated ViewModel tests
- **`MockRepositoryDetailCache`** — protocol-based mock for cache isolation in ViewModel tests

```
GitHubExplorerTests/
├── ModelTests/
│   ├── RepositoryModelTests.swift
│   ├── RepositoryDetailModelTests.swift
│   └── StargazerBandTests.swift
├── ServiceTests/
│   ├── GitHubServiceTests.swift
│   └── GitHubServiceErrorTests.swift
├── ViewModelTests/
│   ├── ViewModelTests.swift
│   └── GroupingOptionTests.swift
└── TestHelpers.swift
```

### UI Tests

UI tests use **XCTest** and run against the live app to verify key elements exist:
- Navigation title, toolbar buttons (favorites, grouping)
- Repository list loads cells
- Tapping a row navigates to the detail view

### Test coverage

- **Models** — JSON decoding, equality, stargazer band classification
- **GitHubService** — Fetch, Link header parsing, auth headers, rate-limit handling, error cases
- **ViewModel** — Loading, pagination, grouping, favorites filtering, error state
- **Errors** — Localized descriptions for all error types
- **UI** — Element existence for list and detail screens

```bash
# Run unit tests
xcodebuild test \
  -project GitHubExplorer.xcodeproj \
  -scheme GitHubExplorer \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Dependencies

None — the app uses only Apple system frameworks:
- SwiftUI
- SwiftData
- Foundation
- Observation

## License

This project is for educational and demonstration purposes.
