import Testing
import Foundation
@testable import GitHubExplorer

@Suite("RepositoryListViewModel")
@MainActor struct ViewModelTests {

    private func makeViewModel(
        repos: [RepositoryDTO]? = nil,
        nextURL: URL? = nil
    ) -> (RepositoryListViewModel, MockGitHubService, MockRepositoryDetailCache) {
        let mock = MockGitHubService()
        mock.stubPages(.success(RepositoryPage(
            repositories: repos ?? [makeTestRepo()],
            nextURL: nextURL
        )))
        let cache = MockRepositoryDetailCache()
        let vm = RepositoryListViewModel(service: mock, detailCache: cache)
        return (vm, mock, cache)
    }

    @Test("loadInitial populates repositories")
    func loadInitial() async {
        let (vm, _, _) = makeViewModel()
        await vm.loadInitial()

        #expect(!vm.repositories.isEmpty)
        #expect(vm.repositories[0].name == "grit")
        #expect(vm.isLoading == false)
        #expect(vm.error == nil)
    }

    @Test("loadInitial sets hasMorePages when nextURL is present")
    func hasMorePages() async {
        let (vm, _, _) = makeViewModel(
            nextURL: URL(string: "https://api.github.com/repositories?since=369")
        )
        await vm.loadInitial()

        #expect(vm.hasMorePages == true)
    }

