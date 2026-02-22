import SwiftUI

struct GlassCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SDALTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SDALTheme.line, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

struct SDALPill: View {
    let text: String
    var tint: Color = SDALTheme.softPanel
    var foreground: Color = SDALTheme.ink

    var body: some View {
        Text(text)
            .font(SDALTypography.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint, in: Capsule())
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
            Text(message)
                .font(SDALTypography.caption.weight(.semibold))
                .lineLimit(2)
        }
        .foregroundStyle(isError ? SDALTheme.danger : SDALTheme.success)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background((isError ? SDALTheme.danger : SDALTheme.success).opacity(0.15), in: Capsule())
        .overlay(
            Capsule()
                .stroke((isError ? SDALTheme.danger : SDALTheme.success).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}
