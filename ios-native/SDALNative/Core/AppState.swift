import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var session: SessionUser?
    @Published var isBootstrapping = true

    private let api = APIClient.shared

    func bootstrapSession() async {
        defer { isBootstrapping = false }
        do {
            session = try await api.fetchSession()
        } catch {
            session = nil
        }
    }

    func login(username: String, password: String) async throws {
        try await api.login(username: username, password: password)
        session = try await api.fetchSession()
    }

    func refreshSession() async {
        do {
            session = try await api.fetchSession()
        } catch {
            session = nil
        }
    }

    func logout() async {
        do {
            try await api.logout()
        } catch {
            // Ignore logout failures and clear local state anyway.
        }
        session = nil
    }
}
