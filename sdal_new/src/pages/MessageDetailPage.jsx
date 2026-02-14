import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';

export default function MessageDetailPage() {
  const { id } = useParams();
  const [message, setMessage] = useState(null);
  const [sender, setSender] = useState(null);
  const [receiver, setReceiver] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    fetch(`/api/messages/${id}`, { credentials: 'include' })
      .then(async (res) => {
        if (!res.ok) throw new Error(await res.text());
        return res.json();
      })
      .then((p) => {
        setMessage(p.row || null);
        setSender(p.sender || null);
        setReceiver(p.receiver || null);
      })
      .catch((err) => setError(err.message));
  }, [id]);

  async function remove() {
    setError('');
    const res = await fetch(`/api/messages/${id}`, { method: 'DELETE', credentials: 'include' });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setError('Mesaj silindi.');
  }

  if (!message) return <Layout title="Mesaj">{error ? <div className="error">{error}</div> : 'Yükleniyor...'}</Layout>;

  return (
    <Layout title={message.konu || 'Mesaj'}>
      <div className="panel">
        <div className="panel-body">
          <div className="meta">Gönderen: {sender?.kadi}</div>
          <div className="meta">Alıcı: {receiver?.kadi}</div>
          <div className="meta">Tarih: {message.tarih ? new Date(message.tarih).toLocaleString() : ''}</div>
          <div className="panel-body">{message.mesaj}</div>
          <button className="btn ghost" onClick={remove}>Sil</button>
          {error ? <div className="muted">{error}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
