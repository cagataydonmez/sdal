import React, { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';
import RichTextEditor from '../components/RichTextEditor.jsx';
import { isRichTextEmpty } from '../utils/richText.js';

export default function MessageComposePage() {
  const [searchParams] = useSearchParams();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [recipient, setRecipient] = useState(null);
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const [searchError, setSearchError] = useState('');
  const [searching, setSearching] = useState(false);
  const [prefilled, setPrefilled] = useState(false);

  useEffect(() => {
    const q = query.trim().replace(/^@+/, '');
    if (q.length < 1) {
      setResults([]);
      setSearchError('');
      return;
    }
    const timer = setTimeout(() => {
      setSearching(true);
      setSearchError('');
      fetch(`/api/messages/recipients?q=${encodeURIComponent(q)}&limit=12`, { credentials: 'include' })
        .then(async (r) => {
          if (!r.ok) throw new Error(await r.text());
          return r.json();
        })
        .then((p) => setResults(p.items || []))
        .catch((err) => {
          setResults([]);
          setSearchError(err.message || 'Üye araması başarısız.');
        })
        .finally(() => setSearching(false));
    }, 250);
    return () => clearTimeout(timer);
  }, [query]);

  useEffect(() => {
    if (prefilled) return;
    const toId = searchParams.get('to');
    const replyTo = searchParams.get('replyTo');
    async function prefillRecipient(memberId) {
      const res = await fetch(`/api/members/${memberId}`, { credentials: 'include' });
      if (!res.ok) return;
      const payload = await res.json();
      if (!payload?.row) return;
      setRecipient(payload.row);
      setQuery(payload.row.kadi || '');
      setResults([]);
    }
    async function prefillReply(messageId) {
      const res = await fetch(`/api/messages/${messageId}`, { credentials: 'include' });
      if (!res.ok) return;
      const payload = await res.json();
      const row = payload.row;
      if (!row) return;
      let currentId = null;
      try {
        const sRes = await fetch('/api/session', { credentials: 'include' });
        if (sRes.ok) {
          const sp = await sRes.json();
          currentId = Number(sp?.user?.id || 0) || null;
        }
      } catch {
        // ignore
      }
      const senderId = Number(payload.sender?.id || 0) || null;
      const receiverId = Number(payload.receiver?.id || 0) || null;
      const target = currentId && senderId === currentId ? payload.receiver : payload.sender;
      if (target?.id) {
        setRecipient(target);
        setQuery(target.kadi || '');
      }
      if (!subject) {
        const raw = String(row.konu || '').trim();
        setSubject(raw.toLowerCase().startsWith('re:') ? raw : `Re: ${raw || 'Mesaj'}`);
      }
      const plain = String(row.mesaj || '').replace(/<[^>]+>/g, ' ').replace(/\\s+/g, ' ').trim();
      if (!body && plain) setBody(`\n\n---\n${plain.slice(0, 240)}`);
    }
    (async () => {
      if (toId) await prefillRecipient(toId);
      if (replyTo) await prefillReply(replyTo);
      setPrefilled(true);
    })();
  }, [searchParams, prefilled, subject, body]);

  async function submit(e) {
    e.preventDefault();
    setError('');
    setStatus('');
    if (!recipient?.id) {
      setError('Alıcı seçmelisin.');
      return;
    }
    const res = await fetch('/api/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ kime: recipient.id, konu: subject, mesaj: body })
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setStatus('Mesaj gönderildi.');
    emitAppChange('message:created');
    setSubject('');
    setBody('');
  }

  return (
    <Layout title="Yeni Mesaj">
      <div className="panel">
        <div className="panel-body">
          <div className="stack">
            <input className="input" placeholder="Üye ara (@kullanici da olur)..." value={query} onChange={(e) => setQuery(e.target.value)} />
            {query.trim().replace(/^@+/, '').length >= 1 ? (
              <div className="list">
                {searching ? <div className="muted">Aranıyor...</div> : null}
                {!searching && !results.length ? <div className="muted">Sonuç bulunamadı.</div> : null}
                {results.map((u) => (
                  <button key={u.id} type="button" className="list-item" onClick={() => setRecipient(u)}>
                    <div className="name">{u.isim} {u.soyisim}</div>
                    <div className="meta">@{u.kadi}</div>
                  </button>
                ))}
                {searchError ? <div className="error">{searchError}</div> : null}
              </div>
            ) : null}
            {recipient ? (
              <div className="composer-actions">
                <div className="chip">Alıcı: {recipient.isim} {recipient.soyisim} (@{recipient.kadi})</div>
                <button className="btn ghost" type="button" onClick={() => setRecipient(null)}>Alıcıyı Temizle</button>
              </div>
            ) : null}
          </div>
          <form className="stack" onSubmit={submit}>
            <input className="input" placeholder="Konu" value={subject} onChange={(e) => setSubject(e.target.value)} />
            <RichTextEditor value={body} onChange={setBody} placeholder="Mesaj" minHeight={140} />
            <button className="btn primary" type="submit" disabled={isRichTextEmpty(body)}>Gönder</button>
            {status ? <div className="ok">{status}</div> : null}
            {error ? <div className="error">{error}</div> : null}
          </form>
        </div>
      </div>
    </Layout>
  );
}
