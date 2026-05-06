import Foundation

enum WatchAPIError: LocalizedError {
    case httpStatus(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .httpStatus(let status):
            return "HTTP \(status)"
        case .emptyResponse:
            return "Boş yanıt"
        }
    }
}

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

        let (data, _) = try await send(request)
        if data.isEmpty { throw WatchAPIError.emptyResponse }
        return try JSONSerialization.jsonObject(with: data)
    }

    // MARK: - GET → [[String:Any]]

    func fetchArray(path: String, baseUrl: String, cookie: String) async throws -> [[String: Any]] {
        let raw = try await fetch(path: path, baseUrl: baseUrl, cookie: cookie)
        if let arr = raw as? [[String: Any]] { return arr }
        if let dict = raw as? [String: Any] {
            if let arr = extractArray(from: dict) { return arr }
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

        let (data, _) = try await send(request)
        if data.isEmpty { return [:] as [String: Any] }
        return (try? JSONSerialization.jsonObject(with: data)) ?? [:]
    }

    // MARK: - POST → [String:Any]

    func postDict(path: String, body: [String: Any], baseUrl: String, cookie: String) async throws -> [String: Any] {
        let raw = try await post(path: path, body: body, baseUrl: baseUrl, cookie: cookie)
        return (raw as? [String: Any]) ?? [:]
    }

    private func extractArray(from dict: [String: Any]) -> [[String: Any]]? {
        for key in ["items", "results", "posts", "threads",
                    "notifications", "messages", "contacts",
                    "members", "users", "stories", "list", "records"] {
            if let arr = dict[key] as? [[String: Any]] { return arr }
        }
        for key in ["data", "payload", "result"] {
            if let nestedArr = dict[key] as? [[String: Any]] { return nestedArr }
            if let nestedDict = dict[key] as? [String: Any],
               let arr = extractArray(from: nestedDict) {
                return arr
            }
        }
        return nil
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse?) {
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { return (data, nil) }
                if (200...299).contains(http.statusCode) {
                    return (data, http)
                }
                if http.statusCode == 401 || http.statusCode == 403 {
                    NotificationCenter.default.post(name: .sdalWatchAuthRejected, object: nil)
                    throw WatchAPIError.httpStatus(http.statusCode)
                }
                if [408, 425, 429, 500, 502, 503, 504].contains(http.statusCode), attempt < 2 {
                    try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 350_000_000)
                    continue
                }
                throw WatchAPIError.httpStatus(http.statusCode)
            } catch {
                lastError = error
                if Task.isCancelled { throw error }
                if attempt < 2, shouldRetry(error) {
                    try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 350_000_000)
                    continue
                }
                throw error
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if error is WatchAPIError { return false }
        let code = (error as? URLError)?.code
        return code == .timedOut
            || code == .cannotFindHost
            || code == .cannotConnectToHost
            || code == .networkConnectionLost
            || code == .notConnectedToInternet
            || code == .dnsLookupFailed
    }
}
