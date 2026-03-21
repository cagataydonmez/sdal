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
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        configuration.label
            .font(.subheadline.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(SDALTheme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                shape
                    .fill(emphasized ? SDALTheme.elevatedPanel : SDALTheme.softPanel)
                    .background(.thinMaterial, in: shape)
                    .overlay(
                        shape.strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    )
                    .overlay(
                        shape.strokeBorder(
                            emphasized ? SDALTheme.primary.opacity(0.24) : SDALTheme.line.opacity(0.7),
                            lineWidth: 1
                        )
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape
                    .fill(SDALTheme.card.opacity(0.9))
                    .background(.thinMaterial, in: shape)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.clear,
                                SDALTheme.primary.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(shape)
                    )
                    .overlay(
                        shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .overlay(
                        shape.inset(by: 1)
                            .stroke(SDALTheme.line.opacity(0.72), lineWidth: 1)
                    )
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(0.07), radius: 18, y: 10)
    }
}

struct SDALPill: View {
    let text: String
    var tint: Color = SDALTheme.softPanel
    var foreground: Color = SDALTheme.ink

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(tint.opacity(0.92))
                    .background(.thinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .overlay(
                        Capsule()
                            .stroke(SDALTheme.line.opacity(0.6), lineWidth: 1)
                    )
            }
    }
}

struct SDALSkeletonLines: View {
    var rows: Int = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<rows, id: \.self) { idx in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(SDALTheme.softPanel)
                    .frame(height: 10)
                    .frame(maxWidth: idx.isMultiple(of: 2) ? .infinity : 220, alignment: .leading)
            }
        }
        .redacted(reason: .placeholder)
    }
}

struct GlobalActionFeedbackChip: View {
    let message: String
    var isError: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                .font(.caption.bold())
                .symbolRenderingMode(.hierarchical)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .fontDesign(.rounded)
                .lineLimit(2)
        }
        .foregroundStyle(isError ? SDALTheme.danger : SDALTheme.success)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(SDALTheme.elevatedPanel.opacity(0.96))
                .background(.thinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke((isError ? SDALTheme.danger : SDALTheme.success).opacity(0.35), lineWidth: 1)
                )
        }
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}
