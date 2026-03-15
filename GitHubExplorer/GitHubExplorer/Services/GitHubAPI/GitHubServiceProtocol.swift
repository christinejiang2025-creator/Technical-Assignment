import Foundation

struct RepositoryPage: Sendable {
    let repositories: [RepositoryDTO]
    let nextURL: URL?
}

protocol GitHubServiceProtocol {
    func fetchPublicRepositories(url: URL?) async throws -> RepositoryPage
    func fetchRepositoryDetail(owner: String, repo: String) async throws -> RepositoryDetailDTO
}

extension GitHubServiceProtocol {
    func fetchPublicRepositories() async throws -> RepositoryPage {
        try await fetchPublicRepositories(url: nil)
    }
}
