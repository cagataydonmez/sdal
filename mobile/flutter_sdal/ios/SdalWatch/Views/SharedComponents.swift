import SwiftUI

// MARK: - Avatar

struct AvatarView: View {
    let initials: String
    let photoUrl: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.18))
            if photoUrl.isEmpty {
                Text(initials)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            } else {
                AsyncImage(url: URL(string: photoUrl)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Text(initials)
                            .font(.system(size: size * 0.38, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Error + Retry

struct ErrorRetryView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(.red)
            Text("Yüklenemedi")
                .font(.caption2)
            Button("Tekrar dene", action: onRetry)
                .font(.system(size: 11))
        }
        .padding()
    }
}
