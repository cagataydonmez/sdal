import Foundation

enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case sessionExpired
    case unexpectedHTMLResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case .sessionExpired:
            return "Your session expired. Please sign in again."
        case .unexpectedHTMLResponse:
            return "The server returned an unexpected page. Please try again."
        case let .httpError(code, message):
            return "Server error (\(code)): \(message)"
        }
    }
}

struct EmptyResponse: Decodable {}
struct OAuthProvidersEnvelope: Decodable {
    let providers: [OAuthProvider]
}
struct OAuthProvider: Decodable, Identifiable {
    let provider: String
    let title: String?
    let startUrl: String?

    var id: String { provider }
}

struct DownloadedFile {
    let fileName: String
    let data: Data
    let mimeType: String?
}
struct FollowToggleResponse: Decodable {
    let ok: Bool?
    let following: Bool?

    private enum CodingKeys: String, CodingKey {
        case ok, following, followed, isFollowing, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.decodeLossyBool(forKey: .ok)
        if let value = c.decodeLossyBool(forKey: .following)
            ?? c.decodeLossyBool(forKey: .followed)
            ?? c.decodeLossyBool(forKey: .isFollowing) {
            following = value
        } else if let status = c.decodeLossyString(forKey: .status)?.lowercased() {
            switch status {
            case "following", "followed", "on", "true", "1":
                following = true
            case "unfollowed", "off", "false", "0":
                following = false
            default:
                following = nil
            }
        } else {
            following = nil
        }
    }
}
struct TranslationResponse: Decodable {
    let translatedText: String?
    let sourceLanguage: String?

    private enum CodingKeys: String, CodingKey {
        case translatedText, sourceLanguage, translated, translation, ceviri, data
    }

