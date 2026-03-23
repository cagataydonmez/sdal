import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link, useSearchParams } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import { formatDateTime } from '../utils/date.js';
import RichTextEditor from '../components/RichTextEditor.jsx';
import TranslatableHtml from '../components/TranslatableHtml.jsx';
import NativeImageButtons from '../components/NativeImageButtons.jsx';
import { isRichTextEmpty } from '../utils/richText.js';
import { useI18n } from '../utils/i18n.jsx';
import { useNotificationNavigationTracking } from '../utils/notificationNavigation.js';
import { avatarAlt, contentImageAlt } from '../utils/a11y.js';

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

function notificationFocusCopy(focus, canManageEvent, t) {
  const normalizedFocus = String(focus || '').trim().toLowerCase();
  if (normalizedFocus === 'response') {
    return canManageEvent
      ? {
          title: t('event_notification_response_title'),
          message: t('event_notification_response_message')
        }
      : {
          title: t('event_notification_attendance_title'),
          message: t('event_notification_attendance_message')
        };
  }
  if (normalizedFocus === 'comments') {
    return {
      title: t('event_notification_comments_title'),
      message: t('event_notification_comments_message')
    };
  }
  if (normalizedFocus === 'details') {
    return {
      title: t('event_notification_update_title'),
      message: t('event_notification_update_message')
    };
  }
  return null;
}

const EVENT_DAY_MS = 24 * 60 * 60 * 1000;

function eventImageUrl(photo) {
  return photo ? `/api/media/vesikalik/${photo}` : '/legacy/vesikalik/nophoto.jpg';
}

function eventTiming(event) {
  const now = Date.now();
  const startsAt = Date.parse(event?.starts_at || '');
  const endsAt = Date.parse(event?.ends_at || '');
  const hasStart = Number.isFinite(startsAt);
  const hasEnd = Number.isFinite(endsAt);
  const activeUntil = hasEnd ? endsAt : startsAt;
  const hoursUntilStart = hasStart ? (startsAt - now) / (60 * 60 * 1000) : Number.POSITIVE_INFINITY;
  const isPast = hasStart && Number.isFinite(activeUntil) ? activeUntil < now : false;
  const isToday = hasStart ? Math.abs(startsAt - now) < EVENT_DAY_MS : false;
  const isSoon = hasStart ? startsAt >= now && startsAt - now <= EVENT_DAY_MS * 3 : false;
  return {
    startsAt: hasStart ? startsAt : null,
    isPast,
    isToday,
    isSoon,
    hoursUntilStart
  };
}

function eventStageLabel(event, timing, copy, t) {
  if (Number(event?.approved || 0) !== 1) return t('pending_approval');
  if (timing.isPast) return copy.stagePast;
  if (timing.isToday) return copy.stageLive;
  if (timing.isSoon) return copy.stageSoon;
  return copy.stageDefault;
}

