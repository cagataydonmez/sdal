import React, { useState } from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function ActivationResendPage() {
  const [email, setEmail] = useState('');
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
      body: JSON.stringify({ email: email || undefined })
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
          <div>
            E-mail adresiniz: <input type="email" required className="inptxt" value={email} onChange={(e) => setEmail(e.target.value)} />
          </div>
          <br />
          <input type="submit" className="sub" value="Gönder" />
          {message ? <div className="sdal-alert sdal-alert-success" role="status">{message}</div> : null}
          {error ? <div className="sdal-alert sdal-alert-error" role="alert">{error}</div> : null}
        </div>
      </form>
    </LegacyLayout>
  );
}
