import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import { useI18n } from '../utils/i18n.jsx';

function stripHtml(value) {
  return String(value || '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}

function asInt(value) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
}

function deliveryState(message, mine) {
  if (!mine) return '';
  if (message?.readAt || message?.read_at) return 'read';
  if (message?.deliveredAt || message?.delivered_at) return 'delivered';
  return 'sent';
}

export default function MessengerPage() {
  const { user } = useAuth();
  const { t } = useI18n();
  const currentUserId = asInt(user?.id);
  const [threads, setThreads] = useState([]);
  const [selectedThreadId, setSelectedThreadId] = useState(null);
  const [messages, setMessages] = useState([]);
  const [draft, setDraft] = useState('');
  const [search, setSearch] = useState('');
  const [contactSearch, setContactSearch] = useState('');
  const [contacts, setContacts] = useState([]);
  const [loadingThreads, setLoadingThreads] = useState(false);
  const [loadingMessages, setLoadingMessages] = useState(false);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const [selectedMessageMeta, setSelectedMessageMeta] = useState(null);
  const threadsReq = useRef(0);
  const messagesReq = useRef(0);
  const wsRef = useRef(null);
  const wsRetryRef = useRef(null);

  const selectedThread = useMemo(
    () => threads.find((t) => String(t.id) === String(selectedThreadId)) || null,
    [threads, selectedThreadId]
  );

  const loadThreads = useCallback(async (silent = false) => {
    const reqId = ++threadsReq.current;
    if (!silent) setLoadingThreads(true);
    try {
      const res = await fetch(`/api/sdal-messenger/threads?limit=80&offset=0&q=${encodeURIComponent(search.trim())}`, {
        credentials: 'include'
      });
      if (!res.ok) {
        throw new Error(await res.text());
      }
      const payload = await res.json();
      if (reqId !== threadsReq.current) return;
      const next = payload.items || [];
      setThreads(next);
      if (!selectedThreadId && next.length) {
        setSelectedThreadId(next[0].id);
      } else if (selectedThreadId && !next.find((t) => String(t.id) === String(selectedThreadId))) {
        setSelectedThreadId(next[0]?.id || null);
      }
    } catch (err) {
      if (!silent) setError(String(err?.message || t('messenger_error_threads_load')));
    } finally {
      if (!silent) setLoadingThreads(false);
    }
  }, [search, selectedThreadId]);

  const loadMessages = useCallback(async (threadId) => {
    const reqId = ++messagesReq.current;
    if (!threadId) {
      setMessages([]);
      return;
    }
    setLoadingMessages(true);
    try {
      const res = await fetch(`/api/sdal-messenger/threads/${threadId}/messages?limit=120`, {
        credentials: 'include'
      });
      if (!res.ok) throw new Error(await res.text());
      const payload = await res.json();
      if (reqId !== messagesReq.current) return;
      setMessages(payload.items || []);
      await fetch(`/api/sdal-messenger/threads/${threadId}/read`, {
        method: 'POST',
        credentials: 'include'
      });
      await loadThreads(true);
    } catch (err) {
      setError(String(err?.message || t('messenger_error_messages_load')));
    } finally {
      setLoadingMessages(false);
    }
  }, [loadThreads]);

  useEffect(() => {
    loadThreads(false);
  }, [loadThreads]);

  useEffect(() => {
    if (!selectedThreadId) return;
    loadMessages(selectedThreadId);
  }, [selectedThreadId, loadMessages]);

  useEffect(() => {
    const id = setInterval(() => {
      loadThreads(true);
      if (selectedThreadId) loadMessages(selectedThreadId);
    }, 7000);
    return () => clearInterval(id);
  }, [loadThreads, loadMessages, selectedThreadId]);

  useEffect(() => {
    if (!currentUserId) return undefined;
    let closed = false;

    const connect = () => {
      if (closed) return;
      const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
      const ws = new WebSocket(`${proto}://${window.location.host}/ws/messenger?userId=${encodeURIComponent(String(currentUserId))}`);
      wsRef.current = ws;
      ws.onmessage = (evt) => {
        try {
          const payload = JSON.parse(String(evt?.data || '{}'));
          if (!String(payload?.type || '').startsWith('messenger:')) return;
          const eventThreadId = asInt(payload?.threadId ?? payload?.item?.threadId ?? payload?.item?.thread_id);
          if (eventThreadId && selectedThreadId && String(eventThreadId) === String(selectedThreadId)) {
            loadMessages(selectedThreadId);
          } else {
            loadThreads(true);
          }
        } catch {
          // no-op
        }
      };
      ws.onclose = () => {
        if (closed) return;
        clearTimeout(wsRetryRef.current);
        wsRetryRef.current = setTimeout(connect, 1200);
      };
      ws.onerror = () => {
        try { ws.close(); } catch {}
      };
    };

    connect();

    return () => {
      closed = true;
      clearTimeout(wsRetryRef.current);
      wsRetryRef.current = null;
      try { wsRef.current?.close(); } catch {}
      wsRef.current = null;
    };
  }, [currentUserId, selectedThreadId, loadMessages, loadThreads]);

  useEffect(() => {
    if (!contactSearch.trim()) {
      setContacts([]);
      return;
    }
    const id = setTimeout(async () => {
      try {
        const res = await fetch(`/api/sdal-messenger/contacts?q=${encodeURIComponent(contactSearch.trim())}&limit=12`, {
          credentials: 'include'
        });
        if (!res.ok) return;
        const payload = await res.json();
        setContacts(payload.items || []);
      } catch {
        setContacts([]);
      }
    }, 260);
    return () => clearTimeout(id);
  }, [contactSearch]);

  async function createThread(userId) {
    try {
      const res = await fetch('/api/sdal-messenger/threads', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ userId })
      });
      if (!res.ok) throw new Error(await res.text());
      const payload = await res.json();
      setContactSearch('');
      setContacts([]);
      await loadThreads(true);
      if (payload.threadId) {
        setSelectedThreadId(payload.threadId);
        await loadMessages(payload.threadId);
      }
    } catch (err) {
      setError(String(err?.message || t('messenger_error_thread_create')));
    }
  }

  async function sendMessage() {
    const text = draft.trim();
    if (!text || !selectedThreadId) return;
    const clientWrittenAt = new Date().toISOString();
    setSending(true);
    try {
      const res = await fetch(`/api/sdal-messenger/threads/${selectedThreadId}/messages`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ text, clientWrittenAt })
      });
      if (!res.ok) throw new Error(await res.text());
      const payload = await res.json();
      if (payload.item) {
        setMessages((prev) => [...prev, payload.item]);
      } else {
        await loadMessages(selectedThreadId);
      }
      setDraft('');
      await fetch(`/api/sdal-messenger/threads/${selectedThreadId}/read`, {
        method: 'POST',
        credentials: 'include'
      });
      await loadThreads(true);
      await loadMessages(selectedThreadId);
    } catch (err) {
      setError(String(err?.message || t('messenger_error_send')));
    } finally {
      setSending(false);
    }
  }

  return (
    <Layout title={t('messenger_page_title')}>
      <div className="messenger-shell">
        <aside className="messenger-sidebar panel">
          <div className="panel-body">
            <input
              className="input"
              placeholder={t('messenger_search_threads_placeholder')}
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <input
              className="input"
              placeholder={t('messenger_search_contacts_placeholder')}
              value={contactSearch}
              onChange={(e) => setContactSearch(e.target.value)}
            />
            {contacts.length ? (
              <div className="list messenger-contacts">
                {contacts.map((c) => (
                  <button key={c.id} className="list-item messenger-contact" onClick={() => createThread(c.id)}>
                    <strong>@{c.kadi || 'uye'}</strong>
                    <span>{[c.isim, c.soyisim].filter(Boolean).join(' ') || '-'}</span>
                  </button>
                ))}
              </div>
            ) : null}

            <div className="list messenger-thread-list">
              {loadingThreads ? <div className="muted">{t('loading')}</div> : null}
              {!loadingThreads && !threads.length ? <div className="muted">{t('messenger_empty_threads')}</div> : null}
              {threads.map((thread) => {
                const active = String(thread.id) === String(selectedThreadId);
                return (
                  <button
                    key={thread.id}
                    className={`list-item messenger-thread ${active ? 'messenger-thread-active' : ''}`}
                    onClick={() => setSelectedThreadId(thread.id)}
                  >
                    <div className="row">
                      <strong>@{thread?.peer?.kadi || 'uye'}</strong>
                      <span className="meta">{thread?.lastMessage?.createdAt || ''}</span>
                    </div>
                    <div className="row">
                      <span className="message-snippet">{stripHtml(thread?.lastMessage?.body || t('messenger_no_message_snippet'))}</span>
                      {(thread?.unreadCount || 0) > 0 ? <span className="messenger-badge">{thread.unreadCount}</span> : null}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        </aside>

        <section className="messenger-main panel">
          <div className="panel-body messenger-main-body">
            <div className="messenger-main-head">
              <h3>{selectedThread ? `@${selectedThread?.peer?.kadi || 'uye'}` : t('messenger_select_thread_title')}</h3>
            </div>
            <div className="messenger-messages">
              {!loadingMessages && !messages.length ? <div className="muted">{t('messenger_empty_messages')}</div> : null}
              {messages.map((m) => {
                const senderId = asInt(m?.senderId ?? m?.sender_id);
                const peerId = asInt(selectedThread?.peer?.id);
                const mineBySession = currentUserId > 0 && senderId === currentUserId;
                const mineByPeer = peerId > 0 && senderId > 0 && senderId !== peerId;
                const mineByApi = asInt(m?.isMine ?? m?.is_mine ?? m?.ismine) === 1;
                const mine = mineByApi || mineBySession || mineByPeer;
                const state = deliveryState(m, mine);
                const stateLabel = state === 'read' ? t('messenger_state_read') : state === 'delivered' ? t('messenger_state_delivered') : t('messenger_state_sent');
                const createdAt = m?.createdAt || m?.created_at || '';
                return (
                  <div key={m.id} className={`messenger-bubble-row ${mine ? 'mine' : 'theirs'}`}>
                    <button className="messenger-bubble" onClick={() => setSelectedMessageMeta(m)}>
                      <div>{stripHtml(m.body)}</div>
                      <div className="meta">
                        <span>{createdAt}</span>
                        {mine ? (
                          <span className={`msg-state ${state}`}>
                            <span className="ticks">{state === 'sent' ? '✓' : '✓✓'}</span>
                            <span className="state-label">{stateLabel}</span>
                          </span>
                        ) : null}
                      </div>
                    </button>
                  </div>
                );
              })}
            </div>
            <div className="messenger-composer">
              <textarea
                className="input"
                rows={2}
                placeholder={t('messenger_composer_placeholder')}
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    sendMessage();
                  }
                }}
                disabled={!selectedThreadId}
              />
              <button className="btn primary" onClick={sendMessage} disabled={!selectedThreadId || !draft.trim() || sending}>
                {sending ? t('sending') : t('messenger_send')}
              </button>
            </div>
            {error ? <div className="error">{error}</div> : null}
          </div>
        </section>
      </div>
      {selectedMessageMeta ? createPortal(
        <div className="messenger-meta-overlay" onClick={() => setSelectedMessageMeta(null)}>
          <div className="messenger-meta-card" onClick={(e) => e.stopPropagation()}>
            <h4>{t('messenger_meta_title')}</h4>
            <div className="messenger-meta-row"><span>{t('messenger_meta_written')}</span><strong>{selectedMessageMeta.clientWrittenAt || selectedMessageMeta.client_written_at || selectedMessageMeta.createdAt || selectedMessageMeta.created_at || t('messenger_meta_no_info')}</strong></div>
            <div className="messenger-meta-row"><span>{t('messenger_meta_received')}</span><strong>{selectedMessageMeta.serverReceivedAt || selectedMessageMeta.server_received_at || selectedMessageMeta.createdAt || selectedMessageMeta.created_at || t('messenger_meta_no_info')}</strong></div>
            <div className="messenger-meta-row"><span>{t('messenger_meta_delivered')}</span><strong>{selectedMessageMeta.deliveredAt || selectedMessageMeta.delivered_at || t('messenger_meta_not_delivered')}</strong></div>
            <div className="messenger-meta-row"><span>{t('messenger_meta_read')}</span><strong>{selectedMessageMeta.readAt || selectedMessageMeta.read_at || t('messenger_meta_not_read')}</strong></div>
            <button className="btn" onClick={() => setSelectedMessageMeta(null)}>{t('close')}</button>
          </div>
        </div>
      , document.body) : null}
    </Layout>
  );
}
