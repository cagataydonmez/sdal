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
    @Published var announcementsState: LoadState<[WatchAnnouncement]>     = .idle
    @Published var eventsState:        LoadState<[WatchEvent]>            = .idle

    @Published var deepLinkTarget:    DeepLinkTarget? = nil
    @Published var selectedFeedType:  String          = "main"

    // Pending push token — registered as soon as a session is available
    private var pendingPushToken: Data? = nil
    private var pushRegistrationTask: Task<Void, Never>?

    private let api = WatchAPIClient.shared
    private var autoRefreshTask: Task<Void, Never>?
    private var lastNotifiedUnreadCount: Int?

    // MARK: - Bootstrap

    func loadAll(cookie: String, baseUrl: String) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPosts(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadStories(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadThreads(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadNotifications(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadOnlineMembers(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadAnnouncements(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadEvents(cookie: cookie, baseUrl: baseUrl) }
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
            group.addTask { await self.loadPosts(cookie: cookie, baseUrl: baseUrl, silent: true) }
            group.addTask { await self.loadStories(cookie: cookie, baseUrl: baseUrl, silent: true) }
            group.addTask { await self.loadThreads(cookie: cookie, baseUrl: baseUrl, silent: true) }
            group.addTask { await self.loadNotifications(cookie: cookie, baseUrl: baseUrl, silent: true) }
            group.addTask { await self.loadOnlineMembers(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadAnnouncements(cookie: cookie, baseUrl: baseUrl, silent: true) }
            group.addTask { await self.loadEvents(cookie: cookie, baseUrl: baseUrl, silent: true) }
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
        let hex = token.map { String(format: "%02x", $0) }.joined()
        let installationId = watchInstallationId()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        pushRegistrationTask?.cancel()
        pushRegistrationTask = Task { [weak self] in
            do {
                try await self?.api.post(
                    path: "/api/new/mobile/push/register",
                    body: [
                        "installation_id": installationId,
                        "push_token": hex,
                        "platform": "watchos",
                        "app_version": appVersion,
                    ],
                    baseUrl: baseUrl,
                    cookie: cookie
                )
                await MainActor.run {
                    self?.pendingPushToken = nil
                }
            } catch {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.registerPendingTokenIfNeeded(cookie: cookie, baseUrl: baseUrl)
                }
            }
        }
    }

    private func watchInstallationId() -> String {
        let key = "sdal_watch_installation_id"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let next = "watch-\(UUID().uuidString)"
        UserDefaults.standard.set(next, forKey: key)
        return next
    }

    // MARK: - Feed

    func loadPosts(cookie: String, baseUrl: String, silent: Bool = false) async {
        if !silent { postsState = .loading }
        do {
            let path = "/api/new/feed?feedType=\(selectedFeedType)&limit=20&offset=0"
            let raw = try await api.fetchArray(path: path, baseUrl: baseUrl, cookie: cookie)
            let posts = raw.compactMap { WatchPost(json: $0) }
            postsState = .loaded(posts)
        } catch {
            if !silent { postsState = .failed(error.localizedDescription) }
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

    func toggleLike(postId: Int, cookie: String, baseUrl: String) async throws -> (liked: Bool, count: Int?) {
        let result = try await api.postDict(
            path: "/api/new/posts/\(postId)/like",
            body: [:],
            baseUrl: baseUrl,
            cookie: cookie
        )
        let liked = (result["liked"] as? Bool) ?? false
        let count = (result["likeCount"] as? Int) ?? (result["like_count"] as? Int)
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

    func loadStories(cookie: String, baseUrl: String, silent: Bool = false) async {
        if !silent { storiesState = .loading }
        do {
            let path = "/api/new/stories?feedType=\(selectedFeedType)"
            let raw = try await api.fetchArray(path: path, baseUrl: baseUrl, cookie: cookie)
            let stories = raw.compactMap { WatchStory(json: $0) }
            storiesState = .loaded(stories)
        } catch {
            if !silent { storiesState = .failed(error.localizedDescription) }
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

    func searchMembers(query: String, cookie: String, baseUrl: String, silent: Bool = false) async {
        if !silent { membersState = .loading }
        do {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let path = "/api/members?term=\(encoded)&excludeSelf=1&page=1&pageSize=20"
            let raw = try await api.fetchArray(path: path, baseUrl: baseUrl, cookie: cookie)
            let members = raw.compactMap { WatchMember(json: $0) }
            membersState = .loaded(members)
        } catch {
            if !silent { membersState = .failed(error.localizedDescription) }
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
                    path: "/api/members?online=1&excludeSelf=1&sort=online&page=1&pageSize=50",
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

    func loadThreads(cookie: String, baseUrl: String, silent: Bool = false) async {
        if !silent { threadsState = .loading }
        do {
            let raw = try await api.fetchArray(
                path: "/api/sdal-messenger/threads",
                baseUrl: baseUrl,
                cookie: cookie
            )
            let threads = raw.compactMap { WatchThread(json: $0) }
            maybeNotifyUnreadMessages(threads)
            threadsState = .loaded(threads)
        } catch {
            if !silent { threadsState = .failed(error.localizedDescription) }
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
            body: ["text": body],
            baseUrl: baseUrl,
            cookie: cookie
        )
    }

    func markThreadRead(threadId: Int, cookie: String, baseUrl: String) async {
        try? await api.post(
            path: "/api/sdal-messenger/threads/\(threadId)/read",
            body: [:],
            baseUrl: baseUrl,
            cookie: cookie
        )
        await loadThreads(cookie: cookie, baseUrl: baseUrl, silent: true)
    }

    func createThread(recipientId: Int, body: String, cookie: String, baseUrl: String) async throws -> Int {
        let result = try await api.postDict(
            path: "/api/sdal-messenger/threads",
            body: ["recipientIds": [recipientId]],
            baseUrl: baseUrl,
            cookie: cookie
        )
        let tid = (result["threadId"] as? Int)
            ?? (result["thread_id"] as? Int)
            ?? (result["id"] as? Int)
            ?? 0
        guard tid > 0 else { throw WatchAPIError.emptyResponse }
        if tid > 0 {
            try await sendMessage(threadId: tid, body: body, cookie: cookie, baseUrl: baseUrl)
        }
        await loadThreads(cookie: cookie, baseUrl: baseUrl)
        return tid
    }

    func loadContacts(cookie: String, baseUrl: String, silent: Bool = false) async {
        if !silent { contactsState = .loading }
        do {
            let raw = try await api.fetchArray(
                path: "/api/sdal-messenger/contacts",
                baseUrl: baseUrl,
                cookie: cookie
            )
            let contacts = raw.compactMap { WatchContact(json: $0) }
            contactsState = .loaded(contacts)
        } catch {
            if !silent { contactsState = .failed(error.localizedDescription) }
        }
    }

    // MARK: - Notifications

    func loadNotifications(cookie: String, baseUrl: String, silent: Bool = false) async {
        if !silent { notificationsState = .loading }
        do {
            let raw = try await api.fetchArray(
                path: "/api/new/notifications",
                baseUrl: baseUrl,
                cookie: cookie
            )
            let items = raw.compactMap { WatchNotificationItem(json: $0) }
            notificationsState = .loaded(items)
        } catch {
            if !silent { notificationsState = .failed(error.localizedDescription) }
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

    // MARK: - Announcements

    func loadAnnouncements(cookie: String, baseUrl: String, silent: Bool = false) async {
        if !silent { announcementsState = .loading }
        do {
            let raw = try await api.fetchArray(
                path: "/api/new/announcements?limit=30&offset=0",
                baseUrl: baseUrl,
                cookie: cookie
            )
            let items = raw.compactMap { WatchAnnouncement(json: $0) }
            announcementsState = .loaded(items)
        } catch {
            if !silent { announcementsState = .failed(error.localizedDescription) }
        }
    }

    // MARK: - Events

    func loadEvents(cookie: String, baseUrl: String, silent: Bool = false) async {
        if !silent { eventsState = .loading }
        do {
            let raw = try await api.fetchArray(
                path: "/api/new/events?limit=30&offset=0",
                baseUrl: baseUrl,
                cookie: cookie
            )
            let items = raw.compactMap { WatchEvent(json: $0) }
            eventsState = .loaded(items)
        } catch {
            if !silent { eventsState = .failed(error.localizedDescription) }
        }
    }

    func respondToEvent(eventId: Int, response: String, cookie: String, baseUrl: String) async throws {
        let path = "/api/new/events/\(eventId)/\(response)"
        let result = try await api.postDict(path: path, body: [:], baseUrl: baseUrl, cookie: cookie)
        if case .loaded(var events) = eventsState {
            if let idx = events.firstIndex(where: { $0.id == eventId }) {
                let old = events[idx].myResponse
                events[idx].myResponse = response
                let counts = (result["response_counts"] as? [String: Any]) ?? [:]
                if let a = counts["attend"] as? Int {
                    events[idx].attendCount = a
                } else {
                    if old != "attend"  && response == "attend"  { events[idx].attendCount  += 1 }
                    if old == "attend"  && response != "attend"  { events[idx].attendCount  = max(0, events[idx].attendCount - 1) }
                }
                if let d = counts["decline"] as? Int {
                    events[idx].declineCount = d
                } else {
                    if old != "decline" && response == "decline" { events[idx].declineCount += 1 }
                    if old == "decline" && response != "decline" { events[idx].declineCount = max(0, events[idx].declineCount - 1) }
                }
                eventsState = .loaded(events)
            }
        }
    }

    private func maybeNotifyUnreadMessages(_ threads: [WatchThread]) {
        let count = threads.reduce(0) { $0 + $1.unreadCount }
        defer { lastNotifiedUnreadCount = count }
        guard let previous = lastNotifiedUnreadCount, count > previous else { return }

        let content = UNMutableNotificationContent()
        content.title = "Yeni mesaj"
        content.body = count == 1 ? "Okunmamış 1 mesajın var." : "\(count) okunmamış mesajın var."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "sdal-watch-message-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
