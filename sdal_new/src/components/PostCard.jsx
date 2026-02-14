import React, { useEffect, useState } from 'react';
import { emitAppChange } from '../utils/live.js';
import { formatDateTime } from '../utils/date.js';
import { applyMention, detectMentionContext } from '../utils/mentions.js';

export default function PostCard({ post, onRefresh, focused = false }) {
  const [comment, setComment] = useState('');
  const [comments, setComments] = useState([]);
  const [showComments, setShowComments] = useState(false);
  const [followed, setFollowed] = useState([]);
  const [mentionCtx, setMentionCtx] = useState(null);

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

  async function loadFollowed() {
    if (followed.length) return;
    const res = await fetch('/api/new/follows', { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    setFollowed(payload.items || []);
  }

  function handleCommentChange(value, caretPos) {
    setComment(value);
    const nextCtx = detectMentionContext(value, caretPos);
    setMentionCtx(nextCtx);
    if (!nextCtx) return;
    loadFollowed();
  }

  function insertMention(kadi) {
    setComment((prev) => applyMention(prev, mentionCtx, kadi));
    setMentionCtx(null);
  }

  async function toggleLike() {
    await fetch(`/api/new/posts/${post.id}/like`, { method: 'POST', credentials: 'include' });
    emitAppChange('post:liked', { postId: post.id });
    onRefresh?.();
  }

  async function submitComment(e) {
    e.preventDefault();
    if (!comment.trim()) return;
    await fetch(`/api/new/posts/${post.id}/comments`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ comment })
    });
    setComment('');
    setShowComments(true);
    setMentionCtx(null);
    emitAppChange('post:commented', { postId: post.id });
    loadComments();
    onRefresh?.();
  }

  return (
    <article className="post-card">
      <div className="post-header">
        <img className="avatar" src={post.author?.resim ? `/api/media/vesikalik/${post.author.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
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
        <p dangerouslySetInnerHTML={{ __html: post.content || '' }} />
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
        <input value={comment} onChange={(e) => handleCommentChange(e.target.value, e.target.selectionStart)} placeholder="Yorum yaz..." />
        <button className="btn">Gönder</button>
      </form>
      {mentionCtx ? (
        <div className="mention-box">
          {followed
            .filter((u) => !mentionCtx.query || String(u.kadi || '').toLowerCase().startsWith(mentionCtx.query.toLowerCase()))
            .slice(0, 8)
            .map((u) => (
              <button key={u.following_id} type="button" className="mention-item" onClick={() => insertMention(u.kadi)}>
                @{u.kadi}
              </button>
            ))}
        </div>
      ) : null}
      {showComments ? (
        <div className="comment-list">
          {comments.length === 0 ? <div className="muted">Henüz yorum yok.</div> : null}
          {comments.map((c) => (
            <a key={c.id} className="comment-line" href={`/new/members/${c.user_id}`}>
              <img className="avatar" src={c.resim ? `/api/media/vesikalik/${c.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              <div>
                <div className="name">@{c.kadi}</div>
                <div dangerouslySetInnerHTML={{ __html: c.comment || '' }} />
              </div>
            </a>
          ))}
        </div>
      ) : null}
    </article>
  );
}
