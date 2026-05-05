import SwiftUI

@main
struct SdalWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager.shared
    @StateObject private var viewModel = WatchViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(viewModel)
                .onAppear {
                    sessionManager.activate()
                }
        }
    }
}
