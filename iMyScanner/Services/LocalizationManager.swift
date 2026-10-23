import Foundation
import Combine
import os

enum AppLanguage: String, CaseIterable, Codable, Sendable {
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
///
/// This only re-points the app's *own* `Localizable.strings` lookups. It does
/// NOT change what language system-provided screens shown in-process (the
/// VisionKit scanner, PHPicker, the file browser, the share sheet, Quick
/// Look) display -- those consult the process-wide "AppleLanguages" preferred
/// languages list, which is Apple's own per-app language override mechanism
/// and is separate from this class's private `storageKey`. `setLanguage(_:)`
/// writes both, so a fresh launch after switching also affects those system
/// screens (a live in-process language change of already-loaded system
/// framework resources isn't possible on iOS -- Bundle resolves a process's
/// preferred language once at launch -- so this can only take full effect on
/// next launch; the app's own screens update immediately via `language`
/// regardless).
@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    private nonisolated static let storageKey = "app.language.option"
    private static let systemPreferredLanguagesKey = "AppleLanguages"

    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
            let bundle = Self.bundle(for: language)
            Self.currentBundle.withLock { $0 = bundle }
        }
    }

    /// The bundle `L(_:)` reads from. Behind a lock so background work (exports,
    /// imports) can look up strings while the main actor changes the language.
    /// Seeded from the saved preference, so it is right even before `shared` exists.
    private nonisolated static let currentBundle = OSAllocatedUnfairLock(initialState: bundle(for: savedLanguage()))

    /// True right after `setLanguage(_:)` actually changed the language, so the caller
    /// can tell the user a restart is needed for system screens to fully match.
    @Published private(set) var pendingSystemLanguageChange = false

    /// Updates both the app's own strings (live) and the process-wide preferred
    /// language Apple's system frameworks read (takes effect next launch).
    func setLanguage(_ newLanguage: AppLanguage) {
        guard newLanguage != language else { return }
        language = newLanguage
        UserDefaults.standard.set([newLanguage.rawValue], forKey: Self.systemPreferredLanguagesKey)
        pendingSystemLanguageChange = true
    }

    private init() {
        language = Self.savedLanguage()
    }

    private nonisolated static func savedLanguage() -> AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let saved = AppLanguage(rawValue: raw) {
            return saved
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("pt") ? .portuguese : .english
    }

    private nonisolated static func bundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    nonisolated static func string(_ key: String) -> String {
        currentBundle.withLock { $0 }.localizedString(forKey: key, value: nil, table: nil)
    }
}

func L(_ key: String) -> String {
    LocalizationManager.string(key)
}
