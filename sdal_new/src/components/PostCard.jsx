import React, { useEffect, useState } from 'react';
import { emitAppChange } from '../utils/live.js';

export default function PostCard({ post, onRefresh, focused = false }) {
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
    if (!comment.trim()) return;
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
        <div className="meta">{new Date(post.createdAt).toLocaleString()}</div>
      </div>
      <div className="post-body">
        <p>{post.content}</p>
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
        <input value={comment} onChange={(e) => setComment(e.target.value)} placeholder="Yorum yaz..." />
        <button className="btn">Gönder</button>
      </form>
      {showComments ? (
        <div className="comment-list">
          {comments.length === 0 ? <div className="muted">Henüz yorum yok.</div> : null}
          {comments.map((c) => (
            <a key={c.id} className="comment-line" href={`/new/members/${c.user_id}`}>
              <img className="avatar" src={c.resim ? `/api/media/vesikalik/${c.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              <div>
                <div className="name">@{c.kadi}</div>
                <div>{c.comment}</div>
              </div>
            </a>
          ))}
        </div>
      ) : null}
    </article>
  );
}
