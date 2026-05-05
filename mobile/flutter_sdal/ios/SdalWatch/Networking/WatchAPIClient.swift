import Foundation

actor WatchAPIClient {
    static let shared = WatchAPIClient()
    private init() {}

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    // MARK: - Generic fetch

    func fetch(
        path: String,
        baseUrl: String,
        cookie: String
    ) async throws -> Any {
        let urlString = baseUrl.hasSuffix("/")
            ? "\(baseUrl)\(path.hasPrefix("/") ? String(path.dropFirst()) : path)"
            : "\(baseUrl)\(path)"

        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SDAL-Watch/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try JSONSerialization.jsonObject(with: data)
    }

    // MARK: - Typed helpers

    func fetchArray(path: String, baseUrl: String, cookie: String) async throws -> [[String: Any]] {
        let raw = try await fetch(path: path, baseUrl: baseUrl, cookie: cookie)
        if let arr = raw as? [[String: Any]] { return arr }
        if let dict = raw as? [String: Any] {
            // Try common wrapper keys
            for key in ["data", "items", "results", "posts", "threads", "notifications"] {
                if let arr = dict[key] as? [[String: Any]] { return arr }
            }
        }
        return []
    }
}
