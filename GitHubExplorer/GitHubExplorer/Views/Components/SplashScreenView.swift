import SwiftUI

/// Animated launch screen with a compass motif, shown once on cold start.
struct SplashScreenView: View {
    @State private var compassRotation: Double = Layout.initialRotation
    @State private var iconScale: CGFloat = Layout.initialScale
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(Layout.backgroundColorName)
                .ignoresSafeArea()

            VStack(spacing: .spacingXXLarge) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: Layout.ringStrokeWidth)
                        .frame(width: Layout.ringSize, height: Layout.ringSize)

                    compassNeedle
                        .rotationEffect(.degrees(compassRotation))

                    Circle()
                        .fill(.white)
                        .frame(width: Layout.centerDotSize, height: Layout.centerDotSize)

                    ForEach(0..<Layout.tickCount, id: \.self) { i in
                        let isMajor = i % 3 == 0
                        Rectangle()
                            .fill(Color.white.opacity(isMajor ? 0.8 : 0.3))
                            .frame(
                                width: isMajor ? Layout.majorTickWidth : Layout.minorTickWidth,
                                height: isMajor ? Layout.majorTickHeight : Layout.minorTickHeight
                            )
                            .offset(y: Layout.tickOffset)
                            .rotationEffect(.degrees(Double(i) * Layout.tickSpacing))
                    }
                }
                .scaleEffect(iconScale)

                VStack(spacing: .spacingxSmall) {
                    Text(Strings.title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .opacity(titleOpacity)

                    Text(Strings.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .opacity(subtitleOpacity)
                }
            }
        }
        .task {
            withAnimation(.easeOut(duration: Timing.scaleDuration)) {
                iconScale = 1.0
            }
            withAnimation(.easeInOut(duration: Timing.rotationDuration).delay(Timing.rotationDelay)) {
                compassRotation = 0
            }
            withAnimation(.easeIn(duration: Timing.fadeDuration).delay(Timing.titleDelay)) {
                titleOpacity = 1
            }
            withAnimation(.easeIn(duration: Timing.fadeDuration).delay(Timing.subtitleDelay)) {
                subtitleOpacity = 1
            }
        }
    }

    private var compassNeedle: some View {
        VStack(spacing: .zero) {
            Triangle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.9, green: 0.3, blue: 0.2), Color(red: 0.8, green: 0.2, blue: 0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: Layout.needleWidth, height: Layout.needleHeight)

            Triangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), Color.white.opacity(0.6)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: Layout.needleWidth, height: Layout.needleHeight)
                .rotationEffect(.degrees(180))
        }
    }

    // MARK: - Constants

    private enum Layout {
        static let backgroundColorName = "LaunchBackground"
        static let ringSize: CGFloat = 120
        static let ringStrokeWidth: CGFloat = 3
        static let centerDotSize: CGFloat = 12
        static let needleWidth: CGFloat = 16
        static let needleHeight: CGFloat = 40
        static let tickCount = 12
        static let tickOffset: CGFloat = -52
        static let tickSpacing: Double = 30
        static let majorTickWidth: CGFloat = 2.5
        static let majorTickHeight: CGFloat = 10
        static let minorTickWidth: CGFloat = 1.5
        static let minorTickHeight: CGFloat = 6
        static let initialRotation: Double = -30
        static let initialScale: CGFloat = 0.6
    }

    private enum Timing {
        static let scaleDuration: Double = 0.6
        static let rotationDuration: Double = 0.8
        static let rotationDelay: Double = 0.2
        static let fadeDuration: Double = 0.4
        static let titleDelay: Double = 0.3
        static let subtitleDelay: Double = 0.5
    }

    private enum Strings {
        static let title = String(localized: "splash.title")
        static let subtitle = String(localized: "splash.subtitle")
    }
}

#Preview {
    SplashScreenView()
}
