import Foundation

@MainActor
@Observable
final class AnnouncementsViewModel {
    var announcements: [Announcement] = []
    var selectedAnnouncement: Announcement?
    var isLoading = false
    var error: String?

    func loadAnnouncements() async {
        isLoading = true
        error = nil
        do {
            let response: AnnouncementsResponse = try await APIClient.shared.get(
                "/api/new/announcements",
                query: ["limit": "50"]
            )
            announcements = response.items ?? []
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func createAnnouncement(title: String, body: String) async {
        do {
            struct CreateBody: Encodable { let title: String; let body: String }
            try await APIClient.shared.postVoid("/api/new/announcements", body: CreateBody(title: title, body: body))
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        await loadAnnouncements()
    }
}
