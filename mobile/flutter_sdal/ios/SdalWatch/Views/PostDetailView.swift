import SwiftUI

struct PostDetailView: View {
    let postId: Int

    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    @State private var post: WatchPost? = nil
    @State private var comments: [WatchComment] = []
    @State private var loadError: String? = nil
    @State private var isLoading = true
    @State private var showCommentInput = false
    @State private var newComment = ""
    @State private var isSendingComment = false
    @State private var likeError: String? = nil

    private var cookie:  String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let err = loadError {
                ErrorRetryView(message: err) { Task { await load() } }
            } else if let post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        // ── Author ──────────────────────────────────────
                        HStack(spacing: 6) {
                            AvatarView(initials: post.initials, photoUrl: post.authorPhoto, size: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(post.authorName.isEmpty
                                     ? "@\(post.authorHandle)"
                                     : post.authorName)
                                    .font(.caption2).fontWeight(.semibold).lineLimit(1)
                                if !post.createdAt.isEmpty {
                                    Text(relativeTime(post.createdAt))
                                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                                }
                            }
                        }

                        // ── Content ─────────────────────────────────────
                        Text(post.content)
                            .font(.caption2)

                        // ── Post image ──────────────────────────────────
                        if !post.imageUrl.isEmpty {
                            AsyncImage(url: URL(string: post.imageUrl)) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                case .failure:
                                    EmptyView()
                                default:
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(height: 100)
                                        .overlay(ProgressView().scaleEffect(0.7))
                                }
                            }
                        }

                        // ── Actions ─────────────────────────────────────
                        HStack(spacing: 0) {
                            // Like button — large tap area
                            Button {
                                Task { await toggleLike() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: post.liked ? "heart.fill" : "heart")
                                        .foregroundStyle(post.liked ? .red : .secondary)
                                    Text("\(post.likeCount)")
                                        .foregroundStyle(post.liked ? .red : .secondary)
                                }
                                .font(.system(size: 13))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Label("\(comments.count)", systemImage: "bubble.left")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 6)

                            Spacer()
                        }

                        if let err = likeError {
                            Text(err).font(.system(size: 9)).foregroundStyle(.red)
                        }

                        Divider()

                        // ── Comments ─────────────────────────────────────
                        if comments.isEmpty {
                            Text("Henüz yorum yok")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(comments) { c in
                                CommentRow(comment: c)
                            }
                        }

                        // ── Add comment ───────────────────────────────────
                        Button {
                            showCommentInput = true
                        } label: {
                            Label("Yorum ekle", systemImage: "plus.bubble")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 4)
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Gönderi")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(isPresented: $showCommentInput) {
            commentInputSheet
        }
    }

    private var commentInputSheet: some View {
        VStack(spacing: 10) {
            Text("Yorum ekle")
                .font(.caption2).fontWeight(.semibold)
            TextField("Yorumunuz...", text: $newComment)
                .font(.caption2)
            Button("Gönder") {
                Task { await submitComment() }
            }
            .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty || isSendingComment)
            .buttonStyle(.borderedProminent)
            .font(.caption2)
        }
        .padding()
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            async let p = viewModel.fetchPostDetail(id: postId, cookie: cookie, baseUrl: baseUrl)
            async let c = viewModel.fetchComments(postId: postId, cookie: cookie, baseUrl: baseUrl)
            let (fetchedPost, fetchedComments) = try await (p, c)
            post     = fetchedPost
            comments = fetchedComments
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleLike() async {
        guard var p = post else { return }
        likeError = nil
        // Optimistic update
        p.liked.toggle()
        p.likeCount += p.liked ? 1 : -1
        post = p
        do {
            let result = try await viewModel.toggleLike(postId: postId, cookie: cookie, baseUrl: baseUrl)
            p.liked     = result.liked
            p.likeCount = result.count
            post = p
        } catch {
            // Revert
            p.liked.toggle()
            p.likeCount += p.liked ? 1 : -1
            post = p
            likeError = "Beğeni gönderilemedi"
        }
    }

    private func submitComment() async {
        let text = newComment.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSendingComment = true
        do {
            try await viewModel.addComment(postId: postId, comment: text, cookie: cookie, baseUrl: baseUrl)
            newComment      = ""
            showCommentInput = false
            // Reload comments
            comments = (try? await viewModel.fetchComments(
                postId: postId, cookie: cookie, baseUrl: baseUrl
            )) ?? comments
        } catch {}
        isSendingComment = false
    }
}

// MARK: - Comment Row

private struct CommentRow: View {
    let comment: WatchComment

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            AvatarView(initials: comment.initials, photoUrl: comment.authorPhoto, size: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(comment.authorName.isEmpty ? "@\(comment.authorHandle)" : comment.authorName)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                Text(comment.comment)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 2)
    }
}
