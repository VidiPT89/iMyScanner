import SwiftUI

/// Central brand palette and typography helpers for iMyScanner.
/// Colors follow the app icon (scanner blue to violet on deep navy),
/// defined as Color Set assets so they adapt automatically between the
/// app's dark and light appearances.
///
/// Hex values (documented here since asset catalogs store them as raw
/// components rather than hex strings):
///   AccentPrimary   - dark: #3D7BEA   light: #2563D6
///   AccentSecondary - dark: #A15CF0   light: #8B3FD9
///   BackgroundBlack - dark: #0A0C17   light: #F4F5FA
///   SurfaceDark     - dark: #161A2B   light: #FFFFFF
enum AppColor {
    static let accentPrimary = Color("AccentPrimary")
    static let accentSecondary = Color("AccentSecondary")
    static let backgroundBlack = Color("BackgroundBlack")
    static let surfaceDark = Color("SurfaceDark")
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
                    colors: [AppColor.accentPrimary, AppColor.accentSecondary],
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
            .foregroundStyle(AppColor.accentPrimary)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(AppColor.accentPrimary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
