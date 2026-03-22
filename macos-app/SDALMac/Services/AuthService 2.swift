import Foundation
import SwiftUI

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    var currentUser: User?
    var isLoading = true
    var isAuthenticated: Bool { currentUser != nil }
    var error: String?

    private init() {}

    func checkSession() async {
        isLoading = true
        error = nil
        do {
            let response: SessionResponse = try await APIClient.shared.get("/api/session")
            currentUser = response.user
        } catch {
            currentUser = nil
        }
        isLoading = false
    }

    func login(username: String, password: String) async throws {
        error = nil
        let body = LoginRequest(kadi: username, sifre: password)
        let response: LoginResponse = try await APIClient.shared.post("/api/auth/login", body: body)

        if let user = response.user {
            currentUser = user
        } else {
            // Session cookie was set by backend - fetch full session
            await checkSession()
            if currentUser == nil {
                let msg = response.error ?? response.message ?? "Login failed"
                self.error = msg
                throw APIError.serverError(401, msg)
            }
        }
    }

    func logout() async {
        do {
            try await APIClient.shared.postVoid("/api/auth/logout")
        } catch {
            // Ignore logout errors
        }
        currentUser = nil
        // Clear cookies
        if let cookies = HTTPCookieStorage.shared.cookies(for: APIConfig.url("/")) {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }

    func refresh() async {
        await checkSession()
    }
}
