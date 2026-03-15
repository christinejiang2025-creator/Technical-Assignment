import Foundation

/// Stateless GitHub API client — handles HTTP requests, authentication, JSON decoding,
/// and error mapping. Knows nothing about caching or request deduplication.
@MainActor
final class GitHubService: GitHubServiceProtocol {

    private let session: URLSession
    /// GitHub personal access token. Raises the API rate limit from 60 to 5,000 requests/hour.
    private let token: String?
    private let baseURL = URL(string: "https://api.github.com/repositories")!

    init(token: String? = nil) {
        self.session = URLSession(configuration: .default)
        self.token = token
    }

    init(session: URLSession, token: String? = nil) {
        self.session = session
        self.token = token
    }

    // MARK: - Public Repositories (paginated via Link header)

    func fetchPublicRepositories(url: URL? = nil) async throws -> RepositoryPage {
        let requestURL = url ?? baseURL
        let (data, httpResponse) = try await performRequest(url: requestURL)

        let repositories = try JSONDecoder().decode([RepositoryDTO].self, from: data)
        let nextURL = parseNextURL(from: httpResponse)

        return RepositoryPage(repositories: repositories, nextURL: nextURL)
    }

    // MARK: - Single Repository Detail

    func fetchRepositoryDetail(owner: String, repo: String) async throws -> RepositoryDetailDTO {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)")!
        let (data, _) = try await performRequest(url: url)
        return try JSONDecoder().decode(RepositoryDetailDTO.self, from: data)
    }

    // MARK: - Shared Request Logic

    private func performRequest(url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubServiceError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubServiceError.invalidResponse(statusCode: -1)
        }

        if httpResponse.statusCode == 403 {
            try throwRateLimitErrorIfNeeded(from: httpResponse)
            throw GitHubServiceError.invalidResponse(statusCode: 403)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GitHubServiceError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        return (data, httpResponse)
    }

    // MARK: - Link Header Parsing

    /// Parses the `Link` header to extract the URL with `rel="next"`.
    ///
    /// Example header:
    /// `<https://api.github.com/repositories?since=369>; rel="next"`
    private func parseNextURL(from response: HTTPURLResponse) -> URL? {
        guard let linkHeader = response.value(forHTTPHeaderField: "Link") else {
            return nil
        }

        let links = linkHeader.components(separatedBy: ",")
        for link in links {
            let segments = link.components(separatedBy: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard segments.count == 2 else { continue }

            let relPart = segments[1]
            guard relPart == "rel=\"next\"" else { continue }

            var urlString = segments[0]
            if urlString.hasPrefix("<") { urlString.removeFirst() }
            if urlString.hasSuffix(">") { urlString.removeLast() }

            return URL(string: urlString)
        }

        return nil
    }

    // MARK: - Rate Limiting

    private func throwRateLimitErrorIfNeeded(from response: HTTPURLResponse) throws {
        guard let remainingStr = response.value(forHTTPHeaderField: "x-ratelimit-remaining"),
              let remaining = Int(remainingStr),
              remaining == 0,
              let resetStr = response.value(forHTTPHeaderField: "x-ratelimit-reset"),
              let resetTimestamp = TimeInterval(resetStr)
        else {
            return
        }

        let resetDate = Date(timeIntervalSince1970: resetTimestamp)
        throw GitHubServiceError.rateLimited(resetDate: resetDate)
    }
}
