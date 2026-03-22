import Foundation

enum AppConfig {
    static let baseURL = URL(string: "https://sdalsosyal.mywire.org")!
    static let apiPrefix = "/api"

    static func apiURL(path: String, query: [String: String]? = nil) -> URL? {
        let componentsWithEmbeddedQuery = path.hasPrefix("/")
            ? URLComponents(string: path)
            : URLComponents(string: "/" + path)
        let normalizedPath = componentsWithEmbeddedQuery?.path.isEmpty == false
            ? componentsWithEmbeddedQuery?.path ?? path
            : (path.hasPrefix("/") ? path : "/" + path)
        guard var components = URLComponents(url: baseURL.appendingPathComponent(apiPrefix), resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = apiPrefix + normalizedPath
        let embeddedItems = componentsWithEmbeddedQuery?.queryItems ?? []
        let explicitItems = (query ?? [:])
            .sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        let combinedItems = embeddedItems + explicitItems
        if !combinedItems.isEmpty {
            components.queryItems = combinedItems
        }
        return components.url
    }

    static func webSocketURL(path: String, query: [String: String]? = nil) -> URL? {
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = normalizedPath
        if let query, !query.isEmpty {
            components.queryItems = query
                .sorted { $0.key < $1.key }
                .map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url
    }

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
