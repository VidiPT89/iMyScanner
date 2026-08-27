import Foundation
import Combine

enum AppLanguage: String, CaseIterable, Codable {
    case english = "en"
    case portuguese = "pt-PT"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .portuguese: return "Português (Portugal)"
        }
    }
}

/// Provides in-app localized strings independent of the device's system
/// locale, so the user can switch language from Settings and see it take
/// effect immediately without restarting the app.
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    private let storageKey = "app.language.option"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        }
    }

    var bundle: Bundle {
        LocalizationManager.bundle(for: language)
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let saved = AppLanguage(rawValue: raw) {
            language = saved
        } else {
            let preferred = Locale.preferredLanguages.first ?? "en"
            language = preferred.hasPrefix("pt") ? .portuguese : .english
        }
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    func string(_ key: String, comment: String = "") -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

func L(_ key: String) -> String {
    LocalizationManager.shared.string(key)
}
