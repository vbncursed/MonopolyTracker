import Foundation

/// Режим выбора языка интерфейса.
enum LanguageMode: String, CaseIterable, Identifiable {
    case system
    case russian = "ru"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: String(localized: "Системный")
        case .russian: "Русский"
        case .english: "English"
        }
    }

    /// Код локализации для применения. nil = использовать системный.
    var resourceCode: String? {
        switch self {
        case .system: nil
        case .russian: "ru"
        case .english: "en"
        }
    }
}
