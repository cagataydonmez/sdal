import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case feed = "Feed"
    case messages = "Messages"
    case members = "Members"
    case groups = "Groups"
    case events = "Events"
    case stories = "Stories"
    case jobs = "Jobs"
    case announcements = "Announcements"
    case notifications = "Notifications"
    case profile = "Profile"
    case admin = "Admin"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .feed: return "text.bubble"
        case .messages: return "message"
        case .members: return "person.2"
        case .groups: return "person.3"
        case .events: return "calendar"
        case .stories: return "camera"
        case .jobs: return "briefcase"
        case .announcements: return "megaphone"
        case .notifications: return "bell"
        case .profile: return "person.crop.circle"
        case .admin: return "gearshape.2"
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: SidebarItem? = .feed
    @State private var notificationsVM = NotificationsViewModel()
    @State private var messengerVM = MessengerViewModel()

    private let auth = AuthService.shared

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .task {
            await notificationsVM.loadUnreadCount()
            notificationsVM.startPolling()
        }
        .onDisappear { notificationsVM.stopPolling() }
        .onReceive(NotificationCenter.default.publisher(for: .navigate)) { notif in
            if let item = notif.object as? SidebarItem {
                selectedItem = item
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        List(selection: $selectedItem) {
            Section("Main") {
                sidebarRow(.feed)
                sidebarRow(.messages, badge: unreadMessages)
                sidebarRow(.members)
            }

            Section("Community") {
                sidebarRow(.groups)
                sidebarRow(.events)
                sidebarRow(.stories)
                sidebarRow(.jobs)
                sidebarRow(.announcements)
            }

            Section {
                sidebarRow(.notifications, badge: notificationsVM.unreadCount)
                sidebarRow(.profile)
            }

            if auth.currentUser?.isAdmin == true {
                Section {
                    sidebarRow(.admin)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            userFooter
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }

    private func sidebarRow(_ item: SidebarItem, badge: Int = 0) -> some View {
        Label {
            HStack {
                Text(item.rawValue)
                Spacer()
                if badge > 0 {
                    SidebarBadge(count: badge)
                }
            }
        } icon: {
            Image(systemName: item.icon)
        }
        .tag(item)
    }

    private var unreadMessages: Int {
        messengerVM.threads.reduce(0) { $0 + ($1.unreadCount ?? 0) }
    }

    private var userFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                AvatarView(
                    url: auth.currentUser?.photoURL,
                    initials: auth.currentUser?.initials ?? "?",
                    size: 28,
                    isOnline: true
                )

                VStack(alignment: .leading, spacing: 1) {
                    Text(auth.currentUser?.displayName ?? "User")
                        .font(.caption).fontWeight(.medium).lineLimit(1)
                    Text("@\(auth.currentUser?.kadi ?? "")")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }

                Spacer()

                Button { Task { await auth.logout() } } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Sign out")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .feed:
            FeedView()
        case .messages:
            MessengerView()
        case .members:
            MembersView()
        case .groups:
            GroupsView()
        case .events:
            EventsView()
        case .stories:
            StoriesView()
        case .jobs:
            JobsView()
        case .announcements:
            AnnouncementsView()
        case .notifications:
            NotificationsView()
        case .profile:
            ProfileView()
        case .admin:
            AdminView()
        case nil:
            EmptyStateView(
                icon: "sidebar.leading",
                title: "Welcome to SDAL",
                message: "Select a section from the sidebar to get started."
            )
        }
    }
}
