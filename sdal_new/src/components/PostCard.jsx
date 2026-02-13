import React, { useState } from 'react';

export default function PostCard({ post, onRefresh }) {
  const [comment, setComment] = useState('');

  async function toggleLike() {
    await fetch(`/api/new/posts/${post.id}/like`, { method: 'POST', credentials: 'include' });
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
        <div className="pill">💬 {post.commentCount}</div>
      </div>
      <form className="comment-form" onSubmit={submitComment}>
        <input value={comment} onChange={(e) => setComment(e.target.value)} placeholder="Yorum yaz..." />
        <button className="btn">Gönder</button>
      </form>
    </article>
  );
}
