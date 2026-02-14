import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';

export default function AlbumPhotoPage() {
  const { id } = useParams();
  const [photo, setPhoto] = useState(null);
  const [comments, setComments] = useState([]);
  const [comment, setComment] = useState('');
  const [error, setError] = useState('');

  async function load() {
    const res = await fetch(`/api/photos/${id}`, { credentials: 'include' });
    if (!res.ok) return;
    const data = await res.json();
    setPhoto(data.row || null);
    setComments(data.comments || []);
  }

  useEffect(() => {
    load();
  }, [id]);

  async function submit(e) {
    e.preventDefault();
    setError('');
    const res = await fetch(`/api/photos/${id}/comments`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ yorum: comment })
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setComment('');
    load();
  }

  if (!photo) return <Layout title="Fotoğraf">Yükleniyor...</Layout>;

  return (
    <Layout title={photo.baslik || 'Fotoğraf'}>
      <div className="panel">
        <img className="post-image" src={`/api/media/kucukresim?width=900&file=${encodeURIComponent(photo.dosyaadi)}`} alt="" />
        <div className="panel-body">
          <div className="meta">{photo.tarih ? new Date(photo.tarih).toLocaleString() : ''}</div>
          <div>{photo.aciklama}</div>
        </div>
      </div>
      <div className="panel">
        <div className="panel-body">
          <form className="stack" onSubmit={submit}>
            <textarea className="input" placeholder="Yorum yaz..." value={comment} onChange={(e) => setComment(e.target.value)} />
            <button className="btn">Yorum Ekle</button>
            {error ? <div className="error">{error}</div> : null}
          </form>
        </div>
      </div>
      <div className="panel">
        <h3>Yorumlar</h3>
        <div className="panel-body">
          {comments.map((c) => (
            <div key={c.id} className="list-item">
              <div>
                <div className="name">{c.uyeadi}</div>
                <div className="meta">{c.tarih ? new Date(c.tarih).toLocaleString() : ''}</div>
              </div>
              <div>{c.yorum}</div>
            </div>
          ))}
        </div>
      </div>
    </Layout>
  );
}
