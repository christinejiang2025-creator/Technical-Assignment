import Testing
import Foundation
@testable import GitHubExplorer

@Suite("RepositoryDetail Model")
@MainActor struct RepositoryDetailModelTests {

    @Test("Decodes all fields from JSON")
    func decodesFullJSON() throws {
        let detail = try JSONDecoder().decode(RepositoryDetailDTO.self, from: Data(detailJSON.utf8))

        #expect(detail.id == 1)
        #expect(detail.language == "Ruby")
        #expect(detail.stargazersCount == 42)
        #expect(detail.forksCount == 10)
        #expect(detail.openIssuesCount == 3)
        #expect(detail.watchersCount == 42)
        #expect(detail.size == 1024)
    }

    @Test("Decodes null language as nil")
    func decodesNilLanguage() throws {
        let json = """
        {"id":1,"language":null,"stargazers_count":0,"forks_count":0,
         "open_issues_count":0,"watchers_count":0,"size":0,
         "created_at":"2024-01-01T00:00:00Z","updated_at":"2024-01-01T00:00:00Z"}
        """
        let detail = try JSONDecoder().decode(RepositoryDetailDTO.self, from: Data(json.utf8))
        #expect(detail.language == nil)
    }
}
