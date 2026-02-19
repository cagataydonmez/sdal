import React, { useCallback, useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { formatDateTime } from '../utils/date.js';
import { useI18n } from '../utils/i18n.jsx';

const PAGE_SIZE = 20;

function getTarget(n) {
  if ((n.type === 'like' || n.type === 'comment' || n.type === 'mention_post') && n.entity_id) return `/new?post=${n.entity_id}`;
  if ((n.type === 'event_comment' || n.type === 'event_invite' || n.type === 'mention_event') && n.entity_id) return '/new/events';
  if ((n.type === 'mention_group' || n.type === 'group_join_request' || n.type === 'group_join_approved' || n.type === 'group_join_rejected' || n.type === 'group_invite') && n.entity_id) return `/new/groups/${n.entity_id}`;
  if ((n.type === 'mention_photo' || n.type === 'photo_comment') && n.entity_id) return `/new/albums/photo/${n.entity_id}`;
  if (n.type === 'mention_message' && n.entity_id) return `/new/messages/${n.entity_id}`;
  if (n.type === 'follow' && n.source_user_id) return `/new/members/${n.source_user_id}`;
  return '/new';
}

export default function NotificationsPage() {
  const { t } = useI18n();
  const [items, setItems] = useState([]);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(false);
  const sentinelRef = useRef(null);
  const itemsRef = useRef([]);
  const loadingRef = useRef(false);

  useEffect(() => {
    itemsRef.current = items;
  }, [items]);

  const load = useCallback(async (append = false) => {
    if (loadingRef.current) return;
    loadingRef.current = true;
    setLoading(true);
    const offset = append ? itemsRef.current.length : 0;
    const res = await fetch(`/api/new/notifications?limit=${PAGE_SIZE}&offset=${offset}`, { credentials: 'include', cache: 'no-store' });
    if (!res.ok) {
      setLoading(false);
      loadingRef.current = false;
      return;
    }
    const payload = await res.json();
    const next = payload.items || [];
    setItems((prev) => (append ? [...prev, ...next] : next));
    setHasMore(Boolean(payload.hasMore));
    setLoading(false);
    loadingRef.current = false;
  }, []);

  useEffect(() => {
    load(false);
    fetch('/api/new/notifications/read', { method: 'POST', credentials: 'include' }).catch(() => {});
  }, [load]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting) && hasMore && !loading) {
        load(true);
      }
    }, { rootMargin: '360px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [load, hasMore, loading]);

  return (
    <Layout title={t('nav_notifications')}>
      <div className="panel">
        <div className="panel-body">
          {items.length === 0 ? <div className="muted">{t('notifications_empty')}</div> : null}
          {items.map((n) => (
            <div key={n.id} className={`notif notif-link${n.read_at ? '' : ' unread'}`}>
              <img className="avatar" src={n.resim ? `/api/media/vesikalik/${n.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              <div className="notif-content">
                <a href={getTarget(n)}>
                  <b>@{n.kadi}</b> {n.verified ? <span className="badge">✓</span> : null} {n.message}
                </a>
                <div className="meta">{formatDateTime(n.created_at)}</div>
              </div>
            </div>
          ))}
          <div ref={sentinelRef} />
          {loading ? <div className="muted">{t('loading')}</div> : null}
          {!hasMore && items.length > 0 ? <div className="muted">{t('notifications_all_loaded')}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
