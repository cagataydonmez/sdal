import React, { startTransition, useCallback, useEffect, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';
import { useI18n } from '../utils/i18n.jsx';

async function readResponsePayload(res) {
  try {
    return await res.clone().json();
  } catch {
    return null;
  }
}

async function readResponseMessage(res, fallbackMessage) {
  const payload = await readResponsePayload(res);
  const message = payload?.message || payload?.error;
  if (message) return String(message);
  try {
    const text = await res.text();
    if (text) return text;
  } catch {
    // no-op
  }
  return fallbackMessage;
}

async function fetchJson(url, fallback, options = {}) {
  try {
    const res = await fetch(url, { credentials: 'include', ...options });
    if (!res.ok) {
      return {
        ok: false,
        data: fallback,
        message: await readResponseMessage(res, 'Beklenmeyen bir hata oluştu.')
      };
    }
    return { ok: true, data: await res.json(), message: '' };
  } catch {
    return { ok: false, data: fallback, message: 'İstek tamamlanamadı.' };
  }
}

function daysSince(value) {
  if (!value) return null;
  const ts = new Date(value).getTime();
  if (!Number.isFinite(ts)) return null;
  return Math.floor((Date.now() - ts) / (24 * 60 * 60 * 1000));
}

function staleHint(value, t) {
  const age = daysSince(value);
  if (age == null || age < 7) return null;
  if (age >= 30) return t('network_hub_stale_30d');
  return t('network_hub_stale_7d');
}

function emptyMetrics() {
  return {
    connections: { requested: 0, accepted: 0, pending_incoming: 0, pending_outgoing: 0 },
    mentorship: { requested: 0, accepted: 0 },
    teacherLinks: { created: 0 },
    time_to_first_network_success_days: null
  };
}

function readConnectionUserField(item, legacyKey, modernKey) {
  return item?.[legacyKey] || item?.[modernKey] || '';
}

function avatarUrl(photo) {
  return photo ? `/api/media/vesikalik/${photo}` : '/legacy/vesikalik/nophoto.jpg';
}

function PersonLink({ href, photo, name, handle, meta }) {
  return (
    <div className="network-person-block">
      <a href={href} className="network-avatar-link">
        <img src={avatarUrl(photo)} alt="" />
      </a>
      <div className="network-person-copy">
        <div className="network-person-name">{name}</div>
        <div className="network-person-handle">@{handle}</div>
        {meta ? <div className="network-person-meta">{meta}</div> : null}
      </div>
    </div>
  );
}

function SectionCard({ title, kicker, count, actions, children }) {
  return (
    <section className="panel network-section-card">
      <div className="network-section-head">
        <div>
          <span className="network-section-kicker">{kicker}</span>
          <h3>{title}</h3>
        </div>
        <div className="network-section-tools">
          {typeof count === 'number' ? <span className="chip">{count}</span> : null}
          {actions}
        </div>
      </div>
      <div className="panel-body network-section-body">{children}</div>
    </section>
  );
}

function LoadingState({ label = 'Yükleniyor...' }) {
  return (
    <div className="network-empty-state network-loading-state">
      <strong>{label}</strong>
      <span>Veriler arka planda hazırlanıyor.</span>
    </div>
  );
}

export default function NetworkingHubPage() {
  const { t } = useI18n();
  const [bootstrapping, setBootstrapping] = useState(true);
  const [hubRefreshing, setHubRefreshing] = useState(false);
  const [discoveryLoading, setDiscoveryLoading] = useState(true);
  const [metricsWindow, setMetricsWindow] = useState('30d');
  const [metrics, setMetrics] = useState(() => emptyMetrics());
  const [loadError, setLoadError] = useState('');
  const [loadNotice, setLoadNotice] = useState('');
  const [feedback, setFeedback] = useState({ type: '', message: '' });
  const [incoming, setIncoming] = useState([]);
  const [outgoing, setOutgoing] = useState([]);
  const [incomingMentorship, setIncomingMentorship] = useState([]);
  const [outgoingMentorship, setOutgoingMentorship] = useState([]);
  const [teacherEvents, setTeacherEvents] = useState([]);
  const [teacherUnreadCount, setTeacherUnreadCount] = useState(0);
  const [suggestions, setSuggestions] = useState([]);
  const [followingIds, setFollowingIds] = useState(() => new Set());
  const [incomingConnectionMap, setIncomingConnectionMap] = useState({});
  const [outgoingConnectionMap, setOutgoingConnectionMap] = useState({});
  const [pendingAction, setPendingAction] = useState({});

  const hasMountedRef = useRef(false);
  const hubRequestRef = useRef(0);
  const discoveryRequestRef = useRef(0);

  const loadHubData = useCallback(async ({ silent = false, windowValue = '30d' } = {}) => {
    const requestId = hubRequestRef.current + 1;
    hubRequestRef.current = requestId;

    if (!silent) {
      if (hasMountedRef.current) setHubRefreshing(true);
      else setBootstrapping(true);
    }
    setLoadError('');
    if (!silent) setLoadNotice('');

    const [inboxRes, metricsRes] = await Promise.all([
      fetchJson('/api/new/network/inbox?limit=12', { inbox: { connections: { incoming: [], outgoing: [] }, mentorship: { incoming: [], outgoing: [] }, teacherLinks: { events: [], unread_count: 0 } } }),
      fetchJson(`/api/new/network/metrics?window=${encodeURIComponent(windowValue)}`, { metrics: emptyMetrics() })
    ]);

    if (requestId !== hubRequestRef.current) return;

    startTransition(() => {
      setIncoming(inboxRes.data?.inbox?.connections?.incoming || []);
      setOutgoing(inboxRes.data?.inbox?.connections?.outgoing || []);
      setIncomingMentorship(inboxRes.data?.inbox?.mentorship?.incoming || []);
      setOutgoingMentorship(inboxRes.data?.inbox?.mentorship?.outgoing || []);
      setTeacherEvents(inboxRes.data?.inbox?.teacherLinks?.events || []);
      setTeacherUnreadCount(Number(inboxRes.data?.inbox?.teacherLinks?.unread_count || 0));
      setMetrics(metricsRes.data?.metrics || emptyMetrics());
    });

    if (!inboxRes.ok) {
      setLoadError(t('network_hub_load_error'));
    } else if (!metricsRes.ok && !silent) {
      setLoadNotice('Metrikler güncellenemedi. İşlem listesi hazır, sağlık kartları son bilinen veriyle gösteriliyor.');
    }

    setBootstrapping(false);
    setHubRefreshing(false);
  }, [t]);

  const loadDiscoveryData = useCallback(async ({ silent = false } = {}) => {
    const requestId = discoveryRequestRef.current + 1;
    discoveryRequestRef.current = requestId;
    if (!silent) setDiscoveryLoading(true);

    const [suggestionRes, incomingRes, outgoingRes] = await Promise.all([
      fetchJson('/api/new/explore/suggestions?limit=8&offset=0', { items: [] }),
      fetchJson('/api/new/connections/requests?direction=incoming&status=pending&limit=100&offset=0', { items: [] }),
      fetchJson('/api/new/connections/requests?direction=outgoing&status=pending&limit=100&offset=0', { items: [] })
    ]);

    if (requestId !== discoveryRequestRef.current) return;

    const nextIncomingMap = {};
    for (const item of (incomingRes.data?.items || [])) {
      const senderId = Number(item?.sender_id || 0);
      if (!senderId) continue;
      nextIncomingMap[senderId] = Number(item?.id || 0);
    }

    const nextOutgoingMap = {};
    for (const item of (outgoingRes.data?.items || [])) {
      const receiverId = Number(item?.receiver_id || 0);
      if (!receiverId) continue;
      nextOutgoingMap[receiverId] = Number(item?.id || 0);
    }

    startTransition(() => {
      setSuggestions(suggestionRes.data?.items || []);
      setIncomingConnectionMap(nextIncomingMap);
      setOutgoingConnectionMap(nextOutgoingMap);
    });

    if (!silent && (!suggestionRes.ok || !incomingRes.ok || !outgoingRes.ok)) {
      setLoadNotice('Öneriler yavaş yanıt veriyor. Öncelikli istekler hazır, keşif kartları arka planda yenileniyor.');
    }
    setDiscoveryLoading(false);
  }, []);

  const refreshAfterAction = useCallback(() => {
    void loadHubData({ silent: true, windowValue: metricsWindow });
    void loadDiscoveryData({ silent: true });
  }, [loadDiscoveryData, loadHubData, metricsWindow]);

  useEffect(() => {
    hasMountedRef.current = true;
    void loadHubData({ silent: false, windowValue: metricsWindow });
    const discoveryTimer = window.setTimeout(() => {
      void loadDiscoveryData({ silent: false });
    }, 80);

    return () => {
      window.clearTimeout(discoveryTimer);
      hasMountedRef.current = false;
    };
  }, [loadDiscoveryData, loadHubData]);

  useEffect(() => {
    if (!hasMountedRef.current) return;
    const refreshTimer = window.setInterval(() => {
      void loadHubData({ silent: true, windowValue: metricsWindow });
      void loadDiscoveryData({ silent: true });
    }, 25000);
    return () => window.clearInterval(refreshTimer);
  }, [loadDiscoveryData, loadHubData, metricsWindow]);

  useEffect(() => {
    if (!bootstrapping) {
      void loadHubData({ silent: true, windowValue: metricsWindow });
    }
  }, [bootstrapping, loadHubData, metricsWindow]);

  async function runAction(key, action) {
    if (pendingAction[key]) return;
    setPendingAction((prev) => ({ ...prev, [key]: true }));
    setFeedback({ type: '', message: '' });
    try {
      await action();
    } finally {
      setPendingAction((prev) => ({ ...prev, [key]: false }));
    }
  }

  function incrementMetric(path, delta) {
    setMetrics((prev) => {
      const next = {
        ...prev,
        connections: { ...(prev.connections || {}) },
        mentorship: { ...(prev.mentorship || {}) },
        teacherLinks: { ...(prev.teacherLinks || {}) }
      };
      if (path === 'connections.accepted') next.connections.accepted = Math.max(0, Number(next.connections.accepted || 0) + delta);
      if (path === 'connections.pending_incoming') next.connections.pending_incoming = Math.max(0, Number(next.connections.pending_incoming || 0) + delta);
      if (path === 'connections.pending_outgoing') next.connections.pending_outgoing = Math.max(0, Number(next.connections.pending_outgoing || 0) + delta);
      if (path === 'mentorship.accepted') next.mentorship.accepted = Math.max(0, Number(next.mentorship.accepted || 0) + delta);
      if (path === 'teacherLinks.created') next.teacherLinks.created = Math.max(0, Number(next.teacherLinks.created || 0) + delta);
      return next;
    });
  }

  async function acceptRequest(requestId) {
    await runAction(`accept-${requestId}`, async () => {
      const senderId = Number(incoming.find((item) => Number(item.id) === Number(requestId))?.sender_id || 0);
      const res = await fetch(`/api/new/connections/accept/${requestId}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) {
        setFeedback({ type: 'error', message: await readResponseMessage(res, 'Bağlantı isteği kabul edilemedi.') });
        return;
      }
      setIncoming((prev) => prev.filter((item) => Number(item.id) !== Number(requestId)));
      if (senderId > 0) {
        setIncomingConnectionMap((prev) => {
          const next = { ...prev };
          delete next[senderId];
          return next;
        });
        setOutgoingConnectionMap((prev) => {
          const next = { ...prev };
          delete next[senderId];
          return next;
        });
        setSuggestions((prev) => prev.filter((item) => Number(item.id) !== senderId));
      }
      incrementMetric('connections.pending_incoming', -1);
      incrementMetric('connections.accepted', 1);
      emitAppChange('connection:accepted', { requestId });
      setFeedback({ type: 'ok', message: 'Bağlantı isteği kabul edildi.' });
      refreshAfterAction();
    });
  }

  async function ignoreRequest(requestId) {
    await runAction(`ignore-${requestId}`, async () => {
      const senderId = Number(incoming.find((item) => Number(item.id) === Number(requestId))?.sender_id || 0);
      const res = await fetch(`/api/new/connections/ignore/${requestId}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) {
        setFeedback({ type: 'error', message: await readResponseMessage(res, 'Bağlantı isteği yok sayılamadı.') });
        return;
      }
      setIncoming((prev) => prev.filter((item) => Number(item.id) !== Number(requestId)));
      if (senderId > 0) {
        setIncomingConnectionMap((prev) => {
          const next = { ...prev };
          delete next[senderId];
          return next;
        });
      }
      incrementMetric('connections.pending_incoming', -1);
      emitAppChange('connection:ignored', { requestId });
      setFeedback({ type: 'ok', message: 'Bağlantı isteği yok sayıldı.' });
      refreshAfterAction();
    });
  }

  async function connectUser(userId) {
    await runAction(`connect-${userId}`, async () => {
      const targetId = Number(userId || 0);
      if (!targetId) return;
      const incomingRequestId = Number(incomingConnectionMap[targetId] || 0);
      const outgoingRequestId = Number(outgoingConnectionMap[targetId] || 0);
      const endpoint = incomingRequestId
        ? `/api/new/connections/accept/${incomingRequestId}`
        : outgoingRequestId
          ? `/api/new/connections/cancel/${outgoingRequestId}`
          : `/api/new/connections/request/${targetId}`;
      const res = await fetch(endpoint, { method: 'POST', credentials: 'include' });
      if (!res.ok) {
        const message = await readResponseMessage(res, 'Bağlantı işlemi başarısız.');
        setFeedback({ type: 'error', message });
        refreshAfterAction();
        return;
      }

      const payload = await readResponsePayload(res);
      if (incomingRequestId) {
        setIncoming((prev) => prev.filter((item) => Number(item.id) !== incomingRequestId));
        setSuggestions((prev) => prev.filter((item) => Number(item.id) !== targetId));
        setIncomingConnectionMap((prev) => {
          const next = { ...prev };
          delete next[targetId];
          return next;
        });
        setOutgoingConnectionMap((prev) => {
          const next = { ...prev };
          delete next[targetId];
          return next;
        });
        incrementMetric('connections.pending_incoming', -1);
        incrementMetric('connections.accepted', 1);
      } else if (outgoingRequestId) {
        setOutgoingConnectionMap((prev) => {
          const next = { ...prev };
          delete next[targetId];
          return next;
        });
        incrementMetric('connections.pending_outgoing', -1);
      } else {
        const nextRequestId = Number(payload?.request_id || 0);
        if (nextRequestId > 0) {
          setOutgoingConnectionMap((prev) => ({ ...prev, [targetId]: nextRequestId }));
        }
        incrementMetric('connections.pending_outgoing', 1);
      }

      emitAppChange(
        incomingRequestId ? 'connection:accepted' : outgoingRequestId ? 'connection:cancelled' : 'connection:request',
        { userId: targetId, requestId: incomingRequestId || outgoingRequestId || payload?.request_id || 0 }
      );
      setFeedback({
        type: 'ok',
        message: incomingRequestId ? 'Bağlantı isteği kabul edildi.' : outgoingRequestId ? 'Bağlantı isteği geri çekildi.' : 'Yeni bağlantı isteği gönderildi.'
      });
      refreshAfterAction();
    });
  }

  async function acceptMentorship(id) {
    await runAction(`mentorship-accept-${id}`, async () => {
      const res = await fetch(`/api/new/mentorship/accept/${id}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) {
        setFeedback({ type: 'error', message: await readResponseMessage(res, 'Mentorluk talebi kabul edilemedi.') });
        return;
      }
      setIncomingMentorship((prev) => prev.filter((item) => Number(item.id) !== Number(id)));
      incrementMetric('mentorship.accepted', 1);
      emitAppChange('mentorship:accepted', { id });
      setFeedback({ type: 'ok', message: 'Mentorluk talebi kabul edildi.' });
      refreshAfterAction();
    });
  }

  async function declineMentorship(id) {
    await runAction(`mentorship-decline-${id}`, async () => {
      const res = await fetch(`/api/new/mentorship/decline/${id}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) {
        setFeedback({ type: 'error', message: await readResponseMessage(res, 'Mentorluk talebi reddedilemedi.') });
        return;
      }
      setIncomingMentorship((prev) => prev.filter((item) => Number(item.id) !== Number(id)));
      setFeedback({ type: 'ok', message: 'Mentorluk talebi reddedildi.' });
      refreshAfterAction();
    });
  }

  async function markTeacherLinksRead() {
    await runAction('teacher-links-read', async () => {
      const res = await fetch('/api/new/network/inbox/teacher-links/read', { method: 'POST', credentials: 'include' });
      if (!res.ok) {
        setFeedback({ type: 'error', message: await readResponseMessage(res, 'Bildirimler güncellenemedi.') });
        return;
      }
      emitAppChange('teacher-links:read');
      setTeacherUnreadCount(0);
      setTeacherEvents((prev) => prev.map((item) => ({ ...item, read_at: item.read_at || new Date().toISOString() })));
      setFeedback({ type: 'ok', message: 'Öğretmen ağı bildirimleri okundu olarak işaretlendi.' });
    });
  }

  async function toggleFollow(userId) {
    await runAction(`follow-${userId}`, async () => {
      const res = await fetch(`/api/new/follow/${userId}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) {
        setFeedback({ type: 'error', message: await readResponseMessage(res, 'Takip durumu değiştirilemedi.') });
        return;
      }
      setFollowingIds((prev) => {
        const next = new Set(prev);
        const key = Number(userId);
        if (next.has(key)) next.delete(key);
        else next.add(key);
        return next;
      });
      emitAppChange('follow:changed', { userId });
      setFeedback({ type: 'ok', message: 'Takip durumu güncellendi.' });
      setSuggestions((prev) => prev.filter((item) => Number(item.id) !== Number(userId)));
      refreshAfterAction();
    });
  }

  const actionableCount = incoming.length + incomingMentorship.length + teacherUnreadCount;
  const acceptedConnections = Number(metrics.connections?.accepted || 0);
  const mentorshipWins = Number(metrics.mentorship?.accepted || 0);
  const teacherLinksCreated = Number(metrics.teacherLinks?.created || 0);

  return (
    <Layout title={t('network_hub_title')}>
      <section className="network-hero">
        <div className="network-hero-copy">
          <span className="network-eyebrow">Networking command center</span>
          <h2>{t('network_hub_intro_title')}</h2>
          <p>{t('network_hub_intro_subtitle')}</p>
          <div className="network-inline-stats">
            <div className="network-inline-stat">
              <strong>{actionableCount}</strong>
              <span>Aksiyon bekleyen konu</span>
            </div>
            <div className="network-inline-stat">
              <strong>{acceptedConnections}</strong>
              <span>Kabul edilen bağlantı</span>
            </div>
            <div className="network-inline-stat">
              <strong>{mentorshipWins + teacherLinksCreated}</strong>
              <span>Mentorluk ve öğretmen bağı</span>
            </div>
          </div>
        </div>
        <div className="network-hero-actions">
          <a className="btn primary" href="/new/explore">Yeni kişi keşfet</a>
          <a className="btn ghost" href="/new/network/teachers">Öğretmen ağına git</a>
          <a className="btn ghost" href="/new/messages">Mesaj kutusuna git</a>
          {hubRefreshing ? <span className="chip">Arka planda güncelleniyor</span> : null}
        </div>
      </section>

      <div className="network-feedback-slot">
        {feedback.message ? <div className={feedback.type === 'error' ? 'error' : 'ok'}>{feedback.message}</div> : null}
        {loadError ? <div className="error">{loadError}</div> : null}
        {loadNotice ? <div className="network-soft-alert">{loadNotice}</div> : null}
      </div>

      <section className="panel network-section-card">
        <div className="network-section-head">
          <div>
            <span className="network-section-kicker">Health snapshot</span>
            <h3>{t('network_hub_metrics_title')}</h3>
          </div>
          <div className="network-section-tools">
            <div className="network-window-tabs">
              {['7d', '30d', '90d'].map((windowValue) => (
                <button
                  key={windowValue}
                  className={`btn ${metricsWindow === windowValue ? 'primary' : 'ghost'}`}
                  onClick={() => setMetricsWindow(windowValue)}
                >
                  {t('network_hub_window_days', { days: windowValue.replace('d', '') })}
                </button>
              ))}
            </div>
          </div>
        </div>
        <div className="panel-body network-section-body">
          {bootstrapping ? <LoadingState label={t('loading')} /> : (
            <div className="network-metric-grid">
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_connections')}</span>
                <strong>{metrics.connections?.accepted || 0}</strong>
                <p>{t('network_hub_metric_requested_short', { count: metrics.connections?.requested || 0 })}</p>
              </div>
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_pending')}</span>
                <strong>{metrics.connections?.pending_incoming || 0}</strong>
                <p>{t('network_hub_metric_outgoing_short', { count: metrics.connections?.pending_outgoing || 0 })}</p>
              </div>
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_mentorship')}</span>
                <strong>{metrics.mentorship?.accepted || 0}</strong>
                <p>{t('network_hub_metric_requested_short', { count: metrics.mentorship?.requested || 0 })}</p>
              </div>
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_teacher_links')}</span>
                <strong>{metrics.teacherLinks?.created || 0}</strong>
                <p>
                  {metrics.time_to_first_network_success_days == null
                    ? t('network_hub_metric_ttf_empty')
                    : t('network_hub_metric_ttf_value', { days: metrics.time_to_first_network_success_days })}
                </p>
              </div>
            </div>
          )}
        </div>
      </section>

      <div className="network-dashboard">
        <div className="network-column">
          <SectionCard title={t('network_hub_incoming_title')} kicker="Priority queue" count={incoming.length}>
            {bootstrapping ? <LoadingState label={t('loading')} /> : null}
            {!bootstrapping && incoming.length === 0 ? <div className="network-empty-state"><strong>Temiz görünüm.</strong><span>{t('network_hub_incoming_empty')}</span></div> : null}
            {!bootstrapping ? (
              <div className="network-list">
                {incoming.map((item) => (
                  <article className="network-action-card" key={item.id}>
                    <PersonLink
                      href={`/new/members/${item.sender_id}`}
                      photo={readConnectionUserField(item, 'user_resim', 'resim')}
                      name={`${readConnectionUserField(item, 'user_isim', 'isim')} ${readConnectionUserField(item, 'user_soyisim', 'soyisim')}`}
                      handle={readConnectionUserField(item, 'user_kadi', 'kadi')}
                    />
                    <div className="network-card-actions">
                      <button className="btn primary" onClick={() => acceptRequest(item.id)} disabled={Boolean(pendingAction[`accept-${item.id}`])}>{t('connection_accept')}</button>
                      <button className="btn ghost" onClick={() => ignoreRequest(item.id)} disabled={Boolean(pendingAction[`ignore-${item.id}`])}>{t('ignore')}</button>
                    </div>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>

          <SectionCard title={t('network_hub_mentorship_incoming_title')} kicker="Mentor queue" count={incomingMentorship.length}>
            {bootstrapping ? <LoadingState label={t('loading')} /> : null}
            {!bootstrapping && incomingMentorship.length === 0 ? <div className="network-empty-state"><strong>Mentorluk kuyruğu boş.</strong><span>{t('network_hub_mentorship_incoming_empty')}</span></div> : null}
            {!bootstrapping ? (
              <div className="network-list">
                {incomingMentorship.map((item) => (
                  <article className="network-action-card" key={`mi-${item.id}`}>
                    <PersonLink
                      href={`/new/members/${item.requester_id}`}
                      photo={item.resim}
                      name={`${item.isim} ${item.soyisim}`}
                      handle={item.kadi}
                      meta={item.focus_area || staleHint(item.created_at, t)}
                    />
                    <div className="network-card-actions">
                      <button className="btn primary" onClick={() => acceptMentorship(item.id)} disabled={Boolean(pendingAction[`mentorship-accept-${item.id}`])}>{t('connection_accept')}</button>
                      <button className="btn ghost" onClick={() => declineMentorship(item.id)} disabled={Boolean(pendingAction[`mentorship-decline-${item.id}`])}>{t('network_hub_decline')}</button>
                    </div>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>
        </div>

        <div className="network-column">
          <SectionCard
            title={t('network_hub_teacher_links_title')}
            kicker="Verified graph"
            count={teacherUnreadCount}
            actions={teacherUnreadCount > 0 ? (
              <button className="btn ghost" onClick={markTeacherLinksRead} disabled={Boolean(pendingAction['teacher-links-read'])}>
                {t('network_hub_mark_teacher_links_read')}
              </button>
            ) : null}
          >
            {bootstrapping ? <LoadingState label={t('loading')} /> : null}
            {!bootstrapping && teacherEvents.length === 0 ? <div className="network-empty-state"><strong>Yeni öğretmen bildirimi yok.</strong><span>{t('network_hub_teacher_links_empty')}</span></div> : null}
            {!bootstrapping ? (
              <div className="network-list">
                {teacherEvents.map((item) => (
                  <article className="network-action-card" key={`tl-${item.id}`}>
                    <PersonLink
                      href={`/new/members/${item.source_user_id}`}
                      photo={item.resim}
                      name={`${item.isim} ${item.soyisim}`}
                      handle={item.kadi}
                      meta={item.message || t('network_hub_teacher_links_default_message')}
                    />
                    {!item.read_at ? <span className="chip">Yeni</span> : null}
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>

          <SectionCard title={t('network_hub_outgoing_title')} kicker="Pipeline" count={outgoing.length}>
            {bootstrapping ? <LoadingState label={t('loading')} /> : null}
            {!bootstrapping && outgoing.length === 0 ? <div className="network-empty-state"><strong>Bekleyen giden istek yok.</strong><span>{t('network_hub_outgoing_empty')}</span></div> : null}
            {!bootstrapping ? (
              <div className="network-list">
                {outgoing.map((item) => (
                  <article className="network-action-card" key={item.id}>
                    <PersonLink
                      href={`/new/members/${item.receiver_id}`}
                      photo={readConnectionUserField(item, 'user_resim', 'resim')}
                      name={`${readConnectionUserField(item, 'user_isim', 'isim')} ${readConnectionUserField(item, 'user_soyisim', 'soyisim')}`}
                      handle={readConnectionUserField(item, 'user_kadi', 'kadi')}
                    />
                    <span className="chip">{t('connection_pending')}</span>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>

          <SectionCard title={t('network_hub_mentorship_outgoing_title')} kicker="Outbound mentor asks" count={outgoingMentorship.length}>
            {bootstrapping ? <LoadingState label={t('loading')} /> : null}
            {!bootstrapping && outgoingMentorship.length === 0 ? <div className="network-empty-state"><strong>Bekleyen mentorluk isteği yok.</strong><span>{t('network_hub_mentorship_outgoing_empty')}</span></div> : null}
            {!bootstrapping ? (
              <div className="network-list">
                {outgoingMentorship.map((item) => (
                  <article className="network-action-card" key={`mo-${item.id}`}>
                    <PersonLink
                      href={`/new/members/${item.mentor_id}`}
                      photo={item.resim}
                      name={`${item.isim} ${item.soyisim}`}
                      handle={item.kadi}
                      meta={item.focus_area || staleHint(item.created_at, t)}
                    />
                    <a className="btn ghost" href="/new/messages">{t('member_send_message')}</a>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>
        </div>
      </div>

      <SectionCard title={t('network_hub_suggestions_title')} kicker="Discovery engine" count={suggestions.length}>
        {discoveryLoading ? <LoadingState label="Öneriler hazırlanıyor..." /> : null}
        {!discoveryLoading && suggestions.length === 0 ? <div className="network-empty-state"><strong>Şimdilik yeni öneri yok.</strong><span>Biraz sonra tekrar yenilendiğinde yeni bağlantı adayları görünecek.</span></div> : null}
        {!discoveryLoading ? (
          <div className="network-suggestion-grid">
            {suggestions.map((item) => {
              const key = Number(item.id || 0);
              const incomingRequestId = Number(incomingConnectionMap[key] || 0);
              const outgoingRequestId = Number(outgoingConnectionMap[key] || 0);
              const outgoingPending = outgoingRequestId > 0;
              const label = incomingRequestId
                ? t('connection_accept')
                : outgoingPending
                  ? t('connection_withdraw')
                  : t('connection_request');
              return (
                <article className="network-suggestion-card" key={item.id}>
                  <PersonLink
                    href={`/new/members/${item.id}`}
                    photo={item.resim}
                    name={`${item.isim} ${item.soyisim}${item.verified ? ' ✓' : ''}`}
                    handle={item.kadi}
                    meta={Array.isArray(item.reasons) && item.reasons.length > 0 ? item.reasons[0] : ''}
                  />
                  <div className="network-card-actions">
                    <button
                      className="btn ghost"
                      onClick={() => connectUser(item.id)}
                      disabled={Boolean(pendingAction[`connect-${item.id}`])}
                    >
                      {label}
                    </button>
                    <button
                      className="btn ghost"
                      onClick={() => toggleFollow(item.id)}
                      disabled={Boolean(pendingAction[`follow-${item.id}`])}
                    >
                      {followingIds.has(Number(item.id)) ? t('unfollow') : t('follow')}
                    </button>
                  </div>
                </article>
              );
            })}
          </div>
        ) : null}
      </SectionCard>
    </Layout>
  );
}