export default function EventsPage() {
  const { t } = useI18n();
  const { user } = useAuth();
  const [searchParams] = useSearchParams();
  const [events, setEvents] = useState([]);
  const [comments, setComments] = useState({});
  const [drafts, setDrafts] = useState({});
  const [form, setForm] = useState({ title: '', description: '', location: '', starts_at: '', ends_at: '' });
  const [imageFile, setImageFile] = useState(null);
  const [responsePrefs, setResponsePrefs] = useState({});
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [notifyBusyId, setNotifyBusyId] = useState(0);
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const sentinelRef = useRef(null);
  const commentsRef = useRef({});
  const eventsRef = useRef([]);
  const loadingMoreRef = useRef(false);
  const cardRefs = useRef(new Map());
  const focusedEventId = Number(searchParams.get('event') || 0);
  const focusedNotificationFocus = String(searchParams.get('focus') || '').trim().toLowerCase();
  const notificationId = Number(searchParams.get('notification') || 0);
  const notificationLandingResolved = !notificationId || !focusedEventId || events.some((item) => Number(item.id || 0) === focusedEventId);

  useNotificationNavigationTracking(notificationId, {
    surface: 'events_page',
    resolved: notificationLandingResolved
  });

  const isAdmin = user?.admin === 1;

  const pulseCopy = useMemo(() => {
    return {
      stagePast: t('events_stage_past'),
      stageLive: t('events_stage_live'),
      stageSoon: t('events_stage_soon'),
      stageDefault: t('events_stage_default'),
      statWindow: t('events_stat_window'),
      statResponses: t('events_stat_responses'),
      statComments: t('events_stat_comments'),
      densityLabel: t('events_density_label')
    };
  }, [t]);

  const boardItems = useMemo(() => events.map((event) => {
    const timing = eventTiming(event);
    const attendCount = Number(event.response_counts?.attend || 0);
    const declineCount = Number(event.response_counts?.decline || 0);
    const commentCount = Number((comments[event.id] || []).length || 0);
    const totalResponses = attendCount + declineCount;
    const responseMomentum = totalResponses + (commentCount * 0.7);
    const attendRatio = totalResponses > 0 ? attendCount / totalResponses : 0;
    const declineRatio = totalResponses > 0 ? declineCount / totalResponses : 0;
    const canManageEvent = isAdmin || Number(event.created_by || 0) === Number(user?.id || 0);
    return {
      event,
      timing,
      attendCount,
      declineCount,
      commentCount,
      totalResponses,
      responseMomentum,
      attendRatio,
      declineRatio,
      canManageEvent
    };
  }), [comments, events, isAdmin, user?.id]);

  const featuredItem = useMemo(() => {
    if (!boardItems.length) return null;
    const focused = boardItems.find((item) => Number(item.event.id || 0) === focusedEventId);
    if (focused) return focused;
    const upcoming = boardItems
      .filter((item) => !item.timing.isPast && item.timing.startsAt !== null)
      .sort((a, b) => a.timing.startsAt - b.timing.startsAt);
    return upcoming[0] || boardItems[0];
  }, [boardItems, focusedEventId]);

  const boardStats = useMemo(() => {
    const upcomingCount = boardItems.filter((item) => !item.timing.isPast).length;
    const liveSoonCount = boardItems.filter((item) => item.timing.isToday || item.timing.isSoon).length;
    const totalResponses = boardItems.reduce((sum, item) => sum + item.totalResponses, 0);
    const totalComments = boardItems.reduce((sum, item) => sum + item.commentCount, 0);
    const pendingCount = boardItems.filter((item) => Number(item.event.approved || 0) !== 1).length;
    return { upcomingCount, liveSoonCount, totalResponses, totalComments, pendingCount };
  }, [boardItems]);

  const pulseRailItems = useMemo(() => boardItems
    .filter((item) => !item.timing.isPast)
    .sort((a, b) => {
      if (a.timing.startsAt === null) return 1;
      if (b.timing.startsAt === null) return -1;
      return a.timing.startsAt - b.timing.startsAt;
    })
    .slice(0, 4), [boardItems]);

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

  useEffect(() => {
    if (!focusedEventId) return;
    const timer = window.setTimeout(() => {
      const node = cardRefs.current.get(focusedEventId);
      node?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 180);
    return () => window.clearTimeout(timer);
  }, [focusedEventId, events.length]);

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

  async function notifyEventAudience(eventId, mode = 'invite') {
    setError('');
    setStatus('');
    setNotifyBusyId(Number(eventId || 0));
    try {
      const res = await apiJson(`/api/new/events/${eventId}/notify`, {
        method: 'POST',
        body: JSON.stringify({ mode })
      });
      const count = Number(res.count || 0);
      if (mode === 'reminder') {
        setStatus(count > 0 ? t('event_notify_reminder_sent', { count }) : t('event_notify_reminder_not_found'));
      } else if (mode === 'starts_soon') {
        setStatus(count > 0 ? t('event_notify_starts_soon_sent', { count }) : t('event_notify_starts_soon_not_found'));
      } else {
        setStatus(t('events_notify_count', { count }));
      }
    } catch (err) {
      setError(err.message || t('event_notify_failed'));
    } finally {
      setNotifyBusyId(0);
    }
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
      <div className="events-pulse-board">
        <section className="events-pulse-grid">
          <div className="panel events-pulse-hero">
            <div className="events-pulse-hero-copy">
              <div className="events-pulse-kicker">
                <span className="events-pulse-mark">SDAL</span>
                <span>{t('nav_events')}</span>
              </div>
              <div className="events-pulse-title-row">
                <div>
                  <h2 className="events-pulse-title">{featuredItem?.event?.title || t('nav_events')}</h2>
                  <p className="events-pulse-summary">
                    {featuredItem
                      ? `${featuredItem.event.location || t('location')} · ${formatDateTime(featuredItem.event.starts_at)}`
                      : t('events_loading_more')}
                  </p>
                </div>
                <div className="events-pulse-density">
                  <span className="events-pulse-density-value">{Math.round((featuredItem?.responseMomentum || 0) * 10) / 10}</span>
                  <span className="events-pulse-density-label">{pulseCopy.densityLabel}</span>
                </div>
              </div>
              <div className="events-pulse-stat-row">
                <div className="events-pulse-stat">
                  <span className="events-pulse-stat-value">{boardStats.upcomingCount}</span>
                  <span className="events-pulse-stat-label">{t('nav_events')}</span>
                </div>
                <div className="events-pulse-stat">
                  <span className="events-pulse-stat-value">{boardStats.liveSoonCount}</span>
                  <span className="events-pulse-stat-label">{pulseCopy.statWindow}</span>
                </div>
                <div className="events-pulse-stat">
                  <span className="events-pulse-stat-value">{boardStats.totalResponses}</span>
                  <span className="events-pulse-stat-label">{pulseCopy.statResponses}</span>
                </div>
                <div className="events-pulse-stat">
                  <span className="events-pulse-stat-value">{boardStats.totalComments}</span>
                  <span className="events-pulse-stat-label">{pulseCopy.statComments}</span>
                </div>
              </div>
              {featuredItem ? (
                <div className="events-pulse-featured-footer">
                  <div className="events-pulse-featured-meta">
                    <span className={`events-stage-pill${featuredItem.timing.isToday ? ' is-live' : featuredItem.timing.isSoon ? ' is-soon' : ''}`}>
                      {eventStageLabel(featuredItem.event, featuredItem.timing, pulseCopy, t)}
                    </span>
                    <span className="events-pulse-featured-note">{t('added_by')}: @{featuredItem.event.creator_kadi || t('member_fallback')}</span>
                  </div>
                  <div className="events-avatar-swarm">
                    {(featuredItem.event.attendees || []).slice(0, 5).map((attendee, idx) => (
                      <img
                        key={`${featuredItem.event.id}-attendee-${attendee.id || attendee.kadi || idx}`}
                        className="events-avatar-swarm-item"
                        src={eventImageUrl(attendee.resim)}
                        alt={avatarAlt(attendee)}
                        loading="lazy"
                        decoding="async"
                      />
                    ))}
                    {featuredItem.totalResponses > 0 ? <span className="events-avatar-swarm-count">+{featuredItem.totalResponses}</span> : null}
                  </div>
                </div>
              ) : null}
            </div>
            <div className="events-pulse-hero-visual">
              {featuredItem?.event?.image ? (
                <img
                  src={featuredItem.event.image}
                  className="events-pulse-hero-image"
                  alt={contentImageAlt(featuredItem.event.title || t('nav_events'), featuredItem.event.description || '')}
                />
              ) : (
                <div className="events-pulse-placeholder">
                  <span>{t('nav_events')}</span>
                  <strong>{featuredItem?.event?.location || t('location')}</strong>
                </div>
              )}
            </div>
          </div>

          <div className="panel events-compose-panel">
            <div className="events-compose-head">
              <div>
                <div className="events-compose-kicker">{t('nav_events')}</div>
                <h3>{isAdmin ? t('events_new') : t('events_suggestion')}</h3>
              </div>
              {boardStats.pendingCount > 0 ? <span className="events-stage-pill">{t('pending_approval')}</span> : null}
            </div>
            <div className="panel-body events-compose-body">
              <div className="events-compose-grid">
                <input className="input" placeholder={t('title')} value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
                <input className="input" placeholder={t('location')} value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} />
              </div>
              <RichTextEditor
                value={form.description}
                onChange={(next) => setForm((prev) => ({ ...prev, description: next }))}
                placeholder={t('description')}
                minHeight={120}
              />
              <div className="events-compose-grid">
                <input className="input" type="datetime-local" value={form.starts_at} onChange={(e) => setForm({ ...form, starts_at: e.target.value })} />
                <input className="input" type="datetime-local" value={form.ends_at} onChange={(e) => setForm({ ...form, ends_at: e.target.value })} />
              </div>
              <div className="events-compose-tools">
                <NativeImageButtons onPick={setImageFile} onError={setError} />
                <input type="file" accept="image/*" onChange={(e) => setImageFile(e.target.files?.[0] || null)} />
                {imageFile ? <span className="events-upload-chip">{imageFile.name}</span> : null}
              </div>
              <div className="events-compose-actions">
                <button className="btn primary" onClick={create}>{isAdmin ? t('add') : t('suggest')}</button>
                <div className="events-compose-hint">{featuredItem ? featuredItem.event.title : t('nav_events')}</div>
              </div>
              {error ? <div className="error">{error}</div> : null}
              {status ? <div className="muted">{status}</div> : null}
            </div>
          </div>
        </section>

        {pulseRailItems.length ? (
          <section className="events-pulse-rail" aria-label={t('nav_events')}>
            {pulseRailItems.map((item) => (
              <button
                key={`pulse-rail-${item.event.id}`}
                type="button"
                className={`events-pulse-rail-card${focusedEventId === Number(item.event.id || 0) ? ' is-selected' : ''}`}
                onClick={() => cardRefs.current.get(Number(item.event.id || 0))?.scrollIntoView({ behavior: 'smooth', block: 'start' })}
              >
                <span className="events-pulse-rail-time">{formatDateTime(item.event.starts_at)}</span>
                <strong>{item.event.title}</strong>
                <span className="events-pulse-rail-meta">{item.event.location || t('location')}</span>
                <span className="events-pulse-rail-density">{item.totalResponses} · {item.commentCount}</span>
              </button>
            ))}
          </section>
        ) : null}

        <div className="events-stream">
        {boardItems.map((item, index) => {
          const e = item.event;
          const focusCopy = notificationFocusCopy(focusedNotificationFocus, item.canManageEvent, t);
          return (
          <div
            key={e.id}
            className={`panel events-stream-card${focusedEventId === Number(e.id || 0) ? ' notification-focus-card' : ''}${item.timing.isSoon ? ' is-soon' : ''}${item.timing.isToday ? ' is-live' : ''}`}
            style={{ '--event-card-order': index }}
            ref={(node) => {
              if (node) cardRefs.current.set(Number(e.id || 0), node);
              else cardRefs.current.delete(Number(e.id || 0));
            }}
            data-event-card=""
          >
            <div className="events-stream-card-shell">
              <div className="panel-body events-stream-main">
              {focusedEventId === Number(e.id || 0) && notificationId && focusCopy ? (
                <div className="panel notification-focus-inline-panel notification-focus-card">
                  <div className="panel-body">
                    <strong>{focusCopy.title}</strong>
                    <p className="muted">{focusCopy.message}</p>
                  </div>
                </div>
              ) : null}
              <div className="events-stream-overline">
                <span className={`events-stage-pill${item.timing.isToday ? ' is-live' : item.timing.isSoon ? ' is-soon' : ''}`}>{eventStageLabel(e, item.timing, pulseCopy, t)}</span>
                <span className="events-stream-meta-pill">{formatDateTime(e.starts_at)}</span>
                <span className="events-stream-meta-pill">{item.commentCount} · {pulseCopy.statComments}</span>
              </div>
              <div className="events-stream-header">
                <div>
                  <h3>{e.title}</h3>
                  <div className="meta">{e.location} · {formatDateTime(e.starts_at)}{e.ends_at ? ` - ${formatDateTime(e.ends_at)}` : ''}</div>
                </div>
                <div className="events-stream-density">
                  <span className="events-stream-density-value">{item.totalResponses}</span>
                  <span className="events-stream-density-copy">{t('events_attend_count')}</span>
                </div>
              </div>
              {e.image ? <img className="post-image" src={e.image} alt={contentImageAlt(e.title || t('nav_events'), e.description || '')} /> : null}
              <TranslatableHtml html={e.description || ''} />
              <div className="meta">{t('added_by')}: @{e.creator_kadi || t('member_fallback')} {Number(e.approved || 0) === 1 ? '' : `· ${t('pending_approval')}`}</div>
              <div className="composer-actions events-response-actions">
                <button className={`btn ${e.my_response === 'attend' ? 'primary' : 'ghost'}`} onClick={() => respondToEvent(e.id, 'attend')}>{t('events_attend')}</button>
                <button className={`btn ${e.my_response === 'decline' ? 'primary' : 'ghost'}`} onClick={() => respondToEvent(e.id, 'decline')}>{t('events_decline')}</button>
                {e.response_counts ? (
                  <>
                    <span className="chip">{t('events_attend_count')}: {item.attendCount}</span>
                    <span className="chip">{t('events_decline_count')}: {item.declineCount}</span>
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
                <div className="panel events-visibility-panel">
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
              <div className="composer-actions events-admin-actions">
                {isAdmin || Number(e.created_by || 0) === Number(user?.id || 0) ? (
                  <>
                    <button className="btn ghost" disabled={notifyBusyId === Number(e.id || 0)} onClick={() => notifyEventAudience(e.id, 'invite')}>
                      {t('events_notify_followers')}
                    </button>
                    <button className="btn ghost" disabled={notifyBusyId === Number(e.id || 0)} onClick={() => notifyEventAudience(e.id, 'reminder')}>
                      Katılımcılara hatırlatma
                    </button>
                    <button className="btn ghost" disabled={notifyBusyId === Number(e.id || 0)} onClick={() => notifyEventAudience(e.id, 'starts_soon')}>
                      Başlıyor bildirimi
                    </button>
                  </>
                ) : null}
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
                      <Link to={`/new/members/${Number(c.user_id || c.uye_id || 0)}`} aria-label={t('go_profile_aria', { username: c.kadi || t('member_fallback') })}>
                        <img className="avatar" src={c.resim ? `/api/media/vesikalik/${c.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt={avatarAlt(c)} />
                      </Link>
                    ) : (
                      <img className="avatar" src={c.resim ? `/api/media/vesikalik/${c.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt={avatarAlt(c)} />
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
              <aside className="events-stream-side">
                <div className="events-stream-meter-card">
                  <div className="events-stream-meter-head">
                    <span>{t('events_attend_count')}</span>
                    <strong>{item.attendCount}</strong>
                  </div>
                  <div className="events-stream-meter-track" aria-hidden="true">
                    <span className="events-stream-meter-fill is-attend" style={{ '--meter-scale': item.attendRatio }} />
                    <span className="events-stream-meter-fill is-decline" style={{ '--meter-scale': item.declineRatio }} />
                  </div>
                  <div className="events-stream-meter-foot">
                    <span>{t('events_decline_count')}</span>
                    <strong>{item.declineCount}</strong>
                  </div>
                  <div className="events-stream-side-divider" />
                  <div className="events-stream-side-meta">
                    <span>{pulseCopy.statComments}</span>
                    <strong>{item.commentCount}</strong>
                  </div>
                  <div className="events-avatar-stack">
                    {(e.attendees || []).slice(0, 4).map((attendee, attendeeIndex) => (
                      <img
                        key={`${e.id}-stack-${attendee.id || attendee.kadi || attendeeIndex}`}
                        src={eventImageUrl(attendee.resim)}
                        alt={avatarAlt(attendee)}
                        className="events-avatar-stack-item"
                        loading="lazy"
                        decoding="async"
                      />
                    ))}
                    {!e.attendees?.length ? <span className="events-avatar-stack-empty">@{e.creator_kadi || t('member_fallback')}</span> : null}
                  </div>
                </div>
              </aside>
            </div>
          </div>
        )})}
        </div>
        <div ref={sentinelRef} />
        {loadingMore ? <div className="muted">{t('events_loading_more')}</div> : null}
      </div>
    </Layout>
  );
}
