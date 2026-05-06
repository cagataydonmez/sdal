import Foundation
import UserNotifications

enum LoadState<T> {
    case idle
    case loading
    case loaded(T)
    case failed(String)

    var value: T? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

@MainActor
final class WatchViewModel: ObservableObject {

    // MARK: - State

    @Published var postsState:         LoadState<[WatchPost]>             = .idle
    @Published var storiesState:       LoadState<[WatchStory]>            = .idle
    @Published var threadsState:       LoadState<[WatchThread]>           = .idle
    @Published var notificationsState: LoadState<[WatchNotificationItem]> = .idle
    @Published var membersState:       LoadState<[WatchMember]>           = .idle
    @Published var onlineMembersState: LoadState<[WatchMember]>           = .idle
    @Published var contactsState:      LoadState<[WatchContact]>          = .idle

    @Published var deepLinkTarget:    DeepLinkTarget? = nil
    @Published var selectedFeedType:  String          = "main"

    // Pending push token — registered as soon as a session is available
    private var pendingPushToken: Data? = nil

    private let api = WatchAPIClient.shared
    private var autoRefreshTask: Task<Void, Never>?

    // MARK: - Bootstrap

    func loadAll(cookie: String, baseUrl: String) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPosts(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadStories(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadThreads(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadNotifications(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadOnlineMembers(cookie: cookie, baseUrl: baseUrl) }
        }
    }

    /// Call once after session is ready. Fires a silent refresh every 30 s.
    func startAutoRefresh(cookie: String, baseUrl: String) {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 s
                guard !Task.isCancelled, let self else { return }
                await self.silentRefresh(cookie: cookie, baseUrl: baseUrl)
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func silentRefresh(cookie: String, baseUrl: String) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPosts(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadThreads(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadNotifications(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadOnlineMembers(cookie: cookie, baseUrl: baseUrl) }
        }
    }

    // MARK: - Push Token

    func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in }
    }

    /// Store the token. If a session is ready, register immediately; otherwise
    /// the token will be sent when `registerPendingTokenIfNeeded` is called.
    func storePushToken(_ token: Data, cookie: String, baseUrl: String) {
        pendingPushToken = token
        registerPendingTokenIfNeeded(cookie: cookie, baseUrl: baseUrl)
    }

    /// Called whenever the session cookie becomes available.
    func registerPendingTokenIfNeeded(cookie: String, baseUrl: String) {
        guard !cookie.isEmpty, let token = pendingPushToken else { return }
        pendingPushToken = nil
        let hex = token.map { String(format: "%02x", $0) }.joined()
        Task {
            try? await api.post(
                path: "/api/new/mobile/push/register",
                body: ["push_token": hex, "platform": "apns-watch"],
                baseUrl: baseUrl,
                cookie: cookie
            )
        }
    }

    // MARK: - Feed

    func loadPosts(cookie: String, baseUrl: String) async {
        postsState = .loading
        do {
            let path = "/api/new/feed?feedType=\(selectedFeedType)&limit=20&offset=0"
            let raw = try await api.fetchArray(path: path, baseUrl: baseUrl, cookie: cookie)
            let posts = raw.compactMap { WatchPost(json: $0) }
            postsState = .loaded(posts)
        } catch {
            postsState = .failed(error.localizedDescription)
        }
    }

    func fetchPostDetail(id: Int, cookie: String, baseUrl: String) async throws -> WatchPost {
        let dict = try await api.fetchDict(
            path: "/api/new/posts/\(id)",
            baseUrl: baseUrl,
            cookie: cookie
        )
        let itemJson = (dict["item"] as? [String: Any]) ?? dict
        if let post = WatchPost(json: itemJson) { return post }
        throw URLError(.cannotParseResponse)
    }

    func fetchComments(postId: Int, cookie: String, baseUrl: String) async throws -> [WatchComment] {
        let raw = try await api.fetchArray(
            path: "/api/new/posts/\(postId)/comments",
            baseUrl: baseUrl,
            cookie: cookie
        )
        return raw.compactMap { WatchComment(json: $0) }
    }

