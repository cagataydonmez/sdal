import SwiftUI
import PhotosUI
import UIKit

private enum FeedSidePanel: String, CaseIterable, Identifiable {
    case notifications
    case livechat
    case online
    case messages
    case quick

    var id: String { rawValue }
}

struct FeedView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var i18n: LocalizationManager
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var posts: [FeedPost] = []
    @State private var pendingPosts: [FeedPost]?
    @State private var pendingPostsCount = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sheet: AppCommunityDestination?
    @State private var scope = "all"
    @State private var postCommentsTarget: FeedPost?
    @State private var editingPost: FeedPost?
    @State private var feedScrollOffset: CGFloat = 0
    @State private var sidePanel: FeedSidePanel = .notifications

    @State private var notifications: [AppNotification] = []
    @State private var unreadMessages = 0
    @State private var onlineMembers: [MemberSummary] = []
    @State private var chatMessages: [ChatMessage] = []
    @State private var chatDraft = ""
    @State private var quickAccessUsers: [MemberSummary] = []
    @State private var feedbackText: String?
    @State private var feedbackIsError = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && posts.isEmpty {
                    ProgressView(i18n.t("loading_feed"))
                } else if let errorMessage, posts.isEmpty {
                    ScreenErrorView(message: errorMessage) { Task { await load() } }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: FeedScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("feedScroll")).minY)
                            }
                            .frame(height: 0)

                            StoryBarView()

                            PostComposerView {
                                await load()
                            }

                            if pendingPostsCount > 0 {
                                Button {
                                    applyPendingPosts()
                                } label: {
                                    Label(
                                        String(format: i18n.t("new_posts_label"), pendingPostsCount),
                                        systemImage: "arrow.clockwise.circle.fill"
                                    )
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            if !quickAccessUsers.isEmpty && !isCompact {
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Quick Access")
                                            .font(.headline)
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(quickAccessUsers) { member in
                                                    HStack(spacing: 6) {
                                                        AsyncAvatarView(imageName: member.resim, size: 22)
                                                        Text("@\(member.kadi ?? "uye")")
                                                            .font(.caption)
                                                        Button {
                                                            Task { await removeQuickAccess(member.id) }
                                                        } label: {
                                                            Image(systemName: "xmark.circle.fill")
                                                                .font(.caption)
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 6)
                                                    .background(SDALTheme.softPanel)
                                                    .clipShape(Capsule())
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            FeedSidePanelsView(
                                sidePanel: $sidePanel,
                                notifications: notifications,
                                unreadMessages: unreadMessages,
                                onlineMembers: onlineMembers,
                                chatMessages: chatMessages,
                                quickAccessUsers: quickAccessUsers,
                                chatDraft: $chatDraft,
                                isCompact: isCompact,
                                onNotificationTap: { item in
                                    openNotification(item)
                                },
                                onOpenMessages: {
                                    router.selectedTab = .messages
                                },
                                onOpenExplore: {
                                    router.selectedTab = .explore
                                },
                                onSendChat: {
                                    Task { await sendFeedChat() }
                                }
                            )

                            HStack(spacing: 8) {
                                scopeChip(title: i18n.t("all"), value: "all")
                                scopeChip(title: i18n.t("following"), value: "following")
                                scopeChip(title: i18n.t("popular"), value: "popular")
                            }

                            ForEach(posts) { post in
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 10) {
                                            AsyncAvatarView(imageName: post.author?.resim, size: 42)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("@\(post.author?.kadi ?? "uye")")
                                                    .font(.subheadline.bold())
                                                Text(post.createdAt ?? "")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        if let content = post.content, !content.isEmpty {
                                            Text(content)
                                                .font(.body)
                                        }

                                        if let imagePath = post.image,
                                           let url = AppConfig.absoluteURL(path: imagePath) {
                                            CachedRemoteImage(
                                                url: url,
                                                targetSize: CGSize(width: UIScreen.main.bounds.width - 32, height: 320)
                                            ) { image in
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                        .fill(SDALTheme.softPanel)
                                                    image
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(maxWidth: .infinity, maxHeight: 320)
                                                        .clipped()
                                                }
                                                .frame(maxWidth: .infinity)
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            } placeholder: {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(SDALTheme.softPanel)
                                                    .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 320)
                                            }
                                        }

                                        HStack(spacing: 14) {
                                            Button {
                                                Task { await toggleLike(post.id) }
                                            } label: {
                                                Label("\(post.likeCount ?? 0)", systemImage: post.liked == true ? "heart.fill" : "heart")
                                            }
                                            .buttonStyle(PressableActionButtonStyle(active: post.liked == true))
                                            Button {
                                                postCommentsTarget = post
                                            } label: {
                                                Label("\(post.commentCount ?? 0)", systemImage: "bubble.left")
                                            }
                                            .buttonStyle(PressableActionButtonStyle(active: false))
                                        }
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                                .contextMenu {
                                    if appState.session?.id == post.author?.id {
                                        Button("Edit") { editingPost = post }
                                        Button("Delete", role: .destructive) { Task { await deletePost(post.id) } }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .coordinateSpace(name: "feedScroll")
                    .refreshable { await load() }
                }
            }
            .task { if posts.isEmpty { await load() } }
            .task {
                await loadPanels()
            }
            .task {
                await runFeedAutoRefresh()
            }
            .onPreferenceChange(FeedScrollOffsetPreferenceKey.self) { value in
                feedScrollOffset = value
            }
            .navigationTitle(i18n.t("feed"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(i18n.t("events")) { sheet = .events }
                        Button(i18n.t("announcements")) { sheet = .announcements }
                        Button(i18n.t("groups")) { sheet = .groups }
                        Button(i18n.t("games")) { sheet = .games }
                    } label: {
                        Image(systemName: "square.grid.2x2")
                    }
                }
            }
            .sheet(item: $sheet) { destination in
                switch destination {
                case .events: EventsHubView()
                case .announcements: AnnouncementsHubView()
                case .groups: GroupsHubView()
                case .games: GamesHubView()
                }
            }
            .onChange(of: router.openCommunityDestination) { _, destination in
                guard let destination else { return }
                sheet = destination
                router.openCommunityDestination = nil
            }
            .sheet(item: $postCommentsTarget) { post in
                PostCommentsSheet(post: post)
            }
            .sheet(item: $editingPost) { post in
                EditPostSheet(post: post) {
                    editingPost = nil
                    Task { await load() }
                }
            }
            .overlay(alignment: .top) {
                if let feedbackText {
                    GlobalActionFeedbackChip(message: feedbackText, isError: feedbackIsError)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: feedbackText != nil)
            .background(SDALTheme.appBackground.ignoresSafeArea())
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let postsReq = api.fetchFeed(scope: scope)
            async let quickReq = api.fetchQuickAccessUsers()
            let rows = try await postsReq
            quickAccessUsers = (try? await quickReq) ?? []
            posts = filterFeedRows(rows)
            pendingPosts = nil
            pendingPostsCount = 0
        } catch {
            if posts.isEmpty {
                errorMessage = error.localizedDescription
            } else {
                showFeedback(error.localizedDescription, isError: true)
            }
        }
    }

    private func removeQuickAccess(_ userId: Int) async {
        do {
            try await api.removeQuickAccessUser(id: userId)
            quickAccessUsers.removeAll { $0.id == userId }
            showFeedback(i18n.t("removed_from_quick_access"))
        } catch {
            showFeedback(error.localizedDescription, isError: true)
        }
    }

    private func toggleLike(_ postId: Int) async {
        do {
            _ = try await api.togglePostLike(id: postId)
            posts = filterFeedRows(try await api.fetchFeed(scope: scope))
            showFeedback(i18n.t("reaction_updated"))
        } catch {
            showFeedback(error.localizedDescription, isError: true)
        }
    }

    private func deletePost(_ postId: Int) async {
        do {
            try await api.deletePost(id: postId)
            posts.removeAll { $0.id == postId }
            showFeedback(i18n.t("post_deleted"))
        } catch {
            showFeedback(error.localizedDescription, isError: true)
        }
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var isReadingOldFeed: Bool {
        feedScrollOffset < -140
    }

    private func runFeedAutoRefresh() async {
        while !Task.isCancelled {
            do {
                let latest = filterFeedRows(try await api.fetchFeed(scope: scope))
                await MainActor.run {
                    consumeRefreshedPosts(latest)
                }
                await loadPanels()
            } catch {
                await MainActor.run {
                    if posts.isEmpty {
                        errorMessage = error.localizedDescription
                    } else {
                        showFeedback(error.localizedDescription, isError: true)
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 7_000_000_000)
        }
    }

    private func consumeRefreshedPosts(_ latest: [FeedPost]) {
        let existing = Dictionary(uniqueKeysWithValues: posts.map { ($0.id, $0) })
        let hasNew = latest.contains { existing[$0.id] == nil }
        if hasNew && isReadingOldFeed {
            pendingPosts = latest
            pendingPostsCount = latest.filter { existing[$0.id] == nil }.count
            return
        }
        posts = latest
        pendingPosts = nil
        pendingPostsCount = 0
    }

    private func filterFeedRows(_ rows: [FeedPost]) -> [FeedPost] {
        guard scope == "following" || scope == "popular",
              let myId = appState.session?.id else { return rows }
        return rows.filter { $0.author?.id != myId }
    }

    private func applyPendingPosts() {
        guard let pendingPosts else { return }
        posts = pendingPosts
        self.pendingPosts = nil
        pendingPostsCount = 0
    }

    private func loadPanels() async {
        async let notifReq = api.fetchNotifications(limit: 3, offset: 0)
        async let unreadReq = api.fetchUnreadMessagesCount()
        async let onlineReq = api.fetchOnlineMembers(limit: 10)
        async let chatReq = api.fetchChatMessages(limit: 10)
        notifications = (try? await notifReq) ?? notifications
        unreadMessages = (try? await unreadReq) ?? unreadMessages
        onlineMembers = (try? await onlineReq) ?? onlineMembers
        chatMessages = (try? await chatReq) ?? chatMessages
    }

    private func sendFeedChat() async {
        let text = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            _ = try await api.sendChatMessage(message: text)
            chatDraft = ""
            chatMessages = (try? await api.fetchChatMessages(limit: 10)) ?? chatMessages
            showFeedback(i18n.t("message_sent"))
        } catch {
            showFeedback(error.localizedDescription, isError: true)
        }
    }

    private func showFeedback(_ text: String, isError: Bool = false) {
        withAnimation(.easeInOut(duration: 0.20)) {
            feedbackText = text
            feedbackIsError = isError
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            await MainActor.run {
                if feedbackText == text {
                    withAnimation(.easeInOut(duration: 0.20)) {
                        feedbackText = nil
                    }
                }
            }
        }
    }

    private func scopeChip(title: String, value: String) -> some View {
        Button(title) {
            guard scope != value else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                scope = value
            }
            Task { await load() }
        }
        .buttonStyle(FeedScopeChipButtonStyle(active: scope == value))
    }

    private func openNotification(_ n: AppNotification) {
        if let path = notificationTargetPath(n) {
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
}

private struct FeedSidePanelsView: View {
    @EnvironmentObject private var i18n: LocalizationManager

    @Binding var sidePanel: FeedSidePanel
    let notifications: [AppNotification]
    let unreadMessages: Int
    let onlineMembers: [MemberSummary]
    let chatMessages: [ChatMessage]
    let quickAccessUsers: [MemberSummary]
    @Binding var chatDraft: String
    let isCompact: Bool
    let onNotificationTap: (AppNotification) -> Void
    let onOpenMessages: () -> Void
    let onOpenExplore: () -> Void
    let onSendChat: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                if isCompact {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FeedSidePanel.allCases) { item in
                                if item == sidePanel {
                                    Button(panelTitle(item)) {
                                        sidePanel = item
                                    }
                                    .buttonStyle(.borderedProminent)
                                } else {
                                    Button(panelTitle(item)) {
                                        sidePanel = item
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    panelBody(sidePanel)
                } else {
                    panelBody(.notifications)
                    panelBody(.livechat)
                    panelBody(.online)
                    panelBody(.messages)
                    panelBody(.quick)
                }
            }
            .animation(.easeInOut(duration: 0.20), value: sidePanel)
        }
    }

    @ViewBuilder
    private func panelBody(_ panel: FeedSidePanel) -> some View {
        switch panel {
        case .notifications:
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("notifications")).font(.headline)
                if notifications.isEmpty {
                    Text(i18n.t("notifications_empty")).font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(notifications.prefix(3)) { n in
                        Button {
                            onNotificationTap(n)
                        } label: {
                            HStack(spacing: 8) {
                                AsyncAvatarView(imageName: n.resim, size: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(n.message ?? "")
                                        .font(.caption)
                                        .lineLimit(2)
                                    Text("@\(n.kadi ?? "user")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .livechat:
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("live_chat_title")).font(.headline)
                if chatMessages.isEmpty {
                    Text(i18n.t("loading")).font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(chatMessages.suffix(4)) { chat in
                        HStack(spacing: 8) {
                            Text("@\(chat.kadi ?? "user")")
                                .font(.caption.bold())
                            Text(chat.message ?? "")
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField(i18n.t("write_to_chat"), text: $chatDraft)
                        .textFieldStyle(.roundedBorder)
                    Button(i18n.t("send"), action: onSendChat)
                        .buttonStyle(.borderedProminent)
                        .disabled(chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        case .online:
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("online_members")).font(.headline)
                if onlineMembers.isEmpty {
                    Text(i18n.t("online_members_empty")).font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(onlineMembers.prefix(8)) { u in
                        HStack(spacing: 8) {
                            AsyncAvatarView(imageName: u.resim, size: 24)
                            Text("@\(u.kadi ?? "user")")
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
            }
        case .messages:
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("new_messages")).font(.headline)
                Button {
                    onOpenMessages()
                } label: {
                    Text(unreadMessages > 0 ? "\(unreadMessages) \(i18n.t("new_messages"))" : i18n.t("no_new_messages"))
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        case .quick:
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("quick_access")).font(.headline)
                if quickAccessUsers.isEmpty {
                    Text(i18n.t("quick_access")).font(.caption).foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickAccessUsers.prefix(10)) { member in
                                HStack(spacing: 6) {
                                    AsyncAvatarView(imageName: member.resim, size: 20)
                                    Text("@\(member.kadi ?? "uye")").font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(SDALTheme.softPanel)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                Button(i18n.t("feed_discover_members"), action: onOpenExplore)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func panelTitle(_ panel: FeedSidePanel) -> String {
        switch panel {
        case .notifications: return i18n.t("notifications")
        case .livechat: return i18n.t("live_chat_title")
        case .online: return i18n.t("online_members")
        case .messages: return i18n.t("messages")
        case .quick: return i18n.t("quick_access")
        }
    }
}

private struct FeedScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct FeedScopeChipButtonStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(active ? SDALTheme.ink : SDALTheme.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? SDALTheme.primary.opacity(0.22) : SDALTheme.softPanel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(active ? SDALTheme.primary.opacity(0.5) : SDALTheme.line, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

private struct PressableActionButtonStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? SDALTheme.primary.opacity(0.18) : SDALTheme.softPanel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(active ? SDALTheme.primary.opacity(0.45) : SDALTheme.line, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct EditPostSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let post: FeedPost
    let onSaved: () -> Void

    @State private var content = ""
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField(i18n.t("content"), text: $content, axis: .vertical)
                    .lineLimit(3...8)
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(i18n.t("edit_post"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("save")) { Task { await save() } }
                }
            }
            .onAppear {
                content = post.content ?? ""
            }
        }
    }

    private func save() async {
        do {
            try await api.editPost(id: post.id, content: content)
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct PostCommentsSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let post: FeedPost
    @State private var comments: [PostComment] = []
    @State private var text = ""
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                List(comments) { c in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("@\(c.kadi ?? "user")")
                            .font(.caption.bold())
                        Text(c.comment ?? "")
                        Text(c.createdAt ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    TextField(i18n.t("write_comment"), text: $text)
                        .textFieldStyle(.roundedBorder)
                    Button(i18n.t("send")) { Task { await add() } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle(i18n.t("comments"))
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        do { comments = try await api.fetchPostComments(id: post.id) } catch { self.error = error.localizedDescription }
    }

    private func add() async {
        do {
            try await api.addPostComment(id: post.id, comment: text)
            text = ""
            comments = try await api.fetchPostComments(id: post.id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct EventsHubView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [EventItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var createOpen = false
    @State private var selectedEvent: EventItem?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if loading && items.isEmpty {
                    ProgressView(i18n.t("loading"))
                } else if let error, items.isEmpty {
                    ScreenErrorView(message: error) { Task { await load() } }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { e in
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(e.title ?? "-")
                                            .font(.headline)
                                        if let desc = e.description, !desc.isEmpty { Text(desc).font(.subheadline) }
                                        HStack(spacing: 8) {
                                            Text(e.startsAt ?? "")
                                            Text("•")
                                            Text(e.location ?? "-")
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        HStack(spacing: 6) {
                                            if (e.approved == false) {
                                                Text(i18n.t("pending_approval"))
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.orange.opacity(0.18))
                                                    .clipShape(Capsule())
                                            }
                                            if let counts = e.responseCounts {
                                                Text("\(i18n.t("attend")) \(counts.attend ?? 0)")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(SDALTheme.softPanel)
                                                    .clipShape(Capsule())
                                                Text("\(i18n.t("decline")) \(counts.decline ?? 0)")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(SDALTheme.softPanel)
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        HStack(spacing: 8) {
                                            Button(i18n.t("attend")) { Task { await respond(e.id, "attend") } }
                                                .buttonStyle(.bordered)
                                            Button(i18n.t("decline")) { Task { await respond(e.id, "decline") } }
                                                .buttonStyle(.bordered)
                                            Button(i18n.t("notify")) { Task { await notify(e.id) } }
                                                .buttonStyle(.bordered)
                                            Button(i18n.t("comments")) { selectedEvent = e }
                                                .buttonStyle(.borderedProminent)
                                        }

                                        if e.canManageResponses == true {
                                            HStack(spacing: 8) {
                                                Button("\(i18n.t("counts")): \(e.responseVisibility?.showCounts == true ? i18n.t("on") : i18n.t("off"))") {
                                                    Task {
                                                        let v = e.responseVisibility
                                                        await setVisibility(
                                                            e.id,
                                                            showCounts: !(v?.showCounts ?? false),
                                                            showAttendeeNames: v?.showAttendeeNames ?? false,
                                                            showDeclinerNames: v?.showDeclinerNames ?? false
                                                        )
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                                Button("\(i18n.t("attendees")): \(e.responseVisibility?.showAttendeeNames == true ? i18n.t("on") : i18n.t("off"))") {
                                                    Task {
                                                        let v = e.responseVisibility
                                                        await setVisibility(
                                                            e.id,
                                                            showCounts: v?.showCounts ?? false,
                                                            showAttendeeNames: !(v?.showAttendeeNames ?? false),
                                                            showDeclinerNames: v?.showDeclinerNames ?? false
                                                        )
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                            }
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(i18n.t("delete"), role: .destructive) { Task { await deleteEvent(e.id) } }
                                    Button(e.approved == true ? i18n.t("unapprove") : i18n.t("approve")) {
                                        Task { await approveEvent(e.id, approved: e.approved != true) }
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle(i18n.t("events"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button(i18n.t("create")) { createOpen = true } }
            }
            .task { if items.isEmpty { await load() } }
            .sheet(isPresented: $createOpen) {
                EventCreateSheet(onDone: {
                    createOpen = false
                    Task { await load() }
                })
            }
            .sheet(item: $selectedEvent) { event in
                EventCommentsSheet(event: event)
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do { items = try await api.fetchEvents() } catch { self.error = error.localizedDescription }
    }

    private func respond(_ id: Int, _ value: String) async {
        do { try await api.respondEvent(id: id, response: value); await load() } catch { self.error = error.localizedDescription }
    }

    private func notify(_ id: Int) async {
        do { try await api.notifyEventFollowers(id: id) } catch { self.error = error.localizedDescription }
    }

    private func setVisibility(_ id: Int, showCounts: Bool, showAttendeeNames: Bool, showDeclinerNames: Bool) async {
        do {
            try await api.setEventResponseVisibility(id: id, showCounts: showCounts, showAttendeeNames: showAttendeeNames, showDeclinerNames: showDeclinerNames)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func approveEvent(_ id: Int, approved: Bool) async {
        do {
            try await api.approveEvent(id: id, approved: approved)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteEvent(_ id: Int) async {
        do {
            try await api.deleteEvent(id: id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct EventCreateSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let onDone: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var startsAt = ""
    @State private var endsAt = ""
    @State private var item: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showCamera = false
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField(i18n.t("title"), text: $title)
                TextField(i18n.t("description"), text: $description, axis: .vertical)
                TextField(i18n.t("location"), text: $location)
                TextField(i18n.t("starts_at_iso"), text: $startsAt)
                TextField(i18n.t("ends_at_iso"), text: $endsAt)
                PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                    Label(imageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label(i18n.t("camera"), systemImage: "camera")
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("create")) { Task { await save() } }
                        .disabled(title.isEmpty || description.isEmpty)
                }
            }
            .onChange(of: item) { _, newValue in
                guard let newValue else { return }
                Task { imageData = try? await newValue.loadTransferable(type: Data.self) }
            }
            .sheet(isPresented: $showCamera) {
                CameraCapturePicker { data in
                    if let data {
                        imageData = data
                    }
                    showCamera = false
                }
                .ignoresSafeArea()
            }
        }
    }

    private func save() async {
        do {
            if let imageData {
                try await api.createEventWithImage(
                    title: title,
                    description: description,
                    location: location,
                    startsAt: startsAt,
                    endsAt: endsAt,
                    imageData: imageData
                )
            } else {
                try await api.createEvent(title: title, description: description, location: location, startsAt: startsAt, endsAt: endsAt)
            }
            onDone()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct EventCommentsSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let event: EventItem
    @State private var comments: [EventComment] = []
    @State private var text = ""
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                List(comments) { c in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("@\(c.kadi ?? "user")").font(.caption.bold())
                        Text(c.comment ?? "")
                    }
                }
                HStack {
                    TextField(i18n.t("comment"), text: $text)
                        .textFieldStyle(.roundedBorder)
                    Button(i18n.t("send")) { Task { await add() } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle(event.title ?? i18n.t("event"))
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        do { comments = try await api.fetchEventComments(id: event.id) } catch { self.error = error.localizedDescription }
    }

    private func add() async {
        do {
            try await api.addEventComment(id: event.id, comment: text)
            text = ""
            comments = try await api.fetchEventComments(id: event.id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct AnnouncementsHubView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [AnnouncementItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showCreate = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if loading && items.isEmpty {
                    ProgressView(i18n.t("loading"))
                } else if let error, items.isEmpty {
                    ScreenErrorView(message: error) { Task { await load() } }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { a in
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(a.title ?? "-")
                                            .font(.headline)
                                        Text(a.body ?? "")
                                            .font(.subheadline)
                                        HStack(spacing: 8) {
                                            Text(a.createdAt ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if a.approved == false {
                                                Text("Pending approval")
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.orange.opacity(0.18))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) { Task { await deleteAnnouncement(a.id) } }
                                    Button(a.approved == true ? "Unapprove" : "Approve") {
                                        Task { await approveAnnouncement(a.id, approved: a.approved != true) }
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle(i18n.t("announcements"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button(i18n.t("create")) { showCreate = true } }
            }
            .task { if items.isEmpty { await load() } }
            .sheet(isPresented: $showCreate) {
                AnnouncementCreateSheet(onDone: {
                    showCreate = false
                    Task { await load() }
                })
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do { items = try await api.fetchAnnouncements() } catch { self.error = error.localizedDescription }
    }

    private func approveAnnouncement(_ id: Int, approved: Bool) async {
        do {
            try await api.approveAnnouncement(id: id, approved: approved)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteAnnouncement(_ id: Int) async {
        do {
            try await api.deleteAnnouncement(id: id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct AnnouncementCreateSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let onDone: () -> Void

    @State private var title = ""
    @State private var announcementText = ""
    @State private var item: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showCamera = false
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Body", text: $announcementText, axis: .vertical)
                    .lineLimit(4...8)
                PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                    Label(imageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label(i18n.t("camera"), systemImage: "camera")
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { Task { await save() } }
                        .disabled(title.isEmpty || announcementText.isEmpty)
                }
            }
            .onChange(of: item) { _, newValue in
                guard let newValue else { return }
                Task { imageData = try? await newValue.loadTransferable(type: Data.self) }
            }
            .sheet(isPresented: $showCamera) {
                CameraCapturePicker { data in
                    if let data {
                        imageData = data
                    }
                    showCamera = false
                }
                .ignoresSafeArea()
            }
        }
    }

    private func save() async {
        do {
            if let imageData {
                try await api.createAnnouncementWithImage(title: title, body: announcementText, imageData: imageData)
            } else {
                try await api.createAnnouncement(title: title, body: announcementText)
            }
            onDone()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct GroupsHubView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [GroupItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showCreate = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if loading && items.isEmpty {
                    ProgressView(i18n.t("loading"))
                } else if let error, items.isEmpty {
                    ScreenErrorView(message: error) { Task { await load() } }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { g in
                                NavigationLink {
                                    GroupDetailScreen(groupId: g.id)
                                } label: {
                                    GlassCard {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(g.name ?? "-")
                                                .font(.headline)
                                            Text(g.description ?? "")
                                                .font(.subheadline)
                                                .lineLimit(2)
                                            HStack(spacing: 6) {
                                                Text("\(g.members ?? 0) uye")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(SDALTheme.softPanel)
                                                    .clipShape(Capsule())
                                                Text(g.membershipStatus ?? "none")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(SDALTheme.softPanel)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button(g.joined == true ? i18n.t("leave") : i18n.t("join")) {
                                        Task { await joinLeave(g.id) }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle(i18n.t("groups"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button(i18n.t("create")) { showCreate = true } }
            }
            .task { if items.isEmpty { await load() } }
            .sheet(isPresented: $showCreate) {
                GroupCreateSheet(onDone: {
                    showCreate = false
                    Task { await load() }
                })
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do { items = try await api.fetchGroups() } catch { self.error = error.localizedDescription }
    }

    private func joinLeave(_ id: Int) async {
        do { try await api.joinOrLeaveGroup(id: id); await load() } catch { self.error = error.localizedDescription }
    }
}

private struct GroupCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onDone: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                if let error { Text(error).foregroundStyle(.red) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { Task { await save() } }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() async {
        do {
            try await api.createGroup(name: name, description: description)
            onDone()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct GroupDetailScreen: View {
    @EnvironmentObject private var i18n: LocalizationManager
    let groupId: Int

    @State private var detail: GroupDetailEnvelope?
    @State private var text = ""
    @State private var postImageItem: PhotosPickerItem?
    @State private var postImageData: Data?
    @State private var showPostCamera = false
    @State private var coverImageItem: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var showCoverCamera = false
    @State private var eventTitle = ""
    @State private var eventDescription = ""
    @State private var announcementTitle = ""
    @State private var announcementBody = ""
    @State private var visibility = "public"
    @State private var showContactHint = false
    @State private var inviteUserIds = ""
    @State private var joinRequests: [GroupJoinRequestItem] = []
    @State private var pendingInvites: [GroupInviteItem] = []
    @State private var groupEventsFallback: [EventItem] = []
    @State private var groupAnnouncementsFallback: [AnnouncementItem] = []
    @State private var error: String?

    private let api = APIClient.shared
    private var isManager: Bool {
        let role = detail?.myRole?.lowercased()
        return role == "owner" || role == "moderator" || role == "admin"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let group = detail?.group {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            if let cover = group.coverImage,
                               let url = AppConfig.absoluteURL(path: cover) {
                                ZStack(alignment: .bottomLeading) {
                                    CachedRemoteImage(
                                        url: url,
                                        targetSize: CGSize(width: UIScreen.main.bounds.width - 32, height: 150)
                                    ) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        SDALTheme.softPanel
                                    }
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    LinearGradient(
                                        colors: [Color.clear, Color.black.opacity(0.45)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    Text(group.visibility ?? "group")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.35), in: Capsule())
                                        .padding(10)
                                }
                            }
                            Text(group.name ?? "Group")
                                .font(.title3.bold())
                            Text(group.description ?? "")
                            HStack {
                                Text("Status: \(detail?.membershipStatus ?? group.membershipStatus ?? "none")")
                                Spacer()
                                Button((group.joined == true) ? "Leave" : "Join") {
                                    Task { await joinLeave() }
                                }
                                .buttonStyle(.bordered)
                            }
                            if group.invited == true {
                                HStack {
                                    Button("Accept Invite") { Task { await respondInvite("accept") } }
                                        .buttonStyle(.bordered)
                                    Button("Reject Invite") { Task { await respondInvite("reject") } }
                                        .buttonStyle(.bordered)
                                }
                            }
                            Text("Visibility: \(visibility)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if isManager {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Group Settings").font(.headline)
                            Text("Visibility")
                                .font(.caption)
                                .foregroundStyle(SDALTheme.muted)
                            HStack(spacing: 8) {
                                Button("Public") { visibility = "public" }
                                    .buttonStyle(FeedScopeChipButtonStyle(active: visibility == "public"))
                                Button("Members Only") { visibility = "members_only" }
                                    .buttonStyle(FeedScopeChipButtonStyle(active: visibility == "members_only"))
                            }
                            Toggle("Show contact hint", isOn: $showContactHint)
                            Button("Save Settings") { Task { await saveSettings() } }
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cover Photo").font(.headline)
                            PhotosPicker(selection: $coverImageItem, matching: .images, photoLibrary: .shared()) {
                                Label(coverImageData == nil ? "Choose Cover" : "Change Cover", systemImage: "photo")
                            }
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showCoverCamera = true
                                } label: {
                                    Label(i18n.t("camera"), systemImage: "camera")
                                }
                            }
                            Button("Upload Cover") { Task { await uploadCover() } }
                                .buttonStyle(.bordered)
                                .disabled(coverImageData == nil)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Group Post").font(.headline)
                        TextField("Write something...", text: $text, axis: .vertical)
                            .lineLimit(2...5)
                            .textFieldStyle(.roundedBorder)
                        PhotosPicker(selection: $postImageItem, matching: .images, photoLibrary: .shared()) {
                            Label(postImageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                        }
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                showPostCamera = true
                            } label: {
                                Label(i18n.t("camera"), systemImage: "camera")
                            }
                        }
                        Button("Share") { Task { await createPost() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && postImageData == nil)
                    }
                }

                if let posts = detail?.posts {
                    ForEach(posts) { p in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("@\(p.author?.kadi ?? "user")").font(.caption.bold())
                                Text(p.content ?? "")
                            }
                        }
                    }
                }

                if isManager {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Join Requests").font(.headline)
                            if joinRequests.isEmpty {
                                Text("No pending requests").foregroundStyle(.secondary)
                            }
                            ForEach(joinRequests) { r in
                                HStack {
                                    Text("@\(r.kadi ?? "user")")
                                    Spacer()
                                    Button("Approve") { Task { await decideJoinRequest(r.id, action: "approve") } }
                                        .buttonStyle(.bordered)
                                    Button("Reject") { Task { await decideJoinRequest(r.id, action: "reject") } }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Invite Members").font(.headline)
                            TextField("User IDs (comma separated)", text: $inviteUserIds)
                                .textFieldStyle(.roundedBorder)
                            Button("Send Invites") { Task { await sendInvites() } }
                                .buttonStyle(.bordered)
                            ForEach(pendingInvites) { invite in
                                Text("@\(invite.kadi ?? "user") - pending")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let members = detail?.members, !members.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Roles").font(.headline)
                                ForEach(members) { m in
                                    HStack {
                                        Text("@\(m.kadi ?? "user")")
                                        Spacer()
                                        Menu(m.role ?? "member") {
                                            Button("owner") { Task { await setRole(userId: m.id, role: "owner") } }
                                            Button("moderator") { Task { await setRole(userId: m.id, role: "moderator") } }
                                            Button("member") { Task { await setRole(userId: m.id, role: "member") } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Events").font(.headline)
                        TextField("Title", text: $eventTitle).textFieldStyle(.roundedBorder)
                        TextField("Description", text: $eventDescription).textFieldStyle(.roundedBorder)
                        Button("Add Event") { Task { await addGroupEvent() } }
                            .buttonStyle(.bordered)
                        ForEach((detail?.groupEvents?.isEmpty == false ? detail?.groupEvents : groupEventsFallback) ?? []) { e in
                            HStack {
                                Text(e.title ?? "-")
                                Spacer()
                                Button("Delete") { Task { await deleteGroupEvent(e.id) } }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Announcements").font(.headline)
                        TextField("Title", text: $announcementTitle).textFieldStyle(.roundedBorder)
                        TextField("Body", text: $announcementBody).textFieldStyle(.roundedBorder)
                        Button("Add Announcement") { Task { await addGroupAnnouncement() } }
                            .buttonStyle(.bordered)
                        ForEach((detail?.groupAnnouncements?.isEmpty == false ? detail?.groupAnnouncements : groupAnnouncementsFallback) ?? []) { a in
                            HStack {
                                Text(a.title ?? "-")
                                Spacer()
                                Button("Delete") { Task { await deleteGroupAnnouncement(a.id) } }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .padding(16)
        }
        .navigationTitle("Group")
        .task { if detail == nil { await load() } }
        .onChange(of: postImageItem) { _, newValue in
            guard let newValue else { return }
            Task { postImageData = try? await newValue.loadTransferable(type: Data.self) }
        }
        .onChange(of: coverImageItem) { _, newValue in
            guard let newValue else { return }
            Task { coverImageData = try? await newValue.loadTransferable(type: Data.self) }
        }
        .sheet(isPresented: $showPostCamera) {
            CameraCapturePicker { data in
                if let data {
                    postImageData = data
                }
                showPostCamera = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showCoverCamera) {
            CameraCapturePicker { data in
                if let data {
                    coverImageData = data
                }
                showCoverCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private func load() async {
        do {
            detail = try await api.fetchGroupDetail(id: groupId)
            visibility = detail?.group?.visibility ?? "public"
            showContactHint = detail?.group?.showContactHint ?? false
            if detail?.groupEvents?.isEmpty != false {
                groupEventsFallback = (try? await api.fetchGroupEvents(groupId: groupId)) ?? []
            } else {
                groupEventsFallback = []
            }
            if detail?.groupAnnouncements?.isEmpty != false {
                groupAnnouncementsFallback = (try? await api.fetchGroupAnnouncements(groupId: groupId)) ?? []
            } else {
                groupAnnouncementsFallback = []
            }
            if detail?.canReviewRequests == true {
                joinRequests = try await api.fetchGroupJoinRequests(groupId: groupId)
                pendingInvites = try await api.fetchGroupInvitations(groupId: groupId)
            } else {
                joinRequests = []
                pendingInvites = []
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func joinLeave() async {
        do { try await api.joinOrLeaveGroup(id: groupId); await load() } catch { self.error = error.localizedDescription }
    }

    private func respondInvite(_ action: String) async {
        do { try await api.respondGroupInvite(groupId: groupId, action: action); await load() } catch { self.error = error.localizedDescription }
    }

    private func createPost() async {
        do {
            if let postImageData {
                try await api.createGroupPostWithImage(groupId: groupId, content: text, imageData: postImageData)
            } else {
                try await api.createGroupPost(groupId: groupId, content: text)
            }
            text = ""
            postImageData = nil
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func addGroupEvent() async {
        do {
            try await api.createGroupEvent(groupId: groupId, title: eventTitle, description: eventDescription, location: "", startsAt: "", endsAt: "")
            eventTitle = ""
            eventDescription = ""
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteGroupEvent(_ eventId: Int) async {
        do { try await api.deleteGroupEvent(groupId: groupId, eventId: eventId); await load() } catch { self.error = error.localizedDescription }
    }

    private func addGroupAnnouncement() async {
        do {
            try await api.createGroupAnnouncement(groupId: groupId, title: announcementTitle, body: announcementBody)
            announcementTitle = ""
            announcementBody = ""
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteGroupAnnouncement(_ id: Int) async {
        do { try await api.deleteGroupAnnouncement(groupId: groupId, announcementId: id); await load() } catch { self.error = error.localizedDescription }
    }

    private func saveSettings() async {
        do {
            try await api.updateGroupSettings(groupId: groupId, visibility: visibility, showContactHint: showContactHint)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func uploadCover() async {
        guard let coverImageData else { return }
        do {
            try await api.uploadGroupCover(groupId: groupId, imageData: coverImageData)
            self.coverImageData = nil
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func decideJoinRequest(_ requestId: Int, action: String) async {
        do {
            try await api.decideGroupJoinRequest(groupId: groupId, requestId: requestId, action: action)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func sendInvites() async {
        let ids = inviteUserIds
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 > 0 }
        guard !ids.isEmpty else {
            self.error = "Enter valid member ids."
            return
        }
        do {
            try await api.sendGroupInvitations(groupId: groupId, userIds: ids)
            inviteUserIds = ""
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func setRole(userId: Int, role: String) async {
        do {
            try await api.setGroupRole(groupId: groupId, userId: userId, role: role)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct GamesHubView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    LazyVGrid(columns: gameColumns(for: geo.size.width), spacing: 12) {
                        gameCard(title: "Snake", subtitle: "Classic grid runner", key: "snake", arcade: false)
                        gameCard(title: "Tetris", subtitle: "Block stack challenge", key: "tetris", arcade: false)
                        gameCard(title: "Tap Rush", subtitle: "Arcade tap speed", key: "tap-rush", arcade: true)
                        gameCard(title: "Memory Pairs", subtitle: "Match card pairs", key: "memory-pairs", arcade: true)
                        gameCard(title: "Puzzle 2048", subtitle: "Merge to 2048", key: "puzzle-2048", arcade: true)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(i18n.t("games"))
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } } }
        }
    }

    @ViewBuilder
    private func gameCard(title: String, subtitle: String, key: String, arcade: Bool) -> some View {
        NavigationLink {
            MiniGameView(title: title, key: key, arcade: arcade)
        } label: {
            GlassCard {
                HStack(spacing: 12) {
                    Image(systemName: arcade ? "bolt.circle.fill" : "gamecontroller.fill")
                        .font(.title3)
                        .foregroundStyle(SDALTheme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func gameColumns(for width: CGFloat) -> [GridItem] {
        if horizontalSizeClass == .compact || width < 760 {
            return [GridItem(.flexible(), spacing: 12)]
        }
        return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }
}

private struct MiniGameView: View {
    let title: String
    let key: String
    let arcade: Bool

    @State private var score = 0
    @State private var leaderboard: [LeaderboardRow] = []
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title).font(.headline)
                    GameBoardPreview(gameKey: key)
                        .frame(height: 140)
                    Text("Score: \(score)")
                    HStack(spacing: 10) {
                        Button("+1") { score += 1 }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 42)
                        Button("+5") { score += 5 }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 42)
                        Button("+10") { score += 10 }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    HStack {
                        Button("Submit") { Task { await submit() } }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leaderboard").font(.headline)
                    ForEach(Array(leaderboard.enumerated()), id: \.offset) { idx, row in
                        HStack {
                            Text("#\(idx + 1)")
                            Text(row.isim ?? "-")
                            Spacer()
                            Text("\(row.skor ?? row.puan ?? 0)")
                        }
                        .font(.subheadline)
                    }
                }
            }

            if let error {
                Text(error).foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(16)
        .navigationTitle(title)
        .task { await loadLeaderboard() }
    }

    private func loadLeaderboard() async {
        do { leaderboard = try await api.fetchGamesLeaderboard(gameKey: key, arcade: arcade) } catch { self.error = error.localizedDescription }
    }

    private func submit() async {
        do {
            try await api.submitGameScore(gameKey: key, score: score, arcade: arcade)
            await loadLeaderboard()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct GameBoardPreview: View {
    let gameKey: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SDALTheme.softPanel)
            switch gameKey {
            case "snake":
                snakePreview
            case "tetris":
                tetrisPreview
            case "puzzle-2048":
                puzzlePreview
            case "memory-pairs":
                memoryPreview
            default:
                tapPreview
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SDALTheme.line, lineWidth: 1)
        )
    }

    private var snakePreview: some View {
        GeometryReader { geo in
            let size = min(geo.size.width / 11, geo.size.height / 6.2)
            VStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<10, id: \.self) { col in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill((row == 2 && (3...6).contains(col)) ? .green : SDALTheme.card)
                                .frame(width: size, height: size)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var tetrisPreview: some View {
        HStack(alignment: .bottom, spacing: 4) {
            block(.orange, h: 42)
            block(.blue, h: 70)
            block(.mint, h: 56)
            block(.pink, h: 84)
            block(.yellow, h: 34)
            block(.indigo, h: 52)
        }
        .padding(12)
    }

    private var puzzlePreview: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { c in
                        let value = [2, 4, 8, 16, 32, 64, 128, 256, 512][(r * 3 + c) % 9]
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SDALTheme.card)
                            .overlay {
                                Text("\(value)")
                                    .font(.caption.bold())
                                    .foregroundStyle(SDALTheme.ink)
                            }
                    }
                }
            }
        }
        .padding(10)
    }

    private var memoryPreview: some View {
        VStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(i.isMultiple(of: 2) ? SDALTheme.cardAlt : SDALTheme.card)
                            .overlay {
                                Image(systemName: i.isMultiple(of: 2) ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundStyle(SDALTheme.primary)
                            }
                    }
                }
            }
        }
        .padding(10)
    }

    private var tapPreview: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.title2)
                .foregroundStyle(SDALTheme.primary)
            Text("Tap!")
                .font(.headline)
                .foregroundStyle(SDALTheme.ink)
        }
    }

    private func block(_ color: Color, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color.opacity(0.75))
            .frame(maxWidth: .infinity)
            .frame(height: h)
    }
}
