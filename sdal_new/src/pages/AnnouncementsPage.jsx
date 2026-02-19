import React, { useCallback, useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import { formatDateTime } from '../utils/date.js';

async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    credentials: 'include',
    ...options
  });
  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Request failed: ${res.status}`);
  }
  return res.json();
}

function mergeUniqueById(prev, next) {
  const map = new Map();
  for (const item of prev || []) map.set(item.id, item);
  for (const item of next || []) map.set(item.id, item);
  return Array.from(map.values());
}

export default function AnnouncementsPage() {
  const { user } = useAuth();
  const [items, setItems] = useState([]);
  const [form, setForm] = useState({ title: '', body: '' });
  const [imageFile, setImageFile] = useState(null);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const sentinelRef = useRef(null);
  const itemsRef = useRef([]);
  const loadingMoreRef = useRef(false);
  const isAdmin = user?.admin === 1;

  useEffect(() => {
    itemsRef.current = items;
  }, [items]);

  const load = useCallback(async (offset = 0, append = false) => {
    const data = await apiJson(`/api/new/announcements?limit=15&offset=${offset}`);
    const rows = data.items || [];
    setItems((prev) => (append ? mergeUniqueById(prev, rows) : mergeUniqueById([], rows)));
    setHasMore(!!data.hasMore);
  }, []);

  useEffect(() => {
    load(0, false);
  }, [load]);

  const loadMore = useCallback(async () => {
    if (loadingMoreRef.current || loadingMore || !hasMore) return;
    loadingMoreRef.current = true;
    setLoadingMore(true);
    await load(itemsRef.current.length, true);
    setLoadingMore(false);
    loadingMoreRef.current = false;
  }, [loadingMore, hasMore, load]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) loadMore();
    }, { rootMargin: '300px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [loadMore]);

  async function create() {
    setError('');
    setStatus('');
    try {
      if (imageFile) {
        const payload = new FormData();
        payload.append('title', form.title);
        payload.append('body', form.body);
        payload.append('image', imageFile);
        const res = await fetch('/api/new/announcements/upload', {
          method: 'POST',
          credentials: 'include',
          body: payload
        });
        if (!res.ok) throw new Error(await res.text());
      } else {
        await apiJson('/api/new/announcements', { method: 'POST', body: JSON.stringify(form) });
      }
      setForm({ title: '', body: '' });
      setImageFile(null);
      setStatus(isAdmin ? 'Duyuru yayınlandı.' : 'Duyuru önerin admin onayına gönderildi.');
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function approve(id, approved) {
    await apiJson(`/api/new/announcements/${id}/approve`, { method: 'POST', body: JSON.stringify({ approved: approved ? 1 : 0 }) });
    load();
  }

  async function remove(id) {
    await apiJson(`/api/new/announcements/${id}`, { method: 'DELETE' });
    load();
  }

  return (
    <Layout title="Duyurular">
      <div className="panel">
        <h3>{isAdmin ? 'Yeni Duyuru' : 'Duyuru Önerisi'}</h3>
        <div className="panel-body">
          <input className="input" placeholder="Başlık" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          <textarea className="input" placeholder="Duyuru metni" value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} />
          <input type="file" accept="image/*" onChange={(e) => setImageFile(e.target.files?.[0] || null)} />
          <button className="btn primary" onClick={create}>{isAdmin ? 'Yayınla' : 'Öner'}</button>
          {status ? <div className="muted">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>

      <div className="stack">
        {items.map((a) => (
          <div key={a.id} className="panel">
            <h3>{a.title}</h3>
            <div className="panel-body">
              {a.image ? <img className="post-image" src={a.image} alt="" /> : null}
              <div dangerouslySetInnerHTML={{ __html: a.body || '' }} />
              <div className="meta">{formatDateTime(a.created_at)} · @{a.creator_kadi || 'uye'} {Number(a.approved || 0) === 1 ? '' : '· Onay bekliyor'}</div>
              {isAdmin ? (
                <div className="composer-actions">
                  {Number(a.approved || 0) !== 1 ? <button className="btn" onClick={() => approve(a.id, true)}>Onayla</button> : null}
                  {Number(a.approved || 0) !== 0 ? <button className="btn ghost" title="Reddetmek duyurunun yayınlanmaması anlamına gelir." onClick={() => approve(a.id, false)}>Reddet (Yayınlama)</button> : null}
                  <button className="btn ghost" onClick={() => remove(a.id)}>Sil</button>
                </div>
              ) : null}
            </div>
          </div>
        ))}
      </div>
      <div ref={sentinelRef} />
      {loadingMore ? <div className="muted">Daha fazla duyuru yükleniyor...</div> : null}
    </Layout>
  );
}
