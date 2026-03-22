import Foundation

@MainActor
@Observable
final class EventsViewModel {
    var events: [Event] = []
    var isLoading = false
    var error: String?

    func loadEvents() async {
        isLoading = true
        error = nil
        do {
            let response: EventsResponse = try await APIClient.shared.get(
                "/api/new/events",
                query: ["limit": "50"]
            )
            events = response.items ?? []
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func respondToEvent(_ eventId: Int, response: String) async {
        do {
            struct EventResp: Encodable { let response: String }
            let _: EventRespondResponse = try await APIClient.shared.post(
                "/api/new/events/\(eventId)/respond",
                body: EventResp(response: response)
            )
            await loadEvents()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        await loadEvents()
    }
}
