import Testing
import Foundation
@testable import GitHubExplorer

// MARK: - Mock URL Protocol (for GitHubService integration tests)

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

// MARK: - Mock Service (for ViewModel isolation tests)

final class MockGitHubService: GitHubServiceProtocol {
    private var fetchPublicRepositoriesResults: [Result<RepositoryPage, Error>] = []
    private var callIndex = 0

    var fetchRepositoryDetailResult: Result<RepositoryDetailDTO, Error> =
        .failure(GitHubServiceError.invalidResponse(statusCode: -1))

    var fetchDetailHandler: ((String, String) -> Result<RepositoryDetailDTO, Error>)?

    func stubPages(_ results: Result<RepositoryPage, Error>...) {
        fetchPublicRepositoriesResults = results
        callIndex = 0
    }

    func fetchPublicRepositories(url: URL?) async throws -> RepositoryPage {
        let result = fetchPublicRepositoriesResults[callIndex]
        callIndex += 1
        return try result.get()
    }

    func fetchRepositoryDetail(owner: String, repo: String) async throws -> RepositoryDetailDTO {
        if let handler = fetchDetailHandler {
            return try handler(owner, repo).get()
        }
        return try fetchRepositoryDetailResult.get()
    }
}

// MARK: - Mock Detail Cache (for ViewModel isolation tests)

@MainActor
final class MockRepositoryDetailCache: RepositoryDetailCacheProtocol {
    var detailHandler: ((RepositoryDTO) -> Result<RepositoryDetailDTO, Error>)?
    private var cache: [Int: RepositoryDetailDTO] = [:]

    func stubDetail(for id: Int, detail: RepositoryDetailDTO) {
        cache[id] = detail
    }

    func detail(for repository: RepositoryDTO) async throws -> RepositoryDetailDTO {
        if let cached = cache[repository.id] { return cached }
        if let handler = detailHandler {
            let result = handler(repository)
            let detail = try result.get()
            cache[repository.id] = detail
            return detail
        }
        throw GitHubServiceError.invalidResponse(statusCode: -1)
    }

    func cachedDetail(for repoID: Int) -> RepositoryDetailDTO? {
        cache[repoID]
    }
}

// MARK: - Factory Helpers

func makeTestRepo(
    id: Int = 1, name: String = "grit", owner: String = "mojombo",
    ownerType: String = "User", fork: Bool = false,
    description: String? = nil
) -> RepositoryDTO {
    RepositoryDTO(
        id: id, name: name, fullName: "\(owner)/\(name)",
        owner: RepositoryOwnerDTO(id: id, login: owner, avatarURL: "https://a.com/\(id)", type: ownerType),
        isPrivate: false, htmlURL: "https://github.com/\(owner)/\(name)",
        description: description, fork: fork
    )
}

func makeTestDetail(
    id: Int = 1, language: String? = "Ruby", stargazersCount: Int = 42,
    forksCount: Int = 10, openIssuesCount: Int = 3, watchersCount: Int = 42,
    size: Int = 1024, createdAt: String = "2007-10-29T14:37:16Z",
    updatedAt: String = "2024-01-01T00:00:00Z"
) -> RepositoryDetailDTO {
    RepositoryDetailDTO(
        id: id, language: language, stargazersCount: stargazersCount,
        forksCount: forksCount, openIssuesCount: openIssuesCount,
        watchersCount: watchersCount, size: size,
        createdAt: createdAt, updatedAt: updatedAt
    )
}

// MARK: - JSON Fixtures

let singleRepoJSON = """
[{
    "id": 1, "name": "grit", "full_name": "mojombo/grit",
    "owner": {"id": 1, "login": "mojombo", "avatar_url": "https://a.com/1", "type": "User"},
    "private": false, "html_url": "https://github.com/mojombo/grit",
    "description": "Ruby Git bindings", "fork": false
}]
"""

let detailJSON = """
{
    "id": 1, "language": "Ruby", "stargazers_count": 42, "forks_count": 10,
    "open_issues_count": 3, "watchers_count": 42, "size": 1024,
    "created_at": "2007-10-29T14:37:16Z", "updated_at": "2024-01-01T00:00:00Z"
}
"""

func repoJSON(id: Int, name: String, owner: String,
              ownerType: String = "User", fork: Bool = false,
              description: String? = nil) -> String {
    let desc = description.map { "\"\($0)\"" } ?? "null"
    return """
    {"id":\(id),"name":"\(name)","full_name":"\(owner)/\(name)",\
    "owner":{"id":\(id),"login":"\(owner)","avatar_url":"https://a.com/\(id)","type":"\(ownerType)"},\
    "private":false,"html_url":"https://github.com/\(owner)/\(name)",\
    "description":\(desc),"fork":\(fork)}
    """
}

func mockOK(json: String, headers: [String: String]? = nil) -> @Sendable (URLRequest) throws -> (HTTPURLResponse, Data) {
    return { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: headers)!
        return (response, Data(json.utf8))
    }
}

func mockStatus(_ code: Int, headers: [String: String]? = nil) -> @Sendable (URLRequest) throws -> (HTTPURLResponse, Data) {
    return { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: code,
                                       httpVersion: nil, headerFields: headers)!
        return (response, Data())
    }
}
