import SwiftUI

struct PostCardView: View {
    let post: Post
    var onLike: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var showComments = false
    @State private var comments: [PostComment] = []
    @State private var isLoadingComments = false
    @State private var commentText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                AvatarView(
                    url: post.authorPhotoURL,
                    initials: post.author?.initials ?? "?",
                    size: 36
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorDisplayName)
                        .font(.callout)
                        .fontWeight(.semibold)
                    Text(post.relativeTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if post.author?.id == AuthService.shared.currentUser?.id {
                    Button {
                        onDelete?()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete post")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Content
            if let content = post.content, !content.isEmpty {
                Text(HTMLHelper.strip(content))
                    .font(.body)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .textSelection(.enabled)
            }

            // Image
            if let imageURL = post.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        EmptyView()
                    default:
                        ProgressView()
                            .frame(height: 200)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            Divider().padding(.horizontal, 16)

            // Actions
            HStack(spacing: 20) {
                Button {
                    onLike?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: post.liked == true ? "heart.fill" : "heart")
                            .foregroundStyle(post.liked == true ? .red : .secondary)
                        if let count = post.likeCount, count > 0 {
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help(post.liked == true ? "Unlike" : "Like")

                Button {
                    showComments.toggle()
                    if showComments && comments.isEmpty { loadComments() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showComments ? "bubble.left.fill" : "bubble.left")
                            .foregroundStyle(.secondary)
                        if let count = post.commentCount, count > 0 {
                            Text("\(count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Comments")

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Comments section
            if showComments {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    if isLoadingComments {
                        ProgressView()
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(comments) { comment in
                            HStack(alignment: .top, spacing: 8) {
                                AvatarView(url: comment.photoURL, initials: String(comment.displayName.prefix(2)).uppercased(), size: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(comment.displayName)
                                            .font(.caption).fontWeight(.semibold)
                                        Text(comment.createdAt.map { DateFormatter.relativeString(from: $0) } ?? "")
                                            .font(.caption2).foregroundStyle(.tertiary)
                                    }
                                    Text(HTMLHelper.strip(comment.comment ?? ""))
                                        .font(.callout).textSelection(.enabled)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Write a comment...", text: $commentText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { submitComment() }
                        Button { submitComment() } label: {
                            Image(systemName: "arrow.up.circle.fill").font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty)
                        .help("Send comment")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func loadComments() {
        isLoadingComments = true
        Task {
            do {
                let response: CommentsResponse = try await APIClient.shared.get("/api/new/posts/\(post.id)/comments")
                comments = response.items ?? []
            } catch { }
            isLoadingComments = false
        }
    }

    private func submitComment() {
        let text = commentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        commentText = ""
        Task {
            do {
                struct CommentBody: Encodable { let comment: String }
                try await APIClient.shared.postVoid("/api/new/posts/\(post.id)/comments", body: CommentBody(comment: text))
                loadComments()
            } catch { commentText = text }
        }
    }
}

// MARK: - HTML Helper

enum HTMLHelper {
    static func strip(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
