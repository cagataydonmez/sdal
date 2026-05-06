import Foundation
import WatchConnectivity

extension Notification.Name {
    static let sdalWatchAuthRejected = Notification.Name("sdalWatchAuthRejected")
}

final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published private(set) var sessionCookie: String = ""
    @Published private(set) var apiBaseUrl: String = "https://sdal.app"
    @Published private(set) var myUserId: Int = 0
    @Published private(set) var lastContextReceivedAt: Date?

    private let cookieKey   = "sdal_watch_cookie"
    private let baseUrlKey  = "sdal_watch_base_url"
    private let userIdKey   = "sdal_watch_user_id"
    private var recoveryTask: Task<Void, Never>?

    override private init() {
        super.init()
        sessionCookie = UserDefaults.standard.string(forKey: cookieKey) ?? ""
        apiBaseUrl    = UserDefaults.standard.string(forKey: baseUrlKey) ?? "https://sdal.app"
        myUserId      = UserDefaults.standard.integer(forKey: userIdKey)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthRejected),
            name: .sdalWatchAuthRejected,
            object: nil
        )
    }

    // MARK: - Lifecycle

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        startRecoveryLoop()
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
                WCSession.default.transferUserInfo(["action": "requestSessionContext"])
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
            startRecoveryLoop()

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

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if (userInfo["action"] as? String) == "requestSessionContext" {
            requestContext()
            return
        }
        applyContext(userInfo)
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        applyContext(message)
        replyHandler([:])
    }

    // MARK: - Private

    private func applyContext(_ context: [String: Any]) {
        if let cookie = context["cookie"] as? String, cookie.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.sessionCookie = ""
                self.myUserId = 0
                self.lastContextReceivedAt = Date()
                UserDefaults.standard.removeObject(forKey: self.cookieKey)
                UserDefaults.standard.removeObject(forKey: self.userIdKey)
            }
            return
        }

        let newCookie  = (context["cookie"]  as? String).flatMap { $0.isEmpty ? nil : $0 }
        let newUrl     = (context["baseUrl"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let newUserId  = (context["userId"]  as? Int).flatMap { $0 > 0 ? $0 : nil }

        guard newCookie != nil || newUrl != nil || newUserId != nil else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let c  = newCookie  { self.sessionCookie = c }
            if let u  = newUrl     { self.apiBaseUrl = u }
            if let id = newUserId  { self.myUserId = id }
            self.lastContextReceivedAt = Date()
            UserDefaults.standard.set(self.sessionCookie, forKey: self.cookieKey)
            UserDefaults.standard.set(self.apiBaseUrl,    forKey: self.baseUrlKey)
            UserDefaults.standard.set(self.myUserId,      forKey: self.userIdKey)
        }
    }

    private func startRecoveryLoop() {
        guard recoveryTask == nil else { return }
        recoveryTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await MainActor.run {
                    self.requestContext()
                }
                let hasSession = await MainActor.run { !self.sessionCookie.isEmpty }
                let seconds: UInt64 = hasSession ? 300 : 15
                try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            }
        }
    }

    @objc private func handleAuthRejected() {
        requestContext()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.requestContext()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.requestContext()
        }
    }
}
