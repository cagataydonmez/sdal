import Foundation

@MainActor
@Observable
final class NotificationsViewModel {
    var notifications: [AppNotification] = []
    var unreadCount = 0
    var isLoading = false
    var error: String?
    private var pollingTask: Task<Void, Never>?

    func loadNotifications() async {
        isLoading = true
        error = nil
        do {
            let envelope: NotificationsEnvelope = try await APIClient.shared.get(
                "/api/new/notifications",
                query: ["limit": "50", "sort": "recent"]
            )
            notifications = envelope.data?.items ?? []
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadUnreadCount() async {
        do {
            let response: UnreadCountResponse = try await APIClient.shared.get("/api/new/notifications/unread")
            unreadCount = response.count ?? 0
        } catch { }
    }

    func markAllRead() async {
        do {
            try await APIClient.shared.postVoid("/api/new/notifications/read")
            unreadCount = 0
            await loadNotifications()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func markRead(_ notification: AppNotification) async {
        do {
            try await APIClient.shared.postVoid("/api/new/notifications/\(notification.id)/read")
            await loadUnreadCount()
            if let idx = notifications.firstIndex(where: { $0.id == notification.id }) {
                await loadNotifications()
                _ = idx
            }
        } catch { }
    }

    func startPolling() {
        stopPolling()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled else { break }
                await loadUnreadCount()
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        await loadNotifications()
        await loadUnreadCount()
    }
}
