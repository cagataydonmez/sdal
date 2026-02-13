import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';

async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    credentials: 'include',
    ...options
  });
  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Request failed: ${res.status}`);
  }
  return res.json();
}

export default function ProfilePage() {
  const [profile, setProfile] = useState(null);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    apiJson('/api/profile').then((p) => setProfile(p.user || null)).catch(() => {});
  }, []);

  async function save() {
    setError('');
    setStatus('');
    try {
      await apiJson('/api/profile', { method: 'PUT', body: JSON.stringify(profile) });
      setStatus('Profil güncellendi.');
    } catch (err) {
      setError(err.message);
    }
  }

  if (!profile) {
    return <Layout title="Profil"><div className="muted">Yükleniyor...</div></Layout>;
  }

  return (
    <Layout title="Profil">
      <div className="panel">
        <div className="panel-body">
          <div className="form-row">
            <label>İsim</label>
            <input className="input" value={profile.isim || ''} onChange={(e) => setProfile({ ...profile, isim: e.target.value })} />
          </div>
          <div className="form-row">
            <label>Soyisim</label>
            <input className="input" value={profile.soyisim || ''} onChange={(e) => setProfile({ ...profile, soyisim: e.target.value })} />
          </div>
          <div className="form-row">
            <label>Email</label>
            <input className="input" value={profile.email || ''} onChange={(e) => setProfile({ ...profile, email: e.target.value })} />
          </div>
          <div className="form-row">
            <label>Şehir</label>
            <input className="input" value={profile.sehir || ''} onChange={(e) => setProfile({ ...profile, sehir: e.target.value })} />
          </div>
          <div className="form-row">
            <label>Meslek</label>
            <input className="input" value={profile.meslek || ''} onChange={(e) => setProfile({ ...profile, meslek: e.target.value })} />
          </div>
          <div className="form-row">
            <label>Mezuniyet</label>
            <input className="input" value={profile.mezuniyetyili || ''} onChange={(e) => setProfile({ ...profile, mezuniyetyili: e.target.value })} />
          </div>
          <div className="form-row">
            <label>İmza</label>
            <textarea className="input" value={profile.imza || ''} onChange={(e) => setProfile({ ...profile, imza: e.target.value })} />
          </div>
          <button className="btn primary" onClick={save}>Kaydet</button>
          <a className="btn ghost" href="/profil/fotograf">Fotoğraf Düzenle</a>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
