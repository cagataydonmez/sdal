import Foundation

enum AppConfig {
    static let baseURL = URL(string: "https://sdalsosyal.mywire.org")!
    static let apiPrefix = "/api"

    static func absoluteURL(path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        return URL(string: baseURL.absoluteString + path)
    }

    static func avatarURL(imageName: String?) -> URL? {
        guard let imageName, !imageName.isEmpty else { return nil }
        return URL(string: baseURL.absoluteString + "/api/media/vesikalik/" + imageName)
    }

    static func thumbnailURL(fileName: String?, width: Int) -> URL? {
        guard let fileName, !fileName.isEmpty else { return nil }
        let encoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fileName
        return URL(string: baseURL.absoluteString + "/api/media/kucukresim?width=\(width)&file=\(encoded)")
    }
}
