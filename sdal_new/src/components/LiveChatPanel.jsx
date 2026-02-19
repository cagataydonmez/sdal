import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useAuth } from '../utils/auth.jsx';
import { emitAppChange } from '../utils/live.js';
import RichTextEditor from './RichTextEditor.jsx';
import TranslatableHtml from './TranslatableHtml.jsx';
import { isRichTextEmpty } from '../utils/richText.js';
import { useI18n } from '../utils/i18n.jsx';

const PAGE_SIZE = 20;

export default function LiveChatPanel() {
  const { t } = useI18n();
  const { user } = useAuth();
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState('');
  const [error, setError] = useState('');
  const [loadingOlder, setLoadingOlder] = useState(false);
  const [hasOlder, setHasOlder] = useState(true);
  const wsRef = useRef(null);
  const chatBodyRef = useRef(null);
  const atBottomRef = useRef(true);

  const oldestId = useMemo(() => (messages.length ? Number(messages[0].id || 0) : 0), [messages]);
  const latestId = useMemo(() => (messages.length ? Number(messages[messages.length - 1].id || 0) : 0), [messages]);

  const mergeMessages = useCallback((incoming = [], mode = 'append') => {
    if (!incoming.length) return;
    setMessages((prev) => {
      const map = new Map(prev.map((m) => [Number(m.id), m]));
      for (const item of incoming) {
        const key = Number(item.id || 0);
        if (!key) continue;
        map.set(key, item);
      }
      const next = Array.from(map.values()).sort((a, b) => Number(a.id || 0) - Number(b.id || 0));
      if (mode === 'prepend') return next;
      return next;
    });
  }, []);

  const loadInitial = useCallback(async () => {
    try {
      const res = await fetch(`/api/new/chat/messages?limit=${PAGE_SIZE}`, { credentials: 'include' });
      if (!res.ok) return;
      const data = await res.json();
      const items = data.items || [];
      setMessages(items);
      setHasOlder(items.length >= PAGE_SIZE);
      requestAnimationFrame(() => {
        const el = chatBodyRef.current;
        if (!el) return;
        el.scrollTop = el.scrollHeight;
      });
    } catch {
      // ignore
    }
  }, []);

  const loadNewer = useCallback(async () => {
    if (!latestId) return;
    try {
      const res = await fetch(`/api/new/chat/messages?sinceId=${latestId}&limit=${PAGE_SIZE}`, { credentials: 'include' });
      if (!res.ok) return;
      const data = await res.json();
      const items = data.items || [];
      if (items.length) {
        mergeMessages(items, 'append');
        emitAppChange('chat:new');
      }
    } catch {
      // ignore
    }
  }, [latestId, mergeMessages]);

  const loadOlder = useCallback(async () => {
    if (!oldestId || loadingOlder || !hasOlder) return;
    setLoadingOlder(true);
    const el = chatBodyRef.current;
    const prevHeight = el?.scrollHeight || 0;
    try {
      const res = await fetch(`/api/new/chat/messages?beforeId=${oldestId}&limit=${PAGE_SIZE}`, { credentials: 'include' });
      if (!res.ok) return;
      const data = await res.json();
      const items = data.items || [];
      mergeMessages(items, 'prepend');
      setHasOlder(items.length >= PAGE_SIZE);
      requestAnimationFrame(() => {
        if (!el) return;
        const newHeight = el.scrollHeight;
        el.scrollTop = newHeight - prevHeight + el.scrollTop;
      });
    } finally {
      setLoadingOlder(false);
    }
  }, [oldestId, loadingOlder, hasOlder, mergeMessages]);

  useEffect(() => {
    loadInitial();
  }, [loadInitial]);

  useEffect(() => {
    const timer = setInterval(() => {
      if (document.hidden) return;
      loadNewer();
    }, 5000);
    return () => clearInterval(timer);
  }, [loadNewer]);

  useEffect(() => {
    const url = `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/ws/chat`;
    const ws = new WebSocket(url);
    wsRef.current = ws;
    ws.onmessage = (evt) => {
      try {
        const msg = JSON.parse(evt.data);
        if (!msg?.id || !msg?.message) return;
        mergeMessages([{
          ...msg,
          user_id: msg.user_id || msg.user?.id || null,
          kadi: msg.user?.kadi || msg.kadi
        }], 'append');
        emitAppChange('chat:new');
        if (atBottomRef.current) {
          requestAnimationFrame(() => {
            const el = chatBodyRef.current;
            if (!el) return;
            el.scrollTop = el.scrollHeight;
          });
        }
      } catch {
        // ignore invalid ws payload
      }
    };
    return () => ws.close();
  }, [mergeMessages]);

  async function send(e) {
    e.preventDefault();
    setError('');
    let optimisticId = null;
    if (!user?.id) {
      setError(t('live_chat_error_login_required'));
      return;
    }
    if (isRichTextEmpty(text)) return;
    try {
      const message = text;
      optimisticId = Date.now() * -1;
      mergeMessages([{
        id: optimisticId,
        message,
        created_at: new Date().toISOString(),
        user_id: Number(user.id || 0) || null,
        kadi: user.kadi,
        verified: Number(user.verified || 0) === 1
      }], 'append');
      setText('');
      requestAnimationFrame(() => {
        const el = chatBodyRef.current;
        if (!el) return;
        el.scrollTop = el.scrollHeight;
      });
      const res = await fetch('/api/new/chat/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ message })
      });
      if (!res.ok) {
        throw new Error(await res.text());
      }
      const payload = await res.json();
      if (payload?.item) {
        setMessages((prev) => prev.filter((m) => Number(m.id) !== optimisticId));
        mergeMessages([payload.item], 'append');
      }
      if (wsRef.current && wsRef.current.readyState === 1) {
        wsRef.current.send(JSON.stringify({ userId: user.id, message }));
      }
    } catch (err) {
      if (optimisticId !== null) {
        setMessages((prev) => prev.filter((m) => Number(m.id) !== optimisticId));
      }
      setError(err?.message || t('message_send_failed'));
    }
  }

  return (
    <div className="panel chat-panel">
      <h3>{t('live_chat_title')}</h3>
      <div
        ref={chatBodyRef}
        className="chat-body"
        onScroll={(e) => {
          const el = e.currentTarget;
          atBottomRef.current = el.scrollHeight - (el.scrollTop + el.clientHeight) < 20;
          if (el.scrollTop < 20) {
            loadOlder();
          }
        }}
      >
        {loadingOlder ? <div className="muted">{t('live_chat_loading_old')}</div> : null}
        {messages.map((m) => (
          <div key={m.id} className="chat-line">
            <a className="chat-user" href={m.user_id ? `/new/members/${m.user_id}` : '/new/explore'}>
              @{(m.user?.kadi || m.kadi) || t('anonymous')}{(m.user?.verified || m.verified) ? ' ✓' : ''}
            </a>
            <TranslatableHtml html={m.message} className="chat-text" />
          </div>
        ))}
      </div>
      <form className="chat-form" onSubmit={send}>
        <RichTextEditor value={text} onChange={setText} placeholder={t('message_write')} minHeight={66} compact />
        <button className="btn" disabled={isRichTextEmpty(text)}>{t('send')}</button>
      </form>
      {error ? <div className="error">{error}</div> : null}
    </div>
  );
}
