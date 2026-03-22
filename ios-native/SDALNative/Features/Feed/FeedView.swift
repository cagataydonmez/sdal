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

private enum FeedTypeTab: String, CaseIterable, Identifiable {
    case main
    case community

    var id: String { rawValue }
}

private enum FeedFilterTab: String, CaseIterable, Identifiable {
    case latest
    case following
    case popular

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
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var sheet: AppCommunityDestination?
    @State private var routedGroupId: Int?
    @State private var feedType: FeedTypeTab = .main
    @State private var filter: FeedFilterTab = .latest
    @State private var nextCursor: String?
    @State private var nextOffset = 0
    @State private var hasMore = true
    @State private var postCommentsTarget: FeedPost?
    @State private var routedPostId: Int?
    @State private var routedEventId: Int?
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
            feedRootContent
        }
        .task { if posts.isEmpty { await load(reset: true) } }
        .task {
            await loadPanels()
        }
        .task {
            await runFeedAutoRefresh()
        }
        .task {
            consumePendingCommunityRoute()
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
                    Button(i18n.t("groups")) {
                        routedGroupId = nil
                        sheet = .groups
                    }
                    Button(i18n.t("games")) { sheet = .games }
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
            }
        }
        .sheet(item: $sheet) { destination in
            communitySheetView(for: destination)
        }
        .onChange(of: router.openCommunityDestination) { _, destination in
            guard let destination else { return }
            if destination != .groups {
                routedGroupId = nil
            }
            sheet = destination
            router.openCommunityDestination = nil
        }
        .onChange(of: router.openGroupId) { _, groupId in
            guard let groupId else { return }
            routedGroupId = groupId
            sheet = .groups
            router.openGroupId = nil
        }
        .onChange(of: router.openPostId) { _, postId in
            guard let postId else { return }
            routedPostId = postId
            router.openPostId = nil
        }
        .onChange(of: router.openEventId) { _, eventId in
            guard let eventId else { return }
            routedEventId = eventId
            sheet = .events
            router.openEventId = nil
            router.openCommunityDestination = nil
        }
        .onChange(of: sheet) { _, newValue in
            if newValue != .groups {
                routedGroupId = nil
            }
            if newValue != .events {
                routedEventId = nil
            }
        }
        .sheet(item: $postCommentsTarget) { post in
            PostCommentsSheet(post: post)
        }
        .sheet(item: Binding(
            get: { routedPostId.map(RoutedPostSelection.init(id:)) },
            set: { routedPostId = $0?.id }
        )) { selection in
            PostCommentsSheet(postId: selection.id)
        }
        .sheet(item: $editingPost) { post in
            EditPostSheet(post: post) {
                editingPost = nil
                Task { await load(reset: true) }
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

    private var feedRootContent: AnyView {
        if isLoading && posts.isEmpty {
            return AnyView(loadingStateView)
        } else if let errorMessage, posts.isEmpty {
            return AnyView(ScreenErrorView(message: errorMessage) { Task { await load(reset: true) } })
        } else {
            return AnyView(feedScrollView)
        }
    }

    private var feedScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                scrollOffsetReader
                heroSection
                StoryBarView()
                composerSection
                pendingPostsSection
                quickAccessSection
                sidePanelsSection
                discoveryControlsSection
                postsSection
                loadingMoreSection
            }
            .padding(16)
        }
        .coordinateSpace(name: "feedScroll")
        .scrollIndicators(.hidden)
        .refreshable { await load(reset: true) }
    }

    private var loadingStateView: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroSection
                    .redacted(reason: .placeholder)
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(i18n.t("loading_feed"))
                            .font(.headline)
                        SDALSkeletonLines(rows: 8)
                    }
                }
            }
            .padding(16)
        }
    }

    private var scrollOffsetReader: some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: FeedScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("feedScroll")).minY)
        }
        .frame(height: 0)
    }

    private var composerSection: some View {
        PostComposerView(feedType: feedType.rawValue) {
            await load(reset: true)
        }
    }

    private var heroSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(i18n.t("feed"))
                            .font(SDALTypography.title)
                            .foregroundStyle(SDALTheme.ink)
                        Text("@\(appState.session?.kadi ?? "uye")")
                            .font(SDALTypography.bodyStrong)
                            .foregroundStyle(SDALTheme.muted)
                    }

                    Spacer(minLength: 12)

                    AsyncAvatarView(imageName: appState.session?.photo, size: 48)
                }

                HStack(spacing: 8) {
                    statusPill(title: i18n.t("messages"), state: appState.messengerConnectionState)
                    statusPill(title: i18n.t("live_chat_title"), state: appState.chatConnectionState)
                }

                HStack(spacing: 10) {
                    quickActionButton(title: i18n.t("events"), systemImage: "calendar") {
                        sheet = .events
                    }
                    quickActionButton(title: i18n.t("groups"), systemImage: "person.3") {
                        routedGroupId = nil
                        sheet = .groups
                    }
                    quickActionButton(title: i18n.t("messages"), systemImage: "bubble.left.and.bubble.right") {
                        router.selectedTab = .messages
                    }
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(SDALTheme.heroBackground.opacity(0.72))
                .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var pendingPostsSection: some View {
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
            .buttonStyle(PolishedGlassButtonStyle(emphasized: true))
        }
    }

    @ViewBuilder
    private var quickAccessSection: some View {
        if !quickAccessUsers.isEmpty && !isCompact {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(i18n.t("quick_access"))
                            .font(.headline)
                        Spacer()
                        Text("\(quickAccessUsers.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SDALTheme.muted)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
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
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(SDALTheme.elevatedPanel)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    private var sidePanelsSection: some View {
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
    }

    private var discoveryControlsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(i18n.t("feed"))
                            .font(.headline)
                        Text("\(posts.count) \(i18n.t("posts"))")
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    }
                    Spacer()
                }

                Picker("", selection: $feedType) {
                    Text(i18n.t("feed_main")).tag(FeedTypeTab.main)
                    Text(i18n.t("feed_community")).tag(FeedTypeTab.community)
                }
                .pickerStyle(.segmented)
                .onChange(of: feedType) { _, _ in
                    Task { await load(reset: true) }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(title: i18n.t("all"), value: .latest)
                        filterChip(title: i18n.t("following"), value: .following)
                        filterChip(title: i18n.t("popular"), value: .popular)
                    }
                    .padding(.vertical, 1)
                }
            }
        }
    }

    private var postsSection: some View {
        ForEach(posts) { post in
            feedPostCard(post)
                .contextMenu {
                    if appState.session?.id == post.author?.id {
                        Button("Edit") { editingPost = post }
                        Button("Delete", role: .destructive) { Task { await deletePost(post.id) } }
                    }
                }
                .onAppear {
                    Task { await loadMoreIfNeeded(currentPostID: post.id) }
                }
        }
    }

    @ViewBuilder
    private var loadingMoreSection: some View {
        if isLoadingMore {
            ProgressView(i18n.t("loading_feed"))
                .frame(maxWidth: .infinity)
        }
    }

    private func feedPostCard(_ post: FeedPost) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    AsyncAvatarView(imageName: post.author?.resim, size: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("@\(post.author?.kadi ?? "uye")")
                            .font(.subheadline.weight(.semibold))
                        Text(post.createdAt ?? "")
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    }
                    Spacer()
                }

                if let content = post.content, !content.isEmpty {
                    Text(content)
                        .font(SDALTypography.body)
                        .foregroundStyle(SDALTheme.ink)
                }

                feedPostImage(post)

                HStack(spacing: 10) {
                    postActionButton(
                        title: "\(post.likeCount ?? 0)",
                        systemImage: post.liked == true ? "heart.fill" : "heart",
                        active: post.liked == true
                    ) {
                        Task { await toggleLike(post.id) }
                    }

                    postActionButton(
                        title: "\(post.commentCount ?? 0)",
                        systemImage: "bubble.left",
                        active: false
                    ) {
                        postCommentsTarget = post
                    }

                    Spacer()
                }
                .font(.footnote)
            }
        }
    }

    private func communitySheetView(for destination: AppCommunityDestination) -> AnyView {
        switch destination {
        case .events:
            return AnyView(EventsHubView(initialEventId: routedEventId))
        case .announcements:
            return AnyView(AnnouncementsHubView())
        case .groups:
            return AnyView(GroupsHubView(initialGroupId: routedGroupId))
        case .games:
            return AnyView(GamesHubView())
        }
    }

    @ViewBuilder
    private func feedPostImage(_ post: FeedPost) -> some View {
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
    }

    private func load(reset: Bool) async {
        if reset {
            isLoading = true
            errorMessage = nil
        } else {
            isLoadingMore = true
        }
        defer {
            if reset {
                isLoading = false
            } else {
                isLoadingMore = false
            }
        }
        do {
            let requestCursor = reset ? nil : nextCursor
            let requestOffset = reset ? 0 : nextOffset
            async let quickReq = api.fetchQuickAccessUsers()
            async let contractPostsReq = api.fetchFeedPage(
                feedType: feedType.rawValue,
                filter: filter.rawValue,
                limit: 20,
                offset: requestOffset,
                cursor: requestCursor
            )
            let page = try await contractPostsReq
            quickAccessUsers = (try? await quickReq) ?? []
            if reset {
                posts = page.items
                pendingPosts = nil
                pendingPostsCount = 0
            } else {
                mergePage(page.items)
            }
            nextCursor = page.nextCursor
            nextOffset = page.nextOffset ?? posts.count
            hasMore = page.hasMore ?? (!page.items.isEmpty && (page.nextCursor != nil || page.items.count >= 20))
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
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                let current = posts[index]
                let liked = !(current.liked ?? false)
                posts[index] = current.togglingLike(to: liked)
            }
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
                let latest = try await api.fetchFeedPage(
                    feedType: feedType.rawValue,
                    filter: filter.rawValue,
                    limit: 20,
                    offset: 0,
                    cursor: nil
                )
                await MainActor.run {
                    consumeRefreshedPosts(latest.items)
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
            try? await Task.sleep(nanoseconds: 20_000_000_000)
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
        guard !sameFeedPosts(posts, latest) else { return }
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

    private func mergePage(_ incoming: [FeedPost]) {
        guard !incoming.isEmpty else { return }
        var map = Dictionary(uniqueKeysWithValues: posts.map { ($0.id, $0) })
        for item in incoming {
            map[item.id] = item
        }
        posts = map.values.sorted { ($0.id) > ($1.id) }
    }

    private func applyPendingPosts() {
        guard let pendingPosts else { return }
        posts = pendingPosts
        self.pendingPosts = nil
        pendingPostsCount = 0
    }

    private func consumePendingCommunityRoute() {
        if let postId = router.openPostId {
            routedPostId = postId
            router.openPostId = nil
            return
        }
        if let eventId = router.openEventId {
            routedEventId = eventId
            sheet = .events
            router.openEventId = nil
            router.openCommunityDestination = nil
            return
        }
        if let groupId = router.openGroupId {
            routedGroupId = groupId
            sheet = .groups
            router.openGroupId = nil
            router.openCommunityDestination = nil
            return
        }
        if let destination = router.openCommunityDestination {
            if destination != .groups {
                routedGroupId = nil
            }
            sheet = destination
            router.openCommunityDestination = nil
        }
    }

    private func loadPanels() async {
        async let notifReq = api.fetchNotifications(limit: 3, offset: 0)
        async let unreadReq = api.fetchUnreadMessagesCount()
        async let onlineReq = api.fetchOnlineMembers(limit: 10)
        async let chatReq = api.fetchChatMessages(limit: 10)
        if let nextNotifications = try? await notifReq, !sameNotifications(notifications, nextNotifications) {
            notifications = nextNotifications
        }
        if let nextUnread = try? await unreadReq, unreadMessages != nextUnread {
            unreadMessages = nextUnread
        }
        if let nextOnline = try? await onlineReq, !sameMembers(onlineMembers, nextOnline) {
            onlineMembers = nextOnline
        }
        if let nextChatMessages = try? await chatReq, !sameChatMessages(chatMessages, nextChatMessages) {
            chatMessages = nextChatMessages
        }
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

    private func loadMoreIfNeeded(currentPostID: Int) async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        guard let index = posts.firstIndex(where: { $0.id == currentPostID }) else { return }
        let threshold = max(posts.count - 3, 0)
        if index >= threshold {
            await load(reset: false)
        }
    }

    private func filterChip(title: String, value: FeedFilterTab) -> some View {
        Button(title) {
            guard filter != value else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                filter = value
            }
            Task { await load(reset: true) }
        }
        .buttonStyle(FeedScopeChipButtonStyle(active: filter == value))
    }

    private func quickActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PolishedGlassButtonStyle())
    }

    private func statusPill(title: String, state: WebSocketConnectionState) -> some View {
        SDALPill(
            text: title,
            tint: state == .connected ? SDALTheme.success.opacity(0.18) : SDALTheme.softPanel,
            foreground: state == .connected ? SDALTheme.success : SDALTheme.muted
        )
    }

    private func postActionButton(
        title: String,
        systemImage: String,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(active ? SDALTheme.primary : SDALTheme.muted)
        }
        .buttonStyle(PressableActionButtonStyle(active: active))
    }

    private func openNotification(_ n: AppNotification) {
        router.handleNotificationPayload([
            "type": n.type ?? "",
            "entity_id": n.entityId as Any,
            "source_user_id": n.sourceUserId as Any
        ])
    }

    private func sameFeedPosts(_ lhs: [FeedPost], _ rhs: [FeedPost]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            left.id == right.id
                && left.likeCount == right.likeCount
                && left.commentCount == right.commentCount
                && left.liked == right.liked
                && left.content == right.content
                && left.image == right.image
        }
    }

    private func sameNotifications(_ lhs: [AppNotification], _ rhs: [AppNotification]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            left.id == right.id
                && left.readAt == right.readAt
                && left.message == right.message
        }
    }

    private func sameMembers(_ lhs: [MemberSummary], _ rhs: [MemberSummary]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            left.id == right.id
                && left.kadi == right.kadi
                && left.online == right.online
        }
    }

    private func sameChatMessages(_ lhs: [ChatMessage], _ rhs: [ChatMessage]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return zip(lhs, rhs).allSatisfy { left, right in
            left.id == right.id
                && left.message == right.message
                && left.createdAt == right.createdAt
        }
    }
}

private struct RoutedPostSelection: Identifiable {
    let id: Int
}