    @Test("loadInitial sets error on failure")
    func loadInitialError() async {
        let mock = MockGitHubService()
        mock.stubPages(.failure(GitHubServiceError.invalidResponse(statusCode: 500)))
        let cache = MockRepositoryDetailCache()
        let vm = RepositoryListViewModel(service: mock, detailCache: cache)

        await vm.loadInitial()

        #expect(vm.repositories.isEmpty)
        #expect(vm.error != nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadInitial tracks rateLimitResetDate on rate limit error")
    func loadInitialRateLimit() async {
        let resetDate = Date.now.addingTimeInterval(3600)
        let mock = MockGitHubService()
        mock.stubPages(.failure(GitHubServiceError.rateLimited(resetDate: resetDate)))
        let cache = MockRepositoryDetailCache()
        let vm = RepositoryListViewModel(service: mock, detailCache: cache)

        await vm.loadInitial()

        #expect(vm.rateLimitResetDate != nil)
    }

    @Test("loadMore appends repositories")
    func loadMore() async {
        let nextURL = URL(string: "https://api.github.com/repositories?since=1")!
        let mock = MockGitHubService()
        mock.stubPages(
            .success(RepositoryPage(repositories: [makeTestRepo(id: 1, name: "a", owner: "x")], nextURL: nextURL)),
            .success(RepositoryPage(repositories: [makeTestRepo(id: 2, name: "b", owner: "y")], nextURL: nil))
        )
        let cache = MockRepositoryDetailCache()
        let vm = RepositoryListViewModel(service: mock, detailCache: cache)

        await vm.loadInitial()
        #expect(vm.repositories.count == 1)

        await vm.loadMore()

        #expect(vm.repositories.count == 2)
        #expect(vm.repositories[1].name == "b")
    }

    @Test("loadMore sets loadMoreFailed on rate limit without triggering error alert")
    func loadMoreRateLimit() async {
        let nextURL = URL(string: "https://api.github.com/repositories?since=1")!
        let resetDate = Date.now.addingTimeInterval(3600)
        let mock = MockGitHubService()
        mock.stubPages(
            .success(RepositoryPage(repositories: [makeTestRepo()], nextURL: nextURL)),
            .failure(GitHubServiceError.rateLimited(resetDate: resetDate))
        )
        let cache = MockRepositoryDetailCache()
        let vm = RepositoryListViewModel(service: mock, detailCache: cache)

        await vm.loadInitial()
        await vm.loadMore()

        #expect(vm.loadMoreFailed == true)
        #expect(vm.rateLimitResetDate != nil)
        #expect(vm.error == nil, "Rate limit during loadMore should not set error (no alert)")
    }

    @Test("dismissError clears the error")
    func dismissError() async {
        let mock = MockGitHubService()
        mock.stubPages(.failure(GitHubServiceError.invalidResponse(statusCode: 500)))
        let cache = MockRepositoryDetailCache()
        let vm = RepositoryListViewModel(service: mock, detailCache: cache)

        await vm.loadInitial()
        #expect(vm.error != nil)

        vm.dismissError()
        #expect(vm.error == nil)
    }

    // MARK: - Grouping

    private func loadedViewModel() async -> RepositoryListViewModel {
        let repos = [
            makeTestRepo(id: 1, name: "alpha", owner: "alice", ownerType: "User", fork: false),
            makeTestRepo(id: 2, name: "beta",  owner: "bob",   ownerType: "Organization", fork: true),
            makeTestRepo(id: 3, name: "gamma", owner: "alice", ownerType: "User", fork: true),
            makeTestRepo(id: 4, name: "delta", owner: "corp",  ownerType: "Organization", fork: false)
        ]
        let (vm, _, _) = makeViewModel(repos: repos)
        await vm.loadInitial()
        return vm
    }

    @Test("Groups by none returns single group")
    func groupByNone() async {
        let vm = await loadedViewModel()
        vm.grouping = .none

        let groups = vm.groupedRepositories(favoriteIDs: [])

        #expect(groups.count == 1)
        #expect(groups[0].title == String(localized: "grouping.allRepositories"))
        #expect(groups[0].repos.count == 4)
    }

    @Test("Groups by owner type uses localized labels")
    func groupByOwnerType() async {
        let vm = await loadedViewModel()
        vm.grouping = .ownerType

        let groups = vm.groupedRepositories(favoriteIDs: [])
        let titles = groups.map(\.title)

        let userLabel = RepositoryGrouper.localizedOwnerType("User")
        let orgLabel = RepositoryGrouper.localizedOwnerType("Organization")

        #expect(titles.contains(userLabel))
        #expect(titles.contains(orgLabel))

        let users = groups.first { $0.title == userLabel }
        let orgs = groups.first { $0.title == orgLabel }
        #expect(users?.repos.count == 2)
        #expect(orgs?.repos.count == 2)
    }

    @Test("Groups by fork status")
    func groupByForkStatus() async {
        let vm = await loadedViewModel()
        vm.grouping = .forkStatus

        let groups = vm.groupedRepositories(favoriteIDs: [])
        let titles = groups.map(\.title)
        
        let originalLabel = String(localized: "grouping.original")
        let forkedLabel = String(localized: "grouping.forked")

        #expect(titles.contains(originalLabel))
        #expect(titles.contains(forkedLabel))

        let originals = groups.first { $0.title == originalLabel }
        let forks = groups.first { $0.title == forkedLabel }
        #expect(originals?.repos.count == 2)
        #expect(forks?.repos.count == 2)
    }

    @Test("Groups by language uses 'Unknown' for repos without details")
    func groupByLanguageWithoutDetails() async {
        let vm = await loadedViewModel()
        vm.grouping = .language

        let groups = vm.groupedRepositories(favoriteIDs: [])

        #expect(groups.count == 1)
        #expect(groups[0].title == String(localized: "grouping.loading"))
    }

    @Test("Groups by stargazer band uses 'Loading...' for repos without details")
    func groupByStarsWithoutDetails() async {
        let vm = await loadedViewModel()
        vm.grouping = .stargazerBand

        let groups = vm.groupedRepositories(favoriteIDs: [])

        #expect(groups.count == 1)
        #expect(groups[0].title == String(localized: "grouping.loading"))
    }

    // MARK: - Grouping with Details Loaded

    private func loadedViewModelWithDetails() async -> RepositoryListViewModel {
        let repos = [
            makeTestRepo(id: 1, name: "alpha", owner: "alice", ownerType: "User", fork: false),
            makeTestRepo(id: 2, name: "beta",  owner: "bob",   ownerType: "Organization", fork: true),
            makeTestRepo(id: 3, name: "gamma", owner: "carol", ownerType: "User", fork: true),
            makeTestRepo(id: 4, name: "delta", owner: "corp",  ownerType: "Organization", fork: false)
        ]
        let mock = MockGitHubService()
        mock.stubPages(.success(RepositoryPage(
            repositories: repos, nextURL: nil
        )))
        let cache = MockRepositoryDetailCache()
        cache.detailHandler = { repo in
            switch repo.name {
            case "alpha": return .success(makeTestDetail(id: 1, language: "Swift", stargazersCount: 0))
            case "beta":  return .success(makeTestDetail(id: 2, language: "Python", stargazersCount: 5))
            case "gamma": return .success(makeTestDetail(id: 3, language: nil, stargazersCount: 150))
            case "delta": return .success(makeTestDetail(id: 4, language: "Swift", stargazersCount: 5000))
            default:      return .failure(GitHubServiceError.invalidResponse(statusCode: 404))
            }
        }
        let vm = RepositoryListViewModel(service: mock, detailCache: cache)
        await vm.loadInitial()
        for repo in repos { await vm.fetchDetail(for: repo) }
        return vm
    }

    @Test("Groups by language with actual languages loaded")
    func groupByLanguageWithDetails() async {
        let vm = await loadedViewModelWithDetails()
        vm.grouping = .language

        let groups = vm.groupedRepositories(favoriteIDs: [])
        let titles = groups.map(\.title)

        #expect(titles.contains("Swift"))
        #expect(titles.contains("Python"))
        #expect(titles.contains(String(localized: "grouping.unknown")))
        #expect(groups.first { $0.title == "Swift" }?.repos.count == 2)
        #expect(groups.first { $0.title == "Python" }?.repos.count == 1)
    }

    @Test("Groups by stargazer band with actual star counts")
    func groupByStarsWithDetails() async {
        let vm = await loadedViewModelWithDetails()
        vm.grouping = .stargazerBand

        let groups = vm.groupedRepositories(favoriteIDs: [])
        let titles = groups.map(\.title)

        #expect(titles.contains(String(localized: "stargazerBand.zero")))
        #expect(titles.contains(String(localized: "stargazerBand.1to10")))
        #expect(titles.contains(String(localized: "stargazerBand.101to1K")))
        #expect(titles.contains(String(localized: "stargazerBand.over1K")))
        #expect(groups.count == 4)
    }

    // MARK: - Search Filtering

    @Test("Search filters repositories by name")
    func searchByName() async {
        let vm = await loadedViewModel()
        vm.searchText = "alpha"

        let groups = vm.groupedRepositories(favoriteIDs: [])
        let allRepos = groups.flatMap(\.repos)

        #expect(allRepos.count == 1)
        #expect(allRepos[0].name == "alpha")
    }

    @Test("Search filters repositories by owner")
    func searchByOwner() async {
        let vm = await loadedViewModel()
        vm.searchText = "alice"

        let groups = vm.groupedRepositories(favoriteIDs: [])
        let allRepos = groups.flatMap(\.repos)

        #expect(allRepos.count == 2)
        #expect(allRepos.allSatisfy { $0.owner.login == "alice" })
    }

    @Test("Search is case-insensitive")
    func searchCaseInsensitive() async {
        let vm = await loadedViewModel()
        vm.searchText = "BETA"

        let groups = vm.groupedRepositories(favoriteIDs: [])
        let allRepos = groups.flatMap(\.repos)

        #expect(allRepos.count == 1)
        #expect(allRepos[0].name == "beta")
    }

    @Test("Search with no matches returns empty")
    func searchNoMatch() async {
        let vm = await loadedViewModel()
        vm.searchText = "zzzzz"

        let groups = vm.groupedRepositories(favoriteIDs: [])

        #expect(groups.isEmpty)
    }

    @Test("Search by description")
    func searchByDescription() async {
        let repos = [
            makeTestRepo(id: 1, name: "a", owner: "x", description: "A networking library"),
            makeTestRepo(id: 2, name: "b", owner: "y", description: "A math library"),
            makeTestRepo(id: 3, name: "c", owner: "z", description: nil)
        ]
        let (vm, _, _) = makeViewModel(repos: repos)
        await vm.loadInitial()
        vm.searchText = "networking"

        let groups = vm.groupedRepositories(favoriteIDs: [])
        let allRepos = groups.flatMap(\.repos)

        #expect(allRepos.count == 1)
        #expect(allRepos[0].name == "a")
    }

    // MARK: - Favorites

    @Test("Favorites filter shows only favorited repos")
    func favoritesFilter() async {
        let vm = await loadedViewModel()
        vm.showFavoritesOnly = true

        let groups = vm.groupedRepositories(favoriteIDs: [1, 3])

        let allRepos = groups.flatMap(\.repos)
        #expect(allRepos.count == 2)
        #expect(allRepos.allSatisfy { [1, 3].contains($0.id) })
    }

    @Test("Favorites filter returns empty when no favorites")
    func favoritesFilterEmpty() async {
        let vm = await loadedViewModel()
        vm.showFavoritesOnly = true

        let groups = vm.groupedRepositories(favoriteIDs: [])

        #expect(groups.isEmpty)
    }
}
