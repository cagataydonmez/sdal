import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    @State private var showComposer = false

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.error {
                ErrorBanner(message: error) { await viewModel.refresh() }
            }

            if viewModel.isLoading && viewModel.posts.isEmpty {
                LoadingView(message: "Loading feed...")
            } else if viewModel.posts.isEmpty {
                EmptyStateView(
                    icon: "text.bubble",
                    title: "No posts yet",
                    message: "Be the first to share something with the community.",
                    action: { showComposer = true },
                    actionLabel: "Create Post"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(viewModel.posts) { post in
                            PostCardView(
                                post: post,
                                onLike: { Task { await viewModel.likePost(post) } },
                                onDelete: { Task { await viewModel.deletePost(post.id) } }
                            )
                        }
                        if viewModel.hasMore {
                            ProgressView()
                                .padding()
                                .task { await viewModel.loadMore() }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle("Feed")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showComposer = true } label: {
                    Label("New Post", systemImage: "square.and.pencil")
                }
                .help("Create a new post (⌘N)")
                .keyboardShortcut("n", modifiers: .command)

                Button { Task { await viewModel.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh feed (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .sheet(isPresented: $showComposer) {
            PostComposerSheet { content in
                Task { await viewModel.createPost(content: content) }
            }
        }
        .task { await viewModel.loadFeed(reset: true) }
    }
}
