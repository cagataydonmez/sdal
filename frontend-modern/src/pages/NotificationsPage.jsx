import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { readApiPayload } from '../utils/api.js';
import { bulkReadNotifications, openNotification, readNotification, runNotificationAction } from '../utils/notificationApi.js';
import { useI18n } from '../utils/i18n.jsx';
import { emitAppChange, useLiveRefresh } from '../utils/live.js';
import { buildNotificationViewModel, getNotificationCategoryLabel, getNotificationExperimentVariant } from '../utils/notificationRegistry.js';
import { fetchNotificationPreferences, NOTIFICATION_PREFERENCE_DEFAULTS, updateNotificationPreferences } from '../utils/notificationPreferences.js';
import { NOTIFICATION_TELEMETRY_EVENTS, sendNotificationTelemetry } from '../utils/notificationTelemetry.js';
import NotificationCard from '../components/NotificationCard.jsx';

const PAGE_SIZE = 20;

function mergeUniqueById(prev, next) {
  const map = new Map();
  for (const item of prev || []) map.set(Number(item?.id || 0), item);
  for (const item of next || []) map.set(Number(item?.id || 0), item);
  return Array.from(map.values()).filter((item) => Number(item?.id || 0) > 0);
}

export default function NotificationsPage() {
  const { t } = useI18n();
  const [searchParams, setSearchParams] = useSearchParams();
  const [items, setItems] = useState([]);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(false);
  const [busyId, setBusyId] = useState(0);
  const [bulkBusy, setBulkBusy] = useState(false);
  const [error, setError] = useState('');
  const [preferences, setPreferences] = useState(NOTIFICATION_PREFERENCE_DEFAULTS);
  const [experiments, setExperiments] = useState({ assignments: {}, configs: [] });
  const [preferencesLoading, setPreferencesLoading] = useState(true);
  const [preferencesBusy, setPreferencesBusy] = useState(false);
  const [preferencesStatus, setPreferencesStatus] = useState('');
  const sentinelRef = useRef(null);
  const loadingRef = useRef(false);
  const nextCursorRef = useRef('');
  const impressionIdsRef = useRef(new Set());
  const knownUnreadIdsRef = useRef(new Set());
  const hydratedRef = useRef(false);
  const selectedTab = String(searchParams.get('tab') || 'all').trim().toLowerCase();
  const tabs = useMemo(() => ([
    { key: 'all', label: 'Tümü' },
    { key: 'action', label: 'Aksiyon Gerekenler' },
    { key: 'networking', label: 'Networking' },
    { key: 'groups', label: 'Gruplar' },
    { key: 'events', label: 'Etkinlikler' },
    { key: 'jobs', label: 'İlanlar' },
    { key: 'social', label: 'Sosyal' },
    { key: 'system', label: 'Sistem' }
  ]), []);
  const sortOrderVariant = getNotificationExperimentVariant(experiments.assignments, 'sort_order', 'priority');
  const inboxLayoutVariant = getNotificationExperimentVariant(experiments.assignments, 'inbox_layout', 'grouped');
  const ctaWordingVariant = getNotificationExperimentVariant(experiments.assignments, 'cta_wording', 'neutral');

  const loadPreferences = useCallback(async () => {
    setPreferencesLoading(true);
    const result = await fetchNotificationPreferences();
    if (result.ok) {
      setPreferences(result.preferences);
      setExperiments(result.experiments);
      setPreferencesStatus('');
    } else {
      setError(result.message || 'Bildirim tercihleri yüklenemedi.');
    }
    setPreferencesLoading(false);
  }, []);

  const load = useCallback(async (append = false) => {
    if (loadingRef.current) return;
    loadingRef.current = true;
    setLoading(true);
    setError('');
    const cursor = append ? String(nextCursorRef.current || '').trim() : '';
    const query = new URLSearchParams({
      limit: String(PAGE_SIZE),
      sort: sortOrderVariant === 'recent' ? 'recent' : 'priority'
    });
    if (cursor) query.set('cursor', cursor);
    const res = await fetch(`/api/new/notifications?${query.toString()}`, { credentials: 'include', cache: 'no-store' });
    if (!res.ok) {
      setError('Bildirimler yüklenemedi.');
      setLoading(false);
      loadingRef.current = false;
      return;
    }
    const { data } = await readApiPayload(res, '');
    const next = Array.isArray(data?.items) ? data.items.map(buildNotificationViewModel) : [];
    const nextUnreadIds = new Set(next.filter((item) => !item.read_at).map((item) => Number(item.id || 0)).filter((value) => value > 0));
    if (append === false && hydratedRef.current) {
      const newUnreadIds = Array.from(nextUnreadIds).filter((id) => !knownUnreadIdsRef.current.has(id));
      if (newUnreadIds.length > 0) {
        emitAppChange('notification:new', { ids: newUnreadIds, source: 'notifications_page_poll' });
      }
    }
    knownUnreadIdsRef.current = nextUnreadIds;
    hydratedRef.current = true;
    setItems((prev) => (append ? mergeUniqueById(prev, next) : next));
    setHasMore(Boolean(data?.hasMore));
    nextCursorRef.current = String(data?.next_cursor || '').trim();
    setLoading(false);
    loadingRef.current = false;
  }, [sortOrderVariant, t]);

  useEffect(() => {
    load(false);
  }, [load]);

  useEffect(() => {
    loadPreferences();
  }, [loadPreferences]);

  useLiveRefresh(() => load(false), { intervalMs: 12000, eventTypes: ['notification:new', 'notification:read', 'notification:opened', 'notification:action'] });

  useEffect(() => {
    const nextEvents = items
      .filter((item) => {
        const key = `page:${Number(item.id || 0)}`;
        if (!Number(item.id || 0) || impressionIdsRef.current.has(key)) return false;
        impressionIdsRef.current.add(key);
        return true;
      })
      .map((item) => ({
        notification_id: Number(item.id || 0),
        event_name: NOTIFICATION_TELEMETRY_EVENTS.impression,
        notification_type: item.type || '',
        surface: 'notifications_page'
      }));
    if (nextEvents.length) {
      void sendNotificationTelemetry(nextEvents);
    }
  }, [items]);

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

  const unreadCount = useMemo(
    () => items.reduce((sum, item) => (item.read_at ? sum : sum + 1), 0),
    [items]
  );
  const actionableCount = useMemo(
    () => items.reduce((sum, item) => (item.isActionable && !item.read_at ? sum + 1 : sum), 0),
    [items]
  );
  const groupedCounts = useMemo(() => {
    const counts = { networking: 0, groups: 0, events: 0, jobs: 0, social: 0, system: 0 };
    for (const item of items) {
      if (counts[item.category] != null) counts[item.category] += 1;
    }
    return counts;
  }, [items]);
  const orderedItems = useMemo(() => (
    [...items].sort((left, right) => {
      const leftRank = left.read_at ? (left.isActionable ? 2 : 3) : (left.isActionable ? 0 : 1);
      const rightRank = right.read_at ? (right.isActionable ? 2 : 3) : (right.isActionable ? 0 : 1);
      if (leftRank !== rightRank) return leftRank - rightRank;
      return Number(right.id || 0) - Number(left.id || 0);
    })
  ), [items]);
  const filteredItems = useMemo(() => orderedItems.filter((item) => {
    if (selectedTab === 'all') return true;
    if (selectedTab === 'action') return Boolean(item.isActionable);
    return item.category === selectedTab;
  }), [orderedItems, selectedTab]);
  const actionItems = filteredItems.filter((item) => item.isActionable);
  const recentItems = filteredItems.filter((item) => !item.isActionable);

  async function handleRead(notification) {
    setBusyId(Number(notification.id || 0));
    const result = await readNotification(notification.id);
    if (result.ok) {
      setItems((prev) => prev.map((item) => (
        Number(item.id) === Number(notification.id)
          ? { ...item, read_at: item.read_at || new Date().toISOString() }
          : item
      )));
    } else if (result.message) {
      setError(result.message);
    }
    setBusyId(0);
  }

  async function handleOpen(notification) {
    setItems((prev) => prev.map((item) => (
      Number(item.id) === Number(notification.id)
        ? { ...item, read_at: item.read_at || new Date().toISOString() }
        : item
    )));
    void openNotification(notification.id, {
      surface: 'notifications_page',
      notificationType: notification.type || ''
    });
  }

  async function handleAction(notification, action) {
    setBusyId(Number(notification.id || 0));
    const result = await runNotificationAction(action, {
      surface: 'notifications_page',
      notificationId: notification.id,
      notificationType: notification.type || ''
    });
    if (result.ok) {
      if (action.kind === 'mark_teacher_notifications_read') {
        setItems((prev) => prev.map((item) => (
          item.type === 'teacher_network_linked'
            ? { ...item, read_at: item.read_at || new Date().toISOString() }
            : item
        )));
      }
      await load(false);
    } else if (result.message) {
      setError(result.message);
    }
    setBusyId(0);
  }

  async function handleBulkRead() {
    setBulkBusy(true);
    const unreadIds = items.filter((item) => !item.read_at).map((item) => Number(item.id || 0)).filter((value) => value > 0);
    const result = await bulkReadNotifications(unreadIds);
    if (result.ok) {
      const now = new Date().toISOString();
      setItems((prev) => prev.map((item) => ({ ...item, read_at: item.read_at || now })));
    } else if (result.message) {
      setError(result.message);
    }
    setBulkBusy(false);
  }

  async function handleSavePreferences() {
    setPreferencesBusy(true);
    setPreferencesStatus('');
    const result = await updateNotificationPreferences(preferences);
    if (result.ok) {
      setPreferences(result.preferences);
      setPreferencesStatus('Bildirim tercihleri güncellendi.');
      emitAppChange('notification:preferences-updated', { preferences: result.preferences });
    } else {
      setError(result.message || 'Bildirim tercihleri güncellenemedi.');
    }
    setPreferencesBusy(false);
  }

  return (
    <Layout title={t('nav_notifications')}>
      <div className="panel">
        <div className="panel-body">
          <div className="notification-preferences-panel">
            <div className="notification-page-heading">
              <strong>Bildirim tercihleri</strong>
              <span className="meta">
                Sıralama: {sortOrderVariant === 'recent' ? 'En yeni önce' : 'Öncelik önce'} ·
                Düzen: {inboxLayoutVariant === 'flat' ? 'Düz akış' : 'Gruplu'}
              </span>
            </div>
            <div className="notification-preferences-grid">
              {Object.entries(preferences.categories || {}).map(([key, enabled]) => (
                <label key={key} className="notification-preference-toggle">
                  <input
                    type="checkbox"
                    checked={Boolean(enabled)}
                    onChange={(e) => setPreferences((prev) => ({
                      ...prev,
                      categories: { ...prev.categories, [key]: e.target.checked }
                    }))}
                  />
                  <span>{getNotificationCategoryLabel(key)}</span>
                </label>
              ))}
            </div>
            <div className="notification-preferences-grid">
              <label className="notification-preference-toggle">
                <input
                  type="checkbox"
                  checked={Boolean(preferences?.quiet_mode?.enabled)}
                  onChange={(e) => setPreferences((prev) => ({
                    ...prev,
                    quiet_mode: { ...prev.quiet_mode, enabled: e.target.checked }
                  }))}
                />
                <span>Sessiz mod</span>
              </label>
              <label className="form-row">
                <span className="meta">Başlangıç</span>
                <input
                  className="input"
                  type="time"
                  value={preferences?.quiet_mode?.start || ''}
                  onChange={(e) => setPreferences((prev) => ({
                    ...prev,
                    quiet_mode: { ...prev.quiet_mode, start: e.target.value }
                  }))}
                />
              </label>
              <label className="form-row">
                <span className="meta">Bitiş</span>
                <input
                  className="input"
                  type="time"
                  value={preferences?.quiet_mode?.end || ''}
                  onChange={(e) => setPreferences((prev) => ({
                    ...prev,
                    quiet_mode: { ...prev.quiet_mode, end: e.target.value }
                  }))}
                />
              </label>
            </div>
            <div className="composer-actions">
              <button className="btn ghost" onClick={loadPreferences} disabled={preferencesLoading || preferencesBusy}>
                {preferencesLoading ? t('loading') : 'Tercihleri yenile'}
              </button>
              <button className="btn primary" onClick={handleSavePreferences} disabled={preferencesBusy || preferencesLoading}>
                {preferencesBusy ? t('loading') : 'Tercihleri kaydet'}
              </button>
            </div>
            {preferencesStatus ? <div className="ok">{preferencesStatus}</div> : null}
          </div>

          <div className="notification-page-summary">
            <div className="notification-summary-card">
              <strong>{unreadCount}</strong>
              <span>Okunmamış</span>
            </div>
            <div className="notification-summary-card">
              <strong>{actionableCount}</strong>
              <span>Aksiyon bekleyen</span>
            </div>
            <div className="notification-summary-card">
              <strong>{groupedCounts.networking}</strong>
              <span>{getNotificationCategoryLabel('networking')}</span>
            </div>
            <div className="notification-summary-card">
              <strong>{groupedCounts.groups + groupedCounts.events + groupedCounts.jobs + groupedCounts.social}</strong>
              <span>Diğer akışlar</span>
            </div>
            <div className="notification-summary-card">
              <strong>{groupedCounts.system}</strong>
              <span>Sistem</span>
            </div>
          </div>

          <div className="notification-tabs">
            {tabs.map((tab) => (
              <button
                key={tab.key}
                className={`btn ${selectedTab === tab.key ? 'primary' : 'ghost'}`}
                onClick={() => {
                  const next = new URLSearchParams(searchParams);
                  if (tab.key === 'all') next.delete('tab');
                  else next.set('tab', tab.key);
                  setSearchParams(next);
                }}
              >
                {tab.label}
              </button>
            ))}
          </div>

          <div className="composer-actions">
            <button className="btn ghost" onClick={handleBulkRead} disabled={bulkBusy || unreadCount === 0}>
              {bulkBusy ? t('loading') : 'Tümünü okundu yap'}
            </button>
          </div>
          {error ? <div className="muted">{error}</div> : null}
          {filteredItems.length === 0 ? <div className="muted">{t('notifications_empty')}</div> : null}

          {inboxLayoutVariant === 'flat' ? (
            filteredItems.length > 0 ? (
              <div className="notification-page-section">
                <div className="notification-page-heading">
                  <strong>Bildirim akışı</strong>
                  <span className="meta">{filteredItems.length} kayıt</span>
                </div>
                <div className="notification-card-stack">
                  {filteredItems.map((item) => (
                    <NotificationCard
                      key={item.id}
                      notification={item}
                      busy={busyId === Number(item.id || 0)}
                      ctaVariant={ctaWordingVariant}
                      onOpen={handleOpen}
                      onRead={handleRead}
                      onAction={handleAction}
                    />
                  ))}
                </div>
              </div>
            ) : null
          ) : (
            <>
              {actionItems.length > 0 ? (
                <div className="notification-page-section">
                  <div className="notification-page-heading">
                    <strong>Aksiyon Gerekenler</strong>
                    <span className="meta">{actionItems.length} kayıt</span>
                  </div>
                  <div className="notification-card-stack">
                    {actionItems.map((item) => (
                      <NotificationCard
                        key={item.id}
                        notification={item}
                        busy={busyId === Number(item.id || 0)}
                        ctaVariant={ctaWordingVariant}
                        onOpen={handleOpen}
                        onRead={handleRead}
                        onAction={handleAction}
                      />
                    ))}
                  </div>
                </div>
              ) : null}

              {recentItems.length > 0 ? (
                <div className="notification-page-section">
                  <div className="notification-page-heading">
                    <strong>Son Güncellemeler</strong>
                    <span className="meta">{recentItems.length} kayıt</span>
                  </div>
                  <div className="notification-card-stack">
                    {recentItems.map((item) => (
                      <NotificationCard
                        key={item.id}
                        notification={item}
                        busy={busyId === Number(item.id || 0)}
                        ctaVariant={ctaWordingVariant}
                        onOpen={handleOpen}
                        onRead={handleRead}
                        onAction={handleAction}
                      />
                    ))}
                  </div>
                </div>
              ) : null}
            </>
          )}
          <div ref={sentinelRef} />
          {loading ? <div className="muted">{t('loading')}</div> : null}
          {!hasMore && items.length > 0 ? <div className="muted">{t('notifications_all_loaded')}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
