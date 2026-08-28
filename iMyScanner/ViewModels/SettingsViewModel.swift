import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var themeOption: AppThemeOption {
        didSet { themeManager.option = themeOption }
    }
    @Published var language: AppLanguage {
        didSet { localizationManager.setLanguage(language) }
    }
    /// Mirrors `LocalizationManager.pendingSystemLanguageChange`: true right after the
    /// user switches language, so Settings can explain that a restart is needed for the
    /// camera scanner / file picker / share sheet to fully match.
    @Published var showRestartHint = false

    private let themeManager: ThemeManager
    private let localizationManager: LocalizationManager
    private var cancellables = Set<AnyCancellable>()

    init(
        themeManager: ThemeManager = .shared,
        localizationManager: LocalizationManager = .shared
    ) {
        self.themeManager = themeManager
        self.localizationManager = localizationManager
        self.themeOption = themeManager.option
        self.language = localizationManager.language
        localizationManager.$pendingSystemLanguageChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.showRestartHint = $0 }
            .store(in: &cancellables)
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
