import React, { useEffect, useState } from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { useAuth } from '../utils/auth.jsx';

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

export default function TournamentPage() {
  const { user } = useAuth();
  const [adminOk, setAdminOk] = useState(false);
  const [teams, setTeams] = useState([]);
  const [error, setError] = useState('');

  useEffect(() => {
    apiJson('/api/admin/session')
      .then((data) => setAdminOk(!!data.adminOk))
      .catch(() => setAdminOk(false));
  }, []);

  useEffect(() => {
    if (!user) return;
    apiJson('/api/admin/tournament')
      .then((data) => setTeams(data.teams || []))
      .catch((err) => setError(err.message));
  }, [user]);

  async function deleteTeam(id) {
    if (!window.confirm('Silmek istediğine emin misin?')) return;
    setError('');
    try {
      await apiJson(`/api/admin/tournament/${id}`, { method: 'DELETE' });
      setTeams((prev) => prev.filter((t) => t.id !== id));
    } catch (err) {
      setError(err.message);
    }
  }

  if (!user) {
    return (
      <LegacyLayout pageTitle="Yönetim Futbol Turnuvası">
        Giriş yapmalısınız.
      </LegacyLayout>
    );
  }

  if (!adminOk) {
    return (
      <LegacyLayout pageTitle="Yönetim Futbol Turnuvası">
        Yönetim girişi gerekli.
      </LegacyLayout>
    );
  }

  return (
    <LegacyLayout pageTitle="Yönetim Futbol Turnuvası">
      <hr color="brown" size="1" />
      <a href="/admin">Yönetim Anasayfa</a> | <b>8-9 Aralık Futbol Turnuvası</b>
      <hr color="brown" size="1" />
      {error ? <div className="hatamsg1">{error}</div> : null}
      <table border="0" width="100%" cellPadding="3" cellSpacing="0">
        <tbody>
          <tr>
            <td style={{ border: '1px solid black' }}><b>#</b></td>
            <td style={{ border: '1px solid black' }}><b>Takım İsmi</b></td>
            <td style={{ border: '1px solid black' }}><b>Takım Kaptanı</b></td>
            <td style={{ border: '1px solid black' }}><b>Kayıt Tarihi</b></td>
            <td style={{ border: '1px solid black' }}><b>Oyuncular</b></td>
          </tr>
          {teams.length === 0 ? (
            <tr>
              <td colSpan="5" style={{ border: '1px solid black' }}>
                <b>Henüz kayıt eklenmemiş...</b>
              </td>
            </tr>
          ) : teams.map((t, idx) => (
            <tr key={t.id}>
              <td valign="top" style={{ border: '1px solid black' }}>
                {idx + 1}<br />
                <a href="#" onClick={(e) => { e.preventDefault(); deleteTeam(t.id); }}>Sil</a>
              </td>
              <td valign="top" style={{ border: '1px solid black' }}>{t.tisim}</td>
              <td valign="top" style={{ border: '1px solid black' }}>
                <img src={`/api/media/kucukresim?iwidth=50&r=${encodeURIComponent(`${t.tkid}.jpg`)}`} align="top" alt="" />
                <a href={`/uyeler/${t.tkid}`}> {t.tkid}</a>&nbsp; Tel : {t.tktelefon}
              </td>
              <td valign="top" style={{ border: '1px solid black' }}>{t.tarih}</td>
              <td valign="top" style={{ border: '1px solid black' }}>
                <b>1. </b>{t.boyismi} ( {t.boymezuniyet} )<br />
                <b>2. </b>{t.ioyismi} ( {t.ioymezuniyet} )<br />
                <b>3. </b>{t.uoyismi} ( {t.uoymezuniyet} )<br />
                <b>4. </b>{t.doyismi} ( {t.doymezuniyet} )
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </LegacyLayout>
  );
}
