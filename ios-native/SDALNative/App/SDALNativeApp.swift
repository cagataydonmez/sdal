import SwiftUI

@main
struct SDALNativeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var pushService = PushNotificationService.shared
    @StateObject private var router = AppRouter.shared
    @StateObject private var i18n = LocalizationManager.shared
    @StateObject private var theme = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(pushService)
                .environmentObject(router)
                .environmentObject(i18n)
                .environmentObject(theme)
                .environment(\.font, SDALTypography.body)
                .preferredColorScheme(theme.preferredColorScheme)
                .fontDesign(.rounded)
                .task {
                    await pushService.configure()
                }
        }
    }
}
