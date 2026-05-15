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
        VStack(spacing: 10) {
            Image(sessionManager.logoImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11))

            Text("SDAL")
                .font(.headline)
                .fontWeight(.bold)

            Text("iPhone'da SDAL'ı aç")
                .font(.system(size: 12))
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
                    ProgressView().frame(width: 14, height: 14)
                } else {
                    Text("Bağlan")
                }
            }
            .buttonStyle(.borderedProminent)
            .font(.system(size: 12, weight: .semibold))
        }
        .padding()
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

    private let tabs: [(icon: String, label: String)] = [
        ("newspaper.fill",   "Akış"),
        ("megaphone.fill",   "Topluluk"),
        ("message.fill",     "Mesajlar"),
        ("bell.fill",        "Bildirimler"),
        ("magnifyingglass",  "Keşfet"),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Content ───────────────────────────────────────────────────
            ZStack {
                NavigationStack { FeedView() }
                    .opacity(selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 0)

                NavigationStack { CommunityView() }
                    .opacity(selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 1)

                NavigationStack { MessagesView() }
                    .opacity(selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 2)

                NavigationStack { NotificationsView() }
                    .opacity(selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 3)

                NavigationStack { ExploreView() }
                    .opacity(selectedTab == 4 ? 1 : 0)
                    .allowsHitTesting(selectedTab == 4)
            }
            .padding(.bottom, 50)

            // ── Custom Tab Bar ────────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    tabButton(index: index)
                }
            }
            .frame(height: 50)
            .background {
                if #available(watchOS 10.0, *) {
                    Rectangle().fill(.ultraThinMaterial)
                } else {
                    Rectangle().fill(Color.black.opacity(0.85))
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: viewModel.deepLinkTarget) { target in
            guard let target else { return }
            switch target {
            case .thread:        selectedTab = 2
            case .notifications: selectedTab = 3
            case .post, .member: selectedTab = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                viewModel.deepLinkTarget = nil
            }
        }
    }

    @ViewBuilder
    private func tabButton(index: Int) -> some View {
        let tab    = tabs[index]
        let active = selectedTab == index
        let badge  = badgeCount(for: index)

        Button {
            selectedTab = index
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 3) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: active ? .bold : .regular))
                        .foregroundStyle(active ? Color.accentColor : Color.primary.opacity(0.38))
                        .scaleEffect(active ? 1.12 : 1.0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: active)

                    Text(tab.label)
                        .font(.system(size: 8, weight: active ? .semibold : .regular))
                        .foregroundStyle(active ? Color.accentColor : Color.primary.opacity(0.38))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if badge > 0 {
                    Text("\(min(badge, 9))+")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.accentColor, in: Capsule())
                        .offset(x: -4, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func badgeCount(for index: Int) -> Int {
        switch index {
        case 2: return viewModel.unreadMessageCount
        case 3: return viewModel.unreadNotificationCount
        default: return 0
        }
    }
}
