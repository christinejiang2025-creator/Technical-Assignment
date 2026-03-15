import SwiftUI

/// A single row in the repository list — shows name, owner, description, and optional
/// detail metadata (language, stars) with a favorite toggle.
struct RepositoryRowView: View {
    let repository: RepositoryDTO
    let detail: RepositoryDetailDTO?
    let detailFailed: Bool
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = .avatarSizeSmall
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isAccessibilitySize: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        HStack(alignment: .top, spacing: .spacingRegular) {
            if !isAccessibilitySize {
                avatar
            }

            VStack(alignment: .leading, spacing: .spacingxxSmall) {
                if isAccessibilitySize {
                    HStack(spacing: .spacingSmall) {
                        avatar
                        Text(repository.name)
                            .font(.headline)
                    }
                } else {
                    Text(repository.name)
                        .font(.headline)
                        .lineLimit(2)
                }

                Text(repository.owner.login)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let description = repository.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isAccessibilitySize ? 4 : 2)
                }

                metadataRow
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rowAccessibilityLabel)

            Spacer()

            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: isFavorite ? AppImages.heartFill : AppImages.heart)
                    .foregroundStyle(isFavorite ? .red : .secondary)
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? Strings.removeFavorite : Strings.addFavorite)
            .accessibilityHint(isFavorite
                ? String(localized: "favorite.removeHint \(repository.name)")
                : String(localized: "favorite.addHint \(repository.name)"))
        }
        .padding(.vertical, .paddingxxSmall)
    }

    // MARK: - Subviews

    private var avatar: some View {
        AvatarPlaceholder(name: repository.owner.login, size: min(avatarSize, 56))
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

    private var useVerticalMetadata: Bool {
        dynamicTypeSize > .accessibility2
    }

    @ViewBuilder
    private var metadataRow: some View {
        if useVerticalMetadata {
            VStack(alignment: .leading, spacing: .spacingxxSmall) {
                metadataForkView
                metadataDetailView
            }
        } else {
            HStack(spacing: .spacingxSmall) {
                metadataForkView
                metadataDetailView
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var metadataForkView: some View {
        if repository.fork {
            HStack(spacing: .spacingxxSmall) {
                Image(systemName: AppImages.fork)
                Text(Strings.fork)
            }
            .font(.caption2)
            .foregroundStyle(.orange)
        }
    }
    
    @ViewBuilder
    private var metadataDetailView: some View {
        if let detail {
            if let language = detail.language {
                HStack(spacing: .spacingxxSmall) {
                    Image(systemName: AppImages.code)
                    Text(language)
                }
                .font(.caption2)
                .foregroundStyle(.blue)
            }

            HStack(spacing: .spacingxxSmall) {
                Image(systemName: AppImages.star)
                Text("\(detail.stargazersCount)")
            }
            .font(.caption2)
            .foregroundStyle(.yellow)
            .accessibilityLabel(String(localized: "accessibility.stars \(detail.stargazersCount)"))
        } else if !detailFailed {
            ProgressView()
                .controlSize(.mini)
        }
    }

    // MARK: - Accessibility

    private var rowAccessibilityLabel: String {
        var parts: [String] = [
            repository.name,
            String(localized: "accessibility.by \(repository.owner.login)")
        ]

        if repository.fork {
            parts.append(Strings.fork)
        }

        if let detail {
            if let language = detail.language {
                parts.append(language)
            }
            parts.append(String(localized: "accessibility.stars \(detail.stargazersCount)"))
        }

        if let description = repository.description {
            parts.append(description)
        }

        if isFavorite {
            parts.append(Strings.favorited)
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Constants

    private enum Strings {
        static let fork = String(localized: "repo.fork")
        static let addFavorite = String(localized: "favorite.add")
        static let removeFavorite = String(localized: "favorite.remove")
        static let favorited = String(localized: "accessibility.favorited")
    }
}
