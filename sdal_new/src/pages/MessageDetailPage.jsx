import React, { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';
import { formatDateTime } from '../utils/date.js';
import { useAuth } from '../utils/auth.jsx';

export default function MessageDetailPage() {
  const { user } = useAuth();
  const { id } = useParams();
  const navigate = useNavigate();
  const [message, setMessage] = useState(null);
  const [sender, setSender] = useState(null);
  const [receiver, setReceiver] = useState(null);
  const [error, setError] = useState('');
  const [reply, setReply] = useState('');
  const [sending, setSending] = useState(false);

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
    emitAppChange('message:deleted', { id });
    navigate('/new/messages');
  }

  async function quickReply() {
    setError('');
    const body = String(reply || '').trim();
    if (!body) return;
    const currentId = Number(user?.id || 0);
    const senderId = Number(sender?.id || 0);
    const receiverId = Number(receiver?.id || 0);
    const target = currentId === receiverId ? senderId : receiverId;
    if (!target) return;
    setSending(true);
    const res = await fetch('/api/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({
        kime: target,
        konu: String(message?.konu || '').toLowerCase().startsWith('re:') ? message.konu : `Re: ${message?.konu || 'Mesaj'}`,
        mesaj: body
      })
    });
    setSending(false);
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setReply('');
    emitAppChange('message:created');
    navigate('/new/messages');
  }

  if (!message) return <Layout title="Mesaj">{error ? <div className="error">{error}</div> : 'Yükleniyor...'}</Layout>;

  return (
    <Layout title={message.konu || 'Mesaj'}>
      <div className="panel">
        <div className="panel-body">
          <div className="composer-actions">
            <a className="btn ghost" href="/new/messages">Listeye Dön</a>
            <a className="btn primary" href={`/new/messages/compose?replyTo=${message.id}`}>Cevapla</a>
          </div>
          <div className="meta">Gönderen: {sender?.kadi}</div>
          <div className="meta">Alıcı: {receiver?.kadi}</div>
          <div className="meta">Tarih: {formatDateTime(message.tarih)}</div>
          <div className="message-bubble" dangerouslySetInnerHTML={{ __html: message.mesaj || '' }} />
          <div className="stack">
            <textarea className="input" placeholder="Hızlı cevap yaz..." value={reply} onChange={(e) => setReply(e.target.value)} />
            <div className="composer-actions">
              <button className="btn primary" onClick={quickReply} disabled={sending}>{sending ? 'Gönderiliyor...' : 'Hızlı Cevap Gönder'}</button>
              <button className="btn ghost" onClick={remove}>Sil</button>
            </div>
          </div>
          {error ? <div className="muted">{error}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
