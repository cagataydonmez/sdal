import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { formatDateTime } from '../utils/date.js';
import TranslatableHtml from '../components/TranslatableHtml.jsx';

export default function MessagesPage() {
  const [messages, setMessages] = useState([]);
  const [box, setBox] = useState('inbox');
  const [mode, setMode] = useState('all');
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const [selectedId, setSelectedId] = useState(null);
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

  const selected = useMemo(
    () => filtered.find((m) => String(m.id) === String(selectedId)) || filtered[0] || null,
    [filtered, selectedId]
  );

  useEffect(() => {
    if (!selected && filtered.length) setSelectedId(filtered[0].id);
  }, [filtered, selected]);

  const unreadCount = useMemo(
    () => messages.filter((m) => box === 'inbox' && Number(m.yeni) === 1).length,
    [messages, box]
  );

  return (
    <Layout title="Mesajlar">
      <div className="message-mailbox">
        <aside className="panel mailbox-sidebar">
          <div className="panel-body stack">
            <a className="btn primary" href="/new/messages/compose">Yeni Mesaj</a>
            <button
              className={`btn ${box === 'inbox' ? 'primary' : 'ghost'}`}
              onClick={() => {
                setBox('inbox');
                setMode('all');
                setPage(1);
                setMessages([]);
                setSelectedId(null);
              }}
            >
              Gelen Kutusu {box === 'inbox' ? `(${unreadCount} yeni)` : ''}
            </button>
            <button
              className={`btn ${box === 'outbox' ? 'primary' : 'ghost'}`}
              onClick={() => {
                setBox('outbox');
                setMode('all');
                setPage(1);
                setMessages([]);
                setSelectedId(null);
              }}
            >
              Giden Kutusu
            </button>
            <div className="composer-actions">
              <button className={`btn ${mode === 'all' ? 'primary' : 'ghost'}`} onClick={() => setMode('all')}>Tum Mesajlar</button>
              {box === 'inbox' ? <button className={`btn ${mode === 'unread' ? 'primary' : 'ghost'}`} onClick={() => setMode('unread')}>Okunmamis</button> : null}
            </div>
            <input className="input" placeholder="Mesaj ara..." value={query} onChange={(e) => setQuery(e.target.value)} />
          </div>
        </aside>

        <section className="panel mailbox-list">
          <div className="panel-body">
            <div className="mailbox-list-head">
              <h3>{box === 'inbox' ? 'Gelen Mesajlar' : 'Giden Mesajlar'}</h3>
              {loading ? <span className="meta">Yukleniyor...</span> : null}
            </div>
            <div className="list mailbox-items">
              {!loading && filtered.length === 0 ? <div className="muted">Bu filtrede mesaj bulunamadi.</div> : null}
              {filtered.map((m) => {
                const unread = box === 'inbox' && Number(m.yeni) === 1;
                const active = selected && String(selected.id) === String(m.id);
                return (
                  <button
                    className={`list-item mailbox-item ${unread ? 'unread-item' : ''} ${active ? 'mailbox-item-active' : ''}`}
                    key={m.id}
                    type="button"
                    onClick={() => setSelectedId(m.id)}
                  >
                    <div className="message-list-main">
                      <div className="name">{m.konu || 'Mesaj'}</div>
                      <div className="meta">{m.kimden_kadi} → {m.kime_kadi}{unread ? ' • Yeni' : ''}</div>
                      <div className="message-snippet">{String(m.mesaj || '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 130)}</div>
                    </div>
                    <div className="message-list-side">
                      <div className="meta">{formatDateTime(m.tarih)}</div>
                    </div>
                  </button>
                );
              })}
              <div ref={sentinelRef} />
            </div>
          </div>
        </section>

        <section className="panel mailbox-preview">
          <div className="panel-body">
            {!selected ? <div className="muted">Mesaj sec.</div> : null}
            {selected ? (
              <>
                <div className="mailbox-preview-head">
                  <h3>{selected.konu || 'Mesaj'}</h3>
                  <div className="composer-actions">
                    <a className="btn ghost" href={`/new/messages/${selected.id}`}>Tam Ekran</a>
                    <a className="btn primary" href={`/new/messages/compose?to=${box === 'inbox' ? selected.kimden : selected.kime}&replyTo=${selected.id}`}>Cevapla</a>
                  </div>
                </div>
                <div className="meta">{selected.kimden_kadi} → {selected.kime_kadi}</div>
                <div className="meta">{formatDateTime(selected.tarih)}</div>
                <TranslatableHtml html={selected.mesaj || ''} className="message-bubble" />
              </>
            ) : null}
          </div>
        </section>
      </div>
    </Layout>
  );
}
