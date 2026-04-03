import React, { useEffect, useState } from 'react';
import { Link } from '../router.jsx';
import { emitAppChange } from '../utils/live.js';
import { formatDateTime } from '../utils/date.js';
import RichTextEditor from './RichTextEditor.jsx';
import TranslatableHtml from './TranslatableHtml.jsx';
import AnimatedIcon from './AnimatedIcon.jsx';
import { isRichTextEmpty } from '../utils/richText.js';
import { useI18n } from '../utils/i18n.jsx';
import { useAuth } from '../utils/auth.jsx';
import { avatarAlt, postImageAlt } from '../utils/a11y.js';
import { openAlert, openConfirm } from '../utils/dialogs.js';

function PostActionIcon({ type, active = false }) {
  return <AnimatedIcon name={type === 'comment' ? 'message-square' : 'heart'} size={16} active={active} />;
}

export default function PostCard({ post, onRefresh, focused = false, postHref = '', defaultCommentsOpen = false }) {
  const { t } = useI18n();
  const { user } = useAuth();
  const [comment, setComment] = useState('');
  const [comments, setComments] = useState([]);
  const [showComments, setShowComments] = useState(Boolean(defaultCommentsOpen));
  const [showCommentForm, setShowCommentForm] = useState(Boolean(defaultCommentsOpen));
  const [editing, setEditing] = useState(false);
  const [editContent, setEditContent] = useState(post.content || '');
  const [postBusy, setPostBusy] = useState(false);
  const [liked, setLiked] = useState(!!post.liked);
  const [likeCount, setLikeCount] = useState(Number(post.likeCount || 0));
  const [commentCount, setCommentCount] = useState(Number(post.commentCount || 0));
  const [likeBusy, setLikeBusy] = useState(false);
  const [commentBusy, setCommentBusy] = useState(false);
  const [likePulse, setLikePulse] = useState(false);

  async function loadComments() {
    const res = await fetch(`/api/new/posts/${post.id}/comments`, { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    setComments(payload.items || []);
  }

  useEffect(() => {
    if (!focused) return;
    setShowComments(true);
    loadComments();
  }, [focused, post.id]);

  useEffect(() => {
    setShowComments(Boolean(defaultCommentsOpen));
    setShowCommentForm(Boolean(defaultCommentsOpen));
  }, [defaultCommentsOpen, post.id]);

  useEffect(() => {
    if (!showComments) return;
    loadComments();
  }, [showComments, post.commentCount]);

  useEffect(() => {
    if (!editing) setEditContent(post.content || '');
  }, [post.content, editing]);

  useEffect(() => {
    setLiked(!!post.liked);
    setLikeCount(Number(post.likeCount || 0));
    setCommentCount(Number(post.commentCount || 0));
  }, [post.liked, post.likeCount, post.commentCount]);

  async function toggleLike() {
    if (likeBusy) return;
    const prevLiked = liked;
    const prevCount = likeCount;
    const nextLiked = !prevLiked;
    setLikeBusy(true);
    setLiked(nextLiked);
    setLikeCount((count) => Math.max(0, count + (nextLiked ? 1 : -1)));
    if (nextLiked) {
      setLikePulse(true);
      window.setTimeout(() => setLikePulse(false), 720);
    }
    try {
      const res = await fetch(`/api/new/posts/${post.id}/like`, { method: 'POST', credentials: 'include' });
      if (!res.ok) throw new Error(await res.text());
      emitAppChange('post:liked', { postId: post.id });
    } catch {
      setLiked(prevLiked);
      setLikeCount(prevCount);
    } finally {
      setLikeBusy(false);
      setTimeout(() => onRefresh?.(), 1200);
    }
  }

  async function submitComment(e) {
    e.preventDefault();
    if (isRichTextEmpty(comment) || commentBusy) return;
    setCommentBusy(true);
    const optimisticId = `tmp-${Date.now()}`;
    const draft = comment;
    const optimisticComment = {
      id: optimisticId,
      user_id: user?.id || 0,
      kadi: user?.kadi || 'you',
      resim: user?.photo || '',
      comment: draft
    };
    try {
      setComment('');
      setShowComments(true);
      setShowCommentForm(true);
      setCommentCount((count) => count + 1);
      setComments((prev) => [...prev, optimisticComment]);
      const res = await fetch(`/api/new/posts/${post.id}/comments`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ comment: draft })
      });
      if (!res.ok) throw new Error(await res.text());
      emitAppChange('post:commented', { postId: post.id });
      await loadComments();
    } catch {
      setCommentCount((count) => Math.max(0, count - 1));
      setComments((prev) => prev.filter((c) => String(c.id) !== optimisticId));
      setComment(draft);
    } finally {
      setCommentBusy(false);
      setTimeout(() => onRefresh?.(), 1200);
    }
  }

  const authorId = Number(post.author?.id || post.user_id || 0) || null;
  const canManagePost = !!user?.id && Number(user.id) === Number(authorId);

  async function savePostEdit() {
    if (isRichTextEmpty(editContent)) return;
    setPostBusy(true);
    try {
      let res = await fetch(`/api/new/posts/${post.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ content: editContent })
      });
      if (!res.ok && (res.status === 404 || res.status === 405)) {
        res = await fetch(`/api/new/posts/${post.id}/edit`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({ content: editContent })
        });
      }
      if (!res.ok) throw new Error(await res.text());
      setEditing(false);
      emitAppChange('post:updated', { postId: post.id });
      onRefresh?.();
    } catch (err) {
      await openAlert({ title: t('post_update_failed'), message: err?.message || t('post_update_failed'), tone: 'error' });
    } finally {
      setPostBusy(false);
    }
  }

  async function deletePost() {
    if (!(await openConfirm({ title: t('delete'), message: t('post_confirm_delete'), confirmLabel: t('delete'), cancelLabel: t('close'), tone: 'error' }))) return;
    setPostBusy(true);
    try {
      let res = await fetch(`/api/new/posts/${post.id}`, {
        method: 'DELETE',
        credentials: 'include'
      });
      if (!res.ok && (res.status === 404 || res.status === 405)) {
        res = await fetch(`/api/new/posts/${post.id}/delete`, {
          method: 'POST',
          credentials: 'include'
        });
      }
      if (!res.ok) throw new Error(await res.text());
      emitAppChange('post:deleted', { postId: post.id });
      onRefresh?.();
    } catch (err) {
      await openAlert({ title: t('post_delete_failed'), message: err?.message || t('post_delete_failed'), tone: 'error' });
    } finally {
      setPostBusy(false);
    }
  }

  return (
    <article className={`post-card ${focused ? 'is-focused' : ''} ${showCommentForm ? 'is-conversing' : ''} ${likePulse ? 'is-like-pulsing' : ''}`}>
      <div className="post-header">
        {authorId ? (
          <Link to={`/new/members/${authorId}`} aria-label={`${post.author?.kadi || 'uye'} profiline git`}>
            <img className="avatar" src={post.author?.resim ? `/api/media/vesikalik/${post.author.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt={avatarAlt(post.author)} />
          </Link>
        ) : (
          <img className="avatar" src={post.author?.resim ? `/api/media/vesikalik/${post.author.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt={avatarAlt(post.author)} />
        )}
        <div>
          <div className="name">
            {post.author?.isim} {post.author?.soyisim}
            {post.author?.verified ? <span className="badge">✓</span> : null}
          </div>
          <div className="handle">@{post.author?.kadi}</div>
        </div>
        <div className="post-meta-col">
          <div className="meta">{formatDateTime(post.createdAt)}</div>
          {canManagePost ? (
            <div className="post-meta-actions">
              <button className="btn ghost" disabled={postBusy} onClick={() => setEditing((v) => !v)}>
                {editing ? t('close') : t('edit')}
              </button>
              <button className="btn ghost" disabled={postBusy} onClick={deletePost}>{postBusy ? t('deleting') : t('delete')}</button>
            </div>
          ) : null}
        </div>
      </div>
      <div className="post-body">
        {editing ? (
          <div className="comment-form">
            <RichTextEditor value={editContent} onChange={setEditContent} placeholder={t('group_post_placeholder')} minHeight={90} compact />
            <div className="post-edit-actions">
              <button className="btn ghost" onClick={() => { setEditing(false); setEditContent(post.content || ''); }} disabled={postBusy}>{t('close')}</button>
              <button className="btn primary" onClick={savePostEdit} disabled={postBusy || isRichTextEmpty(editContent)}>
                {postBusy ? t('saving') : t('save')}
              </button>
            </div>
          </div>
        ) : (
          <>
            {postHref ? (
              <Link className="post-body-link" to={postHref} aria-label={`Post #${post.id} detayını aç`}>
                <TranslatableHtml html={post.content || ''} contentClassName="post-rich-body" />
                {post.image || post.variants ? (
                  post.variants ? (
                    <img className="post-image"
                      src={post.variants.feedUrl}
                      srcSet={`${post.variants.thumbUrl} 200w, ${post.variants.feedUrl} 800w, ${post.variants.fullUrl} 1600w`}
                      sizes="(max-width: 600px) 200px, (max-width: 1200px) 800px, 1600px"
                      loading="lazy" alt={postImageAlt(post)} />
                  ) : (
                    <img className="post-image" src={post.image} loading="lazy" alt={postImageAlt(post)} />
                  )
                ) : null}
              </Link>
            ) : (
              <>
                <TranslatableHtml html={post.content || ''} contentClassName="post-rich-body" />
                {post.image || post.variants ? (
                  post.variants ? (
                    <img className="post-image"
                      src={post.variants.feedUrl}
                      srcSet={`${post.variants.thumbUrl} 200w, ${post.variants.feedUrl} 800w, ${post.variants.fullUrl} 1600w`}
                      sizes="(max-width: 600px) 200px, (max-width: 1200px) 800px, 1600px"
                      loading="lazy" alt={postImageAlt(post)} />
                  ) : (
                    <img className="post-image" src={post.image} loading="lazy" alt={postImageAlt(post)} />
                  )
                ) : null}
              </>
            )}
          </>
        )}
      </div>
      <div className="post-actions">
        <button
          className={`pill post-action-pill ${liked ? 'liked' : ''} ${likePulse ? 'is-pulsing' : ''}`}
          onClick={toggleLike}
          disabled={likeBusy}
          aria-pressed={liked}
        >
          <span className="post-action-icon"><PostActionIcon type="like" active={liked} /></span>
          <span>{likeCount}</span>
        </button>
        <button
          className={`pill post-action-pill ${showCommentForm ? 'is-open' : ''}`}
          onClick={() => {
            const next = !showCommentForm;
            setShowCommentForm(next);
            setShowComments(next);
            if (next) loadComments();
          }}
          aria-expanded={showCommentForm}
        >
          <span className="post-action-icon"><PostActionIcon type="comment" active={showCommentForm} /></span>
          <span>{commentCount}</span>
        </button>
      </div>
      {showCommentForm ? (
        <form className="comment-form" onSubmit={submitComment}>
          <RichTextEditor
            value={comment}
            onChange={setComment}
            placeholder={t('comment_placeholder')}
            minHeight={84}
            compact
          />
          <button className="btn primary" disabled={commentBusy}>{t('send')}</button>
        </form>
      ) : null}
      {showComments ? (
        <div className="comment-list">
          {comments.length === 0 ? <div className="muted">{t('no_comments_yet')}</div> : null}
          {comments.map((c) => (
            <div key={c.id} className="comment-line">
              <Link to={`/new/members/${c.user_id}`} aria-label={`${c.kadi || 'uye'} profiline git`}>
                <img className="avatar" src={c.resim ? `/api/media/vesikalik/${c.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt={avatarAlt(c)} />
              </Link>
              <div>
                <Link className="name" to={`/new/members/${c.user_id}`}>@{c.kadi}</Link>
                <TranslatableHtml html={c.comment || ''} />
              </div>
            </div>
          ))}
        </div>
      ) : null}
    </article>
  );
}
