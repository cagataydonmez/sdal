import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';

export default function MessageComposePage() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [recipient, setRecipient] = useState(null);
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const [searchError, setSearchError] = useState('');
  const [searching, setSearching] = useState(false);

  useEffect(() => {
    const q = query.trim();
    if (q.length < 2) {
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
            <input className="input" placeholder="Üye ara..." value={query} onChange={(e) => setQuery(e.target.value)} />
            {query.length >= 2 ? (
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
            {recipient ? <div className="chip">Alıcı: {recipient.isim} {recipient.soyisim} (@{recipient.kadi})</div> : null}
          </div>
          <form className="stack" onSubmit={submit}>
            <input className="input" placeholder="Konu" value={subject} onChange={(e) => setSubject(e.target.value)} />
            <textarea className="input" placeholder="Mesaj" value={body} onChange={(e) => setBody(e.target.value)} />
            <button className="btn primary" type="submit">Gönder</button>
            {status ? <div className="ok">{status}</div> : null}
            {error ? <div className="error">{error}</div> : null}
          </form>
        </div>
      </div>
    </Layout>
  );
}
