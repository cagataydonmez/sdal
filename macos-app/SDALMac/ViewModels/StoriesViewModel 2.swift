import Foundation

@MainActor
@Observable
final class StoriesViewModel {
    var stories: [Story] = []
    var isLoading = false
    var error: String?
    var selectedStory: Story?

    // Group stories by user
    var storyGroups: [(userId: Int, userName: String, stories: [Story])] {
        var groups: [Int: (name: String, stories: [Story])] = [:]
        for story in stories {
            let uid = story.userId ?? 0
            if groups[uid] == nil {
                groups[uid] = (name: story.authorDisplayName, stories: [])
            }
            groups[uid]?.stories.append(story)
        }
        return groups.map { (userId: $0.key, userName: $0.value.name, stories: $0.value.stories) }
            .sorted { ($0.stories.first?.createdAt ?? "") > ($1.stories.first?.createdAt ?? "") }
    }

    func loadStories() async {
        isLoading = true
        error = nil
        do {
            let response: StoriesResponse = try await APIClient.shared.get(
                "/api/new/stories",
                query: ["limit": "60"]
            )
            stories = response.items ?? []
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func markViewed(_ storyId: Int) async {
        do {
            try await APIClient.shared.postVoid("/api/new/stories/\(storyId)/view")
        } catch { }
    }

    func deleteStory(_ storyId: Int) async {
        do {
            try await APIClient.shared.delete("/api/new/stories/\(storyId)")
            stories.removeAll { $0.id == storyId }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refresh() async {
        await loadStories()
    }
}
