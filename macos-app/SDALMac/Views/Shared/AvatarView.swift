import SwiftUI

struct AvatarView: View {
    let url: URL?
    let initials: String
    var size: CGFloat = 36
    var isOnline: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        initialsView
                    default:
                        ProgressView()
                            .frame(width: size, height: size)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initialsView
            }

            if isOnline {
                Circle()
                    .fill(.green)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(
                        Circle()
                            .stroke(Color(.windowBackgroundColor), lineWidth: 2)
                    )
                    .offset(x: 1, y: 1)
            }
        }
    }

    private var initialsView: some View {
        Circle()
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            )
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarView(url: nil, initials: "CD", size: 32)
        AvatarView(url: nil, initials: "JD", size: 48, isOnline: true)
        AvatarView(url: nil, initials: "AB", size: 64)
    }
    .padding()
}
