import SwiftUI

/// Central brand palette and typography helpers for iMyScanner.
/// Colors are approximations of the burnt orange / burnt amber / black
/// palette used on ividi.dev, defined as Color Set assets so they adapt
/// automatically between the app's dark and light appearances.
///
/// Approximate hex values (documented here since asset catalogs store
/// them as raw components rather than hex strings):
///   AccentOrange   - dark: #D9611B   light: #C9581A
///   AccentAmber    - dark: #E8A23A   light: #CC8A2A
///   BackgroundBlack- dark: #0E0C0B   light: #F7F4F1
///   SurfaceDark    - dark: #1B1714   light: #FFFFFF
///   SurfaceLight   - dark: #262019   light: #EFE9E3
enum AppColor {
    static let accentOrange = Color("AccentOrange")
    static let accentAmber = Color("AccentAmber")
    static let backgroundBlack = Color("BackgroundBlack")
    static let surfaceDark = Color("SurfaceDark")
    static let surfaceLight = Color("SurfaceLight")
}

enum AppTypography {
    static func title() -> Font { .system(.title2, design: .rounded).weight(.bold) }
    static func headline() -> Font { .system(.headline, design: .rounded) }
    static func body() -> Font { .system(.body, design: .rounded) }
    static func caption() -> Font { .system(.caption, design: .rounded) }
}

enum AppMetrics {
    static let cornerRadius: CGFloat = 18
    static let smallCornerRadius: CGFloat = 12
    static let standardPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 14
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline())
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [AppColor.accentOrange, AppColor.accentAmber],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.headline())
            .foregroundStyle(AppColor.accentOrange)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(AppColor.accentOrange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
