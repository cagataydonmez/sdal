import React, { useEffect, useState } from 'react';
import { emitAppChange } from '../utils/live.js';
import { formatDateTime } from '../utils/date.js';
import RichTextEditor from './RichTextEditor.jsx';
import TranslatableHtml from './TranslatableHtml.jsx';
import { isRichTextEmpty } from '../utils/richText.js';
import { useI18n } from '../utils/i18n.jsx';
import { useAuth } from '../utils/auth.jsx';

export default function PostCard({ post, onRefresh, focused = false }) {
  const { t } = useI18n();
  const { user } = useAuth();
  const [comment, setComment] = useState('');
  const [comments, setComments] = useState([]);
  const [showComments, setShowComments] = useState(false);
  const [showCommentForm, setShowCommentForm] = useState(false);
  const [editing, setEditing] = useState(false);
  const [editContent, setEditContent] = useState(post.content || '');
  const [postBusy, setPostBusy] = useState(false);

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
    if (!showComments) return;
    loadComments();
  }, [showComments, post.commentCount]);

  useEffect(() => {
    if (!editing) setEditContent(post.content || '');
  }, [post.content, editing]);

  async function toggleLike() {
    await fetch(`/api/new/posts/${post.id}/like`, { method: 'POST', credentials: 'include' });
    emitAppChange('post:liked', { postId: post.id });
    onRefresh?.();
  }

  async function submitComment(e) {
    e.preventDefault();
    if (isRichTextEmpty(comment)) return;
    await fetch(`/api/new/posts/${post.id}/comments`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ comment })
    });
    setComment('');
    setShowComments(true);
    setShowCommentForm(true);
    emitAppChange('post:commented', { postId: post.id });
    loadComments();
    onRefresh?.();
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
      window.alert(err?.message || t('post_update_failed'));
    } finally {
      setPostBusy(false);
    }
  }

  async function deletePost() {
    if (!window.confirm(t('post_confirm_delete'))) return;
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
      window.alert(err?.message || t('post_delete_failed'));
    } finally {
      setPostBusy(false);
    }
  }

  return (
    <article className="post-card">
      <div className="post-header">
        {authorId ? (
          <a href={`/new/members/${authorId}`} aria-label={`${post.author?.kadi || 'uye'} profiline git`}>
            <img className="avatar" src={post.author?.resim ? `/api/media/vesikalik/${post.author.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
          </a>
        ) : (
          <img className="avatar" src={post.author?.resim ? `/api/media/vesikalik/${post.author.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
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
          <TranslatableHtml html={post.content || ''} contentClassName="post-rich-body" />
        )}
        {post.image ? <img className="post-image" src={post.image} alt="" /> : null}
      </div>
      <div className="post-actions">
        <button className={post.liked ? 'pill liked' : 'pill'} onClick={toggleLike}>
          ♥ {post.likeCount}
        </button>
        <button className="pill" onClick={() => {
          const next = !showCommentForm;
          setShowCommentForm(next);
          setShowComments(next);
          if (next) loadComments();
        }}>
          💬 {post.commentCount}
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
          <button className="btn">{t('send')}</button>
        </form>
      ) : null}
      {showComments ? (
        <div className="comment-list">
          {comments.length === 0 ? <div className="muted">{t('no_comments_yet')}</div> : null}
          {comments.map((c) => (
            <div key={c.id} className="comment-line">
              <a href={`/new/members/${c.user_id}`} aria-label={`${c.kadi || 'uye'} profiline git`}>
                <img className="avatar" src={c.resim ? `/api/media/vesikalik/${c.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              </a>
              <div>
                <a className="name" href={`/new/members/${c.user_id}`}>@{c.kadi}</a>
                <TranslatableHtml html={c.comment || ''} />
              </div>
            </div>
          ))}
        </div>
      ) : null}
    </article>
  );
}
