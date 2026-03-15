import Foundation

/// A titled section of repositories, produced by `RepositoryGrouper`.
///
/// Uses `[RepositoryDTO]` directly because every DTO field is consumed downstream
/// (row display, detail navigation, search, grouping). A separate domain model would
/// add a mapping layer without reducing payload — the DTO is already a small value type.
struct RepositoryGroup: Identifiable {
    let title: String
    let repos: [RepositoryDTO]
    var id: String { title }
}
