import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    var body: some View {
        Group {
            switch viewModel.postsState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let msg):
                ErrorRetryView(message: msg) {
                    Task {
                        await viewModel.loadPosts(
                            cookie: sessionManager.sessionCookie,
                            baseUrl: sessionManager.apiBaseUrl
                        )
                    }
                }
            case .loaded(let posts):
                if posts.isEmpty {
                    EmptyFeedView()
                } else {
                    List(posts) { post in
                        PostRow(post: post)
                    }
                    .listStyle(.carousel)
                }
            }
        }
        .navigationTitle("Feed")
    }
}

private struct PostRow: View {
    let post: WatchPost

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                AvatarView(initials: post.initials, photoUrl: post.authorPhoto, size: 24)
                Text(post.authorName.isEmpty ? "@\(post.authorHandle)" : post.authorName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            Text(post.content)
                .font(.caption2)
                .lineLimit(4)
                .foregroundStyle(.primary)
            HStack(spacing: 10) {
                Label("\(post.likeCount)", systemImage: "heart")
                Label("\(post.commentCount)", systemImage: "bubble.left")
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "newspaper")
                .foregroundStyle(.secondary)
            Text("Gönderi yok")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
