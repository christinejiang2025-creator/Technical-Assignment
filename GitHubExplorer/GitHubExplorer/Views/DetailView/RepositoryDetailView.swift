import SwiftUI
import SwiftData

/// Full-screen detail view for a single repository — fetches extended stats on appear
/// and displays metadata, stat cards, and a "View on GitHub" link.
struct RepositoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allFavorites: [FavoriteRepo]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let repository: RepositoryDTO
    let detail: RepositoryDetailDTO?
    let detailFailed: Bool
    let onRetryDetail: () async -> Void

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = .avatarSizeRegular
    @ScaledMetric(relativeTo: .body) private var buttonPadding: CGFloat = .paddingLarge

    private var isFavorite: Bool {
        allFavorites.contains { $0.repoID == repository.id }
    }

    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingXLarge) {
                headerSection
                Divider()

                descriptionView
                statsDetailView
                metadataSection
                
                Divider()
                actionsSection
            }
            .padding()
        }
        .navigationTitle(repository.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? AppImages.heartFill : AppImages.heart)
                        .foregroundStyle(isFavorite ? .red : .primary)
                }
                .accessibilityLabel(isFavorite ? Strings.removeFromFavorites : Strings.addToFavorites)
                .accessibilityHint(isFavorite
                    ? String(localized: "favorite.removeHint \(repository.name)")
                    : String(localized: "favorite.addHint \(repository.name)"))
            }
        }
    }

    // MARK: - Header
    @ViewBuilder
    private var headerSection: some View {
        if isAccessibilitySize {
            VStack(alignment: .leading, spacing: .spacingRegular) {
                headerSectionAvatar
                headerSectionContent
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(headerAccessibilityLabel)
        } else {
            HStack(spacing: .spacingLarge) {
                headerSectionAvatar
                headerSectionContent
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(headerAccessibilityLabel)
        }
    }
    
    private var headerSectionAvatar: some View {
        AvatarPlaceholder(name: repository.owner.login, size: min(avatarSize, 96))
            .overlay {
                AsyncImage(url: URL(string: repository.owner.avatarURL)) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                        .clipShape(Circle())
                } placeholder: {
                    EmptyView()
                }
            }
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
    
    private var headerSectionContent: some View {
        VStack(alignment: .leading, spacing: .spacingxSmall) {
            Text(repository.fullName)
                .font(.title3)
                .fontWeight(.bold)

            HStack(spacing: .spacingSmall) {
                CapsuleLabel(
                    text: localizedOwnerType,
                    icon: repository.owner.type == Strings.organizationType
                        ? AppImages.organization : AppImages.person,
                    tint: .secondary
                )

                if repository.fork {
                    CapsuleLabel(text: Strings.fork, icon: AppImages.fork, tint: .orange)
                }
            }
        }
    }

    private var localizedOwnerType: String {
        switch repository.owner.type.lowercased() {
        case "user":
            return Strings.ownerUser
        case "organization":
            return Strings.ownerOrganization
        default:
            return repository.owner.type
        }
    }

    private var headerAccessibilityLabel: String {
        var parts = [repository.fullName, localizedOwnerType]
        if repository.fork {
            parts.append(Strings.fork)
        }
        return parts.joined(separator: ", ")
    }
    
    // MARK: - description
    @ViewBuilder
    private var descriptionView: some View {
        if let description = repository.description {
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats Detail
    @ViewBuilder
    private var statsDetailView: some View {
        if let detail {
            statsGrid(detail)
        } else if detailFailed {
            VStack(spacing: .spacingSmall) {
                Image(systemName: AppImages.timeout)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(Strings.detailsUnavailable)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await onRetryDetail() }
                } label: {
                    Label(Strings.retry, systemImage: AppImages.retry)
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding()
        } else {
            HStack {
                ProgressView()
                Text(Strings.loadingDetails)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Strings.loadingDetails)
        }
    }
    
    private func statsGrid(_ detail: RepositoryDetailDTO) -> some View {
        let columns = isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, spacing: .spacingRegular) {
            StatCard(title: Strings.stars, value: "\(detail.stargazersCount)", icon: AppImages.starFill, color: .yellow)
            StatCard(title: Strings.forks, value: "\(detail.forksCount)", icon: AppImages.fork, color: .blue)
            StatCard(title: Strings.watchers, value: "\(detail.watchersCount)", icon: AppImages.eyeFill, color: .green)
            StatCard(title: Strings.issues, value: "\(detail.openIssuesCount)", icon: AppImages.issuesFill, color: .orange)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statsAccessibilityLabel(detail))
    }

    private func statsAccessibilityLabel(_ detail: RepositoryDetailDTO) -> String {
        String(localized: "accessibility.statsFormat \(detail.stargazersCount) \(detail.forksCount) \(detail.watchersCount) \(detail.openIssuesCount)")
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: .spacingSmall) {
            if let detail, let language = detail.language {
                Label(language, systemImage: AppImages.code)
                    .font(.subheadline)
                    .accessibilityLabel(String(localized: "accessibility.language \(language)"))
            }

            Label(
                repository.isPrivate ? Strings.privateRepo : Strings.publicRepo,
                systemImage: repository.isPrivate ? AppImages.lockFill : AppImages.lockOpenFill
            )
            .font(.subheadline)
            .accessibilityLabel(String(localized: "accessibility.visibility \(repository.isPrivate ? Strings.privateRepo : Strings.publicRepo)"))

            if let detail {
                Label(detail.createdAt.dateFormatted, systemImage: AppImages.calendar)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(String(localized: "accessibility.created \(detail.createdAt.dateFormatted)"))
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: .spacingRegular) {
            if let url = URL(string: repository.htmlURL) {
                Link(destination: url) {
                    Label(Strings.viewOnGitHub, systemImage: AppImages.safari)
                        .frame(maxWidth: .infinity)
                        .padding(buttonPadding)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: .cornerRadius))
                }
                .accessibilityHint(String(localized: "accessibility.opensInSafari \(repository.fullName)"))
            }

            Button {
                toggleFavorite()
            } label: {
                Label(
                    isFavorite ? Strings.removeFromFavorites : Strings.addToFavorites,
                    systemImage: isFavorite ? AppImages.heartSlashFill : AppImages.heart
                )
                .frame(maxWidth: .infinity)
                .padding(buttonPadding)
                .background(isFavorite ? Color.red.opacity(0.12) : Color.pink.opacity(0.12))
                .foregroundStyle(isFavorite ? .red : .pink)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadius))
            }
            .accessibilityHint(isFavorite
                ? String(localized: "favorite.removeHint \(repository.name)")
                : String(localized: "favorite.addHint \(repository.name)"))
        }
    }

    // MARK: - Helpers

    private func toggleFavorite() {
        withAnimation {
            if let existing = allFavorites.first(where: { $0.repoID == repository.id }) {
                modelContext.delete(existing)
            } else {
                modelContext.insert(FavoriteRepo(from: repository))
            }
        }
    }

    // MARK: - Constants

    private enum Strings {
        static let loadingDetails = String(localized: "detail.loadingDetails")
        static let fork = String(localized: "repo.fork")
        static let stars = String(localized: "detail.stars")
        static let forks = String(localized: "detail.forks")
        static let watchers = String(localized: "detail.watchers")
        static let issues = String(localized: "detail.issues")
        static let privateRepo = String(localized: "repo.private")
        static let publicRepo = String(localized: "repo.public")
        static let viewOnGitHub = String(localized: "detail.viewOnGitHub")
        static let addToFavorites = String(localized: "favorite.add")
        static let removeFromFavorites = String(localized: "favorite.remove")
        static let organizationType = "Organization"
        static let detailsUnavailable = String(localized: "detail.unavailable")
        static let retry = String(localized: "detail.retry")
        static let ownerUser = String(localized: "grouping.ownerUser")
        static let ownerOrganization = String(localized: "grouping.ownerOrganization")
    }
}
