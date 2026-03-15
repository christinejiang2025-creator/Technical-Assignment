import Testing
import Foundation
@testable import GitHubExplorer

@Suite("Repository Model")
@MainActor struct RepositoryModelTests {

    @Test("Decodes all fields from JSON")
    func decodesFullJSON() throws {
        let repos = try JSONDecoder().decode([RepositoryDTO].self, from: Data(singleRepoJSON.utf8))
        let repo = try #require(repos.first)

        #expect(repo.id == 1)
        #expect(repo.name == "grit")
        #expect(repo.fullName == "mojombo/grit")
        #expect(repo.owner.login == "mojombo")
        #expect(repo.owner.type == "User")
        #expect(repo.owner.avatarURL == "https://a.com/1")
        #expect(repo.isPrivate == false)
        #expect(repo.htmlURL == "https://github.com/mojombo/grit")
        #expect(repo.description == "Ruby Git bindings")
        #expect(repo.fork == false)
    }

    @Test("Decodes null description as nil")
    func decodesNilDescription() throws {
        let json = repoJSON(id: 1, name: "t", owner: "u")
        let repo = try JSONDecoder().decode(RepositoryDTO.self, from: Data(json.utf8))
        #expect(repo.description == nil)
    }

    @Test("Equality is based on id only")
    func equalityByID() throws {
        let a = try JSONDecoder().decode(RepositoryDTO.self,
                                         from: Data(repoJSON(id: 1, name: "a", owner: "x").utf8))
        let b = try JSONDecoder().decode(RepositoryDTO.self,
                                         from: Data(repoJSON(id: 1, name: "b", owner: "y").utf8))
        let c = try JSONDecoder().decode(RepositoryDTO.self,
                                         from: Data(repoJSON(id: 2, name: "a", owner: "x").utf8))
        #expect(a == b)
        #expect(a != c)
    }
}
