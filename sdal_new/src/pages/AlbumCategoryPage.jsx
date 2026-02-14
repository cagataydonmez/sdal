import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';

export default function AlbumCategoryPage() {
  const { id } = useParams();
  const [category, setCategory] = useState(null);
  const [photos, setPhotos] = useState([]);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const [loading, setLoading] = useState(false);
  const sentinelRef = useRef(null);

  const load = useCallback((nextPage = 1, append = false) => {
    setLoading(true);
    fetch(`/api/albums/${id}?page=${nextPage}&pageSize=24`, { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => {
        setCategory(p.category || null);
        setPhotos((prev) => (append ? [...prev, ...(p.photos || [])] : (p.photos || [])));
        setPage(p.page || nextPage);
        setPages(p.pages || 1);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [id]);

  useEffect(() => {
    load(1, false);
  }, [id, load]);

  const loadMore = useCallback(() => {
    if (loading || page >= pages) return;
    load(page + 1, true);
  }, [loading, page, pages, load]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) loadMore();
    }, { rootMargin: '300px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [loadMore]);

  if (!category) return <Layout title="Albüm">Yükleniyor...</Layout>;

  return (
    <Layout title={category.kategori}>
      <div className="panel">
        <div className="panel-body">{category.aciklama}</div>
      </div>
      <div className="photo-grid">
        {photos.map((p) => (
          <a key={p.id} href={`/new/albums/photo/${p.id}`}>
            <img src={`/api/media/kucukresim?width=260&file=${encodeURIComponent(p.dosyaadi)}`} alt="" />
          </a>
        ))}
      </div>
      <div ref={sentinelRef} />
      {loading ? <div className="muted">Yükleniyor...</div> : null}
      {!loading && page >= pages && photos.length > 0 ? <div className="muted">Tüm fotoğraflar yüklendi.</div> : null}
    </Layout>
  );
}
