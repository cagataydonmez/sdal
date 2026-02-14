import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';

export default function AlbumCategoryPage() {
  const { id } = useParams();
  const [category, setCategory] = useState(null);
  const [photos, setPhotos] = useState([]);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);

  useEffect(() => {
    fetch(`/api/albums/${id}?page=${page}`, { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => {
        setCategory(p.category || null);
        setPhotos(p.photos || []);
        setPages(p.pages || 1);
      })
      .catch(() => {});
  }, [id, page]);

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
      <div className="panel">
        <div className="panel-body">
          <button className="btn ghost" disabled={page <= 1} onClick={() => setPage((prev) => Math.max(prev - 1, 1))}>Önceki</button>
          <span className="muted">Sayfa {page} / {pages}</span>
          <button className="btn ghost" disabled={page >= pages} onClick={() => setPage((prev) => Math.min(prev + 1, pages))}>Sonraki</button>
        </div>
      </div>
    </Layout>
  );
}
