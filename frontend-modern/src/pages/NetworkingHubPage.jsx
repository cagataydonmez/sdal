import React, { useCallback, useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';
import { useI18n } from '../utils/i18n.jsx';

export default function NetworkingHubPage() {
  const { t } = useI18n();
  const [loading, setLoading] = useState(true);
  const [incoming, setIncoming] = useState([]);
  const [outgoing, setOutgoing] = useState([]);
  const [suggestions, setSuggestions] = useState([]);
  const [followingIds, setFollowingIds] = useState(() => new Set());
  const [pendingAction, setPendingAction] = useState({});

  const loadHub = useCallback(async () => {
    setLoading(true);
    try {
      const [inboxRes, suggestionRes, followsRes] = await Promise.all([
        fetch('/api/new/network/inbox?limit=12', { credentials: 'include' }),
        fetch('/api/new/explore/suggestions?limit=8&offset=0', { credentials: 'include' }),
        fetch('/api/new/follows?limit=400&offset=0', { credentials: 'include' })
      ]);

      const [inboxPayload, suggestionPayload, followsPayload] = await Promise.all([
        inboxRes.ok ? inboxRes.json() : Promise.resolve({ inbox: { connections: { incoming: [], outgoing: [] } } }),
        suggestionRes.ok ? suggestionRes.json() : Promise.resolve({ items: [] }),
        followsRes.ok ? followsRes.json() : Promise.resolve({ items: [] })
      ]);

      setIncoming(inboxPayload?.inbox?.connections?.incoming || []);
      setOutgoing(inboxPayload?.inbox?.connections?.outgoing || []);
      setSuggestions(suggestionPayload.items || []);
      setFollowingIds(new Set((followsPayload.items || []).map((item) => Number(item.following_id))));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadHub();
  }, [loadHub]);

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
      loadHub();
    });
  }

  async function ignoreRequest(requestId) {
    await runAction(`ignore-${requestId}`, async () => {
      const res = await fetch(`/api/new/connections/ignore/${requestId}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) return;
      setIncoming((prev) => prev.filter((item) => Number(item.id) !== Number(requestId)));
      emitAppChange('connection:ignored', { requestId });
    });
  }

  async function connectUser(userId) {
    await runAction(`connect-${userId}`, async () => {
      const res = await fetch(`/api/new/connections/request/${userId}`, { method: 'POST', credentials: 'include' });
      if (!res.ok) return;
      emitAppChange('connection:request', { userId });
      loadHub();
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
        <div className="panel-body muted">{t('network_hub_intro_subtitle')}</div>
      </div>

      <div className="panel">
        <h3>{t('network_hub_incoming_title')}</h3>
        <div className="panel-body stack">
          {loading ? <div className="muted">{t('loading')}</div> : null}
          {!loading && incoming.length === 0 ? <div className="muted">{t('network_hub_incoming_empty')}</div> : null}
          {incoming.map((item) => (
            <div className="member-card" key={item.id}>
              <a href={`/new/members/${item.sender_id}`}>
                <img src={item.user_resim ? `/api/media/vesikalik/${item.user_resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              </a>
              <div>
                <div className="name">{item.user_isim} {item.user_soyisim}</div>
                <div className="handle">@{item.user_kadi}</div>
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
                <img src={item.user_resim ? `/api/media/vesikalik/${item.user_resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
              </a>
              <div>
                <div className="name">{item.user_isim} {item.user_soyisim}</div>
                <div className="handle">@{item.user_kadi}</div>
              </div>
              <span className="chip">{t('connection_pending')}</span>
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
                  <button
                    className="btn ghost"
                    onClick={() => connectUser(item.id)}
                    disabled={Boolean(pendingAction[`connect-${item.id}`])}
                  >
                    {t('connection_request')}
                  </button>
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
