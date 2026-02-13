import React, { useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';

export default function AdminPage() {
  const { user } = useAuth();
  const [userId, setUserId] = useState('');
  const [verified, setVerified] = useState('1');
  const [status, setStatus] = useState('');

  async function updateVerify() {
    setStatus('');
    const res = await fetch('/api/new/admin/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ userId, verified })
    });
    if (!res.ok) {
      setStatus(await res.text());
    } else {
      setStatus('Güncellendi.');
    }
  }
  return (
    <Layout title="Yönetim">
      {user?.admin === 1 ? (
        <div className="panel">
          <div className="panel-body">
            <p>Yönetim paneli klasik arayüzde çalışır.</p>
            <a className="btn primary" href="/admin">Klasik Yönetim Panelini Aç</a>
            <hr className="sdal-hr" />
            <div className="form-row">
              <label>Doğrulama Rozeti</label>
              <input className="input" placeholder="Üye ID" value={userId} onChange={(e) => setUserId(e.target.value)} />
              <select className="input" value={verified} onChange={(e) => setVerified(e.target.value)}>
                <option value="1">Doğrula</option>
                <option value="0">Kaldır</option>
              </select>
              <button className="btn" onClick={updateVerify}>Güncelle</button>
              {status ? <div className="muted">{status}</div> : null}
            </div>
          </div>
        </div>
      ) : (
        <div className="panel">
          <div className="panel-body">Bu sayfaya erişiminiz yok.</div>
        </div>
      )}
    </Layout>
  );
}
