import React, { useCallback, useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';

export default function ExplorePage() {
  const [members, setMembers] = useState([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const sentinelRef = useRef(null);

  const load = useCallback(async (term = '', nextPage = 1, append = false) => {
    setLoading(true);
    const res = await fetch(`/api/members?page=${nextPage}&pageSize=30&term=${encodeURIComponent(term)}`, { credentials: 'include' });
    const payload = await res.json();
    setMembers((prev) => (append ? [...prev, ...(payload.rows || [])] : (payload.rows || [])));
    setPage(payload.page || nextPage);
    setPages(payload.pages || 1);
    setLoading(false);
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => {
      load(query, 1, false);
    }, 250);
    return () => clearTimeout(timer);
  }, [query, load]);

  const loadMore = useCallback(() => {
    if (loading || page >= pages) return;
    load(query, page + 1, true);
  }, [loading, page, pages, load, query]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) loadMore();
    }, { rootMargin: '300px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [loadMore]);

  async function follow(id) {
    await fetch(`/api/new/follow/${id}`, { method: 'POST', credentials: 'include' });
    emitAppChange('follow:changed', { userId: id });
  }

  return (
    <Layout title="Keşfet">
      <div className="panel">
        <div className="panel-body">
          <input
            className="search"
            placeholder="Üye ara..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          {loading ? <div className="muted">Aranıyor...</div> : null}
        </div>
      </div>
      <div className="card-grid">
        {members.map((m) => (
          <div className="member-card" key={m.id}>
            <a href={`/new/members/${m.id}`}>
              <img src={m.resim ? `/api/media/vesikalik/${m.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
            </a>
            <div>
              <div className="name">
                {m.isim} {m.soyisim}
                {m.verified ? <span className="badge">✓</span> : null}
              </div>
              <div className="handle">@{m.kadi}</div>
              <div className="meta">{m.mezuniyetyili || ''}</div>
            </div>
            <button className="btn ghost" onClick={() => follow(m.id)}>Takip</button>
          </div>
        ))}
      </div>
      <div ref={sentinelRef} />
      {loading ? <div className="muted">Yükleniyor...</div> : null}
      {!loading && page >= pages && members.length > 0 ? <div className="muted">Sonuçların sonu.</div> : null}
    </Layout>
  );
}
