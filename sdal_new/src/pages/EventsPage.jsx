import React, { useCallback, useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import { formatDateTime } from '../utils/date.js';
import RichTextEditor from '../components/RichTextEditor.jsx';
import TranslatableHtml from '../components/TranslatableHtml.jsx';
import { isRichTextEmpty } from '../utils/richText.js';
import { useI18n } from '../utils/i18n.jsx';

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
  const { t } = useI18n();
  const { user } = useAuth();
  const [events, setEvents] = useState([]);
  const [comments, setComments] = useState({});
  const [drafts, setDrafts] = useState({});
  const [form, setForm] = useState({ title: '', description: '', location: '', starts_at: '', ends_at: '' });
  const [imageFile, setImageFile] = useState(null);
  const [responsePrefs, setResponsePrefs] = useState({});
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
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
      if (imageFile) {
        const payload = new FormData();
        payload.append('title', form.title);
        payload.append('description', form.description);
        payload.append('location', form.location);
        payload.append('starts_at', form.starts_at);
        payload.append('ends_at', form.ends_at);
        payload.append('image', imageFile);
        const res = await fetch('/api/new/events/upload', {
          method: 'POST',
          credentials: 'include',
          body: payload
        });
        if (!res.ok) throw new Error(await res.text());
      } else {
        await apiJson('/api/new/events', { method: 'POST', body: JSON.stringify(form) });
      }
      setForm({ title: '', description: '', location: '', starts_at: '', ends_at: '' });
      setImageFile(null);
      setStatus(isAdmin ? t('events_status_added') : t('events_status_submitted'));
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
    const text = String(drafts[eventId] || '');
    if (isRichTextEmpty(text)) return;
    await apiJson(`/api/new/events/${eventId}/comments`, { method: 'POST', body: JSON.stringify({ comment: text }) });
    setDrafts((prev) => ({ ...prev, [eventId]: '' }));
    const c = await apiJson(`/api/new/events/${eventId}/comments`);
    setComments((prev) => ({ ...prev, [eventId]: c.items || [] }));
  }

  async function notifyFollowers(eventId) {
    const res = await apiJson(`/api/new/events/${eventId}/notify`, { method: 'POST' });
    setStatus(t('events_notify_count', { count: res.count || 0 }));
  }

  async function respondToEvent(eventId, response) {
    await apiJson(`/api/new/events/${eventId}/respond`, { method: 'POST', body: JSON.stringify({ response }) });
    await load();
  }

  async function saveResponseVisibility(eventId) {
    const pref = responsePrefs[eventId];
    if (!pref) return;
    await apiJson(`/api/new/events/${eventId}/response-visibility`, {
      method: 'POST',
      body: JSON.stringify({
        showCounts: pref.showCounts,
        showAttendeeNames: pref.showAttendeeNames,
        showDeclinerNames: pref.showDeclinerNames
      })
    });
    await load();
  }

  return (
    <Layout title={t('nav_events')}>
      <div className="panel">
        <h3>{isAdmin ? t('events_new') : t('events_suggestion')}</h3>
        <div className="panel-body">
          <input className="input" placeholder={t('title')} value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          <input className="input" placeholder={t('location')} value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} />
          <RichTextEditor
            value={form.description}
            onChange={(next) => setForm((prev) => ({ ...prev, description: next }))}
            placeholder={t('description')}
            minHeight={120}
          />
          <input type="file" accept="image/*" onChange={(e) => setImageFile(e.target.files?.[0] || null)} />
          <input className="input" type="datetime-local" value={form.starts_at} onChange={(e) => setForm({ ...form, starts_at: e.target.value })} />
          <input className="input" type="datetime-local" value={form.ends_at} onChange={(e) => setForm({ ...form, ends_at: e.target.value })} />
          <button className="btn primary" onClick={create}>{isAdmin ? t('add') : t('suggest')}</button>
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
              {e.image ? <img className="post-image" src={e.image} alt="" /> : null}
              <TranslatableHtml html={e.description || ''} />
              <div className="meta">{t('added_by')}: @{e.creator_kadi || t('member_fallback')} {Number(e.approved || 0) === 1 ? '' : `· ${t('pending_approval')}`}</div>
              <div className="composer-actions">
                <button className={`btn ${e.my_response === 'attend' ? 'primary' : 'ghost'}`} onClick={() => respondToEvent(e.id, 'attend')}>{t('events_attend')}</button>
                <button className={`btn ${e.my_response === 'decline' ? 'primary' : 'ghost'}`} onClick={() => respondToEvent(e.id, 'decline')}>{t('events_decline')}</button>
                {e.response_counts ? (
                  <>
                    <span className="chip">{t('events_attend_count')}: {Number(e.response_counts?.attend || 0)}</span>
                    <span className="chip">{t('events_decline_count')}: {Number(e.response_counts?.decline || 0)}</span>
                  </>
                ) : (
                  <span className="chip">{t('events_response_hidden')}</span>
                )}
              </div>
              {(e.attendees?.length || e.decliners?.length) ? (
                <div className="panel">
                  <div className="panel-body">
                    {e.attendees?.length ? <div className="meta">{t('events_attendees')}: {e.attendees.map((u) => `@${u.kadi}`).join(', ')}</div> : null}
                    {e.decliners?.length ? <div className="meta">{t('events_decliners')}: {e.decliners.map((u) => `@${u.kadi}`).join(', ')}</div> : null}
                  </div>
                </div>
              ) : null}
              {e.can_manage_responses ? (
                <div className="panel">
                  <div className="panel-body">
                    <b>{t('events_visibility_title')}</b>
                    <label className="chip">
                      <input
                        type="checkbox"
                        checked={responsePrefs[e.id]?.showCounts ?? Boolean(e.response_visibility?.showCounts ?? true)}
                        onChange={(ev) => setResponsePrefs((prev) => ({
                          ...prev,
                          [e.id]: {
                            showCounts: ev.target.checked,
                            showAttendeeNames: prev[e.id]?.showAttendeeNames ?? Boolean(e.response_visibility?.showAttendeeNames),
                            showDeclinerNames: prev[e.id]?.showDeclinerNames ?? Boolean(e.response_visibility?.showDeclinerNames)
                          }
                        }))}
                      />
                      {t('events_visibility_counts')}
                    </label>
                    <label className="chip">
                      <input
                        type="checkbox"
                        checked={responsePrefs[e.id]?.showAttendeeNames ?? Boolean(e.response_visibility?.showAttendeeNames)}
                        onChange={(ev) => setResponsePrefs((prev) => ({
                          ...prev,
                          [e.id]: {
                            showCounts: prev[e.id]?.showCounts ?? Boolean(e.response_visibility?.showCounts ?? true),
                            showAttendeeNames: ev.target.checked,
                            showDeclinerNames: prev[e.id]?.showDeclinerNames ?? Boolean(e.response_visibility?.showDeclinerNames)
                          }
                        }))}
                      />
                      {t('events_visibility_attendees')}
                    </label>
                    <label className="chip">
                      <input
                        type="checkbox"
                        checked={responsePrefs[e.id]?.showDeclinerNames ?? Boolean(e.response_visibility?.showDeclinerNames)}
                        onChange={(ev) => setResponsePrefs((prev) => ({
                          ...prev,
                          [e.id]: {
                            showCounts: prev[e.id]?.showCounts ?? Boolean(e.response_visibility?.showCounts ?? true),
                            showAttendeeNames: prev[e.id]?.showAttendeeNames ?? Boolean(e.response_visibility?.showAttendeeNames),
                            showDeclinerNames: ev.target.checked
                          }
                        }))}
                      />
                      {t('events_visibility_decliners')}
                    </label>
                    <button className="btn ghost" onClick={() => saveResponseVisibility(e.id)}>{t('save_visibility')}</button>
                  </div>
                </div>
              ) : null}
              <div className="composer-actions">
                <button className="btn ghost" onClick={() => notifyFollowers(e.id)}>{t('events_notify_followers')}</button>
                {isAdmin ? (
                  <>
                    {Number(e.approved || 0) !== 1 ? <button className="btn" onClick={() => approve(e.id, true)}>{t('approve')}</button> : null}
                    {Number(e.approved || 0) !== 0 ? <button className="btn ghost" title={t('events_reject_hint')} onClick={() => approve(e.id, false)}>{t('events_reject_publish')}</button> : null}
                    <button className="btn ghost" onClick={() => remove(e.id)}>{t('delete')}</button>
                  </>
                ) : null}
              </div>
              <div className="comment-list">
                {(comments[e.id] || []).map((c) => (
                  <div key={c.id} className="comment-line">
                    {(Number(c.user_id || c.uye_id || 0) || null) ? (
                      <a href={`/new/members/${Number(c.user_id || c.uye_id || 0)}`} aria-label={t('go_profile_aria', { username: c.kadi || t('member_fallback') })}>
                        <img className="avatar" src={c.resim ? `/api/media/vesikalik/${c.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                      </a>
                    ) : (
                      <img className="avatar" src={c.resim ? `/api/media/vesikalik/${c.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                    )}
                    <div>
                      <div className="name">@{c.kadi} {c.verified ? <span className="badge">✓</span> : null}</div>
                      <div className="meta">{formatDateTime(c.created_at)}</div>
                      <TranslatableHtml html={c.comment || ''} />
                    </div>
                  </div>
                ))}
              </div>
              <form className="comment-form" onSubmit={(ev) => { ev.preventDefault(); addComment(e.id); }}>
                <RichTextEditor
                  value={drafts[e.id] || ''}
                  onChange={(next) => setDrafts((prev) => ({ ...prev, [e.id]: next }))}
                  placeholder={t('events_comment_placeholder')}
                  minHeight={80}
                  compact
                />
                <button className="btn" disabled={isRichTextEmpty(drafts[e.id] || '')}>{t('send')}</button>
              </form>
            </div>
          </div>
        ))}
      </div>
      <div ref={sentinelRef} />
      {loadingMore ? <div className="muted">{t('events_loading_more')}</div> : null}
    </Layout>
  );
}