    func toggleLike(postId: Int, cookie: String, baseUrl: String) async throws -> (liked: Bool, count: Int) {
        let result = try await api.postDict(
            path: "/api/new/posts/\(postId)/react",
            body: ["type": "like"],
            baseUrl: baseUrl,
            cookie: cookie
        )
        let liked = (result["liked"] as? Bool) ?? false
        let count = (result["likeCount"] as? Int) ?? (result["like_count"] as? Int) ?? 0
        return (liked, count)
    }

    func addComment(postId: Int, comment: String, cookie: String, baseUrl: String) async throws {
        try await api.post(
            path: "/api/new/posts/\(postId)/comments",
            body: ["comment": comment],
            baseUrl: baseUrl,
            cookie: cookie
        )
    }

    func createPost(content: String, feedType: String, cookie: String, baseUrl: String) async throws {
        try await api.post(
            path: "/api/new/posts",
            body: ["content": content, "feedType": feedType],
            baseUrl: baseUrl,
            cookie: cookie
        )
        await loadPosts(cookie: cookie, baseUrl: baseUrl)
    }

    // MARK: - Stories

    func loadStories(cookie: String, baseUrl: String) async {
        storiesState = .loading
        do {
            let path = "/api/new/stories?feedType=\(selectedFeedType)"
            let raw = try await api.fetchArray(path: path, baseUrl: baseUrl, cookie: cookie)
            let stories = raw.compactMap { WatchStory(json: $0) }
            storiesState = .loaded(stories)
        } catch {
            storiesState = .failed(error.localizedDescription)
        }
    }

    func markStoryViewed(storyId: Int, cookie: String, baseUrl: String) async {
        try? await api.post(
            path: "/api/new/stories/\(storyId)/view",
            body: [:],
            baseUrl: baseUrl,
            cookie: cookie
        )
        if case .loaded(var stories) = storiesState {
            if let idx = stories.firstIndex(where: { $0.id == storyId }) {
                stories[idx].viewed = true
                storiesState = .loaded(stories)
            }
        }
    }

    // MARK: - Explore / Members

    func searchMembers(query: String, cookie: String, baseUrl: String) async {
        membersState = .loading
        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let path = "/api/members?q=\(encoded)&page=1&pageSize=20"
            let raw = try await api.fetchArray(path: path, baseUrl: baseUrl, cookie: cookie)
            let members = raw.compactMap { WatchMember(json: $0) }
            membersState = .loaded(members)
        } catch {
            membersState = .failed(error.localizedDescription)
        }
    }

    func loadOnlineMembers(cookie: String, baseUrl: String) async {
        do {
            // Try dedicated online endpoint first, fall back to filter param
            let raw = try await api.fetchArray(
                path: "/api/members/online",
                baseUrl: baseUrl,
                cookie: cookie
            )
            let members = raw.compactMap { WatchMember(json: $0) }
            onlineMembersState = .loaded(members)
        } catch {
            // Fallback: query with online flag
            do {
                let raw = try await api.fetchArray(
                    path: "/api/members?online=true&page=1&pageSize=50",
                    baseUrl: baseUrl,
                    cookie: cookie
                )
                let members = raw.compactMap { WatchMember(json: $0) }
                onlineMembersState = .loaded(members)
            } catch {
                onlineMembersState = .loaded([])
            }
        }
    }

    func fetchMember(id: Int, cookie: String, baseUrl: String) async throws -> WatchMember {
        let dict = try await api.fetchDict(
            path: "/api/members/\(id)",
            baseUrl: baseUrl,
            cookie: cookie
        )
        let row = (dict["row"] as? [String: Any]) ?? dict
        if let m = WatchMember(json: row) { return m }
        throw URLError(.cannotParseResponse)
    }

