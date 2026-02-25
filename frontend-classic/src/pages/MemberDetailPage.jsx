import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { tarihduz } from '../utils/date.js';

const aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

export default function MemberDetailPage() {
  const { id } = useParams();
  const [row, setRow] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    fetch(`/api/members/${id}`, { credentials: 'include' })
      .then((res) => res.json())
      .then((payload) => {
        if (!alive) return;
        setRow(payload.row || null);
      })
      .catch(() => {
        if (alive) setRow(null);
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => {
      alive = false;
    };
  }, [id]);

  if (loading) {
    return (
      <LegacyLayout pageTitle="Üye Detay">
        <div style={{ padding: 12 }}>Yükleniyor...</div>
      </LegacyLayout>
    );
  }

  if (!row) {
    return (
      <LegacyLayout pageTitle="Üye Detay">
        <div style={{ padding: 12 }}>Üye bulunamadı.</div>
      </LegacyLayout>
    );
  }

  return (
    <LegacyLayout pageTitle="Üye Detay">
      <table border="0" cellPadding="3" cellSpacing="1" width="100%">
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300', background: '#660000', color: 'white' }} align="left">
              <b>{row.kadi} - Üye Detayları</b>
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300', color: '#000033' }} align="left" valign="top">
              <table border="0" cellPadding="3" cellSpacing="0" width="100%">
                <tbody>
                  <tr>
                    <td width="140" valign="top">
                      {row.resim && row.resim !== 'yok' ? (
                        <img src={`/api/media/kucukresim?width=138&file=${encodeURIComponent(row.resim)}`} border="1" width="138" alt="" />
                      ) : (
                        <img src="/legacy/vesikalik/nophoto.jpg" border="1" width="138" alt="" />
                      )}
                      {row.online === 1 ? (
                        <center><font style={{ color: 'red' }}><b>Bağlı!</b></font></center>
                      ) : null}
                    </td>
                    <td valign="top">
                      <b>İsim Soyisim:</b> {row.isim} {row.soyisim}<br />
                      <b>Kullanıcı Adı:</b> {row.kadi}<br />
                      <b>E-Mail:</b> {row.mailkapali === 1 ? <i>Gizli</i> : row.email}<br />
                      <b>Mezuniyet Yılı:</b> {row.mezuniyetyili || '-'}<br />
                      <b>Doğum Günü:</b> {(row.dogumgun && row.dogumay && row.dogumyil) ? `${row.dogumgun} ${aylar[(row.dogumay || 1) - 1]} ${row.dogumyil}` : '-'}<br />
                      <b>Şehir:</b> {row.sehir}<br />
                      <b>Üniversite:</b> {row.universite}<br />
                      <b>Meslek:</b> {row.meslek}<br />
                      <b>Web:</b> {row.websitesi ? <a href={`${row.websitesi.startsWith('http') ? '' : 'http://'}` + row.websitesi} target="_blank" rel="noreferrer">{row.websitesi}</a> : ''}
                      <br />
                      <b>Son Giriş:</b> {row.sontarih ? tarihduz(row.sontarih) : '-'}
                      <br />
                      <br />
                      <Link to={`/mesajlar/yeni?kime=${row.id}`}>Mesaj Gönder</Link>
                      {' '} - {' '}
                      <Link to={`/hizli-erisim/ekle/${row.id}`}>Hızlı Erişim Listesine Ekle</Link>
                    </td>
                  </tr>
                  <tr>
                    <td colSpan="2" style={{ borderTop: '1px solid #663300' }}>
                      <font style={{ fontSize: 10, color: '#663300' }}>{row.imza}</font>
                    </td>
                  </tr>
                </tbody>
              </table>
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
