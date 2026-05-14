import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @State private var showCompose = false

    private var cookie:  String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    var body: some View {
        Group {
            switch viewModel.postsState {
            case .idle, .loading:
                LoadingView()
            case .failed(let msg):
                ErrorRetryView(message: msg) {
                    Task { await viewModel.loadPosts(cookie: cookie, baseUrl: baseUrl) }
                }
            case .loaded(let posts):
                postList(posts)
            }
        }
        .navigationTitle("Akış")
        .sheet(isPresented: $showCompose) {
            ComposePostView()
        }
    }

    @ViewBuilder
    private func postList(_ posts: [WatchPost]) -> some View {
        List {
            feedHeaderTitle
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 2, trailing: 4))

            // ── Compose header: left = new post, right = my avatar ──────────
            composeHeader
                .listRowInsets(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))

            // ── Feed type tab selector ────────────────────────────────────
            feedTypeSelector
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))

            // ── Story strip ───────────────────────────────────────────────
            if let stories = viewModel.storiesState.value, !stories.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(stories) { story in
                                NavigationLink(destination: StoryDetailView(story: story)) {
                                    VStack(spacing: 3) {
                                        AvatarView(
                                            initials: story.initials,
                                            photoUrl: story.authorPhoto,
                                            size: 34,
                                            ringColor: story.viewed ? nil : .accentColor
                                        )
                                        Text(story.authorName.isEmpty
                                             ? "@\(story.authorHandle)"
                                             : story.authorName.components(separatedBy: " ").first ?? "")
                                            .font(.system(size: 8))
                                            .lineLimit(1)
                                            .foregroundStyle(story.viewed ? .secondary : .primary)
                                    }
                                    .frame(width: 42)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            }

            // ── Posts ─────────────────────────────────────────────────────
            ForEach(posts) { post in
                NavigationLink(destination: PostDetailView(postId: post.id)) {
                    PostRow(post: post)
                }
            }
        }
        .listStyle(.carousel)
        .refreshable {
            await viewModel.loadPosts(cookie: cookie, baseUrl: baseUrl)
            await viewModel.loadStories(cookie: cookie, baseUrl: baseUrl)
        }
    }

    // ── Compose + My Profile header ──────────────────────────────────────

    private var feedHeaderTitle: some View {
        HStack(spacing: 6) {
            Image("SdalLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            Text("SDAL Sosyal")
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var composeHeader: some View {
        HStack(spacing: 6) {
            // Left half – new post button
            Button {
                showCompose = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Yeni gönderi")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)

            // Right half – my profile avatar
            if sessionManager.myUserId > 0 {
                NavigationLink(destination: MemberProfileView(memberId: sessionManager.myUserId)) {
                    AvatarView(initials: "Ben", photoUrl: sessionManager.myUserPhoto, size: 36)
                        .overlay(
                            Circle().stroke(Color.accentColor.opacity(0.4), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .task(id: sessionManager.myUserPhoto) {
                    guard !cookie.isEmpty else { return }
                    await sessionManager.refreshCurrentUserPhotoIfNeeded(cookie: cookie, baseUrl: baseUrl)
                }
            }
        }
    }

    // ── Feed type segmented selector ─────────────────────────────────────

    private var feedTypeSelector: some View {
        HStack(spacing: 0) {
            feedTypeButton(title: "Genel",    tag: "main")
            feedTypeButton(title: "Topluluk", tag: "community")
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func feedTypeButton(title: String, tag: String) -> some View {
        Button {
            guard viewModel.selectedFeedType != tag else { return }
            viewModel.selectedFeedType = tag
            Task {
                await viewModel.loadPosts(cookie: cookie, baseUrl: baseUrl)
                await viewModel.loadStories(cookie: cookie, baseUrl: baseUrl)
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    viewModel.selectedFeedType == tag
                        ? Color.accentColor
                        : Color.clear
                )
                .foregroundStyle(viewModel.selectedFeedType == tag ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Post Row

struct PostRow: View {
    let post: WatchPost
    @EnvironmentObject private var sessionManager: WatchSessionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Author
            HStack(spacing: 5) {
                AvatarView(initials: post.initials, photoUrl: post.authorPhoto, size: 22)
                Text(post.authorName.isEmpty ? "@\(post.authorHandle)" : post.authorName)
                    .font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Spacer()
                if !post.createdAt.isEmpty {
                    Text(relativeTime(post.createdAt))
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                }
            }

            // Content
            Text(post.content)
                .font(.system(size: 11))
                .foregroundStyle(Color.primary.opacity(0.88))
                .lineLimit(4)

            // Thumbnail
            if !post.imageUrl.isEmpty {
                AsyncImage(url: resolvedMediaURL(post.imageUrl, baseUrl: sessionManager.apiBaseUrl)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    case .failure:
                        EmptyView()
                    default:
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 80)
                            .overlay(ProgressView().scaleEffect(0.6))
                    }
                }
            }

            // Stats
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: post.liked ? "heart.fill" : "heart")
                        .foregroundStyle(post.liked ? .red : Color.primary.opacity(0.4))
                    Text("\(post.likeCount)")
                        .foregroundStyle(post.liked ? .red : Color.primary.opacity(0.4))
                }
                HStack(spacing: 3) {
                    Image(systemName: "bubble.left")
                        .foregroundStyle(Color.primary.opacity(0.4))
                    Text("\(post.commentCount)")
                        .foregroundStyle(Color.primary.opacity(0.4))
                }
            }
            .font(.system(size: 10))
        }
        .padding(.vertical, 4)
    }
}
