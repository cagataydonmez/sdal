import React, { useCallback, useEffect, useState } from 'react';
import { emitAppChange, useLiveRefresh } from '../utils/live.js';
import { formatDateTime } from '../utils/date.js';

export default function NotificationPanel() {
  const [items, setItems] = useState([]);

  const load = useCallback(async () => {
    const res = await fetch('/api/new/notifications', { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    setItems(payload.items || []);
  }, []);

  function getTarget(n) {
    if ((n.type === 'like' || n.type === 'comment') && n.entity_id) return `/new?post=${n.entity_id}`;
    if (n.type === 'mention_post' && n.entity_id) return `/new?post=${n.entity_id}`;
    if (n.type === 'mention_event' && n.entity_id) return '/new/events';
    if (n.type === 'mention_group' && n.entity_id) return `/new/groups/${n.entity_id}`;
    if (n.type === 'mention_message' && n.entity_id) return `/new/messages/${n.entity_id}`;
    if (n.type === 'photo_comment' && n.entity_id) return `/new/albums/photo/${n.entity_id}`;
    if ((n.type === 'event_comment' || n.type === 'event_invite') && n.entity_id) return '/new/events';
    if (n.type === 'follow' && n.source_user_id) return `/new/members/${n.source_user_id}`;
    return '/new';
  }

  useEffect(() => {
    load();
  }, [load]);

  useLiveRefresh(load, { intervalMs: 6000, eventTypes: ['notification:new', 'post:liked', 'post:commented', 'follow:changed', '*'] });

  return (
    <div className="panel">
      <h3>Bildirimler</h3>
      <div className="panel-body">
        {items.length === 0 ? <div className="muted">Bildirim yok.</div> : null}
        {items.map((n) => (
          <a
            key={n.id}
            className={`notif notif-link${n.read_at ? '' : ' unread'}`}
            href={getTarget(n)}
            onClick={() => emitAppChange('notification:opened', { id: n.id })}
          >
            <img className="avatar" src={n.resim ? `/api/media/vesikalik/${n.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
            <div>
              <b>@{n.kadi}</b> {n.verified ? <span className="badge">✓</span> : null} {n.message}
              <div className="meta">{formatDateTime(n.created_at)}</div>
            </div>
          </a>
        ))}
      </div>
    </div>
  );
}
