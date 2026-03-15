import SwiftUI
import SwiftData

/// Root view — shows the paginated repository list with search, grouping, favorites,
/// and navigation to `RepositoryDetailView`. Also manages the one-time splash screen.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteRepo.favoritedAt, order: .reverse) private var favorites: [FavoriteRepo]
    @State private var viewModel = RepositoryListViewModel()
    @State private var showSplash = true

    /// Derived from `@Query` which only works in views — kept here instead of the ViewModel
    /// so SwiftData automatically triggers re-renders when favorites change.
    private var favoriteIDs: Set<Int> {
        Set(favorites.map(\.repoID))
    }

    var body: some View {
        ZStack {
            NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.repositories.isEmpty {
                    loadingView
                } else if let error = viewModel.error, viewModel.repositories.isEmpty {
                    errorView(error)
                } else if viewModel.showFavoritesOnly && favoriteIDs.isEmpty {
                    noFavoritesView
                } else {
                    repositoryList
                }
            }
            .navigationTitle(Strings.title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    groupingMenu
                }
                ToolbarItem(placement: .navigation) {
                    favoritesToggle
                }
            }
            .navigationDestination(for: Int.self) { repoID in
                if let (repo, repoDetail, fetchDetailFailed) = viewModel.repoDetails(by: repoID) {
                    RepositoryDetailView(
                        repository: repo,
                        detail: repoDetail,
                        detailFailed: fetchDetailFailed,
                        onRetryDetail: { await viewModel.retryFetchDetail(for: repo) }
                    )
                    .task { await viewModel.fetchDetail(for: repo) }
                } else {
                    ContentUnavailableView(
                        Strings.repoNotFound,
                        systemImage: "questionmark.folder",
                        description: Text(Strings.repoNotFoundDescription)
                    )
                }
            }
        }
        .task {
            if viewModel.repositories.isEmpty {
                await viewModel.loadInitial()
            }
        }
        .alert(
            Strings.alertError,
            isPresented: Binding(
                get: { viewModel.error != nil && !viewModel.repositories.isEmpty },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button(Strings.alertOK) { viewModel.dismissError() }
        } message: {
            Text(viewModel.error?.localizedDescription ?? Strings.unknownError)
        }

            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.4)) {
                showSplash = false
            }
        }
    }

    // MARK: - Repository List

    private var repositoryList: some View {
        List {
            let groups = viewModel.groupedRepositories(favoriteIDs: favoriteIDs)
            ForEach(groups) { group in
                Section(group.title) {
                    ForEach(group.repos) { repo in
                        NavigationLink(value: repo.id) {
                            RepositoryRowView(
                                repository: repo,
                                detail: viewModel.repoDetails[repo.id],
                                detailFailed: viewModel.detailFailedIDs.contains(repo.id),
                                isFavorite: favoriteIDs.contains(repo.id)
                            ) {
                                toggleFavorite(repo)
                            }
                        }
                        .task {
                            await viewModel.fetchDetail(for: repo)
                        }
                    }
                }
            }

            if viewModel.hasMorePages && !viewModel.showFavoritesOnly && viewModel.searchText.isEmpty {
                Section {
                    if viewModel.loadMoreFailed {
                        loadMoreRetryView
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, .paddingSmall)
                            .onAppear {
                                Task { await viewModel.loadMore() }
                            }
                            .accessibilityLabel(Strings.loadingMore)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(
            text: Binding(
                get: { viewModel.searchText },
                set: { viewModel.searchText = $0 }
            ),
            prompt: Strings.searchPrompt
        )
        .refreshable {
            await viewModel.loadInitial()
        }
    }

    // MARK: - Load More Retry

    private var loadMoreRetryView: some View {
        VStack(spacing: .spacingxSmall) {
            if let resetDate = viewModel.rateLimitResetDate, resetDate > .now {
                Label {
                    Text(Strings.rateLimitedPrefix) + Text(resetDate, style: .relative) + Text(".")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Button {
                Task { await viewModel.loadMore() }
            } label: {
                Label(Strings.tapToRetry, systemImage: "arrow.clockwise")
            }
            .foregroundStyle(.blue)
            .accessibilityHint(Strings.retryHint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .paddingxxSmall)
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: .spacingLarge) {
            ProgressView()
                .controlSize(.large)
            Text(Strings.loading)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Strings.loading)
    }

    private func errorView(_ error: GitHubServiceError) -> some View {
        ContentUnavailableView {
            Label(
                isOfflineError(error)
                    ? Strings.offline
                    : Strings.unableToLoad,
                systemImage: isOfflineError(error)
                    ? "wifi.slash"
                    : isRateLimitError(error) ? "clock.badge.exclamationmark" : "wifi.exclamationmark"
            )
        } description: {
            VStack(spacing: .spacingSmall) {
                Text(isOfflineError(error)
                    ? Strings.offlineDescription
                    : error.localizedDescription)
                if isRateLimitError(error) {
                    Text(Strings.rateLimitHint)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
        } actions: {
            Button(Strings.tryAgain) {
                Task { await viewModel.loadInitial() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint(Strings.retryLoadHint)
        }
    }

    private var noFavoritesView: some View {
        ContentUnavailableView(
            Strings.noFavorites,
            systemImage: "heart.slash",
            description: Text(Strings.noFavoritesDescription)
        )
    }

    // MARK: - Toolbar

    private var groupingMenu: some View {
        Menu {
            Picker(Strings.toolbarGroupBy, selection: Binding(
                get: { viewModel.grouping },
                set: { viewModel.grouping = $0 }
            )) {
                ForEach(GroupingOption.allCases) { option in
                    Label(option.displayName, systemImage: option.systemImage)
                        .tag(option)
                }
            }
        } label: {
            Label(Strings.toolbarGroup, systemImage: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel(Strings.groupRepos)
        .accessibilityHint("\(Strings.groupedBy) \(viewModel.grouping.displayName)")
    }

    private var favoritesToggle: some View {
        Button {
            withAnimation { viewModel.showFavoritesOnly.toggle() }
        } label: {
            Image(systemName: viewModel.showFavoritesOnly ? "heart.fill" : "heart")
                .foregroundStyle(viewModel.showFavoritesOnly ? .red : .primary)
        }
        .accessibilityLabel(viewModel.showFavoritesOnly ? Strings.showAll : Strings.showFavorites)
        .accessibilityAddTraits(viewModel.showFavoritesOnly ? .isSelected : [])
    }

    // MARK: - Favorites

    private func toggleFavorite(_ repo: RepositoryDTO) {
        withAnimation {
            if let existing = favorites.first(where: { $0.repoID == repo.id }) {
                modelContext.delete(existing)
            } else {
                modelContext.insert(FavoriteRepo(from: repo))
            }
        }
    }

    // MARK: - Helpers

    private func isRateLimitError(_ error: GitHubServiceError) -> Bool {
        if case .rateLimited = error { return true }
        return false
    }

    private func isOfflineError(_ error: GitHubServiceError) -> Bool {
        if case .networkError(let underlying) = error {
            return (underlying as? URLError)?.code == .notConnectedToInternet
        }
        return false
    }

    // MARK: - Constants

    private enum Strings {
        static let title = String(localized: "explore.title")
        static let loading = String(localized: "explore.loading")
        static let loadingMore = String(localized: "explore.loadingMore")
        static let searchPrompt = String(localized: "explore.searchPrompt")
        static let repoNotFound = String(localized: "explore.repoNotFound")
        static let repoNotFoundDescription = String(localized: "explore.repoNotFoundDescription")
        static let unknownError = String(localized: "explore.unknownError")
        static let offline = String(localized: "explore.offline")
        static let offlineDescription = String(localized: "explore.offlineDescription")
        static let unableToLoad = String(localized: "explore.unableToLoad")
        static let rateLimitHint = String(localized: "explore.rateLimitHint")
        static let tryAgain = String(localized: "explore.tryAgain")
        static let tapToRetry = String(localized: "explore.tapToRetry")
        static let noFavorites = String(localized: "explore.noFavorites")
        static let noFavoritesDescription = String(localized: "explore.noFavoritesDescription")
        static let alertError = String(localized: "alert.error")
        static let alertOK = String(localized: "alert.ok")
        static let toolbarGroupBy = String(localized: "toolbar.groupBy")
        static let toolbarGroup = String(localized: "toolbar.group")
        static let showAll = String(localized: "toolbar.showAll")
        static let showFavorites = String(localized: "toolbar.showFavorites")
        static let groupRepos = String(localized: "accessibility.groupRepos")
        static let groupedBy = String(localized: "accessibility.groupedBy")
        static let retryHint = String(localized: "accessibility.retryHint")
        static let retryLoadHint = String(localized: "accessibility.retryLoadHint")

        static let rateLimitedPrefix = String(localized: "explore.rateLimitedPrefix")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: FavoriteRepo.self, inMemory: true)
}