    func toggleFollow(memberId: Int, cookie: String, baseUrl: String) async throws {
        try await api.post(
            path: "/api/new/follow/\(memberId)",
            body: [:],
            baseUrl: baseUrl,
            cookie: cookie
        )
        // Update both members lists
        func toggle(in state: inout LoadState<[WatchMember]>) {
            if case .loaded(var members) = state {
                if let idx = members.firstIndex(where: { $0.id == memberId }) {
                    members[idx].following.toggle()
                    state = .loaded(members)
                }
            }
        }
        toggle(in: &membersState)
        toggle(in: &onlineMembersState)
    }

    // MARK: - Messages

    func loadThreads(cookie: String, baseUrl: String) async {
        threadsState = .loading
        do {
            let raw = try await api.fetchArray(
                path: "/api/sdal-messenger/threads",
                baseUrl: baseUrl,
                cookie: cookie
            )
            let threads = raw.compactMap { WatchThread(json: $0) }
            threadsState = .loaded(threads)
        } catch {
            threadsState = .failed(error.localizedDescription)
        }
    }

    func loadMessages(threadId: Int, cookie: String, baseUrl: String) async throws -> [WatchMessage] {
        let raw = try await api.fetchArray(
            path: "/api/sdal-messenger/threads/\(threadId)/messages",
            baseUrl: baseUrl,
            cookie: cookie
        )
        return raw.compactMap { WatchMessage(json: $0) }
    }

    func sendMessage(threadId: Int, body: String, cookie: String, baseUrl: String) async throws {
        try await api.post(
            path: "/api/sdal-messenger/threads/\(threadId)/messages",
            body: ["body": body],
            baseUrl: baseUrl,
            cookie: cookie
        )
    }

    func createThread(recipientId: Int, body: String, cookie: String, baseUrl: String) async throws -> Int {
        let result = try await api.postDict(
            path: "/api/sdal-messenger/threads",
            body: ["recipient_id": recipientId, "body": body],
            baseUrl: baseUrl,
            cookie: cookie
        )
        let tid = (result["id"] as? Int) ?? (result["thread_id"] as? Int) ?? 0
        await loadThreads(cookie: cookie, baseUrl: baseUrl)
        return tid
    }

    func loadContacts(cookie: String, baseUrl: String) async {
        contactsState = .loading
        do {
            let raw = try await api.fetchArray(
                path: "/api/sdal-messenger/contacts",
                baseUrl: baseUrl,
                cookie: cookie
            )
            let contacts = raw.compactMap { WatchContact(json: $0) }
            contactsState = .loaded(contacts)
        } catch {
            contactsState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Notifications

    func loadNotifications(cookie: String, baseUrl: String) async {
        notificationsState = .loading
        do {
            let raw = try await api.fetchArray(
                path: "/api/new/notifications",
                baseUrl: baseUrl,
                cookie: cookie
            )
            let items = raw.compactMap { WatchNotificationItem(json: $0) }
            notificationsState = .loaded(items)
        } catch {
            notificationsState = .failed(error.localizedDescription)
        }
    }

    func markNotificationRead(id: Int, cookie: String, baseUrl: String) async {
        try? await api.post(
            path: "/api/new/notifications/\(id)",
            body: [:],
            baseUrl: baseUrl,
            cookie: cookie
        )
        if case .loaded(var items) = notificationsState {
            if let idx = items.firstIndex(where: { $0.id == id }) {
                items[idx].isRead = true
                notificationsState = .loaded(items)
            }
        }
    }

    func markAllNotificationsRead(cookie: String, baseUrl: String) async {
        try? await api.post(
            path: "/api/new/notifications/bulk-read",
            body: [:],
            baseUrl: baseUrl,
            cookie: cookie
        )
        if case .loaded(var items) = notificationsState {
            items = items.map { var n = $0; n.isRead = true; return n }
            notificationsState = .loaded(items)
        }
    }

    // MARK: - Unread counts

    var unreadNotificationCount: Int {
        (notificationsState.value ?? []).filter { !$0.isRead }.count
    }

    var unreadMessageCount: Int {
        (threadsState.value ?? []).reduce(0) { $0 + $1.unreadCount }
    }
}
