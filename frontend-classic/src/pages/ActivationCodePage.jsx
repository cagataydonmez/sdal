import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function ActivationCodePage() {
  const [form, setForm] = useState({ kadi: '', sifre: '', akt: '' });
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  function updateField(name, value) {
    setForm((prev) => ({ ...prev, [name]: value }));
  }

  async function submit(e) {
    e.preventDefault();
    setMessage('');
    setError('');
    const res = await fetch('/api/activate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(form)
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    const data = await res.json();
    setMessage(`Tebrikler ${data.kadi}! Aktivasyon başarıyla tamamlandı.`);
  }

  return (
    <LegacyLayout pageTitle="Aktivasyon Kodu Girişi" showLeftColumn={false}>
      <form onSubmit={submit}>
        <div style={{ padding: 12 }}>
          <b>Aktivasyon kodunuzu giriniz</b><br /><br />
          <table border="0" cellPadding="2" cellSpacing="2">
            <tbody>
              <tr>
                <td align="right"><b>Kullanıcı Adı :</b></td>
                <td align="left">
                  <input className="inptxt" type="text" required size="20" value={form.kadi} onChange={(e) => updateField('kadi', e.target.value)} />
                </td>
              </tr>
              <tr>
                <td align="right"><b>Şifre :</b></td>
                <td align="left">
                  <input className="inptxt" type="password" required size="20" value={form.sifre} onChange={(e) => updateField('sifre', e.target.value)} />
                </td>
              </tr>
              <tr>
                <td align="right"><b>Aktivasyon Kodu :</b></td>
                <td align="left">
                  <input className="inptxt" type="text" required size="20" value={form.akt} onChange={(e) => updateField('akt', e.target.value.trim())} />
                </td>
              </tr>
              <tr>
                <td align="right" colSpan="2">
                  <input type="submit" className="sub" value="Aktivasyonu Tamamla" />
                </td>
              </tr>
            </tbody>
          </table>
          {message ? <div className="sdal-alert sdal-alert-success" role="status">{message}<br /><Link to="/">Anasayfaya dön</Link></div> : null}
          {error ? <div className="sdal-alert sdal-alert-error" role="alert">{error}</div> : null}
        </div>
      </form>
    </LegacyLayout>
  );
}
