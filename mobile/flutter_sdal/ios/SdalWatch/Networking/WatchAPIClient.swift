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

    // MARK: - URL builder

    private func buildURL(path: String, baseUrl: String) throws -> URL {
        let base = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
        let p = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: "\(base)\(p)") else {
            throw URLError(.badURL)
        }
        return url
    }

    // MARK: - Generic GET

    func fetch(path: String, baseUrl: String, cookie: String) async throws -> Any {
        let url = try buildURL(path: path, baseUrl: baseUrl)
        var request = URLRequest(url: url)
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SDAL-Watch/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    // MARK: - GET → [[String:Any]]

    func fetchArray(path: String, baseUrl: String, cookie: String) async throws -> [[String: Any]] {
        let raw = try await fetch(path: path, baseUrl: baseUrl, cookie: cookie)
        if let arr = raw as? [[String: Any]] { return arr }
        if let dict = raw as? [String: Any] {
            // Ordered by specificity — add new response envelope keys here
            for key in ["data", "items", "results", "posts", "threads",
                        "notifications", "messages", "contacts",
                        "members", "users", "stories", "list", "records"] {
                if let arr = dict[key] as? [[String: Any]] { return arr }
            }
        }
        return []
    }

    // MARK: - GET → [String:Any]

    func fetchDict(path: String, baseUrl: String, cookie: String) async throws -> [String: Any] {
        let raw = try await fetch(path: path, baseUrl: baseUrl, cookie: cookie)
        if let dict = raw as? [String: Any] { return dict }
        return [:]
    }

    // MARK: - Generic POST with JSON body

    @discardableResult
    func post(path: String, body: [String: Any], baseUrl: String, cookie: String) async throws -> Any {
        let url = try buildURL(path: path, baseUrl: baseUrl)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SDAL-Watch/1.0", forHTTPHeaderField: "User-Agent")
        if !body.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        if data.isEmpty { return [:] as [String: Any] }
        return (try? JSONSerialization.jsonObject(with: data)) ?? [:]
    }

    // MARK: - POST → [String:Any]

    func postDict(path: String, body: [String: Any], baseUrl: String, cookie: String) async throws -> [String: Any] {
        let raw = try await post(path: path, body: body, baseUrl: baseUrl, cookie: cookie)
        return (raw as? [String: Any]) ?? [:]
    }
}
