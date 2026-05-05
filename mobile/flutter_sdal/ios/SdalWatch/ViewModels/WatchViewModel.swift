import Foundation

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
    @Published var postsState: LoadState<[WatchPost]> = .idle
    @Published var threadsState: LoadState<[WatchThread]> = .idle
    @Published var notificationsState: LoadState<[WatchNotificationItem]> = .idle

    private let api = WatchAPIClient.shared

    // MARK: - Load methods

    func loadAll(cookie: String, baseUrl: String) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPosts(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadThreads(cookie: cookie, baseUrl: baseUrl) }
            group.addTask { await self.loadNotifications(cookie: cookie, baseUrl: baseUrl) }
        }
    }

    func loadPosts(cookie: String, baseUrl: String) async {
        postsState = .loading
        do {
            let raw = try await api.fetchArray(
                path: "/api/new/feed",
                baseUrl: baseUrl,
                cookie: cookie
            )
            let posts = raw.compactMap { WatchPost(json: $0) }
            postsState = .loaded(posts)
        } catch {
            postsState = .failed(error.localizedDescription)
        }
    }

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
}
