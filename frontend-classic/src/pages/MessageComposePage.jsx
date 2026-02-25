import React, { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function MessageComposePage() {
  const [params] = useSearchParams();
  const kime = params.get('kime');
  const ynt = params.get('ynt');
  const [recipient, setRecipient] = useState(null);
  const [konu, setKonu] = useState('');
  const [mesaj, setMesaj] = useState('');
  const [status, setStatus] = useState('');

  useEffect(() => {
    if (!kime) return;
    fetch(`/api/members/${kime}`, { credentials: 'include' })
      .then((res) => res.json())
      .then((payload) => setRecipient(payload.row))
      .catch(() => setRecipient(null));
  }, [kime]);

  useEffect(() => {
    if (!ynt) return;
    fetch(`/api/messages/${ynt}`, { credentials: 'include' })
      .then((res) => res.json())
      .then((payload) => {
        if (payload?.row?.konu) setKonu(`Re:${payload.row.konu}`);
      })
      .catch(() => {});
  }, [ynt]);

  async function onSubmit(e) {
    e.preventDefault();
    setStatus('');
    const res = await fetch('/api/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ kime, konu, mesaj })
    });
    if (res.ok) {
      setStatus('Mesaj gönderildi!');
      setMesaj('');
    } else {
      setStatus(await res.text());
    }
  }

  return (
    <LegacyLayout pageTitle="Mesaj Gönder">
      <form onSubmit={onSubmit}>
        <table border="1" cellPadding="3" cellSpacing="3" borderColor="#663300" bgcolor="#ffffcc">
          <tbody>
            <tr>
              <td colSpan="2" style={{ border: 0, fontSize: 13, color: '#663300' }}>
                <b>Mesaj Gönder</b>
              </td>
            </tr>
            <tr>
              <td align="right" valign="bottom" style={{ border: 0 }}>
                <b>Alıcı : </b>
              </td>
              <td align="left" style={{ border: 0 }}>
                {recipient ? (
                  <>
                    {recipient.resim && recipient.resim !== 'yok' ? (
                      <img src={`/api/media/kucukresim?height=30&file=${encodeURIComponent(recipient.resim)}`} border="1" alt="" />
                    ) : (
                      <img src="/legacy/vesikalik/nophoto.jpg" border="1" alt="" />
                    )}
                    {' '} - {recipient.kadi}
                  </>
                ) : (
                  'Seçilmedi'
                )}
              </td>
            </tr>
            <tr>
              <td align="right" style={{ border: 0 }}>
                <b>Konu : </b>
              </td>
              <td align="left" style={{ border: 0 }}>
                <input type="text" name="konu" size="30" className="inptxt" value={konu} onChange={(e) => setKonu(e.target.value)} style={{ color: 'black' }} />
              </td>
            </tr>
            <tr>
              <td align="right" style={{ border: 0 }} valign="top">
                <b>Mesaj : </b>
              </td>
              <td align="left" style={{ border: 0 }}>
                <textarea className="inptxt" name="mesaj" cols="50" rows="10" value={mesaj} onChange={(e) => setMesaj(e.target.value)} style={{ color: 'black' }} />
              </td>
            </tr>
            <tr>
              <td style={{ border: 0 }} align="left">
                <input type="button" value="Geri Dön" onClick={() => window.history.back()} className="sub" />
              </td>
              <td style={{ border: 0 }} align="right">
                <input type="submit" value="Gönder" className="sub" />
              </td>
            </tr>
          </tbody>
        </table>
        {status ? <div style={{ marginTop: 8 }}>{status}</div> : null}
      </form>
    </LegacyLayout>
  );
}
