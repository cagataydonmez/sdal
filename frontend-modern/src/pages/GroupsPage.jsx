import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Link } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import RichTextEditor from '../components/RichTextEditor.jsx';
import TranslatableHtml from '../components/TranslatableHtml.jsx';
import { useI18n } from '../utils/i18n.jsx';
import { contentImageAlt } from '../utils/a11y.js';

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

  const leadGroup = groups[0] || null;
  const communityGroups = leadGroup ? groups.slice(1) : groups;
  const totalMembers = groups.reduce((sum, group) => sum + Number(group.members || 0), 0);

  function groupActionLabel(group) {
    if (group.joined) return t('leave');
    if (group.invited) return t('group_invite_accept');
    if (group.pending) return t('group_request_cancel');
    return t('group_request_join');
  }

  return (
    <Layout title={t('nav_groups')}>
      <section className="groups-page-shell">
          <div className="panel groups-composer-panel">
            <div className="groups-panel-heading">
              <div>
                <h3>{t('groups_new')}</h3>
                <div className="groups-page-signal">
                  <span className="groups-page-signal-dot" aria-hidden="true" />
                  <span>{groups.length}</span>
                  <span>{t('nav_groups')}</span>
                  <span aria-hidden="true">·</span>
                  <span>{t('groups_member_count', { count: totalMembers })}</span>
                </div>
              </div>
            </div>
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

          {leadGroup ? (
            <article className="group-feature">
              <div className="group-feature-media-wrap">
                <div className="group-feature-glow" aria-hidden="true" />
                <div className="group-feature-media">
                  {leadGroup.cover_image ? (
                    <img src={leadGroup.cover_image} alt={contentImageAlt(leadGroup.name || t('nav_groups'), leadGroup.description || '')} />
                  ) : (
                    <div className="group-cover-empty">{t('cover')}</div>
                  )}
                </div>
              </div>
              <div className="group-feature-body">
                <div className="group-story-kicker">
                  {t('groups_member_count', { count: leadGroup.members })}
                  {leadGroup.visibility === 'members_only' ? ` · ${t('private')}` : ''}
                </div>
                <Link className="group-feature-title" to={`/new/groups/${leadGroup.id}`}>{leadGroup.name}</Link>
                <TranslatableHtml html={leadGroup.description || ''} className="group-feature-copy" />
              </div>
              <div className="group-feature-actions">
                <Link className="btn ghost" to={`/new/groups/${leadGroup.id}`}>{t('open')}</Link>
                <button className="btn" onClick={() => toggleJoin(leadGroup.id)}>
                  {groupActionLabel(leadGroup)}
                </button>
              </div>
            </article>
          ) : null}

          <div className="group-story-list" role="list">
            {communityGroups.map((g) => (
              <article
                className="group-story-card"
                key={g.id}
                role="listitem"
              >
                <Link className="group-story-cover" to={`/new/groups/${g.id}`}>
                  <div className="group-story-cover-media">
                    {g.cover_image ? (
                      <img src={g.cover_image} alt={contentImageAlt(g.name || t('nav_groups'), g.description || '')} />
                    ) : (
                      <div className="group-cover-empty">{t('cover')}</div>
                    )}
                  </div>
                </Link>
                <div className="group-story-main">
                  <Link className="group-story-title" to={`/new/groups/${g.id}`}>{g.name}</Link>
                  <TranslatableHtml html={g.description || ''} className="group-story-copy" />
                  <div className="group-story-meta">
                    <span>{t('groups_member_count', { count: g.members })}</span>
                    {g.visibility === 'members_only' ? <span>{t('private')}</span> : null}
                  </div>
                </div>
                <div className="group-story-actions">
                  <Link className="btn ghost" to={`/new/groups/${g.id}`}>{t('open')}</Link>
                  <button className="btn" onClick={() => toggleJoin(g.id)}>
                    {groupActionLabel(g)}
                  </button>
                </div>
              </article>
            ))}
          </div>

          <div ref={sentinelRef} />
          {loadingMore ? <div className="muted">{t('groups_loading_more')}</div> : null}
          {!loadingMore && hasMore ? (
            <button
              className="btn ghost group-story-more"
              onClick={loadMore}
            >
              {t('show_more')}
            </button>
          ) : null}
      </section>
    </Layout>
  );
}
