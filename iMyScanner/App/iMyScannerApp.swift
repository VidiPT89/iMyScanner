import SwiftUI

@main
struct iMyScannerApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @AppStorage("app.onboarding.completed") private var onboardingCompleted = false

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCompleted {
                    DocumentsListView()
                } else {
                    OnboardingView(isCompleted: $onboardingCompleted)
                }
            }
            .environmentObject(themeManager)
            .environmentObject(localizationManager)
            .preferredColorScheme(themeManager.preferredColorScheme)
            .id(localizationManager.language)
            .tint(AppColor.accentOrange)
        }
    }
}
