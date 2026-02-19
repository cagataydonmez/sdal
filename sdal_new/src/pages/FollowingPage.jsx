import React, { useCallback, useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';
import { formatDateTime } from '../utils/date.js';

export default function FollowingPage() {
  const [items, setItems] = useState([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const sentinelRef = useRef(null);
  const itemsRef = useRef([]);
  const loadingRef = useRef(false);

  useEffect(() => {
    itemsRef.current = items;
  }, [items]);

  const load = useCallback(async (append = false) => {
    if (loadingRef.current) return;
    loadingRef.current = true;
    setLoading(true);
    const offset = append ? itemsRef.current.length : 0;
    const res = await fetch(`/api/new/follows?limit=24&offset=${offset}&sort=engagement`, { credentials: 'include' });
    if (!res.ok) {
      setError(await res.text());
      setLoading(false);
      loadingRef.current = false;
      return;
    }
    const payload = await res.json();
    const next = payload.items || [];
    setItems((prev) => (append ? [...prev, ...next] : next));
    setHasMore(Boolean(payload.hasMore));
    setLoading(false);
    loadingRef.current = false;
  }, []);

  useEffect(() => {
    load(false);
  }, [load]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting) && hasMore && !loading) {
        load(true);
      }
    }, { rootMargin: '340px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [load, hasMore, loading]);

  async function unfollow(id) {
    await fetch(`/api/new/follow/${id}`, { method: 'POST', credentials: 'include' });
    emitAppChange('follow:changed', { userId: id });
    load(false);
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
                <div className="meta">
                  Skor: {Number(m.engagement_score || 0).toFixed(1)} • Takip: {m.followed_at ? formatDateTime(m.followed_at) : '-'}
                </div>
              </div>
            </a>
            <button className="btn ghost" onClick={() => unfollow(m.following_id)}>Takibi Bırak</button>
          </div>
        ))}
        <div ref={sentinelRef} />
        {loading ? <div className="muted">Yükleniyor...</div> : null}
        {!hasMore && items.length > 0 ? <div className="muted">Tüm takiplerin yüklendi.</div> : null}
        {!items.length ? <div className="muted">Henüz takip ettiğin üye yok.</div> : null}
        {error ? <div className="error">{error}</div> : null}
      </div>
    </Layout>
  );
}
