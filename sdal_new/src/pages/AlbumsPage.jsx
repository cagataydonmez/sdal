import React, { useCallback, useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function AlbumsPage() {
  const { t } = useI18n();
  const [categories, setCategories] = useState([]);
  const [latest, setLatest] = useState([]);
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const sentinelRef = useRef(null);

  useEffect(() => {
    fetch('/api/albums', { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => setCategories(p.items || []))
      .catch(() => {});
    fetch('/api/album/latest?limit=24&offset=0', { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => {
        setLatest(p.items || []);
        setHasMore(!!p.hasMore);
      })
      .catch(() => {});
  }, []);

  const loadMore = useCallback(async () => {
    if (loadingMore || !hasMore) return;
    setLoadingMore(true);
    const res = await fetch(`/api/album/latest?limit=24&offset=${latest.length}`, { credentials: 'include' });
    if (!res.ok) {
      setLoadingMore(false);
      return;
    }
    const payload = await res.json();
    setLatest((prev) => {
      const ids = new Set(prev.map((x) => x.id));
      const merged = [...prev];
      for (const item of payload.items || []) if (!ids.has(item.id)) merged.push(item);
      return merged;
    });
    setHasMore(!!payload.hasMore);
    setLoadingMore(false);
  }, [latest.length, hasMore, loadingMore]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) loadMore();
    }, { rootMargin: '300px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [loadMore]);

  return (
    <Layout title={t('albums_title')}>
      <div className="panel">
        <h3>{t('albums_categories')}</h3>
        <div className="panel-body">
          {categories.map((c) => (
            <a key={c.id} className="chip" href={`/new/albums/${c.id}`}>{c.kategori}</a>
          ))}
          <a className="btn primary" href="/new/albums/upload">{t('albums_upload')}</a>
        </div>
      </div>
      <div className="photo-grid">
        {latest.map((p) => (
          <a key={p.id} href={`/new/albums/photo/${p.id}`}>
            <img src={`/api/media/kucukresim?width=200&file=${encodeURIComponent(p.dosyaadi)}`} alt="" />
          </a>
        ))}
      </div>
      <div ref={sentinelRef} />
      {loadingMore ? <div className="muted">{t('albums_loading_more')}</div> : null}
    </Layout>
  );
}
