import React, { useCallback, useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import RichTextEditor from '../components/RichTextEditor.jsx';
import TranslatableHtml from '../components/TranslatableHtml.jsx';
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

export default function GroupsPage() {
  const { t } = useI18n();
  const PAGE_SIZE = 100;
  const [groups, setGroups] = useState([]);
  const [form, setForm] = useState({ name: '', description: '' });
  const [error, setError] = useState('');
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const sentinelRef = useRef(null);
  const groupsRef = useRef([]);
  const loadingMoreRef = useRef(false);

  useEffect(() => {
    groupsRef.current = groups;
  }, [groups]);

  const load = useCallback(async (offset = 0, append = false) => {
    const data = await apiJson(`/api/new/groups?limit=${PAGE_SIZE}&offset=${offset}`);
    const items = data.items || [];
    setGroups((prev) => (append ? mergeUniqueById(prev, items) : mergeUniqueById([], items)));
    setHasMore(!!data.hasMore);
  }, [PAGE_SIZE]);

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

  return (
    <Layout title={t('nav_groups')}>
      <div className="panel">
        <h3>{t('groups_new')}</h3>
        <div className="panel-body">
          <input className="input" placeholder={t('groups_name')} value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <RichTextEditor
            value={form.description}
            onChange={(next) => setForm((prev) => ({ ...prev, description: next }))}
            placeholder={t('description')}
            minHeight={110}
          />
          <button className="btn primary" onClick={create}>{t('create')}</button>
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>

      <div className="card-grid">
        {groups.map((g) => (
          <div className="member-card" key={g.id}>
            {g.cover_image ? <img src={g.cover_image} alt="" /> : <div className="group-cover-empty">{t('cover')}</div>}
            <div>
              <div className="name">{g.name}</div>
              <TranslatableHtml html={g.description || ''} className="meta" />
              <div className="meta">{t('groups_member_count', { count: g.members })} {g.visibility === 'members_only' ? `· ${t('private')}` : ''}</div>
              <a className="btn ghost" href={`/new/groups/${g.id}`}>{t('open')}</a>
            </div>
            <button className="btn" onClick={() => toggleJoin(g.id)}>
              {g.joined ? t('leave') : (g.invited ? t('group_invite_accept') : (g.pending ? t('group_request_cancel') : t('group_request_join')))}
            </button>
          </div>
        ))}
      </div>
      <div ref={sentinelRef} />
      {loadingMore ? <div className="muted">{t('groups_loading_more')}</div> : null}
      {!loadingMore && hasMore ? (
        <button className="btn ghost" onClick={loadMore}>{t('show_more')}</button>
      ) : null}
    </Layout>
  );
}
