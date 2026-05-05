import Foundation
import WatchConnectivity

final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published private(set) var sessionCookie: String = ""
    @Published private(set) var apiBaseUrl: String = "https://sdal.app"

    private let cookieKey = "sdal_watch_cookie"
    private let baseUrlKey = "sdal_watch_base_url"

    override private init() {
        super.init()
        // Restore persisted values
        sessionCookie = UserDefaults.standard.string(forKey: cookieKey) ?? ""
        apiBaseUrl = UserDefaults.standard.string(forKey: baseUrlKey) ?? "https://sdal.app"
    }

    // MARK: - Lifecycle

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func requestContext() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(
            ["action": "requestSessionContext"],
            replyHandler: { [weak self] reply in
                self?.applyContext(reply)
            },
            errorHandler: nil
        )
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            applyContext(session.receivedApplicationContext)
            if sessionCookie.isEmpty {
                requestContext()
            }
        }
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        applyContext(applicationContext)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        applyContext(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        applyContext(message)
        replyHandler([:])
    }

    // MARK: - Private

    private func applyContext(_ context: [String: Any]) {
        var newCookie = ""
        var newUrl = "https://sdal.app"

        if let cookie = context["cookie"] as? String, !cookie.isEmpty {
            newCookie = cookie
        }
        if let url = context["baseUrl"] as? String, !url.isEmpty {
            newUrl = url
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !newCookie.isEmpty { self.sessionCookie = newCookie }
            self.apiBaseUrl = newUrl
            UserDefaults.standard.set(self.sessionCookie, forKey: self.cookieKey)
            UserDefaults.standard.set(self.apiBaseUrl, forKey: self.baseUrlKey)
        }
    }
}
