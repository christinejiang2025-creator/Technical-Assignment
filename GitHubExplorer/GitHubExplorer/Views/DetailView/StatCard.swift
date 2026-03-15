import SwiftUI

/// Rounded card displaying a single numeric stat (stars, forks, issues, watchers).
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    @ScaledMetric(relativeTo: .body) private var cardPadding: CGFloat = .paddingLarge

    var body: some View {
        VStack(spacing: .spacingSmall) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(cardPadding)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}
