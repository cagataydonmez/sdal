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
  const [editingId, setEditingId] = useState(null);
  const [editText, setEditText] = useState('');
  const [messageBusyId, setMessageBusyId] = useState(null);
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
    }, 2000);
    return () => clearInterval(timer);
  }, [loadNewer]);

  useEffect(() => {
    const url = `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/ws/chat`;
    const ws = new WebSocket(url);
    ws.onmessage = (evt) => {
      try {
        const msg = JSON.parse(evt.data);
        const eventType = String(msg?.type || 'chat:new');
        const msgId = Number(msg?.id || 0);
        if (!msgId) return;
        if (eventType === 'chat:deleted') {
          setMessages((prev) => prev.filter((m) => Number(m.id || 0) !== msgId));
          return;
        }
        if (!msg?.message) return;
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
        requestAnimationFrame(() => {
          const el = chatBodyRef.current;
          if (!el) return;
          el.scrollTop = el.scrollHeight;
        });
      }
    } catch (err) {
      if (optimisticId !== null) {
        setMessages((prev) => prev.filter((m) => Number(m.id) !== optimisticId));
      }
      setError(err?.message || t('message_send_failed'));
    }
  }

  function startEdit(message) {
    setEditingId(Number(message?.id || 0) || null);
    setEditText(message?.message || '');
    requestAnimationFrame(() => {
      const el = chatBodyRef.current;
      if (!el) return;
      el.scrollTop = el.scrollHeight;
    });
  }

  async function saveEdit(messageId) {
    if (!messageId || isRichTextEmpty(editText)) return;
    setMessageBusyId(messageId);
    setError('');
    try {
      let res = await fetch(`/api/new/chat/messages/${messageId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ message: editText })
      });
      if (!res.ok && (res.status === 404 || res.status === 405)) {
        res = await fetch(`/api/new/chat/messages/${messageId}/edit`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({ message: editText })
        });
      }
      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      if (data?.item) mergeMessages([data.item], 'append');
      setEditingId(null);
      setEditText('');
      emitAppChange('chat:updated', { messageId });
    } catch (err) {
      setError(err?.message || t('live_chat_edit_failed'));
    } finally {
      setMessageBusyId(null);
    }
  }

  async function removeMessage(messageId) {
    if (!messageId) return;
    setMessageBusyId(messageId);
    setError('');
    try {
      let res = await fetch(`/api/new/chat/messages/${messageId}`, {
        method: 'DELETE',
        credentials: 'include'
      });
      if (!res.ok && (res.status === 404 || res.status === 405)) {
        res = await fetch(`/api/new/chat/messages/${messageId}/delete`, {
          method: 'POST',
          credentials: 'include'
        });
      }
      if (!res.ok) throw new Error(await res.text());
      setMessages((prev) => prev.filter((m) => Number(m.id || 0) !== Number(messageId)));
      emitAppChange('chat:deleted', { messageId });
      if (editingId === Number(messageId)) {
        setEditingId(null);
        setEditText('');
      }
    } catch (err) {
      setError(err?.message || t('live_chat_delete_failed'));
    } finally {
      setMessageBusyId(null);
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
            <div className="chat-line-head">
              <a className="chat-user" href={m.user_id ? `/new/members/${m.user_id}` : '#'}>
                @{(m.user?.kadi || m.kadi) || t('anonymous')}{(m.user?.verified || m.verified) ? ' ✓' : ''}
              </a>
              {Number(user?.id || 0) === Number(m.user_id || 0) ? (
                <div className="chat-line-actions">
                  <button className="btn ghost btn-xs" onClick={() => startEdit(m)} disabled={messageBusyId === m.id}>{t('edit')}</button>
                  <button className="btn ghost btn-xs" onClick={() => removeMessage(m.id)} disabled={messageBusyId === m.id}>
                    {messageBusyId === m.id ? t('deleting') : t('delete')}
                  </button>
                </div>
              ) : null}
            </div>
            {editingId === Number(m.id) ? (
              <div className="chat-edit-box">
                <RichTextEditor value={editText} onChange={setEditText} placeholder={t('message_write')} minHeight={56} compact />
                <div className="chat-edit-actions">
                  <button className="btn ghost btn-xs" onClick={() => { setEditingId(null); setEditText(''); }} disabled={messageBusyId === m.id}>{t('close')}</button>
                  <button className="btn btn-xs" onClick={() => saveEdit(m.id)} disabled={messageBusyId === m.id || isRichTextEmpty(editText)}>
                    {messageBusyId === m.id ? t('saving') : t('save')}
                  </button>
                </div>
              </div>
            ) : (
              <TranslatableHtml html={m.message} className="chat-text" />
            )}
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
