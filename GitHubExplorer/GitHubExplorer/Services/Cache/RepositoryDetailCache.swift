import Foundation

/// Stateful layer over `GitHubServiceProtocol` for per-repo detail fetches.
/// Adds in-memory caching, request deduplication, concurrency throttling (max 3),
/// and rate-limit / failure tracking so the app never re-fetches a failed or cached repo.
@MainActor
final class RepositoryDetailCache: RepositoryDetailCacheProtocol {

    private var cache: [Int: RepositoryDetailDTO] = [:]
    private var inFlightTasks: [Int: Task<RepositoryDetailDTO, Error>] = [:]
    private var failedIDs: Set<Int> = []
    private var rateLimitedUntil: Date?
    private let maxConcurrentFetches = 3
    private let service: any GitHubServiceProtocol

    init(service: any GitHubServiceProtocol) {
        self.service = service
    }

    private var isRateLimited: Bool {
        guard let until = rateLimitedUntil else { return false }
        return Date.now < until
    }

    func detail(for repository: RepositoryDTO) async throws -> RepositoryDetailDTO {
        if let cached = cache[repository.id] {
            return cached
        }

        // Bail immediately if rate-limited or previously failed for this repo
        if isRateLimited {
            throw GitHubServiceError.rateLimited(resetDate: rateLimitedUntil!)
        }
        if failedIDs.contains(repository.id) {
            throw GitHubServiceError.invalidResponse(statusCode: -1)
        }

        // Coalesce duplicate requests for the same repo
        if let existing = inFlightTasks[repository.id] {
            return try await existing.value
        }

        // Throttle: wait for a slot to avoid flooding the API
        while inFlightTasks.count >= maxConcurrentFetches {
            try await Task.sleep(for: .milliseconds(150))
            if isRateLimited {
                throw GitHubServiceError.rateLimited(resetDate: rateLimitedUntil!)
            }
        }

        let owner = repository.owner.login
        let name = repository.name
        let task = Task {
            try await service.fetchRepositoryDetail(owner: owner, repo: name)
        }
        inFlightTasks[repository.id] = task

        do {
            let detail = try await task.value
            cache[repository.id] = detail
            inFlightTasks.removeValue(forKey: repository.id)
            return detail
        } catch let error as GitHubServiceError {
            inFlightTasks.removeValue(forKey: repository.id)
            if case .rateLimited(let resetDate) = error {
                rateLimitedUntil = resetDate
            } else {
                failedIDs.insert(repository.id)
            }
            throw error
        } catch {
            inFlightTasks.removeValue(forKey: repository.id)
            failedIDs.insert(repository.id)
            throw error
        }
    }

    func cachedDetail(for repoID: Int) -> RepositoryDetailDTO? {
        cache[repoID]
    }
}
