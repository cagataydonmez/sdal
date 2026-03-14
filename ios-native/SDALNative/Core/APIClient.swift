import Foundation

enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
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

final class APIClient {
    static let shared = APIClient()

    let session: URLSession
    let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func login(username: String, password: String) async throws {
        struct LoginBody: Encodable {
            let kadi: String
            let sifre: String
        }

        _ = try await request("/auth/login", method: "POST", body: LoginBody(kadi: username, sifre: password), as: EmptyResponse.self)
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
        guard let user = res.user else {
            throw APIError.invalidResponse
        }
        return user
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

    func request<T: Decodable>(_ path: String, method: String = "GET", as type: T.Type) async throws -> T {
        try await request(path, method: method, body: Optional<String>.none, as: type)
    }

    func request<T: Decodable, B: Encodable>(_ path: String, method: String = "GET", body: B?, as type: T.Type) async throws -> T {
        guard let url = URL(string: AppConfig.baseURL.absoluteString + AppConfig.apiPrefix + path) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(currentLanguageCode(), forHTTPHeaderField: "Accept-Language")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.httpError(http.statusCode, message)
        }

        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }

        return try decoder.decode(T.self, from: data)
    }

    func requestMultipart<T: Decodable>(_ path: String, method: String, parts: [MultipartPart], as type: T.Type) async throws -> T {
        guard let url = URL(string: AppConfig.baseURL.absoluteString + AppConfig.apiPrefix + path) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(currentLanguageCode(), forHTTPHeaderField: "Accept-Language")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = MultipartFormData.build(parts: parts, boundary: boundary)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.httpError(http.statusCode, message)
        }
        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }
        return try decoder.decode(T.self, from: data)
    }

    func requestRaw(_ path: String, method: String = "GET", accept: String = "*/*") async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: AppConfig.baseURL.absoluteString + AppConfig.apiPrefix + path) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(currentLanguageCode(), forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.httpError(http.statusCode, message)
        }
        return (data, http)
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
