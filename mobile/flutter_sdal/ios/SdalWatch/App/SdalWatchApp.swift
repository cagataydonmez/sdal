import SwiftUI
import UserNotifications
import WatchKit

// MARK: - App Delegate

class WatchAppDelegate: NSObject, WKApplicationDelegate {

    weak var viewModel: WatchViewModel?
    weak var sessionManager: WatchSessionManager?

    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    WKApplication.shared().registerForRemoteNotifications()
                }
            }
        }
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
            if let type = userInfo["type"] as? String {
                switch type {
                case "message":
                    if let tid = userInfo["thread_id"] as? Int {
                        vm.deepLinkTarget = .thread(tid)
                    }
                case "like", "comment", "mention":
                    if let pid = userInfo["post_id"] as? Int {
                        vm.deepLinkTarget = .post(pid)
                    }
                default:
                    vm.deepLinkTarget = .notifications
                }
            }
            completionHandler(.newData)
        }
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
