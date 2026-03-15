import Foundation

/// Maps the GitHub `GET /repos/{owner}/{repo}` JSON response.
/// Extended stats (stars, forks, language, etc.) fetched separately from the list endpoint.
struct RepositoryDetailDTO: Codable, Sendable {
    let id: Int
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let openIssuesCount: Int
    let watchersCount: Int
    let size: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, language, size
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case watchersCount = "watchers_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
