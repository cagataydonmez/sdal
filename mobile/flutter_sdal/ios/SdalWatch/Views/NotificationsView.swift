import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    private var cookie:  String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    var body: some View {
        Group {
            switch viewModel.notificationsState {
            case .idle, .loading:
                LoadingView()
            case .failed(let msg):
                ErrorRetryView(message: msg) {
                    Task { await viewModel.loadNotifications(cookie: cookie, baseUrl: baseUrl) }
                }
            case .loaded(let items):
                if items.isEmpty {
                    emptyView
                } else {
                    notificationList(items)
                }
            }
        }
        .navigationTitle("Bildirimler")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                let unread = viewModel.unreadNotificationCount
                if unread > 0 {
                    Button("Tümünü oku") {
                        Task { await viewModel.markAllNotificationsRead(cookie: cookie, baseUrl: baseUrl) }
                    }
                    .font(.system(size: 10))
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash").foregroundStyle(.secondary)
            Text("Bildirim yok").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func notificationList(_ items: [WatchNotificationItem]) -> some View {
        List(items) { item in
            NavigationLink(destination: NotificationDetailView(item: item)) {
                NotificationRow(item: item)
            }
            .onAppear {
                if !item.isRead {
                    Task { await viewModel.markNotificationRead(id: item.id, cookie: cookie, baseUrl: baseUrl) }
                }
            }
        }
        .listStyle(.carousel)
        .refreshable {
            await viewModel.loadNotifications(cookie: cookie, baseUrl: baseUrl)
        }
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let item: WatchNotificationItem

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(initials: item.initials, photoUrl: item.actorPhoto, size: 28)
                Image(systemName: item.systemImageName)
                    .font(.system(size: 9))
                    .padding(2)
                    .background(notifColor)
                    .clipShape(Circle())
                    .offset(x: 2, y: 2)
            }
            VStack(alignment: .leading, spacing: 2) {
                if !item.actorName.isEmpty {
                    Text(item.actorName)
                        .font(.caption2)
                        .fontWeight(item.isRead ? .regular : .semibold)
                        .lineLimit(1)
                }
                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            if !item.isRead {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 2)
        .opacity(item.isRead ? 0.75 : 1.0)
    }

    private var notifColor: Color {
        switch item.type {
        case "like":    return .red
        case "comment": return .blue
        case "follow":  return .green
        case "mention": return .orange
        case "message": return .blue
        default:        return .gray
        }
    }
}

// MARK: - Notification Detail

struct NotificationDetailView: View {
    let item: WatchNotificationItem

    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // ── Actor ────────────────────────────────────────────────
                AvatarView(initials: item.initials, photoUrl: item.actorPhoto, size: 44)
                if !item.actorName.isEmpty {
                    Text(item.actorName)
                        .font(.caption2).fontWeight(.semibold)
                        .lineLimit(2).multilineTextAlignment(.center)
                }

                // ── Type label ───────────────────────────────────────────
                HStack(spacing: 6) {
                    Image(systemName: item.systemImageName)
                        .foregroundStyle(typeColor)
                    Text(typeLabel)
                        .font(.caption2).foregroundStyle(.secondary)
                }

                // ── Body ─────────────────────────────────────────────────
                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .lineLimit(5)
                }

                // ── Target image (e.g. the liked post image) ─────────────
                if !item.targetImageUrl.isEmpty {
                    AsyncImage(url: resolvedMediaURL(item.targetImageUrl, baseUrl: sessionManager.apiBaseUrl)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        case .failure:
                            EmptyView()
                        default:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 80)
                                .overlay(ProgressView().scaleEffect(0.7))
                        }
                    }
                }

                // ── Timestamp ────────────────────────────────────────────
                if !item.createdAt.isEmpty {
                    Text(relativeTime(item.createdAt))
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                }

                // ── Navigate to target ───────────────────────────────────
                if item.targetId > 0 {
                    targetNavigationButton
                }
            }
            .padding()
        }
        .navigationTitle("Bildirim")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var targetNavigationButton: some View {
        switch item.targetType {
        case "post":
            NavigationLink(destination: PostDetailView(postId: item.targetId)) {
                Label("Gönderiyi gör", systemImage: "newspaper")
                    .font(.caption2)
            }
            .buttonStyle(.borderedProminent)
        case "thread":
            if let thread = findThread() {
                NavigationLink(destination: ConversationView(thread: thread)) {
                    Label("Mesaja git", systemImage: "bubble.left")
                        .font(.caption2)
                }
                .buttonStyle(.borderedProminent)
            }
        default:
            EmptyView()
        }
    }

    private func findThread() -> WatchThread? {
        viewModel.threadsState.value?.first { $0.id == item.targetId }
    }

    private var typeLabel: String {
        switch item.type {
        case "like":    return "Gönderinizi beğendi"
        case "comment": return "Yorum yaptı"
        case "follow":  return "Sizi takip ediyor"
        case "mention": return "Sizi bahsetti"
        case "message": return "Mesaj gönderdi"
        default:        return "Bildirim"
        }
    }

    private var typeColor: Color {
        switch item.type {
        case "like":    return .red
        case "comment": return .blue
        case "follow":  return .green
        case "mention": return .orange
        case "message": return .blue
        default:        return .gray
        }
    }
}
