import Testing
import Foundation
@testable import GitHubExplorer

@Suite("GitHubService", .serialized)
@MainActor struct GitHubServiceTests {

    @Test("Fetches and decodes repositories")
    func fetchRepositories() async throws {
        MockURLProtocol.handler = mockOK(json: singleRepoJSON)
        let service = GitHubService(session: makeMockSession())

        let page = try await service.fetchPublicRepositories()

        #expect(page.repositories.count == 1)
        #expect(page.repositories[0].name == "grit")
    }

    @Test("Returns nil nextURL when no Link header")
    func noLinkHeader() async throws {
        MockURLProtocol.handler = mockOK(json: singleRepoJSON)
        let service = GitHubService(session: makeMockSession())

        let page = try await service.fetchPublicRepositories()

        #expect(page.nextURL == nil)
    }

    @Test("Parses rel=next URL from Link header")
    func parsesLinkHeader() async throws {
        let next = "https://api.github.com/repositories?since=369"
        MockURLProtocol.handler = mockOK(
            json: singleRepoJSON,
            headers: ["Link": "<\(next)>; rel=\"next\""]
        )
        let service = GitHubService(session: makeMockSession())

        let page = try await service.fetchPublicRepositories()

        #expect(page.nextURL == URL(string: next))
    }

    @Test("Ignores non-next Link relations")
    func ignoresOtherRelations() async throws {
        let header = "<https://api.github.com/repositories?since=1>; rel=\"prev\""
        MockURLProtocol.handler = mockOK(json: singleRepoJSON, headers: ["Link": header])
        let service = GitHubService(session: makeMockSession())

        let page = try await service.fetchPublicRepositories()

        #expect(page.nextURL == nil)
    }

    @Test("Uses the provided URL instead of the base URL")
    func usesProvidedURL() async throws {
        let customURL = URL(string: "https://api.github.com/repositories?since=500")!
        nonisolated(unsafe) var receivedURL: String?

        MockURLProtocol.handler = { request in
            receivedURL = request.url?.absoluteString
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
            return (resp, Data(singleRepoJSON.utf8))
        }
        let service = GitHubService(session: makeMockSession())

        _ = try await service.fetchPublicRepositories(url: customURL)

        #expect(receivedURL == customURL.absoluteString)
    }

    @Test("Sends Accept header")
    func sendsAcceptHeader() async throws {
        nonisolated(unsafe) var capturedAccept: String?
        MockURLProtocol.handler = { request in
            capturedAccept = request.value(forHTTPHeaderField: "Accept")
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
            return (resp, Data(singleRepoJSON.utf8))
        }
        let service = GitHubService(session: makeMockSession())

        _ = try await service.fetchPublicRepositories()

        #expect(capturedAccept == "application/vnd.github+json")
    }

    @Test("Sends Authorization header when token is set")
    func sendsAuthHeader() async throws {
        nonisolated(unsafe) var capturedAuth: String?
        MockURLProtocol.handler = { request in
            capturedAuth = request.value(forHTTPHeaderField: "Authorization")
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
            return (resp, Data(singleRepoJSON.utf8))
        }
        let service = GitHubService(session: makeMockSession(), token: "ghp_test123")

        _ = try await service.fetchPublicRepositories()

        #expect(capturedAuth == "Bearer ghp_test123")
    }

    @Test("Omits Authorization header when no token")
    func noAuthWithoutToken() async throws {
        nonisolated(unsafe) var capturedAuth: String?
        MockURLProtocol.handler = { request in
            capturedAuth = request.value(forHTTPHeaderField: "Authorization")
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
            return (resp, Data(singleRepoJSON.utf8))
        }
        let service = GitHubService(session: makeMockSession())

        _ = try await service.fetchPublicRepositories()

        #expect(capturedAuth == nil)
    }

    @Test("Throws rateLimited on 403 with exhausted rate limit")
    func throwsRateLimited() async throws {
        let resetEpoch = Int(Date.now.timeIntervalSince1970) + 3600
        MockURLProtocol.handler = mockStatus(403, headers: [
            "x-ratelimit-remaining": "0",
            "x-ratelimit-reset": "\(resetEpoch)"
        ])
        let service = GitHubService(session: makeMockSession())

        await #expect(throws: GitHubServiceError.self) {
            _ = try await service.fetchPublicRepositories()
        }
    }

    @Test("Rate limit error carries the correct reset date")
    func rateLimitResetDate() async throws {
        let resetEpoch = 1_700_000_000
        MockURLProtocol.handler = mockStatus(403, headers: [
            "x-ratelimit-remaining": "0",
            "x-ratelimit-reset": "\(resetEpoch)"
        ])
        let service = GitHubService(session: makeMockSession())

        do {
            _ = try await service.fetchPublicRepositories()
            Issue.record("Expected rateLimited error")
        } catch let error as GitHubServiceError {
            guard case .rateLimited(let resetDate) = error else {
                Issue.record("Expected rateLimited, got \(error)")
                return
            }
            #expect(resetDate == Date(timeIntervalSince1970: TimeInterval(resetEpoch)))
        }
    }

    @Test("Throws invalidResponse on 500")
    func throwsOnServerError() async throws {
        MockURLProtocol.handler = mockStatus(500)
        let service = GitHubService(session: makeMockSession())

        do {
            _ = try await service.fetchPublicRepositories()
            Issue.record("Expected invalidResponse error")
        } catch let error as GitHubServiceError {
            guard case .invalidResponse(let code) = error else {
                Issue.record("Expected invalidResponse, got \(error)")
                return
            }
            #expect(code == 500)
        }
    }

    @Test("Throws networkError on connection failure")
    func throwsNetworkError() async throws {
        MockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let service = GitHubService(session: makeMockSession())

        do {
            _ = try await service.fetchPublicRepositories()
            Issue.record("Expected networkError")
        } catch let error as GitHubServiceError {
            guard case .networkError = error else {
                Issue.record("Expected networkError, got \(error)")
                return
            }
        }
    }

    @Test("Fetches repository detail")
    func fetchDetail() async throws {
        MockURLProtocol.handler = mockOK(json: detailJSON)
        let service = GitHubService(session: makeMockSession())

        let detail = try await service.fetchRepositoryDetail(owner: "mojombo", repo: "grit")

        #expect(detail.language == "Ruby")
        #expect(detail.stargazersCount == 42)
    }
}
