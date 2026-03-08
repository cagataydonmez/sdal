import React, { useCallback, useEffect, useState } from 'react';
import { emitAppChange, useLiveRefresh } from '../utils/live.js';
import { formatDateTime } from '../utils/date.js';
import { useI18n } from '../utils/i18n.jsx';

function NotificationSkeleton() {
  return (
    <div className="skeleton-stack" aria-hidden="true">
      <span className="skeleton-line" />
      <span className="skeleton-line" />
    </div>
  );
}

export default function NotificationPanel({ limit = 5, showAllLink = true, showEmptyCta = false, onReload = null }) {
  const [items, setItems] = useState([]);
  const [busyId, setBusyId] = useState(null);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const { t } = useI18n();

  const load = useCallback(async ({ background = true } = {}) => {
    if (!background) {
      setLoading(true);
      setError('');
    }
    try {
      const res = await fetch(`/api/new/notifications?limit=${Math.max(1, Number(limit) || 5)}&offset=0`, { credentials: 'include', cache: 'no-store' });
      if (!res.ok) {
        if (!background) setError('load_failed');
        if (!background) setLoading(false);
        return;
      }
      const payload = await res.json();
      setItems(payload.items || []);
      setHasMore(Boolean(payload.hasMore));
      if (!background) {
        setError('');
        setLoading(false);
      }
    } catch {
      if (!background) {
        setError('load_failed');
        setLoading(false);
      }
    }
  }, [limit]);

  function getTarget(n) {
    if ((n.type === 'like' || n.type === 'comment') && n.entity_id) return `/new?post=${n.entity_id}`;
    if (n.type === 'mention_post' && n.entity_id) return `/new?post=${n.entity_id}`;
    if (n.type === 'mention_event' && n.entity_id) return '/new/events';
    if (n.type === 'mention_group' && n.entity_id) return `/new/groups/${n.entity_id}`;
    if ((n.type === 'group_join_request' || n.type === 'group_join_approved' || n.type === 'group_join_rejected' || n.type === 'group_invite') && n.entity_id) return `/new/groups/${n.entity_id}`;
    if (n.type === 'mention_message' && n.entity_id) return `/new/messages/${n.entity_id}`;
    if (n.type === 'mention_photo' && n.entity_id) return `/new/albums/photo/${n.entity_id}`;
    if (n.type === 'photo_comment' && n.entity_id) return `/new/albums/photo/${n.entity_id}`;
    if ((n.type === 'event_comment' || n.type === 'event_invite') && n.entity_id) return '/new/events';
    if (n.type === 'follow' && n.source_user_id) return `/new/members/${n.source_user_id}`;
    return '/new';
  }

  useEffect(() => {
    load({ background: false }).catch(() => {});
  }, [load]);

  useLiveRefresh(load, { intervalMs: 12000, eventTypes: ['notification:new', 'post:liked', 'post:commented', 'follow:changed'] });

  function inviteStatusLabel(status) {
    if (status === 'accepted') return t('group_invite_accepted');
    if (status === 'rejected') return t('group_invite_rejected');
    return t('group_invite_pending');
  }

  async function respondGroupInvite(notification, action) {
    if (!notification?.entity_id) return;
    if (!['accept', 'reject'].includes(action)) return;
    setBusyId(notification.id);
    try {
      const res = await fetch(`/api/new/groups/${notification.entity_id}/invitations/respond`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action })
      });
      if (!res.ok) {
        throw new Error(await res.text());
      }
      setItems((prev) => prev.map((x) => (
        x.id === notification.id
          ? { ...x, invite_status: action === 'accept' ? 'accepted' : 'rejected' }
          : x
      )));
      emitAppChange('group:invite:responded', { id: notification.id, action, groupId: notification.entity_id });
      setTimeout(() => {
        load().catch(() => {});
      }, 200);
      onReload?.();
    } catch (err) {
      emitAppChange('toast', { type: 'error', message: err?.message || t('group_invite_respond_failed') });
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="panel">
      <h3>{t('nav_notifications')}</h3>
      <div className="panel-body">
        {loading ? <NotificationSkeleton /> : null}

        {!loading && error ? (
          <div className="feed-panel-state">
            <div className="muted">{t('notifications_empty')}</div>
            <button className="btn ghost" onClick={() => load({ background: false }).then(() => onReload?.())}>{t('games_refresh')}</button>
          </div>
        ) : null}

        {!loading && !error && items.length === 0 ? (
          showEmptyCta ? (
            <div className="feed-panel-state">
              <div className="muted">{t('notifications_empty')}</div>
              <a className="btn ghost" href="/new/explore">{t('feed_discover_members')}</a>
            </div>
          ) : <div className="muted">{t('notifications_empty')}</div>
        ) : null}

        {!loading && !error && items.map((n) => (
          <div key={n.id} className={`notif notif-link${n.read_at ? '' : ' unread'}`}>
            <img className="avatar" src={n.resim ? `/api/media/vesikalik/${n.resim}` : '/legacy/vesikalik/nophoto.jpg'} loading="lazy" decoding="async" alt="" />
            <div className="notif-content">
              <a
                href={getTarget(n)}
                onClick={() => emitAppChange('notification:opened', { id: n.id })}
              >
                <b>@{n.kadi}</b> {n.verified ? <span className="badge">✓</span> : null} {n.message}
              </a>
              <div className="meta">{formatDateTime(n.created_at)}</div>
              {n.type === 'group_invite' ? (
                <div className="notif-actions">
                  {(n.invite_status || 'pending') === 'pending' ? (
                    <>
                      <button
                        className="btn"
                        disabled={busyId === n.id}
                        onClick={() => respondGroupInvite(n, 'accept')}
                      >
                        {t('approve')}
                      </button>
                      <button
                        className="btn ghost"
                        disabled={busyId === n.id}
                        onClick={() => respondGroupInvite(n, 'reject')}
                      >
                        {t('reject')}
                      </button>
                    </>
                  ) : (
                    <>
                      <span className={`chip invite-state ${n.invite_status === 'accepted' ? 'ok' : 'rejected'}`}>
                        {inviteStatusLabel(n.invite_status)}
                      </span>
                      {n.invite_status === 'accepted' ? (
                        <a className="btn ghost" href={`/new/groups/${n.entity_id}`}>{t('group_go')}</a>
                      ) : null}
                    </>
                  )}
                </div>
              ) : null}
            </div>
          </div>
        ))}

        {showAllLink ? (
          <a className="btn ghost" href="/new/notifications">
            {t('all_notifications')}
            {hasMore ? ' +' : ''}
          </a>
        ) : null}
      </div>
    </div>
  );
}
