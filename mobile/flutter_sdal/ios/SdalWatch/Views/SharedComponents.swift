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
                .fill(Color.accentColor.opacity(0.14))
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
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 22))
                .foregroundStyle(Color.accentColor.opacity(0.8))
            Text("Yüklenemedi")
                .font(.caption).fontWeight(.medium)
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            Button(action: onRetry) {
                Text("Tekrar dene")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    guard let date = parseSdalDate(iso) else { return iso }
    return relativeString(from: date)
}

private func parseSdalDate(_ raw: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractional.date(from: raw) { return date }

    let internet = ISO8601DateFormatter()
    internet.formatOptions = [.withInternetDateTime]
    if let date = internet.date(from: raw) { return date }

    let simple = DateFormatter()
    simple.locale = Locale(identifier: "tr_TR")
    simple.timeZone = TimeZone.current
    simple.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return simple.date(from: raw)
}

private func relativeString(from date: Date) -> String {
    let now = Date()
    let calendar = Calendar.current
    let seconds = Int(now.timeIntervalSince(date))
    let dayDifference = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0

    if seconds < 0 {
        let futureSeconds = abs(seconds)
        if futureSeconds < 30 { return "şimdi" }
        if futureSeconds < 3600 { return "\(max(1, futureSeconds / 60)) dakika sonra" }
        if dayDifference == 0 { return "\(max(1, futureSeconds / 3600)) saat sonra" }
        return absoluteDateString(from: date, relativeTo: now)
    }

    if seconds < 30 { return "şimdi" }
    if seconds < 3600 { return "\(max(1, seconds / 60)) dakika önce" }
    if dayDifference == 0 { return "\(max(1, seconds / 3600)) saat önce" }
    if dayDifference < 7 { return "\(dayDifference) gün önce" }
    if dayDifference < 14 { return "1 hafta önce" }
    return absoluteDateString(from: date, relativeTo: now)
}

private func absoluteDateString(from date: Date, relativeTo now: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "tr_TR")
    formatter.timeZone = TimeZone.current
    let sameDay = Calendar.current.isDate(date, inSameDayAs: now)
    if sameDay {
        formatter.dateFormat = "HH:mm"
    } else if Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: now) {
        formatter.dateFormat = "d MMMM HH:mm"
    } else {
        formatter.dateFormat = "d MMMM yyyy HH:mm"
    }
    return formatter.string(from: date)
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
