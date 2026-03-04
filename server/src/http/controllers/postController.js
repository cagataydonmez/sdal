import { isHttpError } from '../../shared/httpError.js';
import { toLegacyCommentItem } from '../dto/legacyApiMappers.js';

export function createPostController({
  postService,
  formatUserText,
  isFormattedContentEmpty,
  getCurrentUser,
  hasAdminRole,
  notifyMentions,
  addNotification,
  scheduleEngagementRecalculation
}) {
  function createPost(req, res) {
    try {
      const content = formatUserText(req.body?.content || '');
      const image = req.body?.image || null;
      const groupId = req.body?.group_id || null;

      const created = postService.createPost({
        authorId: req.session.userId,
        content: isFormattedContentEmpty(content) ? '' : content,
        imageUrl: image,
        groupId,
        now: new Date().toISOString()
      });

      notifyMentions({
        text: req.body?.content || '',
        sourceUserId: req.session.userId,
        entityId: created?.id,
        type: 'mention_post',
        message: 'Gönderide senden bahsetti.'
      });
      scheduleEngagementRecalculation('post_created');
      return res.json({ ok: true, id: created?.id });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('posts.createPost failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  function listComments(req, res) {
    try {
      const currentUser = getCurrentUser(req);
      const comments = postService.listPostComments({
        postId: Number(req.params.id),
        viewerId: req.session.userId,
        isAdmin: hasAdminRole(currentUser)
      });
      return res.json({ items: comments.map((comment) => toLegacyCommentItem(comment)) });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('posts.listComments failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  function createComment(req, res) {
    try {
      const currentUser = getCurrentUser(req);
      const comment = formatUserText(req.body?.comment || '');
      const body = isFormattedContentEmpty(comment) ? '' : comment;

      const { post } = postService.createPostComment({
        postId: Number(req.params.id),
        authorId: req.session.userId,
        viewerId: req.session.userId,
        isAdmin: hasAdminRole(currentUser),
        body,
        now: new Date().toISOString()
      });

      if (post?.authorId && Number(post.authorId) !== Number(req.session.userId)) {
        addNotification({
          userId: post.authorId,
          type: 'comment',
          sourceUserId: req.session.userId,
          entityId: req.params.id,
          message: 'Gönderine yorum yaptı.'
        });
      }

      notifyMentions({
        text: req.body?.comment || '',
        sourceUserId: req.session.userId,
        entityId: req.params.id,
        type: 'mention_post',
        message: 'Yorumda senden bahsetti.'
      });
      scheduleEngagementRecalculation('post_comment_created');

      return res.json({ ok: true });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('posts.createComment failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  function toggleLike(req, res) {
    try {
      const currentUser = getCurrentUser(req);
      const postId = Number(req.params.id || 0);
      if (!postId) return res.status(400).send('Geçersiz gönderi.');

      const result = postService.togglePostLike({
        postId,
        viewerId: req.session.userId,
        isAdmin: hasAdminRole(currentUser)
      });

      if (result.liked && result.postAuthorId && Number(result.postAuthorId) !== Number(req.session.userId)) {
        addNotification({
          userId: result.postAuthorId,
          type: 'like',
          sourceUserId: req.session.userId,
          entityId: postId,
          message: 'Gönderini beğendi.'
        });
      }

      scheduleEngagementRecalculation('post_like_changed');
      return res.json({ ok: true, liked: result.liked });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('posts.toggleLike failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  return {
    createPost,
    listComments,
    createComment,
    toggleLike
  };
}
