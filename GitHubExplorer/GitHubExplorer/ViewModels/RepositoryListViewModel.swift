import Foundation
import Observation

/// Drives the repository list screen — owns loading, pagination, detail fetching,
/// search filtering, grouping, and error/rate-limit state.
@Observable
@MainActor
final class RepositoryListViewModel {

    // MARK: - Published State

    private(set) var repositories: [RepositoryDTO] = []
    private(set) var repositoryByID: [Int: RepositoryDTO] = [:]
    private(set) var repoDetails: [Int: RepositoryDetailDTO] = [:]
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var loadMoreFailed = false
    private(set) var error: GitHubServiceError?
    private(set) var rateLimitResetDate: Date?
    private(set) var detailFailedIDs: Set<Int> = []

    var grouping: GroupingOption = .none
    var showFavoritesOnly = false
    var searchText = ""

    // MARK: - Pagination

    private var nextURL: URL?
    var hasMorePages: Bool { nextURL != nil }

    // MARK: - Dependencies

    /// Handles raw API calls for paginated repository lists (`loadInitial`, `loadMore`).
    private let service: any GitHubServiceProtocol
    /// Wraps the same service but adds caching, request deduplication,
    /// concurrency throttling, and rate-limit tracking for per-repo detail fetches.
    private let detailCache: any RepositoryDetailCacheProtocol

    init(service: any GitHubServiceProtocol, detailCache: any RepositoryDetailCacheProtocol) {
        self.service = service
        self.detailCache = detailCache
    }

    init() {
        // Token is read from the Xcode scheme environment variable to keep secrets out of source code.
        let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"]
        let svc = GitHubService(token: token)
        self.service = svc
        // Shares the same service instance so both use the same session and token.
        self.detailCache = RepositoryDetailCache(service: svc)
    }
    
    func repoDetails(by repoID: Int) -> (repo: RepositoryDTO, repoDetail: RepositoryDetailDTO?, fetchDetailFailed: Bool)? {
        guard let repo = repositoryByID[repoID] else { return nil }
        return (repo, repoDetails[repo.id], detailFailedIDs.contains(repo.id))
    }

    // MARK: - Data Loading

    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let page = try await service.fetchPublicRepositories()
            repositories = page.repositories
            repositoryByID = Dictionary(uniqueKeysWithValues: repositories.map { ($0.id, $0) })
            nextURL = page.nextURL
            rateLimitResetDate = nil
        } catch let err as GitHubServiceError {
            error = err
            if case .rateLimited(let resetDate) = err {
                rateLimitResetDate = resetDate
            }
        } catch {
            self.error = .networkError(underlying: error)
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, !isLoading, let url = nextURL else { return }
        isLoadingMore = true
        loadMoreFailed = false

        do {
            let page = try await service.fetchPublicRepositories(url: url)
            repositories.append(contentsOf: page.repositories)
            for repo in page.repositories {
                repositoryByID[repo.id] = repo
            }
            nextURL = page.nextURL
            rateLimitResetDate = nil
        } catch let err as GitHubServiceError {
            loadMoreFailed = true
            if case .rateLimited(let resetDate) = err {
                rateLimitResetDate = resetDate
                // Rate limit info shown inline — don't trigger the alert
            } else {
                error = err
            }
        } catch {
            self.error = .networkError(underlying: error)
            loadMoreFailed = true
        }

        isLoadingMore = false
    }

    func fetchDetail(for repo: RepositoryDTO) async {
        guard repoDetails[repo.id] == nil, !detailFailedIDs.contains(repo.id) else { return }
        do {
            let detail = try await detailCache.detail(for: repo)
            repoDetails[repo.id] = detail
        } catch {
            detailFailedIDs.insert(repo.id)
        }
    }

    func retryFetchDetail(for repo: RepositoryDTO) async {
        detailFailedIDs.remove(repo.id)
        await fetchDetail(for: repo)
    }

    // MARK: - Grouping

    func groupedRepositories(favoriteIDs: Set<Int>) -> [RepositoryGroup] {
        var filtered: [RepositoryDTO]
        if showFavoritesOnly {
            filtered = repositories.filter { favoriteIDs.contains($0.id) }
        } else {
            filtered = repositories
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter {
                $0.name.lowercased().contains(query)
                || $0.owner.login.lowercased().contains(query)
                || ($0.description?.lowercased().contains(query) ?? false)
            }
        }

        let grouper = RepositoryGrouper(grouping: grouping, repoDetails: repoDetails)
        return grouper.group(filtered)
    }

    func dismissError() {
        error = nil
    }
}
