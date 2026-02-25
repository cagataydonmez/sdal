import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { formatDateTime } from '../utils/date.js';
import TranslatableHtml from '../components/TranslatableHtml.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function MessagesPage() {
  const { t } = useI18n();
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
    <Layout title={t('messages_title')}>
      <div className="message-mailbox">
        <aside className="panel mailbox-sidebar">
          <div className="panel-body stack">
            <a className="btn primary" href="/new/messages/compose">{t('message_compose_title')}</a>
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
              {t('messages_inbox')} {box === 'inbox' ? t('messages_unread_count', { count: unreadCount }) : ''}
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
              {t('messages_outbox')}
            </button>
            <div className="composer-actions">
              <button className={`btn ${mode === 'all' ? 'primary' : 'ghost'}`} onClick={() => setMode('all')}>{t('messages_all')}</button>
              {box === 'inbox' ? <button className={`btn ${mode === 'unread' ? 'primary' : 'ghost'}`} onClick={() => setMode('unread')}>{t('messages_unread')}</button> : null}
            </div>
            <input className="input" placeholder={t('messages_search_placeholder')} value={query} onChange={(e) => setQuery(e.target.value)} />
          </div>
        </aside>

        <section className="panel mailbox-list">
          <div className="panel-body">
            <div className="mailbox-list-head">
              <h3>{box === 'inbox' ? t('messages_inbox_list') : t('messages_outbox_list')}</h3>
              {loading ? <span className="meta">{t('loading')}</span> : null}
            </div>
            <div className="list mailbox-items">
              {!loading && filtered.length === 0 ? <div className="muted">{t('messages_empty_filtered')}</div> : null}
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
                      <div className="name">{m.konu || t('message_title')}</div>
                      <div className="meta">{m.kimden_kadi} → {m.kime_kadi}{unread ? ` • ${t('new')}` : ''}</div>
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
            {!selected ? <div className="muted">{t('messages_select_prompt')}</div> : null}
            {selected ? (
              <>
                <div className="mailbox-preview-head">
                  <h3>{selected.konu || t('message_title')}</h3>
                  <div className="composer-actions">
                    <a className="btn ghost" href={`/new/messages/${selected.id}`}>{t('messages_fullscreen')}</a>
                    <a className="btn primary" href={`/new/messages/compose?to=${box === 'inbox' ? selected.kimden : selected.kime}&replyTo=${selected.id}`}>{t('reply')}</a>
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
