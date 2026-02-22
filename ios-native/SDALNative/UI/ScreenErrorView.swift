import SwiftUI

struct ScreenErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(SDALTheme.danger)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SDALTheme.ink)
                Button("Retry", action: retry)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

struct ScreenEmptyView: View {
    let title: String
    let subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        GlassCard {
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.title3)
                    .foregroundStyle(SDALTheme.muted)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(SDALTheme.muted)
                    .multilineTextAlignment(.center)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}
