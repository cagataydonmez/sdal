import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';

export default function RootLoginPage() {
  const { refresh } = useAuth();
  const navigate = useNavigate();
  const [password, setPassword] = useState('');
  const [status, setStatus] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setStatus('');
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ kadi: 'root', sifre: password })
      });
      if (!res.ok) {
        setStatus((await res.text()) || 'Root giriş başarısız.');
        return;
      }
      await refresh();
      navigate('/new/admin');
    } catch {
      setStatus('Root giriş başarısız.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <Layout title="Root Giriş">
      <div className="panel">
        <div className="panel-body stack">
          <h3>Root Giriş</h3>
          <div className="muted">Bu sayfa sadece sistemin root hesabı içindir. Kullanıcı adı sabit: <b>root</b>.</div>
          <form className="stack" onSubmit={submit}>
            <input
              className="input"
              type="password"
              value={password}
              placeholder="ROOT_BOOTSTRAP_PASSWORD"
              onChange={(e) => setPassword(e.target.value)}
            />
            <button className="btn primary" type="submit" disabled={busy}>{busy ? 'Giriş yapılıyor...' : 'Root olarak giriş yap'}</button>
            {status ? <div className="error">{status}</div> : null}
          </form>
          <a className="btn ghost" href="/new/login">Normal giriş sayfasına dön</a>
        </div>
      </div>
    </Layout>
  );
}
