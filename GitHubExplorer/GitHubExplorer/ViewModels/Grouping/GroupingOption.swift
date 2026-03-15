import Foundation

/// Available grouping strategies for the repository list.
enum GroupingOption: String, CaseIterable, Identifiable {
    case none, ownerType, forkStatus, language, stargazerBand

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return Strings.none
        case .ownerType: return Strings.ownerType
        case .forkStatus: return Strings.forkStatus
        case .language: return Strings.language
        case .stargazerBand: return Strings.stars
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "list.bullet"
        case .ownerType: return "person.2"
        case .forkStatus: return "tuningfork"
        case .language: return "chevron.left.forwardslash.chevron.right"
        case .stargazerBand: return "star"
        }
    }

    private enum Strings {
        static let none = String(localized: "grouping.none")
        static let ownerType = String(localized: "grouping.ownerType")
        static let forkStatus = String(localized: "grouping.forkStatus")
        static let language = String(localized: "grouping.language")
        static let stars = String(localized: "grouping.stars")
    }
}
