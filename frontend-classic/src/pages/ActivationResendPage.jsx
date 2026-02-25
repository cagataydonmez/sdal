import React, { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function ActivationResendPage() {
  const [params] = useSearchParams();
  const [email, setEmail] = useState('');
  const [id] = useState(params.get('id') || '');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  async function submit(e) {
    e.preventDefault();
    setError('');
    setMessage('');
    const res = await fetch('/api/activation/resend', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ id: id || undefined, email: email || undefined })
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setMessage('Aktivasyon maili gönderildi.');
  }

  return (
    <LegacyLayout pageTitle="Aktivasyon Gönderme" showLeftColumn={false}>
      <form onSubmit={submit}>
        <div style={{ padding: 12 }}>
          <b>Aktivasyon maili gönder</b><br /><br />
          {id ? (
            <div>Üye ID: <b>{id}</b></div>
          ) : (
            <div>
              E-mail adresiniz: <input type="text" className="inptxt" value={email} onChange={(e) => setEmail(e.target.value)} />
            </div>
          )}
          <br />
          <input type="submit" className="sub" value="Gönder" />
          {message ? <div>{message}</div> : null}
          {error ? <div className="hatamsg1">{error}</div> : null}
        </div>
      </form>
    </LegacyLayout>
  );
}
