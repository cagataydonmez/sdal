import SwiftUI
import UIKit

private extension Color {
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum SDALTheme {
    // Based on sdal_new/src/styles.css light + dark tokens.
    static let primary = Color(red: 1.0, green: 0.42, blue: 0.29)
    static let secondary = Color(red: 0.11, green: 0.50, blue: 0.42)
    static let accent = Color.adaptive(light: .init(red: 0.07, green: 0.07, blue: 0.07, alpha: 1), dark: .init(red: 0.91, green: 0.93, blue: 0.97, alpha: 1))
    static let ink = Color.adaptive(light: .init(red: 0.11, green: 0.11, blue: 0.11, alpha: 1), dark: .init(red: 0.91, green: 0.93, blue: 0.97, alpha: 1))
    static let muted = Color.adaptive(light: .init(red: 0.43, green: 0.43, blue: 0.43, alpha: 1), dark: .init(red: 0.61, green: 0.65, blue: 0.74, alpha: 1))
    static let line = Color.adaptive(light: .init(red: 0.90, green: 0.85, blue: 0.78, alpha: 1), dark: .init(red: 0.17, green: 0.20, blue: 0.27, alpha: 1))
    static let card = Color.adaptive(light: .init(red: 1.0, green: 0.99, blue: 0.98, alpha: 1), dark: .init(red: 0.10, green: 0.14, blue: 0.19, alpha: 1))
    static let cardAlt = Color.adaptive(light: .init(red: 0.98, green: 0.96, blue: 0.94, alpha: 1), dark: .init(red: 0.13, green: 0.17, blue: 0.23, alpha: 1))
    static let softPanel = Color.adaptive(light: .init(red: 0.98, green: 0.96, blue: 0.94, alpha: 1), dark: .init(red: 0.11, green: 0.15, blue: 0.21, alpha: 1))
    static let success = Color.adaptive(light: .init(red: 0.12, green: 0.48, blue: 0.22, alpha: 1), dark: .init(red: 0.49, green: 0.89, blue: 0.67, alpha: 1))
    static let danger = Color.adaptive(light: .init(red: 0.63, green: 0.16, blue: 0.16, alpha: 1), dark: .init(red: 1.0, green: 0.60, blue: 0.65, alpha: 1))

    static let appBackground = LinearGradient(
        colors: [
            Color.adaptive(light: .init(red: 1.0, green: 0.97, blue: 0.94, alpha: 1), dark: .init(red: 0.10, green: 0.14, blue: 0.20, alpha: 1)),
            Color.adaptive(light: .init(red: 0.95, green: 0.94, blue: 0.91, alpha: 1), dark: .init(red: 0.07, green: 0.10, blue: 0.15, alpha: 1)),
            Color.adaptive(light: .init(red: 0.91, green: 0.87, blue: 0.82, alpha: 1), dark: .init(red: 0.05, green: 0.07, blue: 0.11, alpha: 1))
        ],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}

enum SDALTypography {
    static let body = Font.custom("AvenirNext-Regular", size: 16)
    static let bodyStrong = Font.custom("AvenirNext-Medium", size: 16)
    static let heading = Font.custom("AvenirNext-DemiBold", size: 18)
    static let title = Font.custom("AvenirNext-DemiBold", size: 22)
    static let caption = Font.custom("AvenirNext-Regular", size: 12)
}
