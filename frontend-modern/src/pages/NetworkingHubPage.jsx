import React, { useCallback, useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';
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

export default function NetworkingHubPage() {
  const { t } = useI18n();
  const [loading, setLoading] = useState(true);
  const [metricsLoading, setMetricsLoading] = useState(true);
  const [metricsWindow, setMetricsWindow] = useState('30d');
  const [metrics, setMetrics] = useState(() => emptyMetrics());
  const [loadError, setLoadError] = useState('');
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

  function readConnectionUserField(item, legacyKey, modernKey) {
    return item?.[legacyKey] || item?.[modernKey] || '';
  }

  const loadHub = useCallback(async () => {
    setLoading(true);
    setLoadError('');
    try {
      const [inboxRes, suggestionRes, followsRes, incomingRes, outgoingRes] = await Promise.all([
        fetch('/api/new/network/inbox?limit=12', { credentials: 'include' }),
        fetch('/api/new/explore/suggestions?limit=8&offset=0', { credentials: 'include' }),
        fetch('/api/new/follows?limit=400&offset=0', { credentials: 'include' }),
        fetch('/api/new/connections/requests?direction=incoming&status=pending&limit=100&offset=0', { credentials: 'include' }),
        fetch('/api/new/connections/requests?direction=outgoing&status=pending&limit=100&offset=0', { credentials: 'include' })
      ]);

      const [inboxPayload, suggestionPayload, followsPayload, incomingPayload, outgoingPayload] = await Promise.all([
        inboxRes.ok ? inboxRes.json() : Promise.resolve({ inbox: { connections: { incoming: [], outgoing: [] } } }),
        suggestionRes.ok ? suggestionRes.json() : Promise.resolve({ items: [] }),
        followsRes.ok ? followsRes.json() : Promise.resolve({ items: [] }),
        incomingRes.ok ? incomingRes.json() : Promise.resolve({ items: [] }),
        outgoingRes.ok ? outgoingRes.json() : Promise.resolve({ items: [] })
      ]);

      const nextIncomingMap = {};
      for (const item of (incomingPayload.items || [])) {
        const senderId = Number(item?.sender_id || 0);
        if (!senderId) continue;
        nextIncomingMap[senderId] = Number(item?.id || 0);
      }

      setIncoming(inboxPayload?.inbox?.connections?.incoming || []);
      setOutgoing(inboxPayload?.inbox?.connections?.outgoing || []);
      setIncomingMentorship(inboxPayload?.inbox?.mentorship?.incoming || []);
      setOutgoingMentorship(inboxPayload?.inbox?.mentorship?.outgoing || []);
      setTeacherEvents(inboxPayload?.inbox?.teacherLinks?.events || []);
      setTeacherUnreadCount(Number(inboxPayload?.inbox?.teacherLinks?.unread_count || 0));
      setSuggestions(suggestionPayload.items || []);
      setFollowingIds(new Set((followsPayload.items || []).map((item) => Number(item.following_id))));
      const nextOutgoingMap = {};
      for (const item of (outgoingPayload.items || [])) {
        const receiverId = Number(item?.receiver_id || 0);
        if (!receiverId) continue;
        nextOutgoingMap[receiverId] = Number(item?.id || 0);
      }
      setIncomingConnectionMap(nextIncomingMap);
      setOutgoingConnectionMap(nextOutgoingMap);
    } catch {
      setLoadError(t('network_hub_load_error'));
    } finally {
      setLoading(false);
    }
  }, [t]);

  const loadMetrics = useCallback(async (windowValue = metricsWindow) => {
    setMetricsLoading(true);
    try {
      const res = await fetch(`/api/new/network/metrics?window=${encodeURIComponent(windowValue)}`, { credentials: 'include' });
      if (!res.ok) {
        setMetrics(emptyMetrics());
        return;
      }
      const payload = await res.json();
      setMetrics(payload?.metrics || emptyMetrics());
    } catch {
      setMetrics(emptyMetrics());
    } finally {
      setMetricsLoading(false);
    }
  }, [metricsWindow]);

  useEffect(() => {
    loadHub();
  }, [loadHub]);

  useEffect(() => {
    loadMetrics(metricsWindow);
  }, [loadMetrics, metricsWindow]);

  async function runAction(key, action) {
    if (pendingAction[key]) return;
    setPendingAction((prev) => ({ ...prev, [key]: true }));
    try {
      await action();
    } finally {
      setPendingAction((prev) => ({ ...prev, [key]: false }));
    }
  }

  async function acceptRequest(requestId) {
    await runAction(`accept-${requestId}`, async () => {
      const res = await fetch(`/api/new/connections/accept/${requestId}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) return;
      setIncoming((prev) => prev.filter((item) => Number(item.id) !== Number(requestId)));
      emitAppChange('connection:accepted', { requestId });
      await Promise.all([loadHub(), loadMetrics(metricsWindow)]);
    });
  }

  async function ignoreRequest(requestId) {
    await runAction(`ignore-${requestId}`, async () => {
      const res = await fetch(`/api/new/connections/ignore/${requestId}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) return;
      setIncoming((prev) => prev.filter((item) => Number(item.id) !== Number(requestId)));
      emitAppChange('connection:ignored', { requestId });
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
        window.alert(await readResponseMessage(res, 'Bağlantı işlemi başarısız.'));
        return;
      }
      emitAppChange(
        incomingRequestId ? 'connection:accepted' : outgoingRequestId ? 'connection:cancelled' : 'connection:request',
        { userId: targetId, requestId: incomingRequestId || outgoingRequestId }
      );
      await Promise.all([loadHub(), loadMetrics(metricsWindow)]);
    });
  }

  async function acceptMentorship(id) {
    await runAction(`mentorship-accept-${id}`, async () => {
      const res = await fetch(`/api/new/mentorship/accept/${id}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) return;
      setIncomingMentorship((prev) => prev.filter((item) => Number(item.id) !== Number(id)));
      loadHub();
    });
  }

  async function declineMentorship(id) {
    await runAction(`mentorship-decline-${id}`, async () => {
      const res = await fetch(`/api/new/mentorship/decline/${id}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) return;
      setIncomingMentorship((prev) => prev.filter((item) => Number(item.id) !== Number(id)));
    });
  }
  async function markTeacherLinksRead() {
    await runAction('teacher-links-read', async () => {
      const res = await fetch('/api/new/network/inbox/teacher-links/read', { method: 'POST', credentials: 'include' });
      if (!res.ok) return;
      setTeacherUnreadCount(0);
      setTeacherEvents((prev) => prev.map((item) => ({ ...item, read_at: item.read_at || new Date().toISOString() })));
    });
  }

  async function toggleFollow(userId) {
    await runAction(`follow-${userId}`, async () => {
      const res = await fetch(`/api/new/follow/${userId}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) return;
      setFollowingIds((prev) => {
        const next = new Set(prev);
        const key = Number(userId);
        if (next.has(key)) next.delete(key);
        else next.add(key);
        return next;
      });
      emitAppChange('follow:changed', { userId });
    });
  }

  return (
    <Layout title={t('network_hub_title')}>
      <div className="panel">
        <h3>{t('network_hub_intro_title')}</h3>
        <div className="panel-body stack">
          <div className="muted">{t('network_hub_intro_subtitle')}</div>
          <div className="composer-actions">
            <a className="btn ghost" href="/new/network/teachers">Öğretmen Ağına Git</a>
            <a className="btn ghost" href="/new/explore">Kişi Keşfet</a>
            <a className="btn ghost" href="/new/messages">Mesajlara Git</a>
          </div>
        </div>
      </div>

      <div className="panel">
        <h3>{t('network_hub_metrics_title')}</h3>
        <div className="panel-body stack">
          <div className="composer-actions">
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
          {metricsLoading ? <div className="muted">{t('loading')}</div> : null}
          {!metricsLoading && !metrics ? <div className="muted">{t('network_hub_metrics_empty')}</div> : null}
          {!metricsLoading && metrics ? (
            <div className="card-grid">
              <div className="member-card">
                <div className="chip">{t('network_hub_metric_connections')}</div>
                <div>
                  <div className="name">{metrics.connections?.accepted || 0}</div>
                  <div className="meta">{t('network_hub_metric_accepted')}</div>
                </div>
                <div className="muted">{t('network_hub_metric_requested_short', { count: metrics.connections?.requested || 0 })}</div>
              </div>
              <div className="member-card">
                <div className="chip">{t('network_hub_metric_pending')}</div>
                <div>
                  <div className="name">{metrics.connections?.pending_incoming || 0}</div>
                  <div className="meta">{t('network_hub_metric_incoming')}</div>
                </div>
                <div className="muted">{t('network_hub_metric_outgoing_short', { count: metrics.connections?.pending_outgoing || 0 })}</div>
              </div>
              <div className="member-card">
                <div className="chip">{t('network_hub_metric_mentorship')}</div>
                <div>
                  <div className="name">{metrics.mentorship?.accepted || 0}</div>
                  <div className="meta">{t('network_hub_metric_accepted')}</div>
                </div>
                <div className="muted">{t('network_hub_metric_requested_short', { count: metrics.mentorship?.requested || 0 })}</div>
              </div>
              <div className="member-card">
                <div className="chip">{t('network_hub_metric_teacher_links')}</div>
                <div>
                  <div className="name">{metrics.teacherLinks?.created || 0}</div>
                  <div className="meta">{t('network_hub_metric_created')}</div>
                </div>
                <div className="muted">{metrics.time_to_first_network_success_days == null ? t('network_hub_metric_ttf_empty') : t('network_hub_metric_ttf_value', { days: metrics.time_to_first_network_success_days })}</div>
              </div>
            </div>
          ) : null}
        </div>
      </div>

      <div className="panel">
        <h3>{t('network_hub_incoming_title')}</h3>
        <div className="panel-body stack">
          {loadError ? <div className="error">{loadError}</div> : null}
          {loading ? <div className="muted">{t('loading')}</div> : null}
          {!loading && incoming.length === 0 ? <div className="muted">{t('network_hub_incoming_empty')}</div> : null}
          {incoming.map((item) => (
            <div className="member-card" key={item.id}>
              <a href={`/new/members/${item.sender_id}`}>
                <img src={readConnectionUserField(item, 'user_resim', 'resim') ? `/api/media/vesikalik/${readConnectionUserField(item, 'user_resim', 'resim')}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              </a>
              <div>
                <div className="name">{readConnectionUserField(item, 'user_isim', 'isim')} {readConnectionUserField(item, 'user_soyisim', 'soyisim')}</div>
                <div className="handle">@{readConnectionUserField(item, 'user_kadi', 'kadi')}</div>
              </div>
              <div className="composer-actions">
                <button className="btn" onClick={() => acceptRequest(item.id)} disabled={Boolean(pendingAction[`accept-${item.id}`])}>{t('connection_accept')}</button>
                <button className="btn ghost" onClick={() => ignoreRequest(item.id)} disabled={Boolean(pendingAction[`ignore-${item.id}`])}>{t('ignore')}</button>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="panel">
        <h3>{t('network_hub_outgoing_title')}</h3>
        <div className="panel-body stack">
          {!loading && outgoing.length === 0 ? <div className="muted">{t('network_hub_outgoing_empty')}</div> : null}
          {outgoing.map((item) => (
            <div className="member-card" key={item.id}>
              <a href={`/new/members/${item.receiver_id}`}>
                <img src={readConnectionUserField(item, 'user_resim', 'resim') ? `/api/media/vesikalik/${readConnectionUserField(item, 'user_resim', 'resim')}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              </a>
              <div>
                <div className="name">{readConnectionUserField(item, 'user_isim', 'isim')} {readConnectionUserField(item, 'user_soyisim', 'soyisim')}</div>
                <div className="handle">@{readConnectionUserField(item, 'user_kadi', 'kadi')}</div>
              </div>
              <span className="chip">{t('connection_pending')}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="panel">
        <h3>{t('network_hub_mentorship_incoming_title')}</h3>
        <div className="panel-body stack">
          {!loading && incomingMentorship.length === 0 ? <div className="muted">{t('network_hub_mentorship_incoming_empty')}</div> : null}
          {incomingMentorship.map((item) => (
            <div className="member-card" key={`mi-${item.id}`}>
              <a href={`/new/members/${item.requester_id}`}>
                <img src={item.resim ? `/api/media/vesikalik/${item.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              </a>
              <div>
                <div className="name">{item.isim} {item.soyisim}</div>
                <div className="handle">@{item.kadi}</div>
                {item.focus_area ? <div className="meta">{item.focus_area}</div> : null}
                {staleHint(item.created_at, t) ? <div className="meta">{staleHint(item.created_at, t)}</div> : null}
              </div>
              <div className="composer-actions">
                <a className="btn ghost" href={`/new/members/${item.requester_id}`}>{t('profile_view')}</a>
                <a className="btn ghost" href="/new/messages">{t('member_send_message')}</a>
                <button className="btn" onClick={() => acceptMentorship(item.id)} disabled={Boolean(pendingAction[`mentorship-accept-${item.id}`])}>{t('connection_accept')}</button>
                <button className="btn ghost" onClick={() => declineMentorship(item.id)} disabled={Boolean(pendingAction[`mentorship-decline-${item.id}`])}>{t('network_hub_decline')}</button>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="panel">
        <h3>{t('network_hub_mentorship_outgoing_title')}</h3>
        <div className="panel-body stack">
          {!loading && outgoingMentorship.length === 0 ? <div className="muted">{t('network_hub_mentorship_outgoing_empty')}</div> : null}
          {outgoingMentorship.map((item) => (
            <div className="member-card" key={`mo-${item.id}`}>
              <a href={`/new/members/${item.mentor_id}`}>
                <img src={item.resim ? `/api/media/vesikalik/${item.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              </a>
              <div>
                <div className="name">{item.isim} {item.soyisim}</div>
                <div className="handle">@{item.kadi}</div>
                {item.focus_area ? <div className="meta">{item.focus_area}</div> : null}
                {staleHint(item.created_at, t) ? <div className="meta">{staleHint(item.created_at, t)}</div> : null}
              </div>
              <div className="composer-actions">
                <a className="btn ghost" href={`/new/members/${item.mentor_id}`}>{t('profile_view')}</a>
                <a className="btn ghost" href="/new/messages">{t('member_send_message')}</a>
                <button className="btn ghost" disabled>{t('network_hub_add_calendar')}</button>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="panel">
        <h3>{t('network_hub_teacher_links_title')} {teacherUnreadCount > 0 ? <span className="chip">{t('network_hub_unread_count', { count: teacherUnreadCount })}</span> : null}</h3>
        <div className="panel-body stack">
          {teacherUnreadCount > 0 ? (
            <button
              className="btn ghost"
              onClick={markTeacherLinksRead}
              disabled={Boolean(pendingAction['teacher-links-read'])}
            >
              {t('network_hub_mark_teacher_links_read')}
            </button>
          ) : null}
          {!loading && teacherEvents.length === 0 ? <div className="muted">{t('network_hub_teacher_links_empty')}</div> : null}
          {teacherEvents.map((item) => (
            <div className="member-card" key={`tl-${item.id}`}>
              <a href={`/new/members/${item.source_user_id}`}>
                <img src={item.resim ? `/api/media/vesikalik/${item.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              </a>
              <div>
                <div className="name">{item.isim} {item.soyisim}</div>
                <div className="handle">@{item.kadi}</div>
                <div className="meta">{item.message || t('network_hub_teacher_links_default_message')}</div>
              </div>
              <div className="composer-actions">
                <a className="btn ghost" href={`/new/members/${item.source_user_id}`}>{t('profile_view')}</a>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="panel">
        <h3>{t('network_hub_suggestions_title')}</h3>
        <div className="panel-body">
          <div className="card-grid">
            {suggestions.map((item) => (
              <div className="member-card" key={item.id}>
                <a href={`/new/members/${item.id}`}>
                  <img src={item.resim ? `/api/media/vesikalik/${item.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                </a>
                <div>
                  <div className="name">{item.isim} {item.soyisim}{item.verified ? <span className="badge">✓</span> : null}</div>
                  <div className="handle">@{item.kadi}</div>
                  {Array.isArray(item.reasons) && item.reasons.length > 0 ? <div className="meta">{item.reasons[0]}</div> : null}
                </div>
                <div className="composer-actions">
                  {(() => {
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
                      <button
                        className="btn ghost"
                        onClick={() => connectUser(item.id)}
                        disabled={Boolean(pendingAction[`connect-${item.id}`])}
                      >
                        {label}
                      </button>
                    );
                  })()}
                  <button
                    className="btn ghost"
                    onClick={() => toggleFollow(item.id)}
                    disabled={Boolean(pendingAction[`follow-${item.id}`])}
                  >
                    {followingIds.has(Number(item.id)) ? t('unfollow') : t('follow')}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Layout>
  );
}
