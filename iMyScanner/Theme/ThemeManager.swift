import SwiftUI
import Combine

enum AppThemeOption: String, CaseIterable, Codable {
    case dark
    case light
    case system

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

/// Persists and publishes the user's manual theme choice.
/// Defaults to dark mode per product requirements, independent of the
/// system appearance unless the user opts into "follow system".
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private let storageKey = "app.theme.option"

    @Published var option: AppThemeOption {
        didSet {
            UserDefaults.standard.set(option.rawValue, forKey: storageKey)
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let saved = AppThemeOption(rawValue: raw) {
            option = saved
        } else {
            option = .dark
        }
    }

    var preferredColorScheme: ColorScheme? {
        option.colorScheme
    }
}
