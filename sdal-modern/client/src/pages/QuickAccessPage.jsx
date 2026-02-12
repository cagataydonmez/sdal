import React, { useEffect, useState } from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function QuickAccessPage() {
  const [users, setUsers] = useState([]);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  function load() {
    setError('');
    fetch('/api/quick-access', { credentials: 'include' })
      .then((res) => {
        if (!res.ok) throw new Error('Liste alınamadı.');
        return res.json();
      })
      .then((data) => setUsers(data.users || []))
      .catch((err) => setError(err.message));
  }

  useEffect(() => {
    const url = new URL(window.location.href);
    if (url.searchParams.get('hlc') === 'e') setStatus('İstediğiniz üye listeden başarıyla çıkartıldı.');
    if (url.searchParams.get('hle') === 'e') setStatus('İstediğiniz üye listeye başarıyla eklendi.');
    load();
  }, []);

  async function removeUser(id) {
    setError('');
    const res = await fetch('/api/quick-access/remove', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ id })
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    load();
  }

  return (
    <LegacyLayout pageTitle="Hızlı Erişim">
      <table border="1" cellPadding="0" cellSpacing="2" width="100%" bgcolor="#ffffdd" borderColor="#663300">
        <tbody>
          <tr>
            <td style={{ background: '#ffffcc', border: '1px solid #660000' }}>
              <table border="0" cellPadding="3" cellSpacing="0" width="100%">
                {status ? (
                  <tr>
                    <td height="20" valign="center" align="left" style={{ borderBottom: '1px solid #660000', color: 'navy' }}>
                      <b>{status}</b>
                    </td>
                  </tr>
                ) : null}
                <tr>
                  <td height="20" valign="center" align="left" style={{ background: 'navy', borderBottom: '1px solid #660000', color: 'white' }}>
                    <b>Hızlı Erişim Kutusu</b>
                  </td>
                </tr>
                <tr>
                  <td>
                    {users.length === 0 ? (
                      <>Henüz üye eklenmemiş..</>
                    ) : (
                      <table border="0" cellPadding="1" cellSpacing="10">
                        <tbody>
                          <tr>
                            {users.map((u, idx) => (
                              <td key={u.id} width="100" height="100" style={{ border: '1px solid #ebebeb', background: 'white', color: '#000033' }} align="center" valign="top">
                                <a href={`/uyeler/${u.id}`} title={`${u.kadi} isimli üyenin detayları`}><b>{u.kadi?.length > 10 ? `${u.kadi.slice(0, 10)}..` : u.kadi}</b></a><br /><br />
                                <a href={`/uyeler/${u.id}`} title={`${u.kadi} isimli üyenin detayları`}>
                                  <img src={`/api/media/kucukresim?iwidth=50&r=${encodeURIComponent(u.resim || 'nophoto.jpg')}`} border="1" alt="" />
                                </a><br /><br />
                                <small>{u.mezuniyetyili} Mezunu</small>
                                <hr color="#ededed" size="1" />
                                {u.online === 1 ? (
                                  <>
                                    <center><font style={{ color: 'red' }}><b>Bağlı!</b></font></center>
                                    <hr color="#ededed" size="1" />
                                  </>
                                ) : null}
                                <table border="0" cellPadding="0" cellSpacing="0" width="100%">
                                  <tbody>
                                    <tr>
                                      <td align="left" valign="top">
                                        <font style={{ fontSize: 10 }}>
                                          <li><a href={`/mesajlar/yeni?kime=${u.id}`} title={`${u.kadi} isimli üyeye mesaj gönder.`}>Mesaj Gönder</a></li>
                                          <li><a href={`/hizli-erisim/cikart/${u.id}`} title="Bu üyeyi Hızlı Erişim Listesinden Çıkart">Listeden Çıkart</a></li>
                                        </font>
                                      </td>
                                    </tr>
                                  </tbody>
                                </table>
                              </td>
                            ))}
                          </tr>
                        </tbody>
                      </table>
                    )}
                  </td>
                </tr>
                <tr>
                  <td align="left">
                    <form method="post" action="/uyeler">
                      Üye Ara : <input type="text" name="kelime" className="inptxt" />&nbsp;
                      <input type="submit" value="Ara" className="sub" />
                      <input type="hidden" name="tip" value="hara" />
                    </form>
                  </td>
                </tr>
              </table>
              {error ? <div className="hatamsg1">{error}</div> : null}
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
