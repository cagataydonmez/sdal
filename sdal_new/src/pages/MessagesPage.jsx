import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { formatDateTime } from '../utils/date.js';

export default function MessagesPage() {
  const [messages, setMessages] = useState([]);
  const [box, setBox] = useState('inbox');
  const [mode, setMode] = useState('all');
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const messagesRef = useRef([]);
  const sentinelRef = useRef(null);

  useEffect(() => {
    messagesRef.current = messages;
  }, [messages]);

  const load = useCallback(async ({ silent = false, nextPage = 1, append = false } = {}) => {
    if (!silent) setLoading(true);
    fetch(`/api/messages?box=${box}&page=${nextPage}&pageSize=15`, { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => {
        const next = p.rows || [];
        setPage(p.page || nextPage);
        setPages(p.pages || 1);
        if (append) {
          setMessages((prev) => {
            const ids = new Set(prev.map((x) => x.id));
            const merged = [...prev];
            for (const m of next) if (!ids.has(m.id)) merged.push(m);
            return merged;
          });
        } else {
          setMessages(next);
        }
      })
      .catch(() => {})
      .finally(() => {
        if (!silent) setLoading(false);
      });
  }, [box]);

  useEffect(() => {
    load({ silent: false, nextPage: 1, append: false });
  }, [load]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) {
        if (!loading && page < pages) {
          load({ silent: true, nextPage: page + 1, append: true });
        }
      }
    }, { rootMargin: '300px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [loading, page, pages, load]);

  const filtered = useMemo(
    () =>
      messages.filter((m) => {
        if (mode === 'unread' && box === 'inbox' && Number(m.yeni) !== 1) return false;
        if (!query.trim()) return true;
        const q = query.toLowerCase();
        return `${m.konu || ''} ${m.kimden_kadi || ''} ${m.kime_kadi || ''} ${String(m.mesaj || '').replace(/<[^>]+>/g, ' ')}`.toLowerCase().includes(q);
      }),
    [messages, query, mode, box]
  );

  const unreadCount = useMemo(
    () => messages.filter((m) => box === 'inbox' && Number(m.yeni) === 1).length,
    [messages, box]
  );

  return (
    <Layout title="Mesajlar">
      <div className="panel">
        <div className="panel-body">
          <div className="composer-actions">
            <a className="btn primary" href="/new/messages/compose">Yeni Mesaj</a>
            <button className={`btn ${box === 'inbox' ? 'primary' : 'ghost'}`} onClick={() => { setBox('inbox'); setPage(1); setMessages([]); }}>Gelen</button>
            <button className={`btn ${box === 'outbox' ? 'primary' : 'ghost'}`} onClick={() => { setBox('outbox'); setPage(1); setMessages([]); }}>Giden</button>
            <button className={`btn ${mode === 'all' ? 'primary' : 'ghost'}`} onClick={() => setMode('all')}>Tümü</button>
            {box === 'inbox' ? <button className={`btn ${mode === 'unread' ? 'primary' : 'ghost'}`} onClick={() => setMode('unread')}>Sadece Okunmamış</button> : null}
          </div>
          {box === 'inbox' ? <div className="chip">Okunmamış: {unreadCount}</div> : null}
          <input className="input" placeholder="Mesaj ara..." value={query} onChange={(e) => setQuery(e.target.value)} />
        </div>
      </div>
      <div className="list">
        {loading ? <div className="muted">Yükleniyor...</div> : null}
        {!loading && filtered.length === 0 ? <div className="muted">Bu filtrede mesaj bulunamadı.</div> : null}
        {filtered.map((m) => (
          <a className={`list-item message-row ${box === 'inbox' && Number(m.yeni) === 1 ? 'unread-item' : ''}`} key={m.id} href={`/new/messages/${m.id}`}>
            <div className="message-list-main">
              <div className="name">{m.konu || 'Mesaj'}</div>
              <div className="meta">{m.kimden_kadi} → {m.kime_kadi}{box === 'inbox' && Number(m.yeni) === 1 ? ' • Yeni' : ''}</div>
              <div className="message-snippet">{String(m.mesaj || '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 120)}</div>
            </div>
            <div className="message-list-side">
              <div className="meta">{formatDateTime(m.tarih)}</div>
              <button className="btn ghost" type="button" onClick={(e) => {
                e.preventDefault();
                const targetId = box === 'inbox' ? m.kimden : m.kime;
                window.location.href = `/new/messages/compose?to=${targetId}&replyTo=${m.id}`;
              }}
              >
                Cevapla
              </button>
            </div>
          </a>
        ))}
      </div>
      <div ref={sentinelRef} />
    </Layout>
  );
}
