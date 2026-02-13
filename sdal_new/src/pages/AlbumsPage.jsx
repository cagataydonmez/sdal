import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';

export default function AlbumsPage() {
  const [categories, setCategories] = useState([]);
  const [latest, setLatest] = useState([]);

  useEffect(() => {
    fetch('/api/albums', { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => setCategories(p.items || []))
      .catch(() => {});
    fetch('/api/album/latest?limit=24', { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => setLatest(p.items || []))
      .catch(() => {});
  }, []);

  return (
    <Layout title="Fotoğraflar">
      <div className="panel">
        <h3>Kategoriler</h3>
        <div className="panel-body">
          {categories.map((c) => (
            <a key={c.id} className="chip" href={`/album/${c.id}`}>{c.kategori}</a>
          ))}
          <a className="btn primary" href="/album/yeni">Fotoğraf Yükle</a>
        </div>
      </div>
      <div className="photo-grid">
        {latest.map((p) => (
          <a key={p.id} href={`/album/foto/${p.id}`}>
            <img src={`/api/media/kucukresim?width=200&file=${encodeURIComponent(p.dosyaadi)}`} alt="" />
          </a>
        ))}
      </div>
    </Layout>
  );
}
