import Foundation

/// Pure function object that partitions a flat list of repositories into titled sections
/// based on the selected `GroupingOption` (owner type, fork status, language, or star band).
struct RepositoryGrouper {

    let grouping: GroupingOption
    let repoDetails: [Int: RepositoryDetailDTO]

    func group(_ repositories: [RepositoryDTO]) -> [RepositoryGroup] {
        guard !repositories.isEmpty else { return [] }

        switch grouping {
        case .none:
            return [RepositoryGroup(title: Strings.allRepositories, repos: repositories)]

        case .ownerType:
            let grouped = Dictionary(grouping: repositories) { $0.owner.type }
            return grouped.map {
                RepositoryGroup(title: Self.localizedOwnerType($0.key), repos: $0.value)
            }
            .sorted { $0.title < $1.title }

        case .forkStatus:
            let grouped = Dictionary(grouping: repositories) {
                $0.fork ? Strings.forked : Strings.original
            }
            return grouped.map { RepositoryGroup(title: $0.key, repos: $0.value) }
                .sorted { $0.title < $1.title }

        case .language:
            let grouped = Dictionary(grouping: repositories) { repo -> String in
                guard let detail = repoDetails[repo.id] else { return Strings.loading }
                return detail.language ?? Strings.unknown
            }
            return grouped.map { RepositoryGroup(title: $0.key, repos: $0.value) }
                .sorted { lhs, rhs in
                    if lhs.title == Strings.loading { return false }
                    if rhs.title == Strings.loading { return true }
                    if lhs.title == Strings.unknown { return false }
                    if rhs.title == Strings.unknown { return true }
                    return lhs.title < rhs.title
                }

        case .stargazerBand:
            let bandOrder = [
                Strings.starsZero, Strings.stars1to10, Strings.stars11to100,
                Strings.stars101to1K, Strings.starsOver1K, Strings.loading
            ]
            let grouped = Dictionary(grouping: repositories) { repo -> String in
                repoDetails[repo.id]?.stargazerBand ?? Strings.loading
            }
            return grouped.map { RepositoryGroup(title: $0.key, repos: $0.value) }
                .sorted { lhs, rhs in
                    let li = bandOrder.firstIndex(of: lhs.title) ?? bandOrder.count
                    let ri = bandOrder.firstIndex(of: rhs.title) ?? bandOrder.count
                    return li < ri
                }
        }
    }

    static func localizedOwnerType(_ type: String) -> String {
        switch type {
        case "User": return Strings.ownerTypeUser
        case "Organization": return Strings.ownerTypeOrganization
        default: return type
        }
    }

    private enum Strings {
        static let allRepositories = String(localized: "grouping.allRepositories")
        static let forked = String(localized: "grouping.forked")
        static let original = String(localized: "grouping.original")
        static let loading = String(localized: "grouping.loading")
        static let unknown = String(localized: "grouping.unknown")
        static let starsZero = String(localized: "stargazerBand.zero")
        static let stars1to10 = String(localized: "stargazerBand.1to10")
        static let stars11to100 = String(localized: "stargazerBand.11to100")
        static let stars101to1K = String(localized: "stargazerBand.101to1K")
        static let starsOver1K = String(localized: "stargazerBand.over1K")
        static let ownerTypeUser = String(localized: "grouping.ownerUser")
        static let ownerTypeOrganization = String(localized: "grouping.ownerOrganization")
    }
}
