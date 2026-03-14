import SwiftUI
import PhotosUI
import UIKit

enum FeedSidePanel: String, CaseIterable, Identifiable {
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
            if isCancelledRequest(error) { return }
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
                if isCancelledRequest(error) {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    continue
                }
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

    private func isCancelledRequest(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return true }
        return ns.localizedDescription.lowercased().contains("cancel")
            || ns.localizedDescription.lowercased().contains("iptal")
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
