import React, { useCallback, useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { emitAppChange, useLiveRefresh } from '../utils/live.js';
import { useI18n } from '../utils/i18n.jsx';

async function readResponseMessage(res, fallbackMessage) {
  try {
    const payload = await res.clone().json();
    const message = payload?.message || payload?.error;
    if (message) return String(message);
  } catch {
    // no-op
  }
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
      <div className="panel-body">{children}</div>
    </section>
  );
}

export default function NetworkingHubPage() {
  const { t } = useI18n();
  const [loading, setLoading] = useState(true);
  const [metricsLoading, setMetricsLoading] = useState(true);
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

  const loadHub = useCallback(async () => {
    setLoading(true);
    setLoadError('');
    setLoadNotice('');

    const [inboxRes, suggestionRes, followsRes, incomingRes, outgoingRes] = await Promise.all([
      fetchJson('/api/new/network/inbox?limit=12', { inbox: { connections: { incoming: [], outgoing: [] }, mentorship: { incoming: [], outgoing: [] }, teacherLinks: { events: [], unread_count: 0 } } }),
      fetchJson('/api/new/explore/suggestions?limit=8&offset=0', { items: [] }),
      fetchJson('/api/new/follows?limit=400&offset=0', { items: [] }),
      fetchJson('/api/new/connections/requests?direction=incoming&status=pending&limit=100&offset=0', { items: [] }),
      fetchJson('/api/new/connections/requests?direction=outgoing&status=pending&limit=100&offset=0', { items: [] })
    ]);

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

    setIncoming(inboxRes.data?.inbox?.connections?.incoming || []);
    setOutgoing(inboxRes.data?.inbox?.connections?.outgoing || []);
    setIncomingMentorship(inboxRes.data?.inbox?.mentorship?.incoming || []);
    setOutgoingMentorship(inboxRes.data?.inbox?.mentorship?.outgoing || []);
    setTeacherEvents(inboxRes.data?.inbox?.teacherLinks?.events || []);
    setTeacherUnreadCount(Number(inboxRes.data?.inbox?.teacherLinks?.unread_count || 0));
    setSuggestions(suggestionRes.data?.items || []);
    setFollowingIds(new Set((followsRes.data?.items || []).map((item) => Number(item.following_id))));
    setIncomingConnectionMap(nextIncomingMap);
    setOutgoingConnectionMap(nextOutgoingMap);

    if (!inboxRes.ok) {
      setLoadError(t('network_hub_load_error'));
    } else {
      const degradedResults = [suggestionRes, followsRes, incomingRes, outgoingRes].filter((result) => !result.ok);
      if (degradedResults.length > 0) {
        setLoadNotice('Bazı networking bileşenleri eksik yüklendi. Sayfa temel akışıyla çalışıyor, yenileme ile tam veri alınabilir.');
      }
    }

    setLoading(false);
  }, [t]);

  const loadMetrics = useCallback(async (windowValue = metricsWindow) => {
    setMetricsLoading(true);
    const res = await fetchJson(`/api/new/network/metrics?window=${encodeURIComponent(windowValue)}`, emptyMetrics());
    setMetrics(res.ok ? (res.data?.metrics || emptyMetrics()) : emptyMetrics());
    setMetricsLoading(false);
  }, [metricsWindow]);

  useEffect(() => {
    loadHub();
  }, [loadHub]);

  useEffect(() => {
    loadMetrics(metricsWindow);
  }, [loadMetrics, metricsWindow]);

  useLiveRefresh(loadHub, {
    intervalMs: 15000,
    eventTypes: ['connection:accepted', 'connection:ignored', 'connection:cancelled', 'connection:request', 'follow:changed', 'mentorship:accepted', 'teacher-links:read'],
    enabled: true
  });
  useLiveRefresh(() => loadMetrics(metricsWindow), {
    intervalMs: 20000,
    eventTypes: ['connection:accepted', 'connection:request', 'mentorship:accepted'],
    enabled: true
  });

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

  async function acceptRequest(requestId) {
    await runAction(`accept-${requestId}`, async () => {
      const res = await fetch(`/api/new/connections/accept/${requestId}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) {
        setFeedback({ type: 'error', message: await readResponseMessage(res, 'Bağlantı isteği kabul edilemedi.') });
        return;
      }
      emitAppChange('connection:accepted', { requestId });
      setFeedback({ type: 'ok', message: 'Bağlantı isteği kabul edildi.' });
      await Promise.all([loadHub(), loadMetrics(metricsWindow)]);
    });
  }

  async function ignoreRequest(requestId) {
    await runAction(`ignore-${requestId}`, async () => {
      const res = await fetch(`/api/new/connections/ignore/${requestId}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) {
        setFeedback({ type: 'error', message: await readResponseMessage(res, 'Bağlantı isteği yok sayılamadı.') });
        return;
      }
      emitAppChange('connection:ignored', { requestId });
      setFeedback({ type: 'ok', message: 'Bağlantı isteği yok sayıldı.' });
      await Promise.all([loadHub(), loadMetrics(metricsWindow)]);
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
        if (res.status === 409 && message.toLowerCase().includes('zaten bekleyen')) {
          await Promise.all([loadHub(), loadMetrics(metricsWindow)]);
        }
        setFeedback({ type: 'error', message });
        return;
      }
      emitAppChange(
        incomingRequestId ? 'connection:accepted' : outgoingRequestId ? 'connection:cancelled' : 'connection:request',
        { userId: targetId, requestId: incomingRequestId || outgoingRequestId }
      );
      setFeedback({
        type: 'ok',
        message: incomingRequestId ? 'Bağlantı isteği kabul edildi.' : outgoingRequestId ? 'Bağlantı isteği geri çekildi.' : 'Yeni bağlantı isteği gönderildi.'
      });
      await Promise.all([loadHub(), loadMetrics(metricsWindow)]);
    });
  }

  async function acceptMentorship(id) {
    await runAction(`mentorship-accept-${id}`, async () => {
      const res = await fetch(`/api/new/mentorship/accept/${id}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) {
        setFeedback({ type: 'error', message: await readResponseMessage(res, 'Mentorluk talebi kabul edilemedi.') });
        return;
      }
      emitAppChange('mentorship:accepted', { id });
      setFeedback({ type: 'ok', message: 'Mentorluk talebi kabul edildi.' });
      await Promise.all([loadHub(), loadMetrics(metricsWindow)]);
    });
  }

  async function declineMentorship(id) {
    await runAction(`mentorship-decline-${id}`, async () => {
      const res = await fetch(`/api/new/mentorship/decline/${id}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) {
        setFeedback({ type: 'error', message: await readResponseMessage(res, 'Mentorluk talebi reddedilemedi.') });
        return;
      }
      setFeedback({ type: 'ok', message: 'Mentorluk talebi reddedildi.' });
      await loadHub();
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
        </div>
      </section>

      {feedback.message ? <div className={feedback.type === 'error' ? 'error' : 'ok'}>{feedback.message}</div> : null}
      {loadError ? <div className="error">{loadError}</div> : null}
      {loadNotice ? <div className="network-soft-alert">{loadNotice}</div> : null}

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
        <div className="panel-body">
          {metricsLoading ? <div className="muted">{t('loading')}</div> : null}
          {!metricsLoading ? (
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
          ) : null}
        </div>
      </section>

      <div className="network-dashboard">
        <div className="network-column">
          <SectionCard
            title={t('network_hub_incoming_title')}
            kicker="Priority queue"
            count={incoming.length}
          >
            {loading ? <div className="muted">{t('loading')}</div> : null}
            {!loading && incoming.length === 0 ? <div className="network-empty-state"><strong>Temiz görünüm.</strong><span>{t('network_hub_incoming_empty')}</span></div> : null}
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
          </SectionCard>

          <SectionCard
            title={t('network_hub_mentorship_incoming_title')}
            kicker="Mentor queue"
            count={incomingMentorship.length}
          >
            {!loading && incomingMentorship.length === 0 ? <div className="network-empty-state"><strong>Mentorluk kuyruğu boş.</strong><span>{t('network_hub_mentorship_incoming_empty')}</span></div> : null}
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
            {!loading && teacherEvents.length === 0 ? <div className="network-empty-state"><strong>Yeni öğretmen bildirimi yok.</strong><span>{t('network_hub_teacher_links_empty')}</span></div> : null}
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
          </SectionCard>

          <SectionCard
            title={t('network_hub_outgoing_title')}
            kicker="Pipeline"
            count={outgoing.length}
          >
            {!loading && outgoing.length === 0 ? <div className="network-empty-state"><strong>Bekleyen giden istek yok.</strong><span>{t('network_hub_outgoing_empty')}</span></div> : null}
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
          </SectionCard>

          <SectionCard
            title={t('network_hub_mentorship_outgoing_title')}
            kicker="Outbound mentor asks"
            count={outgoingMentorship.length}
          >
            {!loading && outgoingMentorship.length === 0 ? <div className="network-empty-state"><strong>Bekleyen mentorluk isteği yok.</strong><span>{t('network_hub_mentorship_outgoing_empty')}</span></div> : null}
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
          </SectionCard>
        </div>
      </div>

      <SectionCard
        title={t('network_hub_suggestions_title')}
        kicker="Discovery engine"
        count={suggestions.length}
      >
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
      </SectionCard>
    </Layout>
  );
}
