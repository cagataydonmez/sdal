import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';

export default function FollowingPage() {
  const [items, setItems] = useState([]);
  const [error, setError] = useState('');

  async function load() {
    const res = await fetch('/api/new/follows', { credentials: 'include' });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    const payload = await res.json();
    setItems(payload.items || []);
  }

  useEffect(() => {
    load();
  }, []);

  async function unfollow(id) {
    await fetch(`/api/new/follow/${id}`, { method: 'POST', credentials: 'include' });
    emitAppChange('follow:changed', { userId: id });
    load();
  }

  return (
    <Layout title="Takip Ettiklerim">
      <div className="list">
        {items.map((m) => (
          <div key={m.following_id} className="list-item">
            <a href={`/new/members/${m.following_id}`} className="verify-user">
              <img className="avatar" src={m.resim ? `/api/media/vesikalik/${m.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              <div>
                <div className="name">{m.isim} {m.soyisim}</div>
                <div className="meta">@{m.kadi}</div>
              </div>
            </a>
            <button className="btn ghost" onClick={() => unfollow(m.following_id)}>Takibi Bırak</button>
          </div>
        ))}
        {!items.length ? <div className="muted">Henüz takip ettiğin üye yok.</div> : null}
        {error ? <div className="error">{error}</div> : null}
      </div>
    </Layout>
  );
}
