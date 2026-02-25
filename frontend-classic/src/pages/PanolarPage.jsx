import React, { useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { tarihduz } from '../utils/date.js';

export default function PanolarPage() {
  const [params, setParams] = useSearchParams();
  const isl = params.get('isl') || '';
  const mkatid = params.get('mkatid') || '0';
  const sf = params.get('sf') || '1';

  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [mesaj, setMesaj] = useState('');

  const page = Math.max(parseInt(sf, 10) || 1, 1);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError('');
    fetch(`/api/panolar?mkatid=${encodeURIComponent(mkatid)}&page=${page}`, { credentials: 'include' })
      .then((res) => {
        if (!res.ok) throw new Error('Veri alınamadı.');
        return res.json();
      })
      .then((payload) => {
        if (!alive) return;
        setData(payload);
      })
      .catch((err) => {
        if (alive) setError(err.message || 'Hata oluştu.');
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => { alive = false; };
  }, [mkatid, page]);

  const gradCategory = data?.gradCategory || null;
  const currentCategoryName = mkatid === '0' ? 'GENEL Mesaj Panosu' : (data?.categoryName || 'Mesaj Panosu');

  function setNewMessageLink() {
    setParams((prev) => {
      const next = new URLSearchParams(prev);
      next.set('isl', 'myaz');
      next.set('mkatid', mkatid);
      next.delete('sf');
      return next;
    });
  }

  function goBackToList() {
    setParams((prev) => {
      const next = new URLSearchParams(prev);
      next.delete('isl');
      return next;
    });
  }

  async function submitMessage(e) {
    e.preventDefault();
    setError('');
    const res = await fetch('/api/panolar', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ mesaj, katid: mkatid })
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setMesaj('');
    goBackToList();
  }

  async function deleteMessage(id) {
    if (!window.confirm('Silmek istediğine emin misin?')) return;
    setError('');
    const res = await fetch(`/api/panolar/${id}`, { method: 'DELETE', credentials: 'include' });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setData((prev) => {
      if (!prev) return prev;
      return { ...prev, messages: prev.messages.filter((m) => m.id !== id) };
    });
  }

  const smileys = useMemo(() => Array.from({ length: 16 }, (_, i) => i + 1), []);

  function appendSmiley(idx) {
    setMesaj((v) => `${v}:y${idx}:`);
  }

  if (loading) {
    return (
      <LegacyLayout pageTitle="Mesaj Panoları">
        Yükleniyor...
      </LegacyLayout>
    );
  }

  if (error) {
    return (
      <LegacyLayout pageTitle="Mesaj Panoları">
        <div className="hatamsg1">{error}</div>
      </LegacyLayout>
    );
  }

  if (isl === 'myaz') {
    return (
      <LegacyLayout pageTitle="Mesaj Panoları">
        <form method="post" onSubmit={submitMessage} name="mesajform">
          <table border="0" cellPadding="3" cellSpacing="1" width="400">
            <tbody>
              <tr>
                <td colSpan="2" align="left" style={{ border: '1px solid #660000', background: '#660000', color: 'white', fontSize: 13 }}>
                  <b>Mesaj Yaz</b>&nbsp;&nbsp;&nbsp;&nbsp;
                  <a href={`/panolar?mkatid=${mkatid}`} title="Geri Dön" style={{ color: 'white' }}><b>Geri Dön</b></a>
                </td>
              </tr>
              <tr>
                <td style={{ border: '1px solid #663300', background: 'white' }} align="right" valign="top" width="100">
                  <b>Mesaj : </b>
                </td>
                <td style={{ border: '1px solid #663300', background: 'white' }} align="left" valign="top">
                  <textarea className="inptxt" name="mesaj" cols="50" rows="10" value={mesaj} onChange={(e) => setMesaj(e.target.value)}></textarea>
                </td>
              </tr>
              <tr>
                <td colSpan="2" style={{ border: '1px solid #663300', background: 'white' }} align="center" valign="top">
                  <table border="0" cellPadding="2" cellSpacing="0" width="100%">
                    <tbody>
                      <tr>
                        {smileys.map((s) => (
                          <td key={s} style={{ background: 'white' }} align="center">
                            <a title="Yazınıza eklemek için tıklayın!" style={{ cursor: 'pointer' }} onClick={() => appendSmiley(s)}>
                              <img src={`/smiley/${s}.gif`} align="center" border="0" alt="" />
                            </a>
                          </td>
                        ))}
                      </tr>
                    </tbody>
                  </table>
                </td>
              </tr>
              <tr>
                <td colSpan="2" style={{ border: '1px solid #663300', background: 'white' }} align="center" valign="top">
                  <input type="submit" value="Gönder" className="sub" />
                </td>
              </tr>
            </tbody>
          </table>
        </form>
      </LegacyLayout>
    );
  }

  return (
    <LegacyLayout pageTitle="Mesaj Panoları">
      <table border="0" cellPadding="3" cellSpacing="1" width="100%">
        <tbody>
          <tr>
            <td colSpan="2" align="left" style={{ border: '1px solid #660000', background: '#660000', color: 'white', fontSize: 13 }}>
              {mkatid === '0' ? (
                <>
                  <b>GENEL Mesaj Panosu</b>
                  {gradCategory ? (
                    <>
                      {' '}|{' '}
                      <b><a style={{ color: 'white' }} href={`/panolar?mkatid=${gradCategory.id}`} title="Bu kategoriyi görmek için tıklayınız">{gradCategory.kategoriadi} Panosu</a></b>
                    </>
                  ) : null}
                </>
              ) : (
                <>
                  {gradCategory ? <b>{gradCategory.kategoriadi} Mesaj Panosu</b> : <b>{currentCategoryName}</b>}
                  {' '}|{' '}
                  <b><a style={{ color: 'white' }} href="/panolar?mkatid=0" title="Bu kategoriyi görmek için tıklayınız">Genel Mesaj Panosu</a></b>
                </>
              )}
            </td>
          </tr>
          <tr>
            <td colSpan="2" align="left" style={{ border: '1px solid #660000', background: '#663300', color: 'white', fontSize: 13 }}>
              <table border="0" cellSpacing="2" cellPadding="5">
                <tbody>
                  <tr>
                    <td style={{ background: 'white', border: '2px solid black' }}>
                      <a href={`/panolar?isl=myaz&mkatid=${mkatid}`} title="Mesaj Yazmak istiyorum" style={{ color: 'navy', textDecoration: 'none' }}><b> MESAJ YAZ </b></a>
                    </td>
                  </tr>
                </tbody>
              </table>
            </td>
          </tr>
          {data?.messages?.length ? data.messages.map((msg, idx) => (
            <React.Fragment key={msg.id}>
              <tr>
                <td style={{ border: '1px solid #663300', background: 'white' }} align="center" valign="top" width="50">
                  <a href={`/uyeler/${msg.user.id}`} title={`${msg.user.kadi} isimli üyenin profilini görüntüle`}>
                    <img src={`/api/media/kucukresim?iwidth=50&r=${encodeURIComponent(msg.user.resim || 'nophoto.jpg')}`} border="1" width="50" alt="" />
                  </a>
                </td>
                <td style={{ border: '1px solid #663300', background: msg.isNew ? 'navy' : 'white' }} align="left" valign="top">
                  <table border="0" cellPadding="3" cellSpacing="1" width="100%">
                    <tbody>
                      <tr>
                        <td align="left" valign="top" style={{ border: '1px solid #663300', background: '#ffffcc' }}>
                          <b>{msg.user.kadi}</b> - {tarihduz(msg.tarih)}
                          {msg.isNew ? <span> - <font style={{ color: 'red' }}><b>YENİ MESAJ!</b></font></span> : null}
                          {typeof msg.diffSeconds === 'number' ? ` - ${msg.diffSeconds}` : ''}
                          {data.canDelete ? <span> - <a href="#" onClick={(e) => { e.preventDefault(); deleteMessage(msg.id); }}>Sil {msg.id}</a></span> : null}
                        </td>
                      </tr>
                      <tr>
                        <td align="justify" valign="top" style={{ border: '1px solid #663300', background: 'white' }}>
                          <span dangerouslySetInnerHTML={{ __html: msg.mesajHtml }} />
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </td>
              </tr>
              {(idx + 1) % 10 === 0 ? (
                <tr>
                  <td colSpan="2" align="left" style={{ border: '1px solid #660000', background: '#663300', color: 'white', fontSize: 13 }}>
                    <a href={`/panolar?isl=myaz&mkatid=${mkatid}`} title="Mesaj Yazmak istiyorum" style={{ color: 'white', textDecoration: 'none' }}><b> MESAJ YAZ </b></a>
                  </td>
                </tr>
              ) : null}
            </React.Fragment>
          )) : (
            <tr><td colSpan="2"><b>Kayıt Bulunamadı</b></td></tr>
          )}
        </tbody>
      </table>

      <table width="100%" cellPadding="3" cellSpacing="1">
        <tbody>
          {data?.pages > 1 ? (
            <tr>
              <td align="center" style={{ border: '1px solid #663300', background: 'white' }} width="100%">
                <table border="0" cellPadding="2" cellSpacing="1"><tbody><tr>
                  <td style={{ background: 'white', border: '1px solid #ededed' }} width="15" align="center">
                    <b><a href={`/panolar?sf=${page === 1 ? data.pages : page - 1}&mkatid=${mkatid}`} title="Önceki sayfa">&lt;</a></b>
                  </td>
                  {data.pageList.map((p) => (
                    <td key={p} style={{ background: p === page ? 'yellow' : 'white', border: '1px solid #ededed' }} width="15" align="center">
                      {p === page ? <b>{p}</b> : <b><a href={`/panolar?sf=${p}&mkatid=${mkatid}`}>{p}</a></b>}
                    </td>
                  ))}
                  <td style={{ background: 'white', border: '1px solid #ededed' }} width="15" align="center">
                    <b><a href={`/panolar?sf=${page === data.pages ? 1 : page + 1}&mkatid=${mkatid}`} title="Sonraki sayfa">&gt;</a></b>
                  </td>
                </tr></tbody></table>
              </td>
            </tr>
          ) : null}
          <tr>
            <td align="center" style={{ border: '1px solid #663300', background: 'white' }} width="100%">
              <br />Toplam <b>{data?.total || 0}</b> mesaj bulunmaktadır.
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
