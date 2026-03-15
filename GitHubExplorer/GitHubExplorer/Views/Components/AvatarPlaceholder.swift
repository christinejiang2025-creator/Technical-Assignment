import SwiftUI

/// Circular fallback avatar showing the first letter of the owner's name.
struct AvatarPlaceholder: View {
    let name: String
    let size: CGFloat

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }

    var body: some View {
        Circle()
            .overlay {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: size, height: size)
    }
}
