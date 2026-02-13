import React, { useEffect, useRef, useState } from 'react';
import { useAuth } from '../utils/auth.jsx';

export default function LiveChatPanel() {
  const { user } = useAuth();
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState('');
  const [error, setError] = useState('');
  const wsRef = useRef(null);

  useEffect(() => {
    const url = `${window.location.protocol === 'https:' ? 'wss' : 'ws'}://${window.location.host}/ws/chat`;
    const ws = new WebSocket(url);
    wsRef.current = ws;
    ws.onmessage = (evt) => {
      try {
        const msg = JSON.parse(evt.data);
        if (!msg?.message) return;
        setMessages((prev) => [...prev, msg].slice(-50));
      } catch {
        // ignore
      }
    };
    return () => ws.close();
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const res = await fetch('/api/new/chat/messages', { credentials: 'include' });
        if (!res.ok) return;
        const data = await res.json();
        if (!cancelled) setMessages(data.items || []);
      } catch {
        // ignore
      }
    }
    load();
    return () => { cancelled = true; };
  }, []);

  async function send(e) {
    e.preventDefault();
    setError('');
    if (!user?.id) {
      setError('Mesaj göndermek için giriş yapın.');
      return;
    }
    if (!text.trim()) return;
    const payload = { message: text, userId: user.id };
    if (wsRef.current && wsRef.current.readyState === 1) {
      wsRef.current.send(JSON.stringify(payload));
    }
    setText('');
  }

  return (
    <div className="panel chat-panel">
      <h3>Canlı Sohbet</h3>
      <div className="chat-body">
        {messages.map((m) => (
          <div key={m.id} className="chat-line">
            <span className="chat-user">@{(m.user?.kadi || m.kadi) || 'anon'}{(m.user?.verified || m.verified) ? ' ✓' : ''}</span>
            <span className="chat-text">{m.message}</span>
          </div>
        ))}
      </div>
      <form className="chat-form" onSubmit={send}>
        <input value={text} onChange={(e) => setText(e.target.value)} placeholder="Mesaj yaz..." />
        <button className="btn">Gönder</button>
      </form>
      {error ? <div className="error">{error}</div> : null}
    </div>
  );
}
