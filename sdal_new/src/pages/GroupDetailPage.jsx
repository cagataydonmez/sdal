import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import PostCard from '../components/PostCard.jsx';

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

export default function GroupDetailPage() {
  const { id } = useParams();
  const [group, setGroup] = useState(null);
  const [members, setMembers] = useState([]);
  const [posts, setPosts] = useState([]);
  const [content, setContent] = useState('');
  const [filter, setFilter] = useState('');
  const [image, setImage] = useState(null);

  async function load() {
    const data = await apiJson(`/api/new/groups/${id}`);
    setGroup(data.group);
    setMembers(data.members || []);
    setPosts(data.posts || []);
  }

  useEffect(() => {
    load();
  }, [id]);

  async function submit(e) {
    e.preventDefault();
    if (image) {
      const form = new FormData();
      form.append('content', content);
      form.append('filter', filter);
      form.append('image', image);
      await fetch(`/api/new/groups/${id}/posts/upload`, { method: 'POST', credentials: 'include', body: form });
    } else {
      await apiJson(`/api/new/groups/${id}/posts`, { method: 'POST', body: JSON.stringify({ content }) });
    }
    setContent('');
    setImage(null);
    setFilter('');
    load();
  }

  if (!group) {
    return <Layout title="Grup">Yükleniyor...</Layout>;
  }

  return (
    <Layout title={group.name}>
      <div className="panel">
        <h3>{group.name}</h3>
        <div className="panel-body">{group.description}</div>
      </div>
      <div className="panel">
        <div className="panel-body">
          <form onSubmit={submit} className="stack">
            <textarea className="input" placeholder="Gruba bir şey yaz..." value={content} onChange={(e) => setContent(e.target.value)} />
            <div className="composer-actions">
              <input type="file" accept="image/*" onChange={(e) => setImage(e.target.files?.[0] || null)} />
              <select className="input" value={filter} onChange={(e) => setFilter(e.target.value)}>
                <option value="">Filtre yok</option>
                <option value="grayscale">Siyah Beyaz</option>
                <option value="sepia">Sepya</option>
                <option value="vivid">Canlı</option>
                <option value="cool">Soğuk</option>
                <option value="warm">Sıcak</option>
                <option value="blur">Blur</option>
                <option value="sharp">Sharp</option>
              </select>
              <button className="btn primary">Paylaş</button>
            </div>
          </form>
        </div>
      </div>
      <div className="grid">
        <div className="col-main">
          {posts.map((p) => (
            <PostCard key={p.id} post={{
              ...p,
              author: {
                id: p.user_id,
                kadi: p.kadi,
                isim: p.isim,
                soyisim: p.soyisim,
                resim: p.resim,
                verified: p.verified
              },
              likeCount: 0,
              commentCount: 0,
              liked: false
            }} onRefresh={load} />
          ))}
        </div>
        <div className="col-side">
          <div className="panel">
            <h3>Üyeler</h3>
            <div className="panel-body">
              {members.map((m) => (
                <div key={m.id} className="notif">
                  <img className="avatar" src={m.resim ? `/api/media/vesikalik/${m.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                  <div>
                    <b>{m.isim} {m.soyisim}</b>{m.verified ? <span className="badge">✓</span> : null}
                    <div className="meta">@{m.kadi}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
}
