import Foundation

/// Maps the GitHub `GET /repositories` JSON response. One object per public repository.
/// Equality and hashing are based on `id` only, so the same repo is deduplicated across pages.
struct RepositoryDTO: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let fullName: String
    let owner: RepositoryOwnerDTO
    let isPrivate: Bool
    let htmlURL: String
    let description: String?
    let fork: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, owner, description, fork
        case fullName = "full_name"
        case isPrivate = "private"
        case htmlURL = "html_url"
    }

    static func == (lhs: RepositoryDTO, rhs: RepositoryDTO) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
