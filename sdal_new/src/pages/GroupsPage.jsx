import React, { useCallback, useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
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

function mergeUniqueById(prev, next) {
  const map = new Map();
  for (const item of prev || []) map.set(item.id, item);
  for (const item of next || []) map.set(item.id, item);
  return Array.from(map.values());
}

export default function GroupsPage() {
  const [groups, setGroups] = useState([]);
  const [form, setForm] = useState({ name: '', description: '' });
  const [error, setError] = useState('');
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [mentionUsers, setMentionUsers] = useState([]);
  const [mentionCtx, setMentionCtx] = useState(null);
  const sentinelRef = useRef(null);
  const groupsRef = useRef([]);
  const loadingMoreRef = useRef(false);

  useEffect(() => {
    groupsRef.current = groups;
  }, [groups]);

  const load = useCallback(async (offset = 0, append = false) => {
    const data = await apiJson(`/api/new/groups?limit=20&offset=${offset}`);
    const items = data.items || [];
    setGroups((prev) => (append ? mergeUniqueById(prev, items) : mergeUniqueById([], items)));
    setHasMore(!!data.hasMore);
  }, []);

  useEffect(() => {
    load(0, false);
  }, [load]);

  const loadMore = useCallback(async () => {
    if (loadingMoreRef.current || loadingMore || !hasMore) return;
    loadingMoreRef.current = true;
    setLoadingMore(true);
    await load(groupsRef.current.length, true);
    setLoadingMore(false);
    loadingMoreRef.current = false;
  }, [loadingMore, hasMore, load]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) loadMore();
    }, { rootMargin: '300px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [loadMore]);

  async function create() {
    setError('');
    try {
      await apiJson('/api/new/groups', { method: 'POST', body: JSON.stringify(form) });
      setForm({ name: '', description: '' });
      setMentionCtx(null);
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function toggleJoin(id) {
    try {
      await apiJson(`/api/new/groups/${id}/join`, { method: 'POST' });
      await load();
    } catch (err) {
      setError(err.message);
    }
  }

  function handleDescriptionChange(value, caretPos) {
    setForm((prev) => ({ ...prev, description: value }));
    const ctx = detectMentionContext(value, caretPos);
    setMentionCtx(ctx);
    if (!ctx) setMentionUsers([]);
  }

  function insertMention(kadi) {
    setForm((prev) => ({ ...prev, description: applyMention(prev.description, mentionCtx, kadi) }));
    setMentionCtx(null);
  }

  useEffect(() => {
    if (!mentionCtx?.query) {
      setMentionUsers([]);
      return;
    }
    fetchMentionCandidates(mentionCtx.query).then(setMentionUsers).catch(() => setMentionUsers([]));
  }, [mentionCtx?.query]);

  return (
    <Layout title="Gruplar (Deploy Test)">
      <div className="panel">
        <h3>Yeni Grup</h3>
        <div className="panel-body">
          <input className="input" placeholder="Grup adı" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <textarea className="input" placeholder="Açıklama" value={form.description} onChange={(e) => handleDescriptionChange(e.target.value, e.target.selectionStart)} />
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
          <button className="btn primary" onClick={create}>Oluştur</button>
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>

      <div className="card-grid">
        {groups.map((g) => (
          <div className="member-card" key={g.id}>
            {g.cover_image ? <img src={g.cover_image} alt="" /> : <div className="group-cover-empty">Kapak</div>}
            <div>
              <div className="name">{g.name}</div>
              <div className="meta">{g.description}</div>
              <div className="meta">{g.members} üye {g.visibility === 'members_only' ? '· Gizli' : ''}</div>
              <a className="btn ghost" href={`/new/groups/${g.id}`}>Aç</a>
            </div>
            <button className="btn" onClick={() => toggleJoin(g.id)}>
              {g.joined ? 'Ayrıl' : (g.invited ? 'Daveti Kabul Et' : (g.pending ? 'İsteği İptal Et' : 'Katılım İsteği'))}
            </button>
          </div>
        ))}
      </div>
      <div ref={sentinelRef} />
      {loadingMore ? <div className="muted">Daha fazla grup yükleniyor...</div> : null}
    </Layout>
  );
}
