import React, { useState } from 'react';
import Layout from '../components/Layout.jsx';

export default function ActivationResendPage() {
  const [form, setForm] = useState({ id: '', email: '' });
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  async function submit(e) {
    e.preventDefault();
    setStatus('');
    setError('');
    const res = await fetch('/api/activation/resend', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(form)
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setStatus('Aktivasyon e-postası gönderildi.');
  }

  return (
    <Layout title="Aktivasyon Yenile">
      <div className="panel">
        <div className="panel-body">
          <form className="stack" onSubmit={submit}>
            <input className="input" placeholder="Üye ID (opsiyonel)" value={form.id} onChange={(e) => setForm({ ...form, id: e.target.value })} />
            <input className="input" placeholder="E-posta" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            <button className="btn primary" type="submit">Gönder</button>
          </form>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
