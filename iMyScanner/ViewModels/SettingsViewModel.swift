import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var themeOption: AppThemeOption {
        didSet { themeManager.option = themeOption }
    }
    @Published var language: AppLanguage {
        didSet { localizationManager.language = language }
    }

    private let themeManager: ThemeManager
    private let localizationManager: LocalizationManager

    init(
        themeManager: ThemeManager = .shared,
        localizationManager: LocalizationManager = .shared
    ) {
        self.themeManager = themeManager
        self.localizationManager = localizationManager
        self.themeOption = themeManager.option
        self.language = localizationManager.language
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
