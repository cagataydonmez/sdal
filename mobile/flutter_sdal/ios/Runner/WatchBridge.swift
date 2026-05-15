import Foundation
import WatchConnectivity

/// Bridges the iOS app's session cookie to the Apple Watch companion app.
/// Call `WatchBridge.shared.start()` from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    private override init() {}

    private let cookieKey    = "sdal_bridge_cookie"
    private let baseUrlKey   = "sdal_bridge_base_url"
    private let userIdKey    = "sdal_bridge_user_id"
    private let userPhotoKey = "sdal_bridge_user_photo"
    private let themeKey     = "sdal_bridge_active_theme"

    // MARK: - Lifecycle

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            pushContext(to: session)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            pushContext(to: session)
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if (message["action"] as? String) == "requestSessionContext" {
            let context = buildContext()
            replyHandler(context)
            if !context.isEmpty {
                deliverContext(context, via: session)
            }
        } else {
            replyHandler([:])
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        if (message["action"] as? String) == "requestSessionContext" {
            pushContext(to: session)
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        if (userInfo["action"] as? String) == "requestSessionContext" {
            pushContext(to: session)
        }
    }

    // MARK: - Flutter → Watch push

    /// Called by the Flutter MethodChannel when the session changes.
    func pushSession(cookie: String, baseUrl: String, userId: Int = 0, userPhoto: String = "", activeTheme: String = "") {
        // Always persist so buildContext() can serve Watch requests even if
        // isWatchAppInstalled was false when this was first called.
        let ud = UserDefaults.standard
        ud.set(cookie, forKey: cookieKey)
        ud.set(baseUrl, forKey: baseUrlKey)
        if userId > 0 { ud.set(userId, forKey: userIdKey) }
        if !userPhoto.isEmpty { ud.set(userPhoto, forKey: userPhotoKey) }
        let validThemes: Set<String> = ["kor", "atlas", "vibe"]
        let safeTheme = validThemes.contains(activeTheme) ? activeTheme : "kor"
        ud.set(safeTheme, forKey: themeKey)

        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        deliverContext(buildContext(), via: WCSession.default)
    }

    func clearSession() {
        let ud = UserDefaults.standard
        ud.removeObject(forKey: cookieKey)
        ud.removeObject(forKey: baseUrlKey)
        ud.removeObject(forKey: userIdKey)
        ud.removeObject(forKey: userPhotoKey)
        ud.removeObject(forKey: themeKey)

        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        deliverContext(["cookie": "", "baseUrl": "", "issuedAt": Date().timeIntervalSince1970], via: WCSession.default)
    }

    func resendSessionIfAvailable() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
        pushContext(to: WCSession.default)
    }

    // MARK: - Push helpers

    private func pushContext(to session: WCSession) {
        guard session.isPaired else { return }
        let context = buildContext()
        guard !context.isEmpty else { return }
        deliverContext(context, via: session)
    }

    private func deliverContext(_ context: [String: Any], via session: WCSession) {
        guard session.isPaired else { return }
        try? session.updateApplicationContext(context)
        session.transferUserInfo(context)
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil, errorHandler: nil)
        }
    }

    private func buildContext() -> [String: Any] {
        // Prefer UserDefaults (written by Flutter MethodChannel push) over disk.
        let ud = UserDefaults.standard
        if let cookie = ud.string(forKey: cookieKey), !cookie.isEmpty,
           let baseUrl = ud.string(forKey: baseUrlKey), !baseUrl.isEmpty {
            var ctx: [String: Any] = [
                "cookie": cookie,
                "baseUrl": baseUrl,
                "issuedAt": Date().timeIntervalSince1970,
            ]
            let uid = ud.integer(forKey: userIdKey)
            if uid > 0 { ctx["userId"] = uid }
            if let photo = ud.string(forKey: userPhotoKey), !photo.isEmpty {
                ctx["userPhoto"] = photo
            }
            let theme = ud.string(forKey: themeKey) ?? "kor"
            ctx["activeTheme"] = theme
            return ctx
        }
        // Fallback: read cookie_jar v4 files written by Flutter.
        if let (cookie, baseUrl) = readSessionCookieAndUrl() {
            return [
                "cookie": cookie,
                "baseUrl": baseUrl,
                "issuedAt": Date().timeIntervalSince1970,
            ]
        }
        return [:]
    }

    // MARK: - Cookie extraction (fallback)
    // Reads connect.sid from the cookie_jar v4 files written by the Flutter app.
    // cookie_jar v4 with FileStorage layout:
    //   <appSupport>/flutter_sdal/sdal_cookies/<hash>/<hostname>   (no .json extension)
    // File format: {"/": {"connect.sid": "connect.sid=VALUE; Expires=...; ..."}}
    // The filename IS the hostname, so we reconstruct the base URL from it.

    private func readSessionCookieAndUrl() -> (cookie: String, baseUrl: String)? {
        let fm = FileManager.default
        let candidateBases: [URL] = [
            fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!,
            fm.temporaryDirectory,
        ]

        for base in candidateBases {
            let cookieDir = base.appendingPathComponent("flutter_sdal/sdal_cookies")
            if let result = searchCookieDir(cookieDir, fm: fm) { return result }
        }
        return nil
    }

    private func searchCookieDir(_ cookieDir: URL, fm: FileManager) -> (cookie: String, baseUrl: String)? {
        guard let topItems = try? fm.contentsOfDirectory(
            at: cookieDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return nil }

        for item in topItems {
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                guard let subItems = try? fm.contentsOfDirectory(
                    at: item,
                    includingPropertiesForKeys: nil
                ) else { continue }
                for subItem in subItems {
                    if let cookie = parseCookieJarFile(at: subItem) {
                        let hostname = subItem.lastPathComponent
                        let baseUrl = hostname.hasPrefix("http") ? hostname : "https://\(hostname)"
                        return (cookie, baseUrl)
                    }
                }
            } else {
                if let cookie = parseCookieJarFile(at: item) {
                    let hostname = item.lastPathComponent
                    let baseUrl = hostname.hasPrefix("http") ? hostname : "https://\(hostname)"
                    return (cookie, baseUrl)
                }
            }
        }
        return nil
    }

    private func parseCookieJarFile(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        // Format: { "<path>": { "<cookieName>": "<Set-Cookie header string>" } }
        for (_, pathValue) in json {
            guard let cookieDict = pathValue as? [String: Any] else { continue }
            if let setHeader = cookieDict["connect.sid"] as? String {
                // setHeader = "connect.sid=VALUE; Expires=...; Path=/; ..."
                let nameValue = setHeader.components(separatedBy: ";").first?
                    .trimmingCharacters(in: .whitespaces) ?? ""
                if nameValue.hasPrefix("connect.sid=") { return nameValue }
            }
        }
        return nil
    }
}
