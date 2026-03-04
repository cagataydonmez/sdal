import { HttpError } from '../shared/httpError.js';

export class PostService {
  constructor({ postRepository, groupRepository }) {
    this.postRepository = postRepository;
    this.groupRepository = groupRepository;
  }

  createPost({ authorId, content, imageUrl = null, groupId = null, now }) {
    if (!content && !imageUrl) {
      throw new HttpError(400, 'İçerik boş olamaz.');
    }

    const created = this.postRepository.createPost({
      authorId,
      content,
      imageUrl,
      groupId,
      createdAt: now || new Date().toISOString()
    });

    return created;
  }

  requireVisiblePost({ postId, viewerId, isAdmin }) {
    const post = this.postRepository.findById(postId);
    if (!post) {
      throw new HttpError(404, 'Gönderi bulunamadı.');
    }

    if (post.groupId && !isAdmin) {
      const membership = this.groupRepository.findMember(post.groupId, viewerId);
      if (!membership) {
        throw new HttpError(403, 'Bu grup içeriğine erişim için üyelik gerekli.');
      }
    }

    return post;
  }

  listPostComments({ postId, viewerId, isAdmin }) {
    this.requireVisiblePost({ postId, viewerId, isAdmin });
    return this.postRepository.listComments(postId);
  }

  createPostComment({ postId, authorId, viewerId, isAdmin, body, now }) {
    const post = this.requireVisiblePost({ postId, viewerId, isAdmin });
    if (!body) {
      throw new HttpError(400, 'Yorum boş olamaz.');
    }

    const created = this.postRepository.createComment({
      postId,
      authorId,
      body,
      createdAt: now || new Date().toISOString()
    });

    return { created, post };
  }

  togglePostLike({ postId, viewerId, isAdmin }) {
    this.requireVisiblePost({ postId, viewerId, isAdmin });

    const existing = this.postRepository.findLike(postId, viewerId);
    if (existing) {
      this.postRepository.deleteLikeById(existing.id);
      return { liked: false };
    }

    this.postRepository.createLike({
      postId,
      userId: viewerId,
      createdAt: new Date().toISOString()
    });

    const post = this.postRepository.findById(postId);
    return {
      liked: true,
      postAuthorId: post?.authorId || null
    };
  }
}
