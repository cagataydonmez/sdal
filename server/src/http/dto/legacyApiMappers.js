export function toLegacyAuthLoginResponse({ user, role, isAdmin, needsProfile }) {
  return {
    user: {
      id: user.id,
      kadi: user.username,
      isim: user.firstName,
      soyisim: user.lastName,
      photo: user.avatarUrl,
      role,
      admin: isAdmin ? 1 : 0
    },
    needsProfile: Boolean(needsProfile)
  };
}

export function toLegacyFeedItem(post) {
  return {
    id: post.id,
    content: post.content,
    image: post.imageUrl,
    createdAt: post.createdAt,
    author: {
      id: post.author?.id || post.authorId,
      kadi: post.author?.username || '',
      isim: post.author?.firstName || '',
      soyisim: post.author?.lastName || '',
      resim: post.author?.avatarUrl || null,
      verified: post.author?.verified ? 1 : 0
    },
    groupId: post.groupId,
    likeCount: Number(post.likeCount || 0),
    commentCount: Number(post.commentCount || 0),
    liked: Boolean(post.likedByViewer)
  };
}

export function toLegacyCommentItem(comment) {
  return {
    id: comment.id,
    post_id: comment.postId,
    user_id: comment.authorId,
    comment: comment.body,
    created_at: comment.createdAt,
    kadi: comment.author?.username || null,
    isim: comment.author?.firstName || null,
    soyisim: comment.author?.lastName || null,
    resim: comment.author?.avatarUrl || null
  };
}

export function toLegacyChatMessageItem(message) {
  return {
    id: message.id,
    user_id: message.authorId,
    message: message.body,
    created_at: message.createdAt,
    kadi: message.author?.username || null,
    isim: message.author?.firstName || null,
    soyisim: message.author?.lastName || null,
    resim: message.author?.avatarUrl || null,
    verified: message.author?.verified ? 1 : 0
  };
}
