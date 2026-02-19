import React, { useEffect, useState } from 'react';
import { emitAppChange } from '../utils/live.js';
import { formatDateTime } from '../utils/date.js';
import RichTextEditor from './RichTextEditor.jsx';
import TranslatableHtml from './TranslatableHtml.jsx';
import { isRichTextEmpty } from '../utils/richText.js';
import { useI18n } from '../utils/i18n.jsx';

export default function PostCard({ post, onRefresh, focused = false }) {
  const { t } = useI18n();
  const [comment, setComment] = useState('');
  const [comments, setComments] = useState([]);
  const [showComments, setShowComments] = useState(false);

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
    emitAppChange('post:commented', { postId: post.id });
    loadComments();
    onRefresh?.();
  }

  const authorId = Number(post.author?.id || post.user_id || 0) || null;

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
        <div className="meta">{formatDateTime(post.createdAt)}</div>
      </div>
      <div className="post-body">
        <TranslatableHtml html={post.content || ''} contentClassName="post-rich-body" />
        {post.image ? <img className="post-image" src={post.image} alt="" /> : null}
      </div>
      <div className="post-actions">
        <button className={post.liked ? 'pill liked' : 'pill'} onClick={toggleLike}>
          ♥ {post.likeCount}
        </button>
        <button className="pill" onClick={() => {
          const next = !showComments;
          setShowComments(next);
          if (next) loadComments();
        }}>
          💬 {post.commentCount}
        </button>
      </div>
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
