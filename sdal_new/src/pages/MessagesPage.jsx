import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useLiveRefresh } from '../utils/live.js';

export default function MessagesPage() {
  const [messages, setMessages] = useState([]);
  const [box, setBox] = useState('inbox');
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const messagesRef = useRef([]);

  useEffect(() => {
    messagesRef.current = messages;
  }, [messages]);

  const load = useCallback(async ({ silent = false } = {}) => {
    if (!silent) setLoading(true);
    fetch(`/api/messages?box=${box}`, { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => {
        const next = p.rows || [];
        const prev = messagesRef.current;
        const changed =
          prev.length !== next.length ||
          next.some((m, i) => {
            const old = prev[i];
            if (!old) return true;
            return old.id !== m.id || old.yeni !== m.yeni || old.tarih !== m.tarih || old.konu !== m.konu;
          });
        if (changed) setMessages(next);
      })
      .catch(() => {})
      .finally(() => {
        if (!silent) setLoading(false);
      });
  }, [box]);

  useEffect(() => {
    load({ silent: false });
  }, [load]);

  const silentRefresh = useCallback(() => {
    load({ silent: true });
  }, [load]);

  useLiveRefresh(silentRefresh, { intervalMs: 7000, eventTypes: ['message:created', '*'] });

  const filtered = useMemo(
    () =>
      messages.filter((m) => {
        if (!query.trim()) return true;
        const q = query.toLowerCase();
        return `${m.konu || ''} ${m.kimden_kadi || ''} ${m.kime_kadi || ''}`.toLowerCase().includes(q);
      }),
    [messages, query]
  );

  const unreadCount = useMemo(
    () => messages.filter((m) => box === 'inbox' && Number(m.yeni) === 1).length,
    [messages, box]
  );

  return (
    <Layout title="Mesajlar">
      <div className="panel">
        <div className="panel-body">
          <a className="btn primary" href="/new/messages/compose">Yeni Mesaj</a>
          <button className={`btn ${box === 'inbox' ? 'primary' : 'ghost'}`} onClick={() => setBox('inbox')}>Gelen</button>
          <button className={`btn ${box === 'outbox' ? 'primary' : 'ghost'}`} onClick={() => setBox('outbox')}>Giden</button>
          {box === 'inbox' ? <div className="chip">Okunmamış: {unreadCount}</div> : null}
          <input className="input" placeholder="Mesaj ara..." value={query} onChange={(e) => setQuery(e.target.value)} />
        </div>
      </div>
      <div className="list">
        {loading ? <div className="muted">Yükleniyor...</div> : null}
        {filtered.map((m) => (
          <a className={`list-item ${box === 'inbox' && Number(m.yeni) === 1 ? 'unread-item' : ''}`} key={m.id} href={`/new/messages/${m.id}`}>
            <div>
              <div className="name">{m.konu || 'Mesaj'}</div>
              <div className="meta">{m.kimden_kadi} → {m.kime_kadi}{box === 'inbox' && Number(m.yeni) === 1 ? ' • Yeni' : ''}</div>
            </div>
            <div className="meta">{m.tarih ? new Date(m.tarih).toLocaleString() : ''}</div>
          </a>
        ))}
      </div>
    </Layout>
  );
}
