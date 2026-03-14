import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useLocation } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import { formatDateTime } from '../utils/date.js';
import RichTextEditor from '../components/RichTextEditor.jsx';
import TranslatableHtml from '../components/TranslatableHtml.jsx';
import NativeImageButtons from '../components/NativeImageButtons.jsx';
import { useI18n } from '../utils/i18n.jsx';
import { useNotificationNavigationTracking } from '../utils/notificationNavigation.js';

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

export default function AnnouncementsPage() {
  const { t } = useI18n();
  const { user } = useAuth();
  const location = useLocation();
  const [items, setItems] = useState([]);
  const [form, setForm] = useState({ title: '', body: '' });
  const [imageFile, setImageFile] = useState(null);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const sentinelRef = useRef(null);
  const itemsRef = useRef([]);
  const cardRefs = useRef(new Map());
  const loadingMoreRef = useRef(false);
  const isAdmin = user?.admin === 1;
  const searchParams = useMemo(() => new URLSearchParams(location.search || ''), [location.search]);
  const highlightedAnnouncementId = Number(searchParams.get('announcement') || 0);
  const notificationId = Number(searchParams.get('notification') || 0);
  const notificationStatus = String(searchParams.get('status') || '').trim().toLowerCase();
  const landingResolved = !notificationId || !highlightedAnnouncementId || items.some((item) => Number(item.id || 0) === highlightedAnnouncementId);

  useNotificationNavigationTracking(notificationId, {
    surface: 'announcements_page',
    resolved: landingResolved
  });

  useEffect(() => {
    itemsRef.current = items;
  }, [items]);

  const load = useCallback(async (offset = 0, append = false) => {
    const data = await apiJson(`/api/new/announcements?limit=15&offset=${offset}`);
    const rows = data.items || [];
    setItems((prev) => (append ? mergeUniqueById(prev, rows) : mergeUniqueById([], rows)));
    setHasMore(!!data.hasMore);
  }, []);

  useEffect(() => {
    load(0, false);
  }, [load]);

  const loadMore = useCallback(async () => {
    if (loadingMoreRef.current || loadingMore || !hasMore) return;
    loadingMoreRef.current = true;
    setLoadingMore(true);
    await load(itemsRef.current.length, true);
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

  useEffect(() => {
    if (!highlightedAnnouncementId || !items.length) return;
    const timer = window.setTimeout(() => {
      cardRefs.current.get(highlightedAnnouncementId)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 180);
    return () => window.clearTimeout(timer);
  }, [highlightedAnnouncementId, items]);

  async function create() {
    setError('');
    setStatus('');
    try {
      if (imageFile) {
        const payload = new FormData();
        payload.append('title', form.title);
        payload.append('body', form.body);
        payload.append('image', imageFile);
        const res = await fetch('/api/new/announcements/upload', {
          method: 'POST',
          credentials: 'include',
          body: payload
        });
        if (!res.ok) throw new Error(await res.text());
      } else {
        await apiJson('/api/new/announcements', { method: 'POST', body: JSON.stringify(form) });
      }
      setForm({ title: '', body: '' });
      setImageFile(null);
      setStatus(isAdmin ? t('announcements_status_published') : t('announcements_status_submitted'));
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function approve(id, approved) {
    await apiJson(`/api/new/announcements/${id}/approve`, { method: 'POST', body: JSON.stringify({ approved: approved ? 1 : 0 }) });
    load();
  }

  async function remove(id) {
    await apiJson(`/api/new/announcements/${id}`, { method: 'DELETE' });
    load();
  }

  return (
    <Layout title={t('nav_announcements')}>
      <div className="panel">
        <h3>{isAdmin ? t('announcements_new') : t('announcements_suggestion')}</h3>
        <div className="panel-body">
          <input className="input" placeholder={t('title')} value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          <RichTextEditor value={form.body} onChange={(next) => setForm((prev) => ({ ...prev, body: next }))} placeholder={t('announcements_body_placeholder')} minHeight={120} />
          <NativeImageButtons onPick={setImageFile} onError={setError} />
          <input type="file" accept="image/*" onChange={(e) => setImageFile(e.target.files?.[0] || null)} />
          <button className="btn primary" onClick={create}>{isAdmin ? t('publish') : t('suggest')}</button>
          {status ? <div className="muted">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>

      <div className="stack">
        {notificationId && notificationStatus ? (
          <div className="notification-focus-inline-panel">
            <strong>Duyuru kararı güncellendi</strong>
            <div className="muted">
              {notificationStatus === 'approved'
                ? 'Duyuru önerin onaylandı ve yayına alındı.'
                : 'Duyuru önerin reddedildi. Gerekirse metni güncelleyip tekrar gönderebilirsin.'}
            </div>
          </div>
        ) : null}
        {items.map((a) => (
          <div
            key={a.id}
            ref={(node) => {
              if (node) cardRefs.current.set(Number(a.id || 0), node);
              else cardRefs.current.delete(Number(a.id || 0));
            }}
            className={`panel${Number(a.id || 0) === highlightedAnnouncementId ? ' notification-focus-card' : ''}`}
          >
            <h3>{a.title}</h3>
            <div className="panel-body">
              {a.image ? <img className="post-image" src={a.image} alt="" /> : null}
              <TranslatableHtml html={a.body || ''} />
              <div className="meta">{formatDateTime(a.created_at)} · @{a.creator_kadi || t('member_fallback')} {Number(a.approved || 0) === 1 ? '' : `· ${t('pending_approval')}`}</div>
              {isAdmin ? (
                <div className="composer-actions">
                  {Number(a.approved || 0) !== 1 ? <button className="btn" onClick={() => approve(a.id, true)}>{t('approve')}</button> : null}
                  {Number(a.approved || 0) !== 0 ? <button className="btn ghost" title={t('announcements_reject_hint')} onClick={() => approve(a.id, false)}>{t('announcements_reject_publish')}</button> : null}
                  <button className="btn ghost" onClick={() => remove(a.id)}>{t('delete')}</button>
                </div>
              ) : null}
            </div>
          </div>
        ))}
      </div>
      <div ref={sentinelRef} />
      {loadingMore ? <div className="muted">{t('announcements_loading_more')}</div> : null}
    </Layout>
  );
}
