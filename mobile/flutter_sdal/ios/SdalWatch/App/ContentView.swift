import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @EnvironmentObject private var viewModel: WatchViewModel

    var body: some View {
        if sessionManager.sessionCookie.isEmpty {
            UnauthenticatedView()
        } else {
            MainTabView()
                .task(id: sessionManager.sessionCookie) {
                    let cookie  = sessionManager.sessionCookie
                    let baseUrl = sessionManager.apiBaseUrl
                    await viewModel.loadAll(cookie: cookie, baseUrl: baseUrl)
                    viewModel.requestPushPermission()
                    viewModel.startAutoRefresh(cookie: cookie, baseUrl: baseUrl)
                }
        }
    }
}

// MARK: - Unauthenticated

private struct UnauthenticatedView: View {
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @State private var isRetrying = false

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
            Button {
                isRetrying = true
                sessionManager.requestContext()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isRetrying = false
                }
            } label: {
                if isRetrying {
                    ProgressView()
                        .frame(width: 16, height: 16)
                } else {
                    Text("Yenile")
                }
            }
            .buttonStyle(.borderedProminent)
            .font(.caption2)
        }
        .padding()
        // Auto-retry every 5 seconds while waiting
        .task {
            while sessionManager.sessionCookie.isEmpty {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                sessionManager.requestContext()
            }
        }
    }
}

// MARK: - Main Tab View

private struct MainTabView: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                FeedView()
            }
            .tag(0)
            .tabItem {
                Image(systemName: "newspaper.fill")
                Text("Akış")
            }

            NavigationStack {
                ExploreView()
            }
            .tag(1)
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Keşfet")
            }

            NavigationStack {
                MessagesView()
            }
            .tag(2)
            .tabItem {
                Image(systemName: "message.fill")
                Text(tabTitle("Mesajlar", count: viewModel.unreadMessageCount))
            }

            NavigationStack {
                NotificationsView()
            }
            .tag(3)
            .tabItem {
                Image(systemName: "bell.fill")
                Text(tabTitle("Bildirimler", count: viewModel.unreadNotificationCount))
            }
        }
        .onChange(of: viewModel.deepLinkTarget) { target in
            guard let target else { return }
            switch target {
            case .thread:       selectedTab = 2
            case .notifications: selectedTab = 3
            case .post, .member: selectedTab = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.deepLinkTarget = nil
            }
        }
    }

    private func tabTitle(_ title: String, count: Int) -> String {
        count > 0 ? "\(title) \(min(count, 99))" : title
    }
}
