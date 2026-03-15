import Foundation

enum GitHubServiceError: Error, LocalizedError {
    case rateLimited(resetDate: Date)
    case invalidResponse(statusCode: Int)
    case networkError(underlying: Error)

    /// Localized, user-facing error message (required by `LocalizedError`).
    /// Shown as a full-screen error view on initial load failure,
    /// or as a pop-up alert when loading fails after data is already on screen.
    var errorDescription: String? {
        switch self {
        case .rateLimited(let resetDate):
            let formatter = RelativeDateTimeFormatter()
            let relative = formatter.localizedString(for: resetDate, relativeTo: .now)
            return String(localized: "error.rateLimited \(relative)")
        case .invalidResponse(let statusCode):
            return String(localized: "error.invalidResponse \(statusCode)")
        case .networkError(let underlying):
            return String(localized: "error.network \(underlying.localizedDescription)")
        }
    }
}
