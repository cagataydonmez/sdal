import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { emitAppChange, useLiveRefresh } from '../utils/live.js';
import { readApiPayload } from '../utils/api.js';
import { useI18n } from '../utils/i18n.jsx';
import { NETWORKING_EVENTS } from '../utils/networkingRegistry.js';
import { openNotification, readNotification, runNotificationAction } from '../utils/notificationApi.js';
import { buildNotificationViewModel } from '../utils/notificationRegistry.js';
import { NOTIFICATION_TELEMETRY_EVENTS, sendNotificationTelemetry } from '../utils/notificationTelemetry.js';
import NotificationCard from './NotificationCard.jsx';

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
  const impressionIdsRef = useRef(new Set());
  const knownUnreadIdsRef = useRef(new Set());
  const hydratedRef = useRef(false);

  const load = useCallback(async ({ background = true } = {}) => {
    if (!background) {
      setLoading(true);
      setError('');
    }
    try {
      const res = await fetch(`/api/new/notifications?limit=${Math.max(1, Number(limit) || 5)}&sort=priority`, { credentials: 'include', cache: 'no-store' });
      if (!res.ok) {
        if (!background) setError('load_failed');
        if (!background) setLoading(false);
        return;
      }
      const { data } = await readApiPayload(res, '');
      const nextItems = Array.isArray(data?.items) ? data.items.map(buildNotificationViewModel) : [];
      const nextUnreadIds = new Set(nextItems.filter((item) => !item.read_at).map((item) => Number(item.id || 0)).filter((value) => value > 0));
      if (background && hydratedRef.current) {
        const newUnreadIds = Array.from(nextUnreadIds).filter((id) => !knownUnreadIdsRef.current.has(id));
        if (newUnreadIds.length > 0) {
          emitAppChange('notification:new', { ids: newUnreadIds, source: 'notification_panel_poll' });
        }
      }
      knownUnreadIdsRef.current = nextUnreadIds;
      hydratedRef.current = true;
      setItems(nextItems);
      setHasMore(Boolean(data?.hasMore));
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

  useEffect(() => {
    load({ background: false }).catch(() => {});
  }, [load]);

  useLiveRefresh(load, {
    intervalMs: 12000,
    eventTypes: ['notification:new', 'notification:read', 'notification:opened', 'notification:action', 'post:liked', 'post:commented', NETWORKING_EVENTS.followChanged]
  });

  useEffect(() => {
    const nextEvents = items
      .filter((item) => {
        const key = `panel:${Number(item.id || 0)}`;
        if (!Number(item.id || 0) || impressionIdsRef.current.has(key)) return false;
        impressionIdsRef.current.add(key);
        return true;
      })
      .map((item) => ({
        notification_id: Number(item.id || 0),
        event_name: NOTIFICATION_TELEMETRY_EVENTS.impression,
        notification_type: item.type || '',
        surface: 'notification_panel'
      }));
    if (nextEvents.length) {
      void sendNotificationTelemetry(nextEvents);
    }
  }, [items]);

  function handleNotificationOpen(notification) {
    setItems((prev) => prev.map((item) => (
      Number(item.id) === Number(notification.id)
        ? { ...item, read_at: item.read_at || new Date().toISOString() }
        : item
    )));
    void openNotification(notification.id, {
      surface: 'notification_panel',
      notificationType: notification.type || ''
    });
    onReload?.();
  }

  async function handleNotificationRead(notification) {
    setBusyId(notification.id);
    const result = await readNotification(notification.id);
    if (result.ok) {
      setItems((prev) => prev.map((item) => (
        Number(item.id) === Number(notification.id)
          ? { ...item, read_at: item.read_at || new Date().toISOString() }
          : item
      )));
      onReload?.();
    } else if (result.message) {
      emitAppChange('toast', { tone: 'error', message: result.message });
    }
    setBusyId(null);
  }

  async function handleNotificationAction(notification, action) {
    setBusyId(notification.id);
    const result = await runNotificationAction(action, {
      surface: 'notification_panel',
      notificationId: notification.id,
      notificationType: notification.type || ''
    });
    if (!result.ok) {
      emitAppChange('toast', { tone: 'error', message: result.message || t('group_invite_respond_failed') });
      setBusyId(null);
      return;
    }
    if (action.kind === 'mark_teacher_notifications_read') {
      setItems((prev) => prev.map((item) => (
        item.type === 'teacher_network_linked'
          ? { ...item, read_at: item.read_at || new Date().toISOString() }
          : item
      )));
    }
    await load({ background: false });
    emitAppChange('notification:action', { id: notification.id, kind: action.kind });
    onReload?.();
    setBusyId(null);
  }

  const orderedItems = useMemo(() => (
    [...items].sort((left, right) => {
      const leftRank = left.read_at ? (left.isActionable ? 2 : 3) : (left.isActionable ? 0 : 1);
      const rightRank = right.read_at ? (right.isActionable ? 2 : 3) : (right.isActionable ? 0 : 1);
      if (leftRank !== rightRank) return leftRank - rightRank;
      return Number(right.id || 0) - Number(left.id || 0);
    })
  ), [items]);
  const actionItems = orderedItems.filter((item) => item.isActionable).slice(0, limit);
  const recentItems = orderedItems.filter((item) => !item.isActionable).slice(0, Math.max(0, limit - actionItems.length));

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

        {!loading && !error && actionItems.length > 0 ? (
          <div className="notification-panel-section">
            <div className="notification-panel-heading">Aksiyon Gerekenler</div>
            <div className="notification-card-stack">
              {actionItems.map((item) => (
                <NotificationCard
                  key={item.id}
                  compact
                  notification={item}
                  busy={busyId === item.id}
                  onOpen={handleNotificationOpen}
                  onRead={handleNotificationRead}
                  onAction={handleNotificationAction}
                />
              ))}
            </div>
          </div>
        ) : null}

        {!loading && !error && recentItems.length > 0 ? (
          <div className="notification-panel-section">
            <div className="notification-panel-heading">Son Güncellemeler</div>
            <div className="notification-card-stack">
              {recentItems.map((item) => (
                <NotificationCard
                  key={item.id}
                  compact
                  notification={item}
                  busy={busyId === item.id}
                  onOpen={handleNotificationOpen}
                  onRead={handleNotificationRead}
                  onAction={handleNotificationAction}
                />
              ))}
            </div>
          </div>
        ) : null}

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
