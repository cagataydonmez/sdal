import Combine
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var i18n: LocalizationManager

    var body: some View {
        Group {
            if appState.isBootstrapping {
                ProgressView(i18n.t("loading"))
                    .tint(SDALTheme.primary)
            } else if appState.session == nil, !appState.siteAccess.isOpen {
                SiteAccessClosedView(message: appState.siteAccess.message)
            } else if appState.isProfileCompletionRequired {
                NavigationStack {
                    ProfileView(completionRequired: true)
                }
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

private struct SiteAccessClosedView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var i18n: LocalizationManager

    let message: String?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(SDALTheme.secondary)
            Text(i18n.t("site_closed_title"))
                .font(.title3.weight(.bold))
            Text(message?.isEmpty == false ? message! : i18n.t("site_closed_message"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(i18n.t("retry")) {
                Task { await appState.bootstrapSession() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SDALTheme.appBackground.ignoresSafeArea())
    }
}

private struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var i18n: LocalizationManager
    @State private var unreadMessages = 0
    @State private var unreadNotifications = 0
    private let api = APIClient.shared
    private let pushService = PushNotificationService.shared

    var body: some View {
        TabView(selection: $router.selectedTab) {
            FeedView()
                .tabItem { Label(i18n.t("feed"), systemImage: "house.fill") }
                .tag(AppTab.feed)

            ExploreView()
                .tabItem { Label(i18n.t("explore"), systemImage: "person.3.fill") }
                .tag(AppTab.explore)

            NavigationStack {
                SDALMessengerView()
            }
            .tabItem { Label(i18n.t("messenger"), systemImage: "message.fill") }
            .tag(AppTab.messenger)

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

            if unreadNotifications > 0 {
                NotificationsView {
                    unreadNotifications = $0
                    pushService.updateBadgeCount($0)
                }
                    .tabItem { Label(i18n.t("notifications"), systemImage: "bell.fill") }
                    .tag(AppTab.notifications)
                    .badge(unreadNotifications)
            } else {
                NotificationsView {
                    unreadNotifications = $0
                    pushService.updateBadgeCount($0)
                }
                    .tabItem { Label(i18n.t("notifications"), systemImage: "bell.fill") }
                    .tag(AppTab.notifications)
            }

            ProfileView()
                .tabItem { Label(i18n.t("profile"), systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .tint(SDALTheme.primary)
        .task {
            await refreshUnread()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sdalRemoteNotificationReceived)) { _ in
            Task { await refreshUnread() }
        }
    }

    private func refreshUnread() async {
        do { unreadMessages = try await api.fetchUnreadMessagesCount() } catch {}
        do { unreadNotifications = try await api.fetchUnreadNotificationsCount() } catch {}
        pushService.updateBadgeCount(unreadNotifications)
    }
}

private struct NotificationsView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @EnvironmentObject private var router: AppRouter
    @AppStorage("sdal.notifications.quiet_mode") private var quietModeEnabled = false

    @State private var items: [AppNotification] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var offset = 0
    @State private var selectedCategory: NotificationCategoryFilter = .all
    @State private var unreadCount = 0
    @State private var showPreferences = false
    @State private var errorMessage: String?

    let onUnreadCountChange: (Int) -> Void

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
                } else if filteredItems.isEmpty {
                    ScreenEmptyView(
                        title: i18n.t("notifications"),
                        subtitle: i18n.t("notifications_empty"),
                        actionTitle: i18n.t("retry"),
                        action: { Task { await load() } }
                    )
                } else {
                    List {
                        categoryFilterBar
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        ForEach(filteredItems) { n in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    SDALPill(text: notificationCategoryLabel(category(for: n)), tint: SDALTheme.cardAlt, foreground: SDALTheme.ink)
                                    if n.isUnread {
                                        SDALPill(text: i18n.t("new_badge"), tint: SDALTheme.primary.opacity(0.18), foreground: SDALTheme.ink)
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
                                        Button(i18n.t("accept")) { Task { await respondInvite(groupId: groupId, action: "accept") } }
                                            .buttonStyle(.bordered)
                                        Button(i18n.t("reject")) { Task { await respondInvite(groupId: groupId, action: "reject") } }
                                            .buttonStyle(.bordered)
                                    }
                                }
                                if n.type == "group_invite", let status = n.inviteStatus, status != "pending" {
                                    SDALPill(
                                        text: status == "accepted" ? i18n.t("invite_accepted") : i18n.t("invite_rejected"),
                                        tint: status == "accepted" ? SDALTheme.success.opacity(0.15) : SDALTheme.danger.opacity(0.15),
                                        foreground: status == "accepted" ? SDALTheme.success : SDALTheme.danger
                                    )
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(n.isUnread ? SDALTheme.primary.opacity(0.08) : SDALTheme.card.opacity(0.88))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(n.isUnread ? SDALTheme.primary.opacity(0.42) : SDALTheme.line, lineWidth: 1)
                            )
                            .padding(.vertical, 5)
                            .padding(.horizontal, 2)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if n.isUnread {
                                    Button(i18n.t("mark_read")) {
                                        Task { await markNotificationRead(n.id) }
                                    }
                                    .tint(.blue)
                                }
                            }
                            .onAppear {
                                guard n.id == filteredItems.last?.id else { return }
                                Task { await loadMoreIfNeeded() }
                            }
                        }

                        if isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable { await load() }
                }
            }
            .task { if items.isEmpty { await load() } }
            .onReceive(NotificationCenter.default.publisher(for: .sdalRemoteNotificationReceived)) { notification in
                Task { await handleRemoteNotification(notification.userInfo ?? [:]) }
            }
            .navigationTitle(i18n.t("notifications"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(i18n.t("preferences")) {
                        showPreferences = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("mark_all_read")) {
                        Task { await markAllRead() }
                    }
                    .disabled(unreadCount == 0)
                }
            }
            .sheet(isPresented: $showPreferences) {
                NotificationPreferencesSheet(quietModeEnabled: $quietModeEnabled)
            }
            .background(SDALTheme.appBackground.ignoresSafeArea())
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let notifications = try await api.fetchNotifications(category: selectedCategory.apiValue)
            items = notifications
            offset = notifications.count
            hasMore = notifications.count >= 30
            recalculateUnreadCount()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
        if let incoming = AppNotification(pushPayload: userInfo) {
            mergeRemoteNotification(incoming)
        } else {
            await load()
        }
    }

    private func loadMoreIfNeeded() async {
        guard !isLoading, !isLoadingMore, hasMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let more = try await api.fetchNotifications(offset: offset, category: selectedCategory.apiValue)
            if more.isEmpty {
                hasMore = false
            } else {
                items.append(contentsOf: more)
                offset += more.count
                hasMore = more.count >= 30
                recalculateUnreadCount()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markAllRead() async {
        let ids = items.filter(\.isUnread).map(\.id)
        guard !ids.isEmpty else { return }
        do {
            try await api.bulkReadNotifications(ids: ids)
            items = items.map(markReadLocally)
            recalculateUnreadCount()
        } catch {
            // Keep notifications list usable even if read flag update fails.
        }
    }

    private func markNotificationRead(_ id: Int) async {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].isUnread else { return }
        do {
            try await api.markNotificationRead(id: id)
            items[index] = markReadLocally(items[index])
            recalculateUnreadCount()
        } catch {
            errorMessage = error.localizedDescription
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
        Task {
            try? await api.openNotification(id: notification.id)
            await markNotificationRead(notification.id)
        }
        router.handleNotificationPayload([
            "type": notification.type ?? "",
            "entity_id": notification.entityId as Any,
            "source_user_id": notification.sourceUserId as Any
        ])
    }

    private var filteredItems: [AppNotification] {
        if selectedCategory == .all {
            return items
        }
        return items.filter { category(for: $0) == selectedCategory }
    }

    @ViewBuilder
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NotificationCategoryFilter.allCases) { category in
                    Button(notificationCategoryLabel(category)) {
                        guard selectedCategory != category else { return }
                        selectedCategory = category
                        Task { await load() }
                    }
                    .buttonStyle(FeedScopeChipButtonStyle(active: selectedCategory == category))
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func category(for notification: AppNotification) -> NotificationCategoryFilter {
        let type = (notification.type ?? "").lowercased()
        switch type {
        case "like", "comment", "mention_post", "mention_photo", "photo_comment", "follow":
            return .social
        case "mention_message":
            return .messaging
        case "mention_group", "group_join_request", "group_join_approved", "group_join_rejected", "group_invite", "group_invite_accepted", "group_invite_declined", "group_role_changed":
            return .groups
        case "mention_event", "event_comment", "event_invite", "event_response", "event_reminder", "event_starts_soon":
            return .events
        case "connection_request", "connection_accepted", "mentorship_request", "mentorship_accepted", "teacher_network_linked", "teacher_link_review_approved", "teacher_link_review_rejected":
            return .networking
        case "job_application", "job_application_reviewed", "job_application_accepted", "job_application_rejected":
            return .jobs
        default:
            return .system
        }
    }

    private func notificationCategoryLabel(_ category: NotificationCategoryFilter) -> String {
        switch category {
        case .all: return i18n.t("all")
        case .social: return i18n.t("social")
        case .messaging: return i18n.t("messaging")
        case .groups: return i18n.t("groups")
        case .events: return i18n.t("events")
        case .networking: return i18n.t("networking")
        case .jobs: return i18n.t("jobs")
        case .system: return i18n.t("system")
        }
    }

    private func recalculateUnreadCount() {
        unreadCount = items.filter(\.isUnread).count
        onUnreadCountChange(unreadCount)
    }

    private func mergeRemoteNotification(_ incoming: AppNotification) {
        if let existingIndex = items.firstIndex(where: { $0.id == incoming.id }) {
            let merged = items[existingIndex].merged(with: incoming)
            items.remove(at: existingIndex)
            items.insert(merged, at: 0)
        } else {
            items.insert(incoming, at: 0)
            if offset > 0 {
                offset += 1
            }
        }
        recalculateUnreadCount()
    }

    private func markReadLocally(_ notification: AppNotification) -> AppNotification {
        AppNotification(
            id: notification.id,
            type: notification.type,
            entityId: notification.entityId,
            sourceUserId: notification.sourceUserId,
            message: notification.message,
            readAt: ISO8601DateFormatter().string(from: Date()),
            createdAt: notification.createdAt,
            kadi: notification.kadi,
            isim: notification.isim,
            soyisim: notification.soyisim,
            resim: notification.resim,
            verified: notification.verified,
            inviteStatus: notification.inviteStatus
        )
    }
}

private enum NotificationCategoryFilter: String, CaseIterable, Identifiable {
    case all
    case social
    case messaging
    case groups
    case events
    case networking
    case jobs
    case system

    var id: String { rawValue }

    var apiValue: String? {
        self == .all ? nil : rawValue
    }
}

private struct NotificationPreferencesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var i18n: LocalizationManager

    @Binding var quietModeEnabled: Bool

    @State private var preferences: NotificationPreferences?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Toggle(i18n.t("quiet_mode"), isOn: $quietModeEnabled)

                if let preferences {
                    preferenceToggle(i18n.t("social"), current: preferences.socialEnabled ?? true) { value in
                        mutatePreferences { $0.socialEnabled = value }
                    }
                    preferenceToggle(i18n.t("messaging"), current: preferences.messagingEnabled ?? true) { value in
                        mutatePreferences { $0.messagingEnabled = value }
                    }
                    preferenceToggle(i18n.t("groups"), current: preferences.groupsEnabled ?? true) { value in
                        mutatePreferences { $0.groupsEnabled = value }
                    }
                    preferenceToggle(i18n.t("events"), current: preferences.eventsEnabled ?? true) { value in
                        mutatePreferences { $0.eventsEnabled = value }
                    }
                    preferenceToggle(i18n.t("networking"), current: preferences.networkingEnabled ?? true) { value in
                        mutatePreferences { $0.networkingEnabled = value }
                    }
                    preferenceToggle(i18n.t("jobs"), current: preferences.jobsEnabled ?? true) { value in
                        mutatePreferences { $0.jobsEnabled = value }
                    }
                    preferenceToggle(i18n.t("system"), current: preferences.systemEnabled ?? true) { value in
                        mutatePreferences { $0.systemEnabled = value }
                    }
                } else if isLoading {
                    ProgressView(i18n.t("loading"))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(i18n.t("preferences"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(i18n.t("close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? i18n.t("saving") : i18n.t("save")) {
                        Task { await save() }
                    }
                    .disabled(isSaving || preferences == nil)
                }
            }
            .task {
                if preferences == nil {
                    await load()
                }
            }
        }
    }

    private func preferenceToggle(_ title: String, current: Bool, setter: @escaping (Bool) -> Void) -> some View {
        Toggle(title, isOn: Binding(
            get: { current },
            set: { setter($0) }
        ))
    }

    private func mutatePreferences(_ update: (inout NotificationPreferencesDraft) -> Void) {
        guard let current = preferences else { return }
        var draft = NotificationPreferencesDraft(current)
        update(&draft)
        preferences = draft.snapshot
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            preferences = try await api.fetchNotificationPreferences()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        guard let preferences else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await api.updateNotificationPreferences(preferences)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct NotificationPreferencesDraft {
    var socialEnabled: Bool
    var messagingEnabled: Bool
    var groupsEnabled: Bool
    var eventsEnabled: Bool
    var networkingEnabled: Bool
    var jobsEnabled: Bool
    var systemEnabled: Bool

    init(_ preferences: NotificationPreferences) {
        socialEnabled = preferences.socialEnabled ?? true
        messagingEnabled = preferences.messagingEnabled ?? true
        groupsEnabled = preferences.groupsEnabled ?? true
        eventsEnabled = preferences.eventsEnabled ?? true
        networkingEnabled = preferences.networkingEnabled ?? true
        jobsEnabled = preferences.jobsEnabled ?? true
        systemEnabled = preferences.systemEnabled ?? true
    }

    var snapshot: NotificationPreferences {
        NotificationPreferences(
            socialEnabled: socialEnabled,
            messagingEnabled: messagingEnabled,
            groupsEnabled: groupsEnabled,
            eventsEnabled: eventsEnabled,
            networkingEnabled: networkingEnabled,
            jobsEnabled: jobsEnabled,
            systemEnabled: systemEnabled
        )
    }
}
