import Foundation
import UserNotifications
import UIKit

@MainActor
final class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

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

    func didRegisterForRemoteNotifications(token: Data) {
        let tokenHex = token.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            try? await APIClient.shared.registerPushToken(tokenHex)
        }
    }

    func didFailToRegisterForRemoteNotifications() {
        // Keep silent for now; optional telemetry can be added later.
    }
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
            AppRouter.shared.handleNotificationPayload(response.notification.request.content.userInfo)
        }
        completionHandler()
    }
}
