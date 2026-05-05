import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @EnvironmentObject private var viewModel: WatchViewModel

    var body: some View {
        if sessionManager.sessionCookie.isEmpty {
            UnauthenticatedView()
        } else {
            MainTabView()
                .task {
                    await viewModel.loadAll(
                        cookie: sessionManager.sessionCookie,
                        baseUrl: sessionManager.apiBaseUrl
                    )
                }
        }
    }
}

private struct UnauthenticatedView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("SDAL")
                .font(.headline)
            Text("iPhone'da SDAL'ı aç")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Yenile") {
                sessionManager.requestContext()
            }
            .buttonStyle(.borderedProminent)
            .font(.caption2)
        }
        .padding()
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Label("Feed", systemImage: "newspaper")
                }
            MessagesView()
                .tabItem {
                    Label("Mesajlar", systemImage: "bubble.left.and.bubble.right")
                }
            NotificationsView()
                .tabItem {
                    Label("Bildirimler", systemImage: "bell")
                }
        }
    }
}
