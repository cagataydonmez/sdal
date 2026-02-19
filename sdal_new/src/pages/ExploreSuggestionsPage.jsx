import React, { useCallback, useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';
import { useI18n } from '../utils/i18n.jsx';

const PAGE_SIZE = 24;

export default function ExploreSuggestionsPage() {
  const { t } = useI18n();
  const [items, setItems] = useState([]);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(false);
  const [followingIds, setFollowingIds] = useState(() => new Set());
  const [pendingFollow, setPendingFollow] = useState({});
  const sentinelRef = useRef(null);
  const itemsRef = useRef([]);
  const loadingRef = useRef(false);

  useEffect(() => {
    itemsRef.current = items;
  }, [items]);

  const loadFollows = useCallback(async () => {
    const res = await fetch('/api/new/follows?limit=200&offset=0', { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    setFollowingIds(new Set((payload.items || []).map((x) => Number(x.following_id))));
  }, []);

  const load = useCallback(async (append = false) => {
    if (loadingRef.current) return;
    loadingRef.current = true;
    setLoading(true);
    const offset = append ? itemsRef.current.length : 0;
    const res = await fetch(`/api/new/explore/suggestions?limit=${PAGE_SIZE}&offset=${offset}`, { credentials: 'include' });
    if (!res.ok) {
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
    loadFollows();
  }, [load, loadFollows]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting) && hasMore && !loading) {
        load(true);
      }
    }, { rootMargin: '320px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [hasMore, load, loading]);

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
      emitAppChange('follow:changed', { userId: id });
    } finally {
      setPendingFollow((prev) => ({ ...prev, [key]: false }));
    }
  }

  return (
    <Layout title={t('explore_suggestions_title')}>
      <div className="card-grid">
        {items.map((m) => (
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
              <div className="meta">{m.mezuniyetyili || ''}{Number(m.online || 0) === 1 ? ` · ${t('status_online')}` : ''}</div>
            </div>
            <button className="btn ghost" onClick={() => toggleFollow(m.id)} disabled={Boolean(pendingFollow[Number(m.id)])}>
              {followingIds.has(Number(m.id)) ? t('unfollow') : t('follow')}
            </button>
          </div>
        ))}
      </div>
      <div ref={sentinelRef} />
      {loading ? <div className="muted">{t('loading')}</div> : null}
      {!hasMore && items.length > 0 ? <div className="muted">{t('explore_suggestions_all_loaded')}</div> : null}
    </Layout>
  );
}
