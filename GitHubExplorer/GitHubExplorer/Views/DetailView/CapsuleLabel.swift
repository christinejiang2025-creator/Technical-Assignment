import SwiftUI

/// Compact pill-shaped label with an SF Symbol icon, used for language and size tags.
struct CapsuleLabel: View {
    let text: String
    let icon: String
    let tint: Color

    @ScaledMetric(relativeTo: .caption) private var hPadding: CGFloat = .paddingSmall
    @ScaledMetric(relativeTo: .caption) private var vPadding: CGFloat = .paddingxxSmall

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }
}
