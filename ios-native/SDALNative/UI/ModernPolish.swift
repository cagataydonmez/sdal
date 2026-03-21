import SwiftUI
import UIKit

enum SDALHaptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

struct PolishedGlassButtonStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(emphasized ? Color.primary : Color.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                shape
                    .fill(emphasized ? Color(uiColor: .secondarySystemGroupedBackground) : Color(uiColor: .tertiarySystemGroupedBackground))
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(
                        shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
