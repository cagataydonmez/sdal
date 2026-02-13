import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';

export default function MessagesPage() {
  const [messages, setMessages] = useState([]);

  useEffect(() => {
    fetch('/api/messages', { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => setMessages(p.items || []))
      .catch(() => {});
  }, []);

  return (
    <Layout title="Mesajlar">
      <div className="panel">
        <div className="panel-body">
          <a className="btn primary" href="/mesajlar/yeni">Yeni Mesaj</a>
        </div>
      </div>
      <div className="list">
        {messages.map((m) => (
          <a className="list-item" key={m.id} href={`/mesajlar/${m.id}`}>
            <div>
              <div className="name">{m.konu || 'Mesaj'}</div>
              <div className="meta">{m.kimden_adi} → {m.kime_adi}</div>
            </div>
            <div className="meta">{m.tarih ? new Date(m.tarih).toLocaleString() : ''}</div>
          </a>
        ))}
      </div>
    </Layout>
  );
}
