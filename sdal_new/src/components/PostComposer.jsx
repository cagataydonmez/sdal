import React, { useState } from 'react';
import { emitAppChange } from '../utils/live.js';
import { applyMention, detectMentionContext } from '../utils/mentions.js';

const FILTERS = [
  { key: '', label: 'Filtre Yok' },
  { key: 'grayscale', label: 'Siyah Beyaz' },
  { key: 'sepia', label: 'Sepya' },
  { key: 'vivid', label: 'Canlı' },
  { key: 'cool', label: 'Soğuk' },
  { key: 'warm', label: 'Sıcak' },
  { key: 'blur', label: 'Blur' },
  { key: 'sharp', label: 'Sharp' }
];

export default function PostComposer({ onPost }) {
  const [content, setContent] = useState('');
  const [image, setImage] = useState(null);
  const [filter, setFilter] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [followed, setFollowed] = useState([]);
  const [mentionCtx, setMentionCtx] = useState(null);

  async function loadFollowed() {
    if (followed.length) return;
    const res = await fetch('/api/new/follows', { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    setFollowed(payload.items || []);
  }

  function handleContentChange(value, caretPos) {
    setContent(value);
    const nextCtx = detectMentionContext(value, caretPos);
    setMentionCtx(nextCtx);
    if (!nextCtx) return;
    loadFollowed();
  }

  function insertMention(kadi) {
    setContent((prev) => applyMention(prev, mentionCtx, kadi));
    setMentionCtx(null);
  }

  async function submit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      if (image) {
        const form = new FormData();
        form.append('content', content);
        form.append('image', image);
        form.append('filter', filter);
        const res = await fetch('/api/new/posts/upload', {
          method: 'POST',
          credentials: 'include',
          body: form
        });
        if (!res.ok) throw new Error(await res.text());
      } else {
        const res = await fetch('/api/new/posts', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({ content })
        });
        if (!res.ok) throw new Error(await res.text());
      }
      setContent('');
      setImage(null);
      setFilter('');
      emitAppChange('post:created');
      onPost?.();
    } catch (err) {
      setError(err.message || 'Paylaşım başarısız.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <form className="composer" onSubmit={submit}>
      <textarea
        placeholder="Bugün neler oluyor?"
        value={content}
        onChange={(e) => handleContentChange(e.target.value, e.target.selectionStart)}
      />
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
      <div className="composer-actions">
        <input type="file" accept="image/*" onChange={(e) => setImage(e.target.files?.[0] || null)} />
        <button className="btn primary" disabled={loading}>Paylaş</button>
      </div>
      {image ? (
        <div className="filter-grid">
          {FILTERS.map((f) => (
            <button
              key={f.key || 'none'}
              type="button"
              className={`chip ${filter === f.key ? 'chip-active' : ''}`}
              onClick={() => setFilter(f.key)}
            >
              {f.label}
            </button>
          ))}
        </div>
      ) : null}
      {error ? <div className="error">{error}</div> : null}
    </form>
  );
}
