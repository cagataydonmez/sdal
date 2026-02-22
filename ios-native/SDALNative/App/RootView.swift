import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var i18n: LocalizationManager

    var body: some View {
        Group {
            if appState.isBootstrapping {
                ProgressView(i18n.t("loading"))
                    .tint(SDALTheme.primary)
            } else if appState.session != nil {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            await appState.bootstrapSession()
        }
        .background(SDALTheme.appBackground.ignoresSafeArea())
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var i18n: LocalizationManager
    @State private var unreadMessages = 0
    private let api = APIClient.shared

    var body: some View {
        TabView(selection: $router.selectedTab) {
            FeedView()
                .tabItem { Label(i18n.t("feed"), systemImage: "house.fill") }
                .tag(AppTab.feed)

            ExploreView()
                .tabItem { Label(i18n.t("explore"), systemImage: "person.3.fill") }
                .tag(AppTab.explore)

            if unreadMessages > 0 {
                MessagesView()
                    .tabItem { Label(i18n.t("messages"), systemImage: "bubble.left.and.bubble.right.fill") }
                    .tag(AppTab.messages)
                    .badge(unreadMessages)
            } else {
                MessagesView()
                    .tabItem { Label(i18n.t("messages"), systemImage: "bubble.left.and.bubble.right.fill") }
                    .tag(AppTab.messages)
            }

            NotificationsView()
                .tabItem { Label(i18n.t("notifications"), systemImage: "bell.fill") }
                .tag(AppTab.notifications)

            ProfileView()
                .tabItem { Label(i18n.t("profile"), systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .tint(SDALTheme.primary)
        .task {
            await refreshUnread()
        }
    }

    private func refreshUnread() async {
        do { unreadMessages = try await api.fetchUnreadMessagesCount() } catch {}
    }
}

private struct NotificationsView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @EnvironmentObject private var router: AppRouter

    @State private var items: [AppNotification] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(i18n.t("loading_notifications"))
                                .font(.headline)
                            SDALSkeletonLines(rows: 5)
                        }
                    }
                    .padding(16)
                } else if let errorMessage, items.isEmpty {
                    ScreenErrorView(message: errorMessage) { Task { await load() } }
                } else if items.isEmpty {
                    ScreenEmptyView(
                        title: i18n.t("notifications"),
                        subtitle: i18n.t("notifications_empty"),
                        actionTitle: "Reload",
                        action: { Task { await load() } }
                    )
                } else {
                    List(items) { n in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                SDALPill(text: notificationTypeLabel(n.type), tint: SDALTheme.cardAlt, foreground: SDALTheme.ink)
                                if n.readAt == nil || n.readAt?.isEmpty == true {
                                    SDALPill(text: "New", tint: SDALTheme.primary.opacity(0.18), foreground: SDALTheme.ink)
                                }
                                Spacer()
                                Text(n.createdAt ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Button {
                                openNotification(n)
                            } label: {
                                HStack(spacing: 12) {
                                    AsyncAvatarView(imageName: n.resim, size: 42)
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack(spacing: 6) {
                                            Text("@\(n.kadi ?? "user")")
                                                .font(.subheadline.weight(.semibold))
                                            if n.verified == true {
                                                Image(systemName: "checkmark.seal.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(SDALTheme.accent)
                                            }
                                        }
                                        Text(n.message ?? "")
                                            .font(.subheadline)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            if n.type == "group_invite", n.inviteStatus == "pending", let groupId = n.entityId {
                                HStack(spacing: 8) {
                                    Button("Accept") { Task { await respondInvite(groupId: groupId, action: "accept") } }
                                        .buttonStyle(.bordered)
                                    Button("Reject") { Task { await respondInvite(groupId: groupId, action: "reject") } }
                                        .buttonStyle(.bordered)
                                }
                            }
                            if n.type == "group_invite", let status = n.inviteStatus, status != "pending" {
                                SDALPill(
                                    text: status == "accepted" ? "Invite accepted" : "Invite rejected",
                                    tint: status == "accepted" ? SDALTheme.success.opacity(0.15) : SDALTheme.danger.opacity(0.15),
                                    foreground: status == "accepted" ? SDALTheme.success : SDALTheme.danger
                                )
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill((n.readAt == nil || n.readAt?.isEmpty == true) ? SDALTheme.primary.opacity(0.08) : SDALTheme.card.opacity(0.88))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke((n.readAt == nil || n.readAt?.isEmpty == true) ? SDALTheme.primary.opacity(0.42) : SDALTheme.line, lineWidth: 1)
                        )
                        .padding(.vertical, 5)
                        .padding(.horizontal, 2)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await load() }
                }
            }
            .task { if items.isEmpty { await load() } }
            .navigationTitle(i18n.t("notifications"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark all read") {
                        Task { await markAllRead() }
                    }
                    .disabled(items.isEmpty)
                }
            }
            .background(SDALTheme.appBackground.ignoresSafeArea())
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await api.fetchNotifications()
            await markAllRead()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markAllRead() async {
        do {
            try await api.markNotificationsRead()
        } catch {
            // Keep notifications list usable even if read flag update fails.
        }
    }

    private func respondInvite(groupId: Int, action: String) async {
        do {
            try await api.respondGroupInvite(groupId: groupId, action: action)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openNotification(_ notification: AppNotification) {
        if let path = notificationTargetPath(notification) {
            router.handleNotificationPayload(["path": path])
        } else {
            router.selectedTab = .feed
        }
    }

    private func notificationTargetPath(_ n: AppNotification) -> String? {
        let type = (n.type ?? "").lowercased()
        if ["like", "comment", "mention_post"].contains(type), let id = n.entityId {
            return "/new?post=\(id)"
        }
        if ["event_comment", "event_invite", "mention_event"].contains(type) {
            return "/new/events"
        }
        if ["mention_group", "group_join_request", "group_join_approved", "group_join_rejected", "group_invite"].contains(type),
           let id = n.entityId {
            return "/new/groups/\(id)"
        }
        if ["mention_photo", "photo_comment"].contains(type), let id = n.entityId {
            return "/new/albums/photo/\(id)"
        }
        if type == "mention_message", let id = n.entityId {
            return "/new/messages/\(id)"
        }
        if type == "follow", let id = n.sourceUserId {
            return "/new/members/\(id)"
        }
        return "/new"
    }

    private func notificationTypeLabel(_ raw: String?) -> String {
        switch (raw ?? "").lowercased() {
        case "like": return "Like"
        case "comment": return "Comment"
        case "follow": return "Follow"
        case "mention_post", "mention_message", "mention_photo", "mention_group", "mention_event": return "Mention"
        case "group_invite", "group_join_request", "group_join_approved", "group_join_rejected": return "Group"
        case "event_comment", "event_invite": return "Event"
        case "photo_comment": return "Album"
        default: return "Update"
        }
    }
}
