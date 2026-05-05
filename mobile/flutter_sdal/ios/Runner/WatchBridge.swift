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
        var ctx: [String: Any] = ["baseUrl": "https://sdal.app"]
        if let cookie = readSessionCookie() {
            ctx["cookie"] = cookie
        }
        return ctx
    }

    // MARK: - Cookie extraction
    // Reads connect.sid from the cookie_jar files written by the Flutter app.
    // Path: ~/Library/Application Support/flutter_sdal/sdal_cookies/<hostname>.json
    // Each file is a JSON object where keys are cookie names and values have a "value" sub-key.

    private func readSessionCookie() -> String? {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cookieDir = base.appendingPathComponent("flutter_sdal/sdal_cookies")

        guard let files = try? fm.contentsOfDirectory(
            at: cookieDir,
            includingPropertiesForKeys: nil
        ) else { return nil }

        let jsonFiles = files.filter { $0.pathExtension == "json" }

        for fileURL in jsonFiles {
            guard let data = try? Data(contentsOf: fileURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }

            // cookie_jar v4 stores each cookie as a nested JSON string under hostname-keyed entries.
            // We walk all values looking for connect.sid.
            if let value = extractConnectSid(from: json) {
                return "connect.sid=\(value)"
            }

            // Fallback: raw text search for "connect.sid" value pattern
            if let raw = String(data: data, encoding: .utf8),
               let value = regexExtractSid(from: raw) {
                return "connect.sid=\(value)"
            }
        }

        return nil
    }

    private func extractConnectSid(from json: [String: Any]) -> String? {
        // Walk nested dictionaries / arrays recursively
        for (key, val) in json {
            if key == "connect.sid" || key == "connectSid" {
                if let nested = val as? [String: Any], let v = nested["value"] as? String {
                    return v
                }
                if let str = val as? String { return str }
            }
            if let nested = val as? [String: Any],
               let found = extractConnectSid(from: nested) {
                return found
            }
            // cookie_jar may store cookies in an array
            if let arr = val as? [[String: Any]] {
                for item in arr {
                    if (item["name"] as? String) == "connect.sid",
                       let v = item["value"] as? String { return v }
                    if let found = extractConnectSid(from: item) { return found }
                }
            }
        }
        return nil
    }

    private func regexExtractSid(from raw: String) -> String? {
        let pattern = #"connect\.sid["\s]*:["\s]*\{[^}]*"value"\s*:\s*"([^"]{8,})"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(
               in: raw,
               range: NSRange(raw.startIndex..., in: raw)
           ),
           let range = Range(match.range(at: 1), in: raw) {
            return String(raw[range])
        }
        // Simpler fallback: any "value":"<long-string>" near connect.sid
        let simple = #""value"\s*:\s*"(s%3A[^"]{8,})"#
        if let regex = try? NSRegularExpression(pattern: simple),
           let match = regex.firstMatch(
               in: raw,
               range: NSRange(raw.startIndex..., in: raw)
           ),
           let range = Range(match.range(at: 1), in: raw) {
            return String(raw[range])
        }
        return nil
    }
}
