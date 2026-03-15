import Testing
import Foundation
@testable import GitHubExplorer

@Suite("GitHubServiceError")
@MainActor struct GitHubServiceErrorTests {

    @Test("rateLimited has a localized description")
    func rateLimitedDescription() {
        let error = GitHubServiceError.rateLimited(resetDate: Date.now.addingTimeInterval(3600))
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("Rate limited"))
    }

    @Test("invalidResponse has a localized description")
    func invalidResponseDescription() {
        let error = GitHubServiceError.invalidResponse(statusCode: 500)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("500"))
    }

    @Test("networkError wraps the underlying error description")
    func networkErrorDescription() {
        let underlying = URLError(.notConnectedToInternet)
        let error = GitHubServiceError.networkError(underlying: underlying)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains(underlying.localizedDescription))
    }
}
