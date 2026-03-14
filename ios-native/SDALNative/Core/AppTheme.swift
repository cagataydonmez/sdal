import Foundation
import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    static let storageKey = "sdal_native_theme_mode"

    @Published var mode: AppThemeMode {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        mode = AppThemeMode(rawValue: raw ?? AppThemeMode.auto.rawValue) ?? .auto
    }

    var preferredColorScheme: ColorScheme? {
        switch mode {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
