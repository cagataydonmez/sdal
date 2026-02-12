import React, { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function PasswordResetPage() {
  const [params] = useSearchParams();
  const [kadi, setKadi] = useState(params.get('kadi') || '');
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  async function submit(payload) {
    setError('');
    setMessage('');
    const res = await fetch('/api/password-reset', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(payload)
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setMessage('Şifreniz e-mail adresinize gönderildi.');
  }

  return (
    <LegacyLayout pageTitle="Şifre Hatırlama" showLeftColumn={false}>
      <table border="0" cellPadding="0" cellSpacing="0" width="330" style={{ border: '1px solid #000033' }}>
        <tbody>
          <tr>
            <td width="15" height="15" background="/legacy/kose_su.gif"></td>
            <td style={{ background: '#FFFFCC' }} width="300" height="15"></td>
            <td width="15" height="15" background="/legacy/kose_sau.gif"></td>
          </tr>
          <tr>
            <td width="15" height="150" style={{ background: '#FFFFCC' }}></td>
            <td width="300" height="150" bgcolor="#FFFFCC" style={{ fontSize: 11 }}>
              <table border="0" cellPadding="2" cellSpacing="2">
                <caption align="top">
                  <font className="inptxt" style={{ color: 'red', fontSize: 12, border: 0 }}>
                    Lütfen size uygun seçeneği kullanınız. Kullanıcı adınız ve şifreniz e-mail adresinize postalanacaktır.
                  </font>
                </caption>
                <tbody>
                  <tr>
                    <td align="right"><b>Kullanıcı Adım : </b></td>
                    <td align="left"><input type="text" name="kadi" size="20" className="inptxt" value={kadi} onChange={(e) => setKadi(e.target.value)} /></td>
                    <td align="left"><input type="button" name="kadibut" value="Gönder" className="sub" onClick={() => submit({ kadi })} /></td>
                  </tr>
                  <tr>
                    <td align="right"><b>E-mail Adresim : </b></td>
                    <td align="left"><input type="text" name="email" size="20" className="inptxt" value={email} onChange={(e) => setEmail(e.target.value)} /></td>
                    <td align="left"><input type="button" name="emailbut" value="Gönder" className="sub" onClick={() => submit({ email })} /></td>
                  </tr>
                  <tr>
                    <td align="center" colSpan="3">
                      <a href="/uye-kayit" title="hemen kaydolun">sdal.org sitesine kayıt yaptırmak için tıklayın.</a>
                      <br /><a href="/" title="Anasayfa">Anasayfaya gitmek için buraya tıklayın.</a>
                    </td>
                  </tr>
                </tbody>
              </table>
              {error ? <div className="hatamsg1">{error}</div> : null}
              {message ? <div>{message}</div> : null}
            </td>
            <td width="15" height="150" style={{ background: '#FFFFCC' }}></td>
          </tr>
          <tr>
            <td width="15" height="15" background="/legacy/kose_sa.gif"></td>
            <td style={{ background: '#FFFFCC' }} width="300" height="15"></td>
            <td width="15" height="15" background="/legacy/kose_saa.gif"></td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
