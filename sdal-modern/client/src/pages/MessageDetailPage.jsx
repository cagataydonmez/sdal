import React, { useEffect, useState } from 'react';
import { useParams, useSearchParams, Link } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { tarihduz } from '../utils/date.js';

export default function MessageDetailPage() {
  const { id } = useParams();
  const [params] = useSearchParams();
  const kk = params.get('k') || '0';
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    fetch(`/api/messages/${id}`, { credentials: 'include' })
      .then((res) => res.json())
      .then((payload) => {
        if (!alive) return;
        setData(payload);
      })
      .catch(() => {
        if (alive) setData(null);
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => { alive = false; };
  }, [id]);

  if (loading) {
    return (
      <LegacyLayout pageTitle="Mesaj Gör">
        <div style={{ padding: 12 }}>Yükleniyor...</div>
      </LegacyLayout>
    );
  }

  if (!data?.row) {
    return (
      <LegacyLayout pageTitle="Mesaj Gör">
        <div style={{ padding: 12 }}>Mesaj bulunamadı.</div>
      </LegacyLayout>
    );
  }

  const { row, sender, receiver } = data;
  const isInbox = kk === '0';

  return (
    <LegacyLayout pageTitle="Mesaj Gör">
      <table border="0" cellPadding="10" cellSpacing="0" width="600">
        <tbody>
          <tr>
            <td width="100%" style={{ fontSize: 15, color: '#663300' }}>
              <table border="0" cellPadding="0" cellSpacing="0" width="100%">
                <tbody>
                  <tr>
                    <td align="left" style={{ fontSize: 15, color: '#663300' }}><b>Mesajı Görüntüle</b></td>
                    <td align="right"><a href={`/mesajlar?k=${kk}`} title="Mesajlar sayfasına geri dön">Mesajlar sayfasına geri dön >></a></td>
                  </tr>
                </tbody>
              </table>
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300', background: 'white' }} width="100%">
              <table border="0" cellPadding="5" cellSpacing="1" width="100%">
                <tbody>
                  <tr>
                    <td width="50" style={{ border: '1px solid black' }}>
                      {(sender?.resim && sender.resim !== 'yok') ? (
                        <img src={`/api/media/kucukresim?width=50&file=${encodeURIComponent(sender.resim)}`} border="1" className="reflect rheight70 ropacity40" alt="" />
                      ) : (
                        <img src="/legacy/vesikalik/nophoto.jpg" border="1" className="reflect rheight70 ropacity40" alt="" />
                      )}
                    </td>
                    <td width="100%" align="left" valign="center">
                      <ul>
                        {isInbox ? (
                          <>
                            <b>Gönderen : </b>{sender?.kadi}<br /><br />
                            <b>Alıcı : </b>{receiver?.kadi}
                          </>
                        ) : (
                          <>
                            <b>Gönderen : </b>{sender?.kadi}<br /><br />
                            <b>Alıcı : </b>{receiver?.kadi}
                          </>
                        )}
                        <br /><br />
                        <b>Tarih : </b>{tarihduz(row.tarih)}
                      </ul>
                    </td>
                  </tr>
                </tbody>
              </table>
              <hr color="#663300" size="1" />
              <b>{row.konu}</b>
              <hr color="#663300" size="1" />
              <div dangerouslySetInnerHTML={{ __html: row.mesaj }} />
            </td>
          </tr>
          {isInbox ? (
            <tr>
              <td align="right">
                <Link to={`/mesajlar/yeni?kime=${sender?.id}&ynt=${row.id}`} title="Mesajı yanıtla">Yanıtla</Link>
                {' '} - {' '}
                <a href={`/api/messages/${row.id}`} onClick={(e) => { e.preventDefault(); fetch(`/api/messages/${row.id}`, { method: 'DELETE', credentials: 'include' }).then(() => window.location.href = `/mesajlar?k=${kk}`); }}>Sil</a>
              </td>
            </tr>
          ) : null}
        </tbody>
      </table>
    </LegacyLayout>
  );
}
