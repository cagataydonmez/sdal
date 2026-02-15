import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';

export default function ExplorePage() {
  const [members, setMembers] = useState([]);
  const [suggestions, setSuggestions] = useState([]);
  const [followingIds, setFollowingIds] = useState(() => new Set());
  const [pendingFollow, setPendingFollow] = useState({});
  const [query, setQuery] = useState('');
  const [filters, setFilters] = useState({
    relation: 'all',
    verified: false,
    withPhoto: false,
    online: false,
    gradYear: '',
    sort: 'recommended'
  });
  const [loading, setLoading] = useState(false);
  const [loadingSuggestions, setLoadingSuggestions] = useState(false);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const sentinelRef = useRef(null);

  const yearNow = new Date().getFullYear();
  const yearOptions = useMemo(() => {
    const items = [];
    for (let y = yearNow + 1; y >= 1970; y -= 1) items.push(y);
    return items;
  }, [yearNow]);

  const load = useCallback(async (term = '', nextPage = 1, append = false, activeFilters = filters) => {
    setLoading(true);
    const params = new URLSearchParams();
    params.set('page', String(nextPage));
    params.set('pageSize', '30');
    params.set('excludeSelf', '1');
    params.set('term', term || '');
    params.set('sort', activeFilters.sort || 'recommended');
    if (activeFilters.relation !== 'all') params.set('relation', activeFilters.relation);
    if (activeFilters.verified) params.set('verified', '1');
    if (activeFilters.withPhoto) params.set('withPhoto', '1');
    if (activeFilters.online) params.set('online', '1');
    if (activeFilters.gradYear && Number(activeFilters.gradYear) > 0) params.set('gradYear', String(activeFilters.gradYear));

    const res = await fetch(`/api/members?${params.toString()}`, { credentials: 'include' });
    const payload = await res.json();
    setMembers((prev) => {
      const rows = payload.rows || [];
      if (!append) return rows;
      const ids = new Set(prev.map((x) => Number(x.id)));
      const merged = [...prev];
      for (const row of rows) {
        const key = Number(row.id);
        if (!ids.has(key)) merged.push(row);
      }
      return merged;
    });
    setPage(payload.page || nextPage);
    setPages(payload.pages || 1);
    setLoading(false);
  }, [filters]);

  const loadSuggestions = useCallback(async () => {
    setLoadingSuggestions(true);
    try {
      const res = await fetch('/api/new/explore/suggestions?limit=12', { credentials: 'include' });
      if (!res.ok) {
        setSuggestions([]);
        return;
      }
      const payload = await res.json();
      setSuggestions(payload.items || []);
    } finally {
      setLoadingSuggestions(false);
    }
  }, []);

  const loadFollows = useCallback(async () => {
    const res = await fetch('/api/new/follows', { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    const next = new Set((payload.items || []).map((item) => Number(item.following_id)));
    setFollowingIds(next);
  }, []);

  useEffect(() => {
    loadFollows();
    loadSuggestions();
  }, [loadFollows, loadSuggestions]);

  useEffect(() => {
    const timer = setTimeout(() => {
      load(query, 1, false, filters);
    }, 280);
    return () => clearTimeout(timer);
  }, [query, filters, load]);

  const loadMore = useCallback(() => {
    if (loading || page >= pages) return;
    load(query, page + 1, true, filters);
  }, [loading, page, pages, load, query, filters]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) loadMore();
    }, { rootMargin: '300px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [loadMore]);

  async function toggleFollow(id) {
    const key = Number(id);
    if (pendingFollow[key]) return;
    setPendingFollow((prev) => ({ ...prev, [key]: true }));
    try {
      const res = await fetch(`/api/new/follow/${id}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) return;
      setFollowingIds((prev) => {
        const next = new Set(prev);
        if (next.has(key)) next.delete(key);
        else next.add(key);
        return next;
      });
      setSuggestions((prev) => prev.filter((u) => Number(u.id) !== key));
      emitAppChange('follow:changed', { userId: id });
      loadSuggestions();
    } finally {
      setPendingFollow((prev) => ({ ...prev, [key]: false }));
    }
  }

  function setFilter(key, value) {
    setFilters((prev) => ({ ...prev, [key]: value }));
  }

  function renderMemberCard(m, showReasons = false) {
    return (
      <div className="member-card" key={`${showReasons ? 's' : 'm'}-${m.id}`}>
        <a href={`/new/members/${m.id}`}>
          <img src={m.resim ? `/api/media/vesikalik/${m.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
        </a>
        <div>
          <div className="name">
            {m.isim} {m.soyisim}
            {m.verified ? <span className="badge">✓</span> : null}
          </div>
          <div className="handle">@{m.kadi}</div>
          <div className="meta">{m.mezuniyetyili || ''}{Number(m.online || 0) === 1 ? ' · Online' : ''}</div>
          {showReasons && Array.isArray(m.reasons) && m.reasons.length ? (
            <div className="composer-actions">
              {m.reasons.slice(0, 2).map((r) => <span className="chip" key={`${m.id}-${r}`}>{r}</span>)}
            </div>
          ) : null}
        </div>
        <button
          className="btn ghost"
          onClick={() => toggleFollow(m.id)}
          disabled={Boolean(pendingFollow[Number(m.id)])}
        >
          {followingIds.has(Number(m.id)) ? 'Unfollow' : 'Follow'}
        </button>
      </div>
    );
  }

  return (
    <Layout title="Keşfet">
      <div className="panel">
        <div className="panel-body stack">
          <input
            className="search"
            placeholder="Üye ara..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <div className="composer-actions">
            <select className="input" value={filters.relation} onChange={(e) => setFilter('relation', e.target.value)}>
              <option value="all">Herkes</option>
              <option value="not_following">Takip Etmediklerim</option>
              <option value="following">Takip Ettiklerim</option>
            </select>
            <select className="input" value={filters.sort} onChange={(e) => setFilter('sort', e.target.value)}>
              <option value="recommended">Önerilen</option>
              <option value="engagement">Etkileşim Gücü</option>
              <option value="name">Ada Göre</option>
              <option value="recent">Yeni Üyeler</option>
              <option value="online">Online Önce</option>
              <option value="year">Mezuniyet Yılı</option>
            </select>
            <select className="input" value={filters.gradYear} onChange={(e) => setFilter('gradYear', e.target.value)}>
              <option value="">Tüm Yıllar</option>
              {yearOptions.map((y) => <option key={y} value={y}>{y}</option>)}
            </select>
            <label className="chip">
              <input type="checkbox" checked={filters.verified} onChange={(e) => setFilter('verified', e.target.checked)} />
              Verified
            </label>
            <label className="chip">
              <input type="checkbox" checked={filters.withPhoto} onChange={(e) => setFilter('withPhoto', e.target.checked)} />
              Fotoğraflı
            </label>
            <label className="chip">
              <input type="checkbox" checked={filters.online} onChange={(e) => setFilter('online', e.target.checked)} />
              Online
            </label>
          </div>
          {loading ? <div className="muted">Aranıyor...</div> : null}
        </div>
      </div>

      <div className="panel">
        <h3>Tanıyor Olabileceğin Kişiler</h3>
        <div className="panel-body">
          {loadingSuggestions ? <div className="muted">Öneriler hazırlanıyor...</div> : null}
          {!loadingSuggestions && suggestions.length === 0 ? <div className="muted">Şu an öneri bulunamadı.</div> : null}
          <div className="card-grid">
            {suggestions.map((m) => renderMemberCard(m, true))}
          </div>
        </div>
      </div>

      <div className="card-grid">
        {members.map((m) => renderMemberCard(m, false))}
      </div>
      <div ref={sentinelRef} />
      {loading ? <div className="muted">Yükleniyor...</div> : null}
      {!loading && page >= pages && members.length > 0 ? <div className="muted">Sonuçların sonu.</div> : null}
    </Layout>
  );
}
