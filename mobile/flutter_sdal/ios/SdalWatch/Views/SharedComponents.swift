import SwiftUI

// MARK: - Avatar

struct AvatarView: View {
    let initials: String
    let photoUrl: String
    let size: CGFloat
    var ringColor: Color? = nil
    @EnvironmentObject private var sessionManager: WatchSessionManager

    var body: some View {
        ZStack {
            if let ring = ringColor {
                Circle()
                    .stroke(ring, lineWidth: 2)
                    .frame(width: size + 4, height: size + 4)
            }
            Circle()
                .fill(Color.accentColor.opacity(0.18))
            if !photoUrl.isEmpty {
                AsyncImage(url: resolvedMediaURL(photoUrl, baseUrl: sessionManager.apiBaseUrl, profilePhoto: true)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        initialsText
                    }
                }
            } else {
                initialsText
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initialsText: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(Color.accentColor)
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

// MARK: - Loading Overlay

struct LoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Relative Time

func relativeTime(_ iso: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: iso) else {
        let simple = DateFormatter()
        simple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let d = simple.date(from: iso) else { return iso }
        return relativeString(from: d)
    }
    return relativeString(from: date)
}

private func relativeString(from date: Date) -> String {
    let seconds = Int(Date().timeIntervalSince(date))
    if seconds < 60 { return "\(seconds)s" }
    if seconds < 3600 { return "\(seconds / 60)d" }
    if seconds < 86400 { return "\(seconds / 3600)sa" }
    return "\(seconds / 86400)g"
}

// MARK: - FeedType Label

func feedTypeLabel(_ type: String) -> String {
    type == "community" ? "Topluluk" : "Genel"
}

func resolvedMediaURL(_ raw: String, baseUrl: String, profilePhoto: Bool = false) -> URL? {
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, value.lowercased() != "yok" else { return nil }
    guard let base = URL(string: baseUrl) else { return URL(string: value) }
    var origin = "\(base.scheme ?? "https")://\(base.host ?? "sdal.app")"
    if let port = base.port {
        origin += ":\(port)"
    }

    if value.hasPrefix("http://") || value.hasPrefix("https://") {
        if let url = URL(string: value),
           url.host == base.host,
           url.port == base.port,
           url.path.hasPrefix("/uploads/") || url.path.hasPrefix("/api/media/") {
            return watchMediaURL(origin: origin, path: url.path, profilePhoto: profilePhoto)
        }
        return mediaURL(from: value)
    }
    if value.hasPrefix("//") {
        return mediaURL(from: "https:\(value)")
    }

    if value.hasPrefix("/") {
        return watchMediaURL(origin: origin, path: value, profilePhoto: profilePhoto)
    }
    if profilePhoto && !value.contains("/") {
        let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
        return watchMediaURL(origin: origin, path: "/api/media/vesikalik/\(encoded)", profilePhoto: true)
    }
    return watchMediaURL(origin: origin, path: "/\(value)", profilePhoto: profilePhoto)
}

private func mediaURL(from value: String) -> URL? {
    if let url = URL(string: value) { return url }
    let allowed = CharacterSet.urlQueryAllowed.union(.init(charactersIn: "/:#[]@!$&'()*+,;="))
    return URL(string: value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value)
}

private func watchMediaURL(origin: String, path: String, profilePhoto: Bool = false) -> URL? {
    var components = URLComponents(string: "\(origin)/api/media/watch-image")
    let width = profilePhoto ? "96" : "360"
    components?.queryItems = [
        URLQueryItem(name: "width", value: width),
        URLQueryItem(name: "format", value: "jpeg"),
        URLQueryItem(name: "quality", value: "72"),
        URLQueryItem(name: "v", value: "3"),
        URLQueryItem(name: "src", value: path)
    ]
    return components?.url ?? mediaURL(from: "\(origin)\(path)")
}
