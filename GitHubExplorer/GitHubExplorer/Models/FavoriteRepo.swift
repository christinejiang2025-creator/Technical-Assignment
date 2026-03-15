import Foundation
import SwiftData

/// SwiftData persistent model — must be a class because `@Model` requires reference-type identity
/// to track and observe changes against the underlying store.
@Model
final class FavoriteRepo {
    @Attribute(.unique) var repoID: Int
    var name: String
    var fullName: String
    var ownerLogin: String
    var ownerAvatarURL: String
    var ownerType: String
    var htmlURL: String
    var repoDescription: String?
    var isFork: Bool
    var favoritedAt: Date

    init(from repository: RepositoryDTO) {
        self.repoID = repository.id
        self.name = repository.name
        self.fullName = repository.fullName
        self.ownerLogin = repository.owner.login
        self.ownerAvatarURL = repository.owner.avatarURL
        self.ownerType = repository.owner.type
        self.htmlURL = repository.htmlURL
        self.repoDescription = repository.description
        self.isFork = repository.fork
        self.favoritedAt = Date()
    }
}
