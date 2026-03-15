import Foundation

@MainActor
protocol RepositoryDetailCacheProtocol {
    func detail(for repository: RepositoryDTO) async throws -> RepositoryDetailDTO
    func cachedDetail(for repoID: Int) -> RepositoryDetailDTO?
}
