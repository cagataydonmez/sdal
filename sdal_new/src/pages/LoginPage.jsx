import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';

export default function LoginPage() {
  const [kadi, setKadi] = useState('');
  const [sifre, setSifre] = useState('');
  const [error, setError] = useState('');
  const { refresh } = useAuth();
  const navigate = useNavigate();

  async function submit(e) {
    e.preventDefault();
    setError('');
    const res = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ kadi, sifre })
    });
    if (!res.ok) {
      const msg = await res.text();
      setError(msg || 'Giriş başarısız.');
      return;
    }
    await refresh();
    navigate('/new');
  }

  return (
    <Layout title="Giriş">
      <div className="panel">
        <div className="panel-body">
          <form onSubmit={submit} className="stack">
            <input className="input" placeholder="Kullanıcı adı" value={kadi} onChange={(e) => setKadi(e.target.value)} />
            <input className="input" type="password" placeholder="Şifre" value={sifre} onChange={(e) => setSifre(e.target.value)} />
            <button className="btn primary" type="submit">Giriş Yap</button>
            {error ? <div className="error">{error}</div> : null}
          </form>
        </div>
      </div>
    </Layout>
  );
}
