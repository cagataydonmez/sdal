import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';

export default function AdminPage() {
  const { user } = useAuth();
  const [userId, setUserId] = useState('');
  const [verified, setVerified] = useState('1');
  const [status, setStatus] = useState('');
  const [requests, setRequests] = useState([]);
  const [reqStatus, setReqStatus] = useState('');

  useEffect(() => {
    if (user?.admin === 1) {
      loadRequests();
    }
  }, [user]);

  async function loadRequests() {
    setReqStatus('');
    const res = await fetch('/api/new/admin/verification-requests', { credentials: 'include' });
    if (!res.ok) {
      setReqStatus(await res.text());
      return;
    }
    const data = await res.json();
    setRequests(data.items || []);
  }

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

  async function reviewRequest(id, statusValue) {
    setReqStatus('');
    const res = await fetch(`/api/new/admin/verification-requests/${id}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ status: statusValue })
    });
    if (!res.ok) {
      setReqStatus(await res.text());
    } else {
      setReqStatus('Talep güncellendi.');
      loadRequests();
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
            <hr className="sdal-hr" />
            <div className="form-row">
              <label>Doğrulama Talepleri</label>
              {requests.length === 0 ? <div className="muted">Talep yok.</div> : null}
              {requests.map((r) => (
                <div key={r.id} className="list-item verify-row">
                  <div className="verify-user">
                    <img className="avatar" src={r.resim ? `/api/media/vesikalik/${r.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                    <div>
                      <b>{r.isim} {r.soyisim}</b>
                      <div className="meta">@{r.kadi} • #{r.user_id}</div>
                    </div>
                  </div>
                  <div className="verify-actions">
                    <span className="chip">{r.status}</span>
                    <button className="btn" onClick={() => reviewRequest(r.id, 'approved')}>Onayla</button>
                    <button className="btn ghost" onClick={() => reviewRequest(r.id, 'rejected')}>Reddet</button>
                  </div>
                </div>
              ))}
              {reqStatus ? <div className="muted">{reqStatus}</div> : null}
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
