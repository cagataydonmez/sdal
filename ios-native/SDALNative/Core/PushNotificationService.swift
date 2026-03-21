import Foundation
import UserNotifications
import UIKit

@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let deviceTokenDefaultsKey = "sdal.push.device_token"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func configure() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorizationAndRegister() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            authorizationStatus = settings.authorizationStatus
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            // Best effort; UI will remain unchanged.
        }
    }

    func syncRegistrationForCurrentSession(isAuthenticated: Bool) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus

        guard isAuthenticated else {
            updateBadgeCount(0)
            return
        }

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
            if let tokenHex = UserDefaults.standard.string(forKey: deviceTokenDefaultsKey) {
                try? await APIClient.shared.registerPushToken(tokenHex)
            }
        default:
            break
        }
    }

    func didRegisterForRemoteNotifications(token: Data) {
        let tokenHex = token.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(tokenHex, forKey: deviceTokenDefaultsKey)
        Task {
            try? await APIClient.shared.registerPushToken(tokenHex)
        }
    }

    func didFailToRegisterForRemoteNotifications() {
        // Keep silent for now; optional telemetry can be added later.
    }

    func handleRemoteNotification(_ userInfo: [AnyHashable: Any], userInitiated: Bool) {
        if let badge = badgeCount(from: userInfo) {
            updateBadgeCount(badge)
        }
        NotificationCenter.default.post(name: .sdalRemoteNotificationReceived, object: nil, userInfo: userInfo)
        if userInitiated {
            AppRouter.shared.handleNotificationPayload(userInfo)
        }
    }

    func updateBadgeCount(_ count: Int) {
        let badgeCount = max(count, 0)
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(badgeCount) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = badgeCount
        }
    }

    private func badgeCount(from userInfo: [AnyHashable: Any]) -> Int? {
        if let badge = userInfo["badge"] as? Int {
            return badge
        }
        if let aps = userInfo["aps"] as? [String: Any] {
            if let badge = aps["badge"] as? Int {
                return badge
            }
            if let badgeString = aps["badge"] as? String {
                return Int(badgeString)
            }
        }
        return nil
    }
}

extension Notification.Name {
    static let sdalRemoteNotificationReceived = Notification.Name("sdalRemoteNotificationReceived")
}

extension PushNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            PushNotificationService.shared.handleRemoteNotification(
                response.notification.request.content.userInfo,
                userInitiated: true
            )
        }
        completionHandler()
    }
}
