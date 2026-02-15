import React, { useCallback, useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import { formatDateTime } from '../utils/date.js';
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

export default function EventsPage() {
  const { user } = useAuth();
  const [events, setEvents] = useState([]);
  const [comments, setComments] = useState({});
  const [drafts, setDrafts] = useState({});
  const [form, setForm] = useState({ title: '', description: '', location: '', starts_at: '', ends_at: '' });
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [mentionUsers, setMentionUsers] = useState([]);
  const [formMentionCtx, setFormMentionCtx] = useState(null);
  const [commentMentionCtx, setCommentMentionCtx] = useState({});
  const sentinelRef = useRef(null);
  const commentsRef = useRef({});
  const eventsRef = useRef([]);
  const loadingMoreRef = useRef(false);

  const isAdmin = user?.admin === 1;

  useEffect(() => {
    commentsRef.current = comments;
  }, [comments]);

  useEffect(() => {
    eventsRef.current = events;
  }, [events]);

  const load = useCallback(async (offset = 0, append = false) => {
    const data = await apiJson(`/api/new/events?limit=15&offset=${offset}`);
    const items = data.items || [];
    setEvents((prev) => (append ? mergeUniqueById(prev, items) : mergeUniqueById([], items)));
    setHasMore(!!data.hasMore);
    for (const e of items) {
      if (commentsRef.current[e.id]) continue;
      const c = await apiJson(`/api/new/events/${e.id}/comments`);
      setComments((prev) => ({ ...prev, [e.id]: c.items || [] }));
    }
  }, []);

  useEffect(() => {
    load(0, false);
  }, [load]);

  const loadMore = useCallback(async () => {
    if (loadingMoreRef.current || loadingMore || !hasMore) return;
    loadingMoreRef.current = true;
    setLoadingMore(true);
    await load(eventsRef.current.length, true);
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
    setStatus('');
    try {
      await apiJson('/api/new/events', { method: 'POST', body: JSON.stringify(form) });
      setForm({ title: '', description: '', location: '', starts_at: '', ends_at: '' });
      setFormMentionCtx(null);
      setStatus(isAdmin ? 'Etkinlik eklendi.' : 'Etkinlik önerin admin onayına gönderildi.');
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function approve(id, approved) {
    await apiJson(`/api/new/events/${id}/approve`, { method: 'POST', body: JSON.stringify({ approved: approved ? 1 : 0 }) });
    load();
  }

  async function remove(id) {
    await apiJson(`/api/new/events/${id}`, { method: 'DELETE' });
    load();
  }

  async function addComment(eventId) {
    const text = String(drafts[eventId] || '').trim();
    if (!text) return;
    await apiJson(`/api/new/events/${eventId}/comments`, { method: 'POST', body: JSON.stringify({ comment: text }) });
    setDrafts((prev) => ({ ...prev, [eventId]: '' }));
    setCommentMentionCtx((prev) => ({ ...prev, [eventId]: null }));
    const c = await apiJson(`/api/new/events/${eventId}/comments`);
    setComments((prev) => ({ ...prev, [eventId]: c.items || [] }));
  }

  function handleDescriptionChange(value, caretPos) {
    setForm((prev) => ({ ...prev, description: value }));
    const ctx = detectMentionContext(value, caretPos);
    setFormMentionCtx(ctx);
  }

  function insertDescriptionMention(kadi) {
    setForm((prev) => ({ ...prev, description: applyMention(prev.description, formMentionCtx, kadi) }));
    setFormMentionCtx(null);
  }

  function handleCommentDraftChange(eventId, value, caretPos) {
    setDrafts((prev) => ({ ...prev, [eventId]: value }));
    const ctx = detectMentionContext(value, caretPos);
    setCommentMentionCtx((prev) => ({ ...prev, [eventId]: ctx }));
  }

  function insertCommentMention(eventId, kadi) {
    const ctx = commentMentionCtx[eventId];
    setDrafts((prev) => ({ ...prev, [eventId]: applyMention(prev[eventId] || '', ctx, kadi) }));
    setCommentMentionCtx((prev) => ({ ...prev, [eventId]: null }));
  }

  useEffect(() => {
    const q = formMentionCtx?.query || Object.values(commentMentionCtx).find((v) => v?.query)?.query || '';
    if (!q) {
      setMentionUsers([]);
      return;
    }
    fetchMentionCandidates(q).then(setMentionUsers).catch(() => setMentionUsers([]));
  }, [formMentionCtx?.query, commentMentionCtx]);

  async function notifyFollowers(eventId) {
    const res = await apiJson(`/api/new/events/${eventId}/notify`, { method: 'POST' });
    setStatus(`${res.count || 0} kişiye bildirim gönderildi.`);
  }

  return (
    <Layout title="Etkinlikler">
      <div className="panel">
        <h3>{isAdmin ? 'Yeni Etkinlik' : 'Etkinlik Önerisi'}</h3>
        <div className="panel-body">
          <input className="input" placeholder="Başlık" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          <input className="input" placeholder="Konum" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} />
          <textarea className="input" placeholder="Açıklama" value={form.description} onChange={(e) => handleDescriptionChange(e.target.value, e.target.selectionStart)} />
          {formMentionCtx ? (
            <div className="mention-box">
              {mentionUsers
                .slice(0, 8)
                .map((u) => (
                  <button key={u.id || u.following_id || u.kadi} type="button" className="mention-item" onClick={() => insertDescriptionMention(u.kadi)}>
                    @{u.kadi}
                  </button>
                ))}
            </div>
          ) : null}
          <input className="input" type="datetime-local" value={form.starts_at} onChange={(e) => setForm({ ...form, starts_at: e.target.value })} />
          <input className="input" type="datetime-local" value={form.ends_at} onChange={(e) => setForm({ ...form, ends_at: e.target.value })} />
          <button className="btn primary" onClick={create}>{isAdmin ? 'Ekle' : 'Öner'}</button>
          {error ? <div className="error">{error}</div> : null}
          {status ? <div className="muted">{status}</div> : null}
        </div>
      </div>

      <div className="list">
        {events.map((e) => (
          <div key={e.id} className="panel">
            <h3>{e.title}</h3>
            <div className="panel-body">
              <div className="meta">{e.location} · {formatDateTime(e.starts_at)}{e.ends_at ? ` - ${formatDateTime(e.ends_at)}` : ''}</div>
              <div dangerouslySetInnerHTML={{ __html: e.description || '' }} />
              <div className="meta">Ekleyen: @{e.creator_kadi || 'uye'} {Number(e.approved || 0) === 1 ? '' : '· Onay bekliyor'}</div>
              <div className="composer-actions">
                <button className="btn ghost" onClick={() => notifyFollowers(e.id)}>Takipçilerime Bildir</button>
                {isAdmin ? (
                  <>
                    {Number(e.approved || 0) !== 1 ? <button className="btn" onClick={() => approve(e.id, true)}>Onayla</button> : null}
                    {Number(e.approved || 0) !== 0 ? <button className="btn ghost" onClick={() => approve(e.id, false)}>Reddet</button> : null}
                    <button className="btn ghost" onClick={() => remove(e.id)}>Sil</button>
                  </>
                ) : null}
              </div>
              <div className="comment-list">
                {(comments[e.id] || []).map((c) => (
                  <div key={c.id} className="comment-line">
                    {(Number(c.user_id || c.uye_id || 0) || null) ? (
                      <a href={`/new/members/${Number(c.user_id || c.uye_id || 0)}`} aria-label={`${c.kadi || 'uye'} profiline git`}>
                        <img className="avatar" src={c.resim ? `/api/media/vesikalik/${c.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                      </a>
                    ) : (
                      <img className="avatar" src={c.resim ? `/api/media/vesikalik/${c.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                    )}
                    <div>
                      <div className="name">@{c.kadi} {c.verified ? <span className="badge">✓</span> : null}</div>
                      <div className="meta">{formatDateTime(c.created_at)}</div>
                      <div dangerouslySetInnerHTML={{ __html: c.comment || '' }} />
                    </div>
                  </div>
                ))}
              </div>
              <form className="comment-form" onSubmit={(ev) => { ev.preventDefault(); addComment(e.id); }}>
                <input
                  value={drafts[e.id] || ''}
                  onChange={(ev) => handleCommentDraftChange(e.id, ev.target.value, ev.target.selectionStart)}
                  placeholder="Etkinliğe yorum ekle..."
                />
                <button className="btn">Gönder</button>
              </form>
              {commentMentionCtx[e.id] ? (
                <div className="mention-box">
                  {mentionUsers
                    .slice(0, 8)
                    .map((u) => (
                      <button key={u.id || u.following_id || u.kadi} type="button" className="mention-item" onClick={() => insertCommentMention(e.id, u.kadi)}>
                        @{u.kadi}
                      </button>
                    ))}
                </div>
              ) : null}
            </div>
          </div>
        ))}
      </div>
      <div ref={sentinelRef} />
      {loadingMore ? <div className="muted">Daha fazla etkinlik yükleniyor...</div> : null}
    </Layout>
  );
}
