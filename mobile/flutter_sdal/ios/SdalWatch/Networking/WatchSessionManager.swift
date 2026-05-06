import Foundation
import WatchConnectivity

final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published private(set) var sessionCookie: String = ""
    @Published private(set) var apiBaseUrl: String = "https://sdal.app"
    @Published private(set) var myUserId: Int = 0

    private let cookieKey   = "sdal_watch_cookie"
    private let baseUrlKey  = "sdal_watch_base_url"
    private let userIdKey   = "sdal_watch_user_id"

    override private init() {
        super.init()
        sessionCookie = UserDefaults.standard.string(forKey: cookieKey) ?? ""
        apiBaseUrl    = UserDefaults.standard.string(forKey: baseUrlKey) ?? "https://sdal.app"
        myUserId      = UserDefaults.standard.integer(forKey: userIdKey)
    }

    // MARK: - Lifecycle

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Ask the iPhone app for current session context.
    /// Safe to call even if session is not yet reachable — silently no-ops.
    func requestContext() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(
            ["action": "requestSessionContext"],
            replyHandler: { [weak self] reply in self?.applyContext(reply) },
            errorHandler: { _ in
                // iPhone not reachable right now — rely on applicationContext instead
            }
        )
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            // Try the cached context first
            applyContext(session.receivedApplicationContext)

            if sessionCookie.isEmpty {
                // Ask iPhone directly
                requestContext()
                // Retry once more after a few seconds in case iPhone wasn't ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                    guard let self, self.sessionCookie.isEmpty else { return }
                    self.requestContext()
                }
            }
        }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        applyContext(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        applyContext(message)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        applyContext(message)
        replyHandler([:])
    }

    // MARK: - Private

    private func applyContext(_ context: [String: Any]) {
        let newCookie  = (context["cookie"]  as? String).flatMap { $0.isEmpty ? nil : $0 }
        let newUrl     = (context["baseUrl"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let newUserId  = (context["userId"]  as? Int).flatMap { $0 > 0 ? $0 : nil }

        guard newCookie != nil || newUrl != nil || newUserId != nil else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let c  = newCookie  { self.sessionCookie = c }
            if let u  = newUrl     { self.apiBaseUrl = u }
            if let id = newUserId  { self.myUserId = id }
            UserDefaults.standard.set(self.sessionCookie, forKey: self.cookieKey)
            UserDefaults.standard.set(self.apiBaseUrl,    forKey: self.baseUrlKey)
            UserDefaults.standard.set(self.myUserId,      forKey: self.userIdKey)
        }
    }
}
