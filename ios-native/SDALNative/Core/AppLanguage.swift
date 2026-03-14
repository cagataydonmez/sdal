import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case tr
    case en
    case de
    case fr

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tr: return "Turkce"
        case .en: return "English"
        case .de: return "Deutsch"
        case .fr: return "Francais"
        }
    }
}
