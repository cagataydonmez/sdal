import Foundation

@MainActor
@Observable
final class FeedViewModel {
    var posts: [Post] = []
    var isLoading = false
    var error: String?
    var hasMore = true
    private var offset = 0
    private let pageSize = 20

    func loadFeed(reset: Bool = false) async {
        if reset {
            offset = 0
            hasMore = true
        }
        guard hasMore || reset else { return }
        isLoading = true
        error = nil

        do {
            let query = ["offset": "\(offset)", "limit": "\(pageSize)"]
            let response: FeedResponse = try await APIClient.shared.get("/api/new/feed", query: query)
            let newPosts = response.items ?? []
            if reset {
                posts = newPosts
            } else {
                posts.append(contentsOf: newPosts)
            }
            hasMore = response.hasMore ?? !newPosts.isEmpty
            offset += newPosts.count
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        await loadFeed()
    }

    func refresh() async {
        await loadFeed(reset: true)
    }

    func likePost(_ post: Post) async {
        do {
            let _: LikeResponse = try await APIClient.shared.post("/api/new/posts/\(post.id)/like")
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createPost(content: String) async {
        do {
            struct NewPost: Encodable { let content: String }
            let _: CreatePostResponse = try await APIClient.shared.post("/api/new/posts", body: NewPost(content: content))
            await refresh()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deletePost(_ postId: Int) async {
        do {
            try await APIClient.shared.delete("/api/new/posts/\(postId)")
            posts.removeAll { $0.id == postId }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
