import Foundation

/// Nested `owner` object within the GitHub repository JSON response.
/// Represents the user or organization that owns the repository.
struct RepositoryOwnerDTO: Codable, Sendable {
    let id: Int
    let login: String
    let avatarURL: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case id, login, type
        case avatarURL = "avatar_url"
    }
}