    private struct TranslationData: Decodable {
        let translatedText: String?
        let sourceLanguage: String?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let nested = try? c.decodeIfPresent(TranslationData.self, forKey: .data)
        translatedText = c.decodeLossyString(forKey: .translatedText)
            ?? c.decodeLossyString(forKey: .translated)
            ?? c.decodeLossyString(forKey: .translation)
            ?? c.decodeLossyString(forKey: .ceviri)
            ?? nested?.translatedText
        sourceLanguage = c.decodeLossyString(forKey: .sourceLanguage)
            ?? nested?.sourceLanguage
    }
}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        struct LoginBody: Encodable {
            let kadi: String
            let sifre: String
        }

        return try await request("/auth/login", method: "POST", body: LoginBody(kadi: username, sifre: password), as: LoginResponse.self)
    }

    func fetchHealth() async throws -> HealthResponse {
        try await request("/health", as: HealthResponse.self)
    }

    func register(
        username: String,
        password: String,
        passwordRepeat: String,
        email: String,
        firstName: String,
        lastName: String,
        graduationYear: String,
        captchaCode: String
    ) async throws {
        struct Body: Encodable {
            let kadi: String
            let sifre: String
            let sifre2: String
            let email: String
            let isim: String
            let soyisim: String
            let mezuniyetyili: String
            let gkodu: String
        }

        _ = try await request(
            "/register",
            method: "POST",
            body: Body(
                kadi: username,
                sifre: password,
                sifre2: passwordRepeat,
                email: email,
                isim: firstName,
                soyisim: lastName,
                mezuniyetyili: graduationYear,
                gkodu: captchaCode
            ),
            as: APIWriteResponse.self
        )
    }

    func previewRegister(
        username: String,
        password: String,
        passwordRepeat: String,
        email: String,
        firstName: String,
        lastName: String,
        graduationYear: String,
        captchaCode: String
    ) async throws -> RegisterPreviewResponse {
        struct Body: Encodable {
            let kadi: String
            let sifre: String
            let sifre2: String
            let email: String
            let isim: String
            let soyisim: String
            let mezuniyetyili: String
            let gkodu: String
        }
        return try await request(
            "/register/preview",
            method: "POST",
            body: Body(
                kadi: username,
                sifre: password,
                sifre2: passwordRepeat,
                email: email,
                isim: firstName,
                soyisim: lastName,
                mezuniyetyili: graduationYear,
                gkodu: captchaCode
            ),
            as: RegisterPreviewResponse.self
        )
    }

    func resendActivation(memberId: String, email: String) async throws {
        struct Body: Encodable {
            let id: String
            let email: String
        }
        _ = try await request("/activation/resend", method: "POST", body: Body(id: memberId, email: email), as: APIWriteResponse.self)
    }

    func requestPasswordReset(username: String, email: String) async throws {
        struct Body: Encodable {
            let kadi: String
            let email: String
        }
        _ = try await request("/password-reset", method: "POST", body: Body(kadi: username, email: email), as: APIWriteResponse.self)
    }

    func activateAccount(id: String, code: String) async throws -> ActivationResponse {
        let safeId = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        let safeCode = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        return try await request("/activate?id=\(safeId)&akt=\(safeCode)", as: ActivationResponse.self)
    }

    func fetchSession() async throws -> SessionUser {
        let res = try await request("/session", as: SessionEnvelope.self)
        guard let user = res.resolvedUser else {
            throw APIError.invalidResponse
        }
        return user
    }

    func fetchSiteAccess() async throws -> SiteAccessResponse {
        try await request("/site-access", as: SiteAccessResponse.self)
    }

    func fetchOAuthProviders() async throws -> [OAuthProvider] {
        let payload = try await request("/auth/oauth/providers", as: OAuthProvidersEnvelope.self)
        return payload.providers
    }

    func exchangeMobileOAuthToken(_ token: String) async throws {
        struct Body: Encodable { let token: String }
        _ = try await request("/auth/oauth/mobile/exchange", method: "POST", body: Body(token: token), as: APIWriteResponse.self)
    }

    func logout() async throws {
        _ = try await request("/auth/logout", method: "POST", as: EmptyResponse.self)
    }

    func request<T: Decodable>(_ method: String = "GET", _ path: String, query: [String: String]? = nil) async throws -> T {
        try await request(method, path, body: Optional<String>.none, query: query)
    }

    func request<T: Decodable, B: Encodable>(
        _ method: String = "GET",
        _ path: String,
        body: B? = nil,
        query: [String: String]? = nil
    ) async throws -> T {
        guard let url = AppConfig.apiURL(path: path, query: query) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        prepareHeaders(for: &request, method: method, accept: "application/json")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let (data, _) = try await perform(request)
        return try decodeResponse(T.self, from: data)
    }

    func upload<T: Decodable>(
        _ path: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        fields: [String: String]? = nil
    ) async throws -> T {
        var parts = (fields ?? [:]).map {
            MultipartPart(name: $0.key, fileName: nil, mimeType: nil, data: Data($0.value.utf8))
        }
        parts.sort { $0.name < $1.name }
        parts.append(MultipartPart(name: "file", fileName: fileName, mimeType: mimeType, data: fileData))
        return try await requestMultipart(path, method: "POST", parts: parts)
    }

    func requestMultipart<T: Decodable>(_ path: String, method: String, parts: [MultipartPart]) async throws -> T {
        guard let url = AppConfig.apiURL(path: path) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        prepareHeaders(for: &request, method: method, accept: "application/json")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = MultipartFormData.build(parts: parts, boundary: boundary)

        let (data, _) = try await perform(request)
        return try decodeResponse(T.self, from: data)
    }

    func requestRaw(_ method: String = "GET", _ path: String, query: [String: String]? = nil, accept: String = "*/*") async throws -> (Data, HTTPURLResponse) {
        guard let url = AppConfig.apiURL(path: path, query: query) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        prepareHeaders(for: &request, method: method, accept: accept)
        return try await perform(request)
    }

    func extractFilename(from response: HTTPURLResponse) -> String? {
        guard let disposition = response.value(forHTTPHeaderField: "Content-Disposition"), !disposition.isEmpty else {
            return nil
        }

        let parts = disposition.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let extended = parts.first(where: { $0.lowercased().hasPrefix("filename*=") }) {
            var value = String(extended.dropFirst("filename*=".count))
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let encoded = value.replacingOccurrences(of: "UTF-8''", with: "", options: [.caseInsensitive])
            if let decoded = encoded.removingPercentEncoding, !decoded.isEmpty {
                return decoded
            }
        }
        if let plain = parts.first(where: { $0.lowercased().hasPrefix("filename=") }) {
            var value = String(plain.dropFirst("filename=".count))
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }

    func currentLanguageCode() -> String {
        UserDefaults.standard.string(forKey: "sdal_native_lang") ?? "tr"
    }

    private func prepareHeaders(for request: inout URLRequest, method: String, accept: String) {
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(currentLanguageCode(), forHTTPHeaderField: "Accept-Language")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        if method.uppercased() == "POST" {
            request.setValue(UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        }
    }

    private func perform(_ request: URLRequest, retryOnServerError: Bool = true) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if http.statusCode == 401 || looksLikeUnauthorizedHTML(response: http, data: data) {
            NotificationCenter.default.post(name: .sdalUnauthorizedResponse, object: nil)
            throw APIError.sessionExpired
        }
        guard (200...299).contains(http.statusCode) else {
            if retryOnServerError, (500...599).contains(http.statusCode) {
                return try await perform(request, retryOnServerError: false)
            }
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.httpError(http.statusCode, message)
        }
        return (data, http)
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            if let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               text.hasPrefix("<") {
                throw APIError.unexpectedHTMLResponse
            }
            throw error
        }
    }

    private func looksLikeUnauthorizedHTML(response: HTTPURLResponse, data: Data) -> Bool {
        let finalPath = response.url?.path.lowercased() ?? ""
        if finalPath.contains("/login") || finalPath.contains("/giris") {
            return true
        }

        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        guard contentType.contains("text/html") || contentType.contains("application/xhtml") else {
            return false
        }

        guard let text = String(data: data.prefix(4096), encoding: .utf8)?.lowercased() else {
            return false
        }
        if text.contains("<html") || text.contains("<!doctype html") {
            return text.contains("login")
                || text.contains("giris")
                || text.contains("session")
                || text.contains("oturum")
                || text.contains("sign in")
                || text.contains("kadi")
        }
        return false
    }
}

