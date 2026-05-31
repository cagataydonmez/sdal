import { isHttpError } from '../../shared/httpError.js';
import { resolveFeedPostGroupId } from '../../shared/feedPostGroupResolver.js';
import { toLegacyCommentItem } from '../dto/legacyApiMappers.js';

export function createPostController({
  postService,
  userRepository,
  groupRepository,
  formatUserText,
  isFormattedContentEmpty,
  getCurrentUser,
  hasAdminRole,
  notifyMentions,
  addNotification,
  scheduleEngagementRecalculation,
  invalidateFeedCache,
  sqlAllAsync
}) {
  async function getBlockedAuthorIds(viewerId) {
    if (!viewerId || typeof sqlAllAsync !== 'function') return new Set();
    try {
      const rows = await sqlAllAsync('SELECT blocked_id FROM user_blocks WHERE blocker_id = ?', [viewerId]);
      return new Set(rows.map((row) => Number(row.blocked_id)).filter(Boolean));
    } catch {
      return new Set();
    }
  }
  async function createPost(req, res) {
    try {
      const content = formatUserText(req.body?.content || '');
      const image = req.body?.image || null;
      const groupId = await resolveFeedPostGroupId({
        requestedGroupId: req.body?.group_id || null,
        feedType: req.body?.feedType || '',
        authorId: req.session.userId,
        findGraduationYearById: (userId) => userRepository.findGraduationYearById(userId),
        findGroupByName: (name) => groupRepository.findByName(name)
      });

      const created = await postService.createPost({
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
      Promise.resolve(invalidateFeedCache?.()).catch(() => {});
      return res.json({ ok: true, id: created?.id });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('posts.createPost failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function listComments(req, res) {
    try {
      const currentUser = getCurrentUser(req);
      const limit = Math.min(Math.max(parseInt(req.query.limit || '50', 10), 1), 100);
      const beforeId = Math.max(parseInt(req.query.beforeId || req.query.cursor || '0', 10), 0);
      const page = await postService.listPostComments({
        postId: Number(req.params.id),
        viewerId: req.session.userId,
        isAdmin: hasAdminRole(currentUser),
        limit,
        beforeId
      });
      res.setHeader('X-Has-More', page.hasMore ? '1' : '0');
      // App Store 1.2: hide comments from users the viewer has blocked.
      const blockedAuthorIds = await getBlockedAuthorIds(req.session.userId);
      const visibleItems = blockedAuthorIds.size
        ? page.items.filter((comment) => !blockedAuthorIds.has(Number(comment.authorId)))
        : page.items;
      return res.json({ items: visibleItems.map((comment) => toLegacyCommentItem(comment)) });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('posts.listComments failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function createComment(req, res) {
    try {
      const currentUser = getCurrentUser(req);
      const comment = formatUserText(req.body?.comment || '');
      const body = isFormattedContentEmpty(comment) ? '' : comment;

      const { post } = await postService.createPostComment({
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
      Promise.resolve(invalidateFeedCache?.()).catch(() => {});

      return res.json({ ok: true });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('posts.createComment failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function deleteComment(req, res) {
    try {
      const currentUser = getCurrentUser(req);
      const postId = Number(req.params.id || 0);
      const commentId = Number(req.params.commentId || 0);
      if (!postId || !commentId) {
        return res.status(400).send('Geçersiz yorum.');
      }

      await postService.deletePostComment({
        postId,
        commentId,
        viewerId: req.session.userId,
        isAdmin: hasAdminRole(currentUser)
      });

      scheduleEngagementRecalculation('post_comment_deleted');
      Promise.resolve(invalidateFeedCache?.()).catch(() => {});
      return res.json({ ok: true });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('posts.deleteComment failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function toggleLike(req, res) {
    try {
      const currentUser = getCurrentUser(req);
      const postId = Number(req.params.id || 0);
      if (!postId) return res.status(400).send('Geçersiz gönderi.');

      const result = await postService.togglePostLike({
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
      Promise.resolve(invalidateFeedCache?.()).catch(() => {});
      return res.json({ ok: true, liked: result.liked });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('posts.toggleLike failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function updateComment(req, res) {
    try {
      const currentUser = getCurrentUser(req);
      const postId = Number(req.params.id || 0);
      const commentId = Number(req.params.commentId || 0);
      if (!postId || !commentId) return res.status(400).send('Geçersiz yorum.');
      const comment = formatUserText(req.body?.comment || '');
      const body = isFormattedContentEmpty(comment) ? '' : comment;
      await postService.updatePostComment({
        postId,
        commentId,
        viewerId: req.session.userId,
        isAdmin: hasAdminRole(currentUser),
        body,
        now: new Date().toISOString()
      });
      scheduleEngagementRecalculation('post_comment_updated');
      Promise.resolve(invalidateFeedCache?.()).catch(() => {});
      return res.json({ ok: true });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('posts.updateComment failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  async function listLikes(req, res) {
    try {
      const currentUser = getCurrentUser(req);
      const postId = Number(req.params.id || 0);
      if (!postId) return res.status(400).send('Geçersiz gönderi ID.');
      const likes = await postService.listPostLikes({
        postId,
        viewerId: req.session.userId,
        isAdmin: hasAdminRole(currentUser)
      });
      return res.json({ items: likes });
    } catch (err) {
      if (isHttpError(err)) return res.status(err.statusCode).send(err.message);
      console.error('posts.listLikes failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  return {
    createPost,
    listComments,
    createComment,
    deleteComment,
    toggleLike,
    updateComment,
    listLikes
  };
}
