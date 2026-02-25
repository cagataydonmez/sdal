import React, { useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { tarihduz } from '../utils/date.js';

export default function MessagesPage() {
  const [params] = useSearchParams();
  const box = params.get('k') === '1' ? 'outbox' : 'inbox';
  const page = Math.max(parseInt(params.get('sf') || '1', 10), 1);
  const [data, setData] = useState({ rows: [], page: 1, pages: 1, total: 0, box: 'inbox', pageSize: 5 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    fetch(`/api/messages?box=${box}&page=${page}&pageSize=5`, { credentials: 'include' })
      .then((res) => res.json())
      .then((payload) => {
        if (!alive) return;
        setData(payload);
      })
      .catch(() => {
        if (alive) setData({ rows: [], page: 1, pages: 1, total: 0, box, pageSize: 5 });
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => {
      alive = false;
    };
  }, [box, page]);

  return (
    <LegacyLayout pageTitle="Mesajlar">
      <table border="0" cellPadding="3" cellSpacing="0" width="675">
        <tbody>
          <tr>
            <td colSpan="2" width="100%" style={{ fontSize: 15, color: '#663300' }}>
              <b>Mesajlar</b>
            </td>
          </tr>
          <tr>
            <td width="75" valign="top">
              [ <a href="/mesajlar?k=0" title="Gelen Mesajlar">Gelen</a> ]<br /><br />
              [ <a href="/mesajlar?k=1" title="Giden Mesajlar">Giden</a> ]
            </td>
            <td style={{ border: '1px solid #ededed', background: 'white' }} width="100%">
              <table border="0" cellPadding="3" cellSpacing="0" width="100%">
                <tbody>
                  <tr>
                    <td colSpan="4" style={{ border: '1px solid #663300', background: 'navy', color: 'white', fontSize: 12 }}>
                      <b>{box === 'inbox' ? 'Gelen' : 'Giden'}</b>
                    </td>
                  </tr>
                  {loading ? (
                    <tr><td colSpan="4">Yükleniyor...</td></tr>
                  ) : data.rows.length === 0 ? (
                    <tr><td colSpan="4" style={{ border: '1px solid #663300' }}>Kayıt bulunamadı..</td></tr>
                  ) : (
                    <>
                      <tr>
                        <td style={{ border: '1px solid #663300' }} width="200"><b>{box === 'inbox' ? 'Gönderen' : 'Gönderilen'}</b></td>
                        <td style={{ border: '1px solid #663300' }} width="100"><b>Tarih</b></td>
                        <td style={{ border: '1px solid #663300' }} width="250"><b>Konu</b></td>
                        <td style={{ border: '1px solid #663300' }}><b>İşlem</b></td>
                      </tr>
                      {data.rows.map((row) => {
                        const user = box === 'inbox'
                          ? { id: row.kimden, kadi: row.kimden_kadi, resim: row.kimden_resim }
                          : { id: row.kime, kadi: row.kime_kadi, resim: row.kime_resim };
                        const tarih = tarihduz(row.tarih);
                        const parts = tarih ? tarih.split(' ') : [];
                        return (
                          <tr key={row.id}>
                            <td style={{ border: '1px solid #663300' }}>
                              <Link to={`/uyeler/${user.id}`} style={{ textDecoration: 'none' }}>
                                {user.resim && user.resim !== 'yok' ? (
                                  <img src={`/api/media/kucukresim?height=40&file=${encodeURIComponent(user.resim)}`} height="40" border="1" alt="" />
                                ) : (
                                  <img src="/legacy/vesikalik/nophoto.jpg" height="40" border="1" alt="" />
                                )}
                              </Link>
                              {' '} - <Link to={`/uyeler/${user.id}`}><b>{user.kadi}</b></Link>
                            </td>
                            <td style={{ border: '1px solid #663300' }}>{parts.slice(0, 3).join(' ')}</td>
                            <td style={{ border: '1px solid #663300' }}>
                              <Link to={`/mesajlar/${row.id}?k=${box === 'inbox' ? 0 : 1}`} title="Mesajı görmek için tıklayın.">
                                {row.yeni === 1 && box === 'inbox' ? <img src="/legacy/yenimesaj.gif" border="0" alt="" /> : null}
                                {row.yeni === 0 && box === 'inbox' ? <img src="/legacy/eskimesaj.gif" border="0" alt="" /> : null}
                                {row.yeni === 1 && box === 'inbox' ? <b>{(row.konu || '').slice(0, 25)} ( Yeni )</b> : (row.konu || '').slice(0, 25)}
                              </Link>
                            </td>
                            <td style={{ border: '1px solid #663300' }} width="125">
                              <Link to={`/mesajlar/yeni?kime=${user.id}`} title={`${user.kadi} isimli üyeye mesaj göndermek istiyorum.`}>Mesaj Gönder</Link>
                              {' '} / {' '}
                              <a href={`/api/messages/${row.id}`} onClick={(e) => { e.preventDefault(); fetch(`/api/messages/${row.id}`, { method: 'DELETE', credentials: 'include' }).then(() => window.location.reload()); }}>Sil</a>
                            </td>
                          </tr>
                        );
                      })}
                      <tr>
                        <td colSpan="4" align="center" style={{ borderLeft: '1px solid #663300', borderRight: '1px solid #663300', borderBottom: '1px solid #663300' }}>
                          {data.pages > 1 ? (
                            <table border="0" cellPadding="2" cellSpacing="1">
                              <tbody>
                                <tr>
                                  <td style={{ background: 'white', border: '1px solid #ededed' }} width="15" align="center">
                                    <b><a href={`/mesajlar?sf=${page === 1 ? data.pages : page - 1}&k=${box === 'inbox' ? 0 : 1}`}>&lt;</a></b>
                                  </td>
                                  {Array.from({ length: data.pages }, (_, i) => i + 1).map((p) => (
                                    <td key={p} style={{ background: p === page ? 'yellow' : 'white', border: '1px solid #ededed' }} width="15" align="center">
                                      {p === page ? <b>{p}</b> : <b><a href={`/mesajlar?sf=${p}&k=${box === 'inbox' ? 0 : 1}`}>{p}</a></b>}
                                    </td>
                                  ))}
                                  <td style={{ background: 'white', border: '1px solid #ededed' }} width="15" align="center">
                                    <b><a href={`/mesajlar?sf=${page === data.pages ? 1 : page + 1}&k=${box === 'inbox' ? 0 : 1}`}>&gt;</a></b>
                                  </td>
                                </tr>
                              </tbody>
                            </table>
                          ) : null}
                          <div>
                            Toplam <b>{data.pages}</b> sayfada <b>{data.total}</b> mesaj bulunmaktadır.
                          </div>
                        </td>
                      </tr>
                    </>
                  )}
                </tbody>
              </table>
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