extension APIClient {
    func request<T: Decodable>(_ path: String, method: String = "GET", as type: T.Type) async throws -> T {
        try await request(method, path)
    }

    func request<T: Decodable, B: Encodable>(_ path: String, method: String = "GET", body: B?, as type: T.Type) async throws -> T {
        try await request(method, path, body: body)
    }

    func requestMultipart<T: Decodable>(_ path: String, method: String, parts: [MultipartPart], as type: T.Type) async throws -> T {
        try await requestMultipart(path, method: method, parts: parts)
    }

    func requestRaw(_ path: String, method: String = "GET", accept: String = "*/*") async throws -> (Data, HTTPURLResponse) {
        try await requestRaw(method, path, accept: accept)
    }
}

extension KeyedDecodingContainer {
    func decodeLossyInt(forKey key: Key) -> Int? {
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return v }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Int(s) }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return Int(d) }
        return nil
    }

    func decodeLossyBool(forKey key: Key) -> Bool? {
        if let v = try? decodeIfPresent(Bool.self, forKey: key) { return v }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return i != 0 }
        if let s = try? decodeIfPresent(String.self, forKey: key) {
            let value = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "yes"].contains(value) { return true }
            if ["0", "false", "no"].contains(value) { return false }
        }
        return nil
    }

    func decodeLossyString(forKey key: Key) -> String? {
        if let v = try? decodeIfPresent(String.self, forKey: key) { return v }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return String(i) }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return String(d) }
        if let b = try? decodeIfPresent(Bool.self, forKey: key) { return String(b) }
        return nil
    }
}
