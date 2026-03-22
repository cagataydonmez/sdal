import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Link } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';
import { useI18n } from '../utils/i18n.jsx';
import { NETWORKING_EVENTS } from '../utils/networkingRegistry.js';
import { avatarAlt } from '../utils/a11y.js';

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
      emitAppChange(NETWORKING_EVENTS.followChanged, { userId: id });
    } finally {
      setPendingFollow((prev) => ({ ...prev, [key]: false }));
    }
  }

  const featuredMember = items[0] || null;
  const directoryMembers = featuredMember ? items.slice(1) : items;

  return (
    <Layout title={t('explore_suggestions_title')}>
      <section className="suggestions-directory">
        {featuredMember ? (
          <article className="suggestions-directory-feature">
            <Link className="suggestions-directory-feature-avatar" to={`/new/members/${featuredMember.id}`}>
              <img
                src={featuredMember.resim ? `/api/media/vesikalik/${featuredMember.resim}` : '/legacy/vesikalik/nophoto.jpg'}
                alt={avatarAlt(featuredMember)}
              />
            </Link>
            <div className="suggestions-directory-feature-body">
              <div className="suggestions-directory-kicker">{t('explore_suggestions_title')}</div>
              <Link className="suggestions-directory-name" to={`/new/members/${featuredMember.id}`}>
                {featuredMember.isim} {featuredMember.soyisim}
                {featuredMember.verified ? <span className="badge">✓</span> : null}
              </Link>
              <div className="handle">@{featuredMember.kadi}</div>
              <div className="meta">
                {featuredMember.mezuniyetyili || ''}
                {Number(featuredMember.online || 0) === 1 ? ` · ${t('status_online')}` : ''}
              </div>
            </div>
            <div className="suggestions-directory-feature-actions">
              <button
                className="btn ghost"
                onClick={() => toggleFollow(featuredMember.id)}
                disabled={Boolean(pendingFollow[Number(featuredMember.id)])}
              >
                {followingIds.has(Number(featuredMember.id)) ? t('unfollow') : t('follow')}
              </button>
            </div>
          </article>
        ) : null}

        <div className="suggestions-directory-list" role="list">
          {directoryMembers.map((m, index) => (
            <article className="suggestions-directory-row" key={m.id} role="listitem">
              <div className="suggestions-directory-rank" aria-hidden="true">
                {String(index + (featuredMember ? 2 : 1)).padStart(2, '0')}
              </div>
              <Link className="suggestions-directory-row-main" to={`/new/members/${m.id}`}>
                <img src={m.resim ? `/api/media/vesikalik/${m.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt={avatarAlt(m)} />
                <div className="suggestions-directory-row-copy">
                  <div className="name">
                    {m.isim} {m.soyisim}
                    {m.verified ? <span className="badge">✓</span> : null}
                  </div>
                  <div className="handle">@{m.kadi}</div>
                  <div className="meta">
                    {m.mezuniyetyili || ''}
                    {Number(m.online || 0) === 1 ? ` · ${t('status_online')}` : ''}
                  </div>
                </div>
              </Link>
              <button className="btn ghost" onClick={() => toggleFollow(m.id)} disabled={Boolean(pendingFollow[Number(m.id)])}>
                {followingIds.has(Number(m.id)) ? t('unfollow') : t('follow')}
              </button>
            </article>
          ))}
        </div>

        <div ref={sentinelRef} />
        {loading ? <div className="muted suggestions-directory-state">{t('loading')}</div> : null}
        {!hasMore && items.length > 0 ? (
          <div className="muted suggestions-directory-state">{t('explore_suggestions_all_loaded')}</div>
        ) : null}
      </section>
    </Layout>
  );
}
