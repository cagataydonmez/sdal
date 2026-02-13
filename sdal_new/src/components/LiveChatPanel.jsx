import React, { useEffect, useRef, useState } from 'react';

export default function LiveChatPanel() {
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState('');
  const lastIdRef = useRef(0);

  async function load() {
    const res = await fetch(`/api/new/chat/messages?sinceId=${lastIdRef.current}`, { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    const items = payload.items || [];
    if (items.length) {
      lastIdRef.current = items[items.length - 1].id;
      setMessages((prev) => [...prev, ...items].slice(-50));
    }
  }

  useEffect(() => {
    load();
    const t = setInterval(load, 4000);
    return () => clearInterval(t);
  }, []);

  async function send(e) {
    e.preventDefault();
    if (!text.trim()) return;
    await fetch('/api/new/chat/send', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ message: text })
    });
    setText('');
    load();
  }

  return (
    <div className="panel chat-panel">
      <h3>Canlı Sohbet</h3>
      <div className="chat-body">
        {messages.map((m) => (
          <div key={m.id} className="chat-line">
            <span className="chat-user">@{m.kadi}{m.verified ? ' ✓' : ''}</span>
            <span className="chat-text">{m.message}</span>
          </div>
        ))}
      </div>
      <form className="chat-form" onSubmit={send}>
        <input value={text} onChange={(e) => setText(e.target.value)} placeholder="Mesaj yaz..." />
        <button className="btn">Gönder</button>
      </form>
    </div>
  );
}
