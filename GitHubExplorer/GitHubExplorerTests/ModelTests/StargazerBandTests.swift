import Testing
import Foundation
@testable import GitHubExplorer

@Suite("Stargazer Bands")
@MainActor struct StargazerBandTests {

    private func detail(stars: Int) -> RepositoryDetailDTO {
        let json = """
        {"id":1,"language":null,"stargazers_count":\(stars),"forks_count":0,
         "open_issues_count":0,"watchers_count":0,"size":0,
         "created_at":"2024-01-01T00:00:00Z","updated_at":"2024-01-01T00:00:00Z"}
        """
        return try! JSONDecoder().decode(RepositoryDetailDTO.self, from: Data(json.utf8))
    }

    @Test("0 stars")
    func zero() {
        #expect(detail(stars: 0).stargazerBand == String(localized: "stargazerBand.zero"))
    }
    @Test("1 star")
    func one()  {
        #expect(detail(stars: 1).stargazerBand == String(localized: "stargazerBand.1to10"))
    }
    @Test("10 stars")
    func ten() {
        #expect(detail(stars: 10).stargazerBand == String(localized: "stargazerBand.1to10"))
    }
    @Test("11 stars")
    func eleven() {
        #expect(detail(stars: 11).stargazerBand == String(localized: "stargazerBand.11to100"))
    }
    @Test("100 stars")
    func hundred() {
        #expect(detail(stars: 100).stargazerBand == String(localized: "stargazerBand.11to100"))
    }
    @Test("101 stars")
    func hundredOne() {
        #expect(detail(stars: 101).stargazerBand == String(localized: "stargazerBand.101to1K"))
    }
    @Test("1000 stars")
    func thousand() {
        #expect(detail(stars: 1000).stargazerBand == String(localized: "stargazerBand.101to1K"))
    }
    @Test("1001 stars")
    func overThousand() {
        #expect(detail(stars: 1001).stargazerBand == String(localized: "stargazerBand.over1K"))
    }
    @Test("100K stars")
    func massive() {
        #expect(detail(stars: 100_000).stargazerBand == String(localized: "stargazerBand.over1K"))
    }
}
