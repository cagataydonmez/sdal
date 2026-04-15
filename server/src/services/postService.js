import { HttpError } from '../shared/httpError.js';

export class PostService {
  constructor({ postRepository, groupRepository }) {
    this.postRepository = postRepository;
    this.groupRepository = groupRepository;
  }

  async createPost({ authorId, content, imageUrl = null, groupId = null, now }) {
    if (!content && !imageUrl) {
      throw new HttpError(400, 'İçerik boş olamaz.');
    }

    const created = await this.postRepository.createPost({
      authorId,
      content,
      imageUrl,
      groupId,
      createdAt: now || new Date().toISOString()
    });

    return created;
  }

  async requireVisiblePost({ postId, viewerId, isAdmin }) {
    const post = await this.postRepository.findById(postId);
    if (!post) {
      throw new HttpError(404, 'Gönderi bulunamadı.');
    }

    if (post.groupId && !isAdmin) {
      const membership = await this.groupRepository.findMember(post.groupId, viewerId);
      if (!membership) {
        throw new HttpError(403, 'Bu grup içeriğine erişim için üyelik gerekli.');
      }
    }

    return post;
  }

  async listPostComments({ postId, viewerId, isAdmin, limit = 50, beforeId = 0 }) {
    await this.requireVisiblePost({ postId, viewerId, isAdmin });
    const safeLimit = Math.min(Math.max(parseInt(limit, 10) || 50, 1), 100);
    const safeBeforeId = Math.max(parseInt(beforeId, 10) || 0, 0);
    return this.postRepository.listComments({ postId, limit: safeLimit, beforeId: safeBeforeId });
  }

  async createPostComment({ postId, authorId, viewerId, isAdmin, body, now }) {
    const post = await this.requireVisiblePost({ postId, viewerId, isAdmin });
    if (!body) {
      throw new HttpError(400, 'Yorum boş olamaz.');
    }

    const created = await this.postRepository.createComment({
      postId,
      authorId,
      body,
      createdAt: now || new Date().toISOString()
    });

    return { created, post };
  }

  async deletePostComment({ postId, commentId, viewerId, isAdmin }) {
    const post = await this.requireVisiblePost({ postId, viewerId, isAdmin });
    const comment = await this.postRepository.findCommentById(commentId);
    if (!comment || Number(comment.postId) !== Number(postId)) {
      throw new HttpError(404, 'Yorum bulunamadı.');
    }
    const isCommentAuthor = Number(comment.authorId) === Number(viewerId);
    const isPostOwner = Number(post.authorId) === Number(viewerId);
    if (!isAdmin && !isCommentAuthor && !isPostOwner) {
      throw new HttpError(403, 'Bu yorumu silme yetkin yok.');
    }
    await this.postRepository.deleteCommentById(commentId);
    return { comment };
  }

  async updatePostComment({ postId, commentId, viewerId, isAdmin, body, now }) {
    await this.requireVisiblePost({ postId, viewerId, isAdmin });
    const comment = await this.postRepository.findCommentById(commentId);
    if (!comment || Number(comment.postId) !== Number(postId)) {
      throw new HttpError(404, 'Yorum bulunamadı.');
    }
    if (!isAdmin && Number(comment.authorId) !== Number(viewerId)) {
      throw new HttpError(403, 'Bu yorumu düzenleme yetkin yok.');
    }
    if (!body) throw new HttpError(400, 'Yorum boş olamaz.');
    const updated = await this.postRepository.updateCommentById(commentId, body, now);
    return { comment: updated };
  }

  async listPostLikes({ postId, viewerId, isAdmin }) {
    await this.requireVisiblePost({ postId, viewerId, isAdmin });
    return this.postRepository.listLikes(postId);
  }

  async togglePostLike({ postId, viewerId, isAdmin }) {
    await this.requireVisiblePost({ postId, viewerId, isAdmin });

    const existing = await this.postRepository.findLike(postId, viewerId);
    if (existing) {
      await this.postRepository.deleteLikeById(existing.id);
      return { liked: false };
    }

    await this.postRepository.createLike({
      postId,
      userId: viewerId,
      createdAt: new Date().toISOString()
    });

    const post = await this.postRepository.findById(postId);
    return {
      liked: true,
      postAuthorId: post?.authorId || null
    };
  }
}
