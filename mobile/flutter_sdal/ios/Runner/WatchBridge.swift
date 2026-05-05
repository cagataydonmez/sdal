import Foundation
import WatchConnectivity

/// Bridges the iOS app's session cookie to the Apple Watch companion app.
/// Call `WatchBridge.shared.start()` from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()
    private override init() {}

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

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if (message["action"] as? String) == "requestSessionContext" {
            let context = buildContext()
            replyHandler(context)
            try? session.updateApplicationContext(context)
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

    // MARK: - Push helpers

    private func pushContext(to session: WCSession) {
        guard session.isPaired, session.isWatchAppInstalled else { return }
        let context = buildContext()
        try? session.updateApplicationContext(context)
    }

    private func buildContext() -> [String: Any] {
        var ctx: [String: Any] = [:]
        if let (cookie, baseUrl) = readSessionCookieAndUrl() {
            ctx["cookie"] = cookie
            ctx["baseUrl"] = baseUrl
        }
        return ctx
    }

    // MARK: - Cookie extraction
    // Reads connect.sid from the cookie_jar v4 files written by the Flutter app.
    // cookie_jar v4 with FileStorage layout:
    //   <appSupport>/flutter_sdal/sdal_cookies/<hash>/<hostname>   (no .json extension)
    // File format: {"/": {"connect.sid": "connect.sid=VALUE; Expires=...; ..."}}
    // The filename IS the hostname, so we reconstruct the base URL from it.

    private func readSessionCookieAndUrl() -> (cookie: String, baseUrl: String)? {
        let fm = FileManager.default
        // Flutter may write to either Application Support or the temp directory depending
        // on whether $HOME is set in the Flutter process. Check both.
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

    // Parses a single cookie_jar v4 file and returns "connect.sid=VALUE" if present.
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
