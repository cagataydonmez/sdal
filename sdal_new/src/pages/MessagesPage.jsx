import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';

export default function MessagesPage() {
  const [messages, setMessages] = useState([]);
  const [box, setBox] = useState('inbox');

  useEffect(() => {
    fetch(`/api/messages?box=${box}`, { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => setMessages(p.rows || []))
      .catch(() => {});
  }, [box]);

  return (
    <Layout title="Mesajlar">
      <div className="panel">
        <div className="panel-body">
          <a className="btn primary" href="/new/messages/compose">Yeni Mesaj</a>
          <button className={`btn ${box === 'inbox' ? 'primary' : 'ghost'}`} onClick={() => setBox('inbox')}>Gelen</button>
          <button className={`btn ${box === 'outbox' ? 'primary' : 'ghost'}`} onClick={() => setBox('outbox')}>Giden</button>
        </div>
      </div>
      <div className="list">
        {messages.map((m) => (
          <a className="list-item" key={m.id} href={`/new/messages/${m.id}`}>
            <div>
              <div className="name">{m.konu || 'Mesaj'}</div>
              <div className="meta">{m.kimden_kadi} → {m.kime_kadi}</div>
            </div>
            <div className="meta">{m.tarih ? new Date(m.tarih).toLocaleString() : ''}</div>
          </a>
        ))}
      </div>
    </Layout>
  );
}
