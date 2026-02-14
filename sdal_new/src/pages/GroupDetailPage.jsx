import React, { useEffect, useMemo, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import PostCard from '../components/PostCard.jsx';
import { useAuth } from '../utils/auth.jsx';
import { applyMention, detectMentionContext, fetchMentionCandidates } from '../utils/mentions.js';

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
  const { user } = useAuth();
  const [group, setGroup] = useState(null);
  const [members, setMembers] = useState([]);
  const [posts, setPosts] = useState([]);
  const [content, setContent] = useState('');
  const [filter, setFilter] = useState('');
  const [image, setImage] = useState(null);
  const [coverFile, setCoverFile] = useState(null);
  const [status, setStatus] = useState('');
  const [mentionUsers, setMentionUsers] = useState([]);
  const [mentionCtx, setMentionCtx] = useState(null);

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
    setStatus('');
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
    setMentionCtx(null);
    load();
  }

  function handleContentChange(value, caretPos) {
    setContent(value);
    const ctx = detectMentionContext(value, caretPos);
    setMentionCtx(ctx);
    if (!ctx) setMentionUsers([]);
  }

  function insertMention(kadi) {
    setContent((prev) => applyMention(prev, mentionCtx, kadi));
    setMentionCtx(null);
  }

  useEffect(() => {
    if (!mentionCtx?.query) {
      setMentionUsers([]);
      return;
    }
    fetchMentionCandidates(mentionCtx.query).then(setMentionUsers).catch(() => setMentionUsers([]));
  }, [mentionCtx?.query]);

  const myRole = useMemo(() => {
    if (!user?.id) return null;
    const row = members.find((m) => m.id === user.id);
    return row?.role || null;
  }, [members, user]);

  const canManageRoles = user?.admin === 1 || myRole === 'owner';
  const canUpdateCover = user?.admin === 1 || myRole === 'owner' || myRole === 'moderator';

  async function updateRole(targetId, role) {
    setStatus('');
    try {
      await apiJson(`/api/new/groups/${id}/role`, { method: 'POST', body: JSON.stringify({ userId: targetId, role }) });
      setStatus('Rol güncellendi.');
      load();
    } catch (err) {
      setStatus(err.message);
    }
  }

  async function uploadCover(e) {
    e.preventDefault();
    if (!coverFile) return;
    setStatus('');
    const form = new FormData();
    form.append('image', coverFile);
    const res = await fetch(`/api/new/groups/${id}/cover`, { method: 'POST', credentials: 'include', body: form });
    if (!res.ok) {
      setStatus(await res.text());
      return;
    }
    setCoverFile(null);
    load();
  }

  if (!group) {
    return <Layout title="Grup">Yükleniyor...</Layout>;
  }

  return (
    <Layout title={group.name}>
      <div className="panel">
        <div className="group-hero">
          {group.cover_image ? <img src={group.cover_image} alt="" /> : <div className="group-cover-empty">Kapak Görseli</div>}
          <div>
            <h3>{group.name}</h3>
            <div className="panel-body">{group.description}</div>
          </div>
        </div>
        {canUpdateCover ? (
          <form className="group-cover-form" onSubmit={uploadCover}>
            <input type="file" accept="image/*" onChange={(e) => setCoverFile(e.target.files?.[0] || null)} />
            <button className="btn ghost" type="submit">Kapak Güncelle</button>
          </form>
        ) : null}
      </div>
      <div className="panel">
        <div className="panel-body">
          <form onSubmit={submit} className="stack">
            <textarea className="input" placeholder="Gruba bir şey yaz..." value={content} onChange={(e) => handleContentChange(e.target.value, e.target.selectionStart)} />
            {mentionCtx ? (
              <div className="mention-box">
                {mentionUsers
                  .slice(0, 8)
                  .map((u) => (
                    <button key={u.id || u.following_id || u.kadi} type="button" className="mention-item" onClick={() => insertMention(u.kadi)}>
                      @{u.kadi}
                    </button>
                  ))}
              </div>
            ) : null}
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
                    <div className="meta role">{m.role}</div>
                    {canManageRoles && m.id !== user?.id ? (
                      <select className="input role-select" value={m.role} onChange={(e) => updateRole(m.id, e.target.value)}>
                        <option value="member">Üye</option>
                        <option value="moderator">Moderatör</option>
                        <option value="owner">Sahip</option>
                      </select>
                    ) : null}
                  </div>
                </div>
              ))}
            </div>
          </div>
          {status ? <div className="muted">{status}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
