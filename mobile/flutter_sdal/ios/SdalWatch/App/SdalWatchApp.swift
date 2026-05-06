import SwiftUI
import UserNotifications
import WatchKit

// MARK: - App Delegate

class WatchAppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {

    weak var viewModel: WatchViewModel?
    weak var sessionManager: WatchSessionManager?

    func applicationDidFinishLaunching() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    WKApplication.shared().registerForRemoteNotifications()
                }
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        routeNotification(response.notification.request.content.userInfo)
        completionHandler()
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        guard let vm = viewModel, let sm = sessionManager else {
            // Session not ready yet — store token so it can be registered later
            UserDefaults.standard.set(deviceToken, forKey: "sdal_pending_push_token")
            return
        }
        Task { @MainActor in
            vm.storePushToken(
                deviceToken,
                cookie: sm.sessionCookie,
                baseUrl: sm.apiBaseUrl
            )
        }
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        // Silent failure — push is optional on Watch
    }

    func didReceiveRemoteNotification(
        _ userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (WKBackgroundFetchResult) -> Void
    ) {
        guard let vm = viewModel else {
            completionHandler(.noData)
            return
        }
        Task { @MainActor in
            routeNotification(userInfo)
            completionHandler(.newData)
        }
    }

    @MainActor
    private func routeNotification(_ userInfo: [AnyHashable: Any]) {
        guard let vm = viewModel else { return }
        let type = String(describing: userInfo["type"] ?? "")
        let route = String(describing: userInfo["route"] ?? "")
        let notificationId = intValue(userInfo["notificationId"])
        if type == "message", let tid = intValue(userInfo["thread_id"] ?? userInfo["threadId"]) {
            vm.deepLinkTarget = .thread(tid)
        } else if let pid = intValue(userInfo["post_id"] ?? userInfo["postId"]) {
            vm.deepLinkTarget = .post(pid)
        } else if route.contains("/posts/"),
                  let last = route.split(separator: "/").last,
                  let postId = Int(last) {
            vm.deepLinkTarget = .post(postId)
        } else if notificationId != nil || !type.isEmpty {
            vm.deepLinkTarget = .notifications
        }
    }

    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let string = value as? String { return Int(string) }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}

// MARK: - App

@main
struct SdalWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var appDelegate

    @StateObject private var sessionManager = WatchSessionManager.shared
    @StateObject private var viewModel = WatchViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(viewModel)
                .onAppear {
                    sessionManager.activate()
                    appDelegate.viewModel   = viewModel
                    appDelegate.sessionManager = sessionManager
                    // Register any push token that arrived before onAppear
                    if let data = UserDefaults.standard.data(forKey: "sdal_pending_push_token") {
                        UserDefaults.standard.removeObject(forKey: "sdal_pending_push_token")
                        viewModel.storePushToken(
                            data,
                            cookie: sessionManager.sessionCookie,
                            baseUrl: sessionManager.apiBaseUrl
                        )
                    }
                }
                .onChange(of: sessionManager.sessionCookie) { cookie in
                    guard !cookie.isEmpty else { return }
                    // Session just became available — register pending push token
                    viewModel.registerPendingTokenIfNeeded(
                        cookie: cookie,
                        baseUrl: sessionManager.apiBaseUrl
                    )
                }
        }
    }
}
