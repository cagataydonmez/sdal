import React, { useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { tarihduz } from '../utils/date.js';

const aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

export default function MembersPage() {
  const [params, setParams] = useSearchParams();
  const page = Math.max(parseInt(params.get('sf') || '1', 10), 1);
  const term = params.get('kelime') || '';
  const [data, setData] = useState({ rows: [], page: 1, pages: 1, total: 0, ranges: [], pageSize: 10 });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    const query = new URLSearchParams({ page: String(page), pageSize: '10', ...(term ? { term } : {}) }).toString();
    fetch(`/api/members?${query}`, { credentials: 'include' })
      .then((res) => res.json())
      .then((payload) => {
        if (!alive) return;
        setData(payload);
      })
      .catch(() => {
        if (!alive) return;
        setData({ rows: [], page: 1, pages: 1, total: 0, ranges: [], pageSize: 10 });
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => {
      alive = false;
    };
  }, [page, term]);

  const ranges = useMemo(() => data.ranges || [], [data.ranges]);

  return (
    <LegacyLayout pageTitle="Üyeler">
      <table border="0" width="100%">
        <tbody>
          <tr>
            <td align="left" style={{ fontSize: 15, color: '#663300', borderBottom: '1px solid #663300' }}>
              <b>Üyeler</b>
            </td>
          </tr>
        </tbody>
      </table>

      <form method="get" action="/uyeler" style={{ marginTop: 8 }}>
        Üye Ara : <input type="text" name="kelime" className="inptxt" defaultValue={term} />&nbsp;
        <input type="submit" value="Ara" className="sub" />
      </form>

      <table border="0" cellPadding="3" cellSpacing="0" width="100%">
        <tbody>
          <tr>
            <td colSpan="2" style={{ border: '1px solid #663300' }} align="center">
              {term ? (
                <b>Arama: {term}</b>
              ) : (
                <>
                  Sayfalar :{' '}
                  {ranges.map((r, idx) => (
                    <React.Fragment key={`${r.start}-${idx}`}>
                      {idx > 0 ? ' ' : ''}
                      {data.page === idx + 1 ? (
                        <b>{r.start} - {r.end}</b>
                      ) : (
                        <b>[<a href={`/uyeler?sf=${idx + 1}${term ? `&kelime=${encodeURIComponent(term)}` : ''}`} title={`${idx + 1}. sayfaya git.`}>{r.start} - {r.end}</a>]</b>
                      )}
                    </React.Fragment>
                  ))}
                </>
              )}
            </td>
          </tr>

          {loading ? (
            <tr><td>Yükleniyor...</td></tr>
          ) : data.rows.map((row) => (
            <React.Fragment key={row.id}>
              <tr>
                <td style={{ border: '1px solid #663300' }} width="75" valign="top">
                  <Link to={`/uyeler/${row.id}`} title="Üye detaylarını görmek için tıklayın." style={{ textDecoration: 'none' }}>
                    {row.resim && row.resim !== 'yok' ? (
                      <img src={`/api/media/kucukresim?width=75&file=${encodeURIComponent(row.resim)}`} border="1" width="75" alt="" />
                    ) : (
                      <img src="/legacy/vesikalik/nophoto.jpg" border="1" width="75" alt="" />
                    )}
                  </Link>
                  {row.online === 1 ? (
                    <center><font style={{ color: 'red' }}><b>Bağlı!</b></font></center>
                  ) : null}
                </td>
                <td style={{ border: '1px solid #663300' }} valign="top">
                  <table border="0" cellPadding="3" cellSpacing="0" width="100%">
                    <tbody>
                      <tr>
                        <td colSpan="2" width="100%" valign="top" align="left" style={{ borderBottom: '1px solid #663300', background: '#ffffcc' }}>
                          <table border="0" cellPadding="3" cellSpacing="0" width="100%">
                            <tbody>
                              <tr>
                                <td width="50%" align="left" valign="center">
                                  Kullanıcı Adı : <Link to={`/uyeler/${row.id}`} title="Üye detaylarını görmek için tıklayın." style={{ textDecoration: 'none' }}><b>{row.kadi}</b></Link>
                                </td>
                                <td width="50%" align="right" valign="center">
                                  {row.sontarih ? (
                                    <>Siteye son girdiği tarih : <b>{tarihduz(row.sontarih)}</b></>
                                  ) : (
                                    <>Siteye son girdiği tarih belirsiz..</>
                                  )}
                                </td>
                              </tr>
                              <tr>
                                <td width="100%" align="center" valign="center" style={{ borderTop: '1px solid #663300' }} colSpan="2">
                                  <Link to={`/uyeler/${row.id}`} title="Üye detaylarını görmek için tıklayın.">Üye Detaylarını Göster</Link>
                                  {' '} - {' '}
                                  <Link to={`/hizli-erisim/ekle/${row.id}`} title="Bu üyeyi hızlı erişim listeme ekle">Hızlı Erişim Listesine Ekle</Link>
                                  {' '} - {' '}
                                  <Link to={`/mesajlar/yeni?kime=${row.id}`} title={`${row.kadi} isimli üyeye mesaj gönder.`}>Mesaj Gönder</Link>
                                </td>
                              </tr>
                            </tbody>
                          </table>
                        </td>
                      </tr>
                      <tr>
                        <td width="50%" valign="top">
                          <li>İsim Soyisim : <b>{row.isim} {row.soyisim}</b><br /><br /></li>
                          <li>E-Mail : {row.mailkapali === 1 ? <i>Üyemiz e-mail adresinin görünmesini istemiyor.</i> : <b>{row.email}</b>}<br /><br /></li>
                          <li>Mezuniyet Yılı : {row.mezuniyetyili === '0' || row.mezuniyetyili === 0 ? <i>Henüz bir mezuniyet yılı girilmemiş.</i> : <b>{row.mezuniyetyili}</b>}<br /><br /></li>
                          <li>Doğum günü : {(row.dogumgun && row.dogumay && row.dogumyil) ? (
                            <b>{row.dogumgun} {aylar[(row.dogumay || 1) - 1]} {row.dogumyil}</b>
                          ) : (
                            <i>Henüz bir doğum günü girilmemiş.</i>
                          )}</li>
                        </td>
                        <td width="50%" valign="top">
                          <li>Bulunduğu şehir : <b>{row.sehir}</b><br /><br /></li>
                          <li>Üniversite : <b>{row.universite}</b><br /><br /></li>
                          <li>İş : <b>{row.meslek}</b><br /><br /></li>
                          <li>Web Sitesi : <b>{row.websitesi ? <a href={`${row.websitesi.startsWith('http') ? '' : 'http://'}` + row.websitesi} target="_blank" rel="noreferrer">{row.websitesi}</a> : ''}</b></li>
                        </td>
                      </tr>
                      <tr>
                        <td colSpan="2" style={{ borderTop: '1px solid #663300' }} align="center">
                          <font style={{ fontSize: 10, color: '#663300' }}>{row.imza}</font>
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </td>
              </tr>
              <tr>
                <td colSpan="2" style={{ border: '1px solid #663300', background: '#660000' }} height="7" />
              </tr>
            </React.Fragment>
          ))}

          <tr>
            <td colSpan="2" style={{ border: '1px solid #663300' }} align="center">
              {term ? (
                <b>Arama: {term}</b>
              ) : (
                <>
                  Sayfalar :{' '}
                  {ranges.map((r, idx) => (
                    <React.Fragment key={`${r.start}-${idx}-bottom`}>
                      {idx > 0 ? ' ' : ''}
                      {data.page === idx + 1 ? (
                        <b>{r.start} - {r.end}</b>
                      ) : (
                        <b>[<a href={`/uyeler?sf=${idx + 1}${term ? `&kelime=${encodeURIComponent(term)}` : ''}`} title={`${idx + 1}. sayfaya git.`}>{r.start} - {r.end}</a>]</b>
                      )}
                    </React.Fragment>
                  ))}
                </>
              )}
              <br />Toplam <b>{data.total}</b> üyemiz bulunmaktadır.
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
