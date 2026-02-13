import React, { useState } from 'react';

export default function PostComposer({ onPost }) {
  const [content, setContent] = useState('');
  const [image, setImage] = useState(null);
  const [filter, setFilter] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

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
        onChange={(e) => setContent(e.target.value)}
      />
      <div className="composer-actions">
        <input type="file" accept="image/*" onChange={(e) => setImage(e.target.files?.[0] || null)} />
        <select className="input" value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="">Filtre yok</option>
          <option value="grayscale">Siyah Beyaz</option>
          <option value="sepia">Sepya</option>
          <option value="vivid">Canlı</option>
          <option value="cool">Soğuk</option>
          <option value="warm">Sıcak</option>
          <option value="blur">Blur</option>
          <option value="sharp">Sharp</option>
        </select>
        <button className="btn primary" disabled={loading}>Paylaş</button>
      </div>
      {error ? <div className="error">{error}</div> : null}
    </form>
  );
}
