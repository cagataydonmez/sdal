import Foundation

@MainActor
@Observable
final class MembersViewModel {
    var members: [User] = []
    var selectedMember: User?
    var isLoading = false
    var error: String?
    var searchQuery = ""
    var total = 0
    var pages = 0
    private var page = 1
    private var searchTask: Task<Void, Never>?

    func loadMembers(reset: Bool = false) async {
        if reset { page = 1 }
        isLoading = true
        error = nil

        do {
            var query = ["page": "\(page)", "pageSize": "30"]
            if !searchQuery.isEmpty {
                query["term"] = searchQuery
            }
            let response: MemberListResponse = try await APIClient.shared.get("/api/members", query: query)
            let newMembers = response.rows ?? []
            if reset {
                members = newMembers
            } else {
                members.append(contentsOf: newMembers)
            }
            total = response.total ?? members.count
            pages = response.pages ?? 1
            page += 1
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func search(_ query: String) {
        searchQuery = query
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await loadMembers(reset: true)
        }
    }

    func loadMore() async {
        guard !isLoading, page <= pages else { return }
        await loadMembers()
    }

    func refresh() async {
        await loadMembers(reset: true)
    }
}
