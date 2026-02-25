import React, { useEffect, useMemo, useState } from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';

const cities = [
  '01-Adana','02-Adıyaman','03-Afyon','04-Ağrı','05-Amasya','06-Ankara','07-Antalya','08-Artvin','09-Aydın','10-Balıkesir','11-Bilecik','12-Bingöl','13-Bitlis','14-Bolu','15-Burdur','16-Bursa','17-Çanakkale','18-Çankırı','19-Çorum','20-Denizli','21-Diyarbakır','22-Edirne','23-Elazığ','24-Erzincan','25-Erzurum','26-Eskişehir','27-Gaziantep','28-Giresun','29-Gümüşhane','30-Hakkari','31-Hatay','32-Isparta','33-İçel','34-İstanbul','35-İzmir','36-Kars','37-Kastamonu','38-Kayseri','39-Kırklareli','40-Kırşehir','41-Kocaeli','42-Konya','43-Kütahya','44-Malatya','45-Manisa','46-K.Maraş','47-Mardin','48-Muğla','49-Muş','50-Nevşehir','51-Niğde','52-Ordu','53-Rize','54-Sakarya','55-Samsun','56-Siirt','57-Sinop','58-Sivas','59-Tekirdağ','60-Tokat','61-Trabzon','62-Tunceli','63-Şanlıurfa','64-Uşak','65-Van','66-Yozgat','67-Zonguldak','68-Aksaray','69-Bayburt','70-Karaman','71-Kırıkkale','72-Batman','73-Şırnak','74-Bartın','75-Ardahan','76-Iğdır','77-Yalova','78-Karabük','79-Kilis','80-Osmaniye','81-Düzce','Yurt Dışı'
];

export default function ProfilePage() {
  const [user, setUser] = useState(null);
  const [form, setForm] = useState(null);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const [pwd, setPwd] = useState({ eskisifre: '', yenisifre: '', yenisifretekrar: '' });
  const [pwdStatus, setPwdStatus] = useState('');
  const [pwdError, setPwdError] = useState('');

  const years = useMemo(() => {
    const out = [];
    for (let y = 1975; y <= 1999; y += 1) out.push(String(y));
    return out;
  }, []);

  useEffect(() => {
    fetch('/api/profile', { credentials: 'include' })
      .then((res) => res.json())
      .then((data) => {
        setUser(data.user);
        setForm({
          isim: data.user?.isim || '',
          soyisim: data.user?.soyisim || '',
          sehir: data.user?.sehir || cities[0],
          meslek: data.user?.meslek || '',
          websitesi: data.user?.websitesi || '',
          universite: data.user?.universite || '',
          dogumgun: String(data.user?.dogumgun || 1),
          dogumay: String(data.user?.dogumay || 1),
          dogumyil: String(data.user?.dogumyil || years[0]),
          mailkapali: String(data.user?.mailkapali || 0),
          imza: data.user?.imza || ''
        });
      })
      .catch(() => {});
  }, [years]);

  if (!form) {
    return (
      <LegacyLayout pageTitle="Üyelik Bilgilerini Düzenle">
        <div style={{ padding: 12 }}>Yükleniyor...</div>
      </LegacyLayout>
    );
  }

  function updateField(name, value) {
    setForm((f) => ({ ...f, [name]: value }));
  }

  async function submitProfile(e) {
    e.preventDefault();
    setStatus('');
    setError('');
    const res = await fetch('/api/profile', {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(form)
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setStatus('Bilgileriniz başarıyla değiştirildi.');
  }

  async function submitPassword(e) {
    e.preventDefault();
    setPwdStatus('');
    setPwdError('');
    const res = await fetch('/api/profile/password', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(pwd)
    });
    if (!res.ok) {
      setPwdError(await res.text());
      return;
    }
    setPwdStatus('Şifreniz başarıyla değiştirildi.');
    setPwd({ eskisifre: '', yenisifre: '', yenisifretekrar: '' });
  }

  async function uploadPhoto(e) {
    e.preventDefault();
    const file = e.target.elements.file.files[0];
    if (!file) return;
    const fd = new FormData();
    fd.append('file', file);
    const res = await fetch('/api/profile/photo', { method: 'POST', credentials: 'include', body: fd });
    if (res.ok) {
      const data = await res.json();
      setUser((u) => ({ ...u, resim: data.photo }));
    }
  }

  return (
    <LegacyLayout pageTitle="Üyelik Bilgilerini Düzenle">
      {user?.ilkbd === 0 ? (
        <div style={{ padding: 12, color: '#000033' }}>
          Sdal.org'a hoşgeldiniz! Siteye ilk defa girdiğiniz için bu sayfayı görüyorsunuz.
        </div>
      ) : null}
      <form onSubmit={submitProfile}>
        <table border="0" cellPadding="0" cellSpacing="0" width="330">
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
                      Lütfen bilgilerinizi eksiksiz giriniz.
                    </font>
                  </caption>
                  <tbody>
                    <tr>
                      <td align="right"><b>İsim : </b></td>
                      <td align="left"><input type="text" name="isim" size="20" className="inptxt" value={form.isim} onChange={(e) => updateField('isim', e.target.value)} /></td>
                    </tr>
                    <tr>
                      <td align="right"><b>Soyisim : </b></td>
                      <td align="left"><input type="text" name="soyisim" size="20" className="inptxt" value={form.soyisim} onChange={(e) => updateField('soyisim', e.target.value)} /></td>
                    </tr>
                    <tr>
                      <td align="right"><b>Şehir : </b></td>
                      <td align="left">
                        <select name="sehir" className="inptxt" value={form.sehir} onChange={(e) => updateField('sehir', e.target.value)}>
                          {cities.map((c) => <option key={c} value={c}>{c}</option>)}
                        </select>
                      </td>
                    </tr>
                    <tr>
                      <td align="right"><b>Şu anki işi : </b></td>
                      <td align="left"><input type="text" name="meslek" size="20" className="inptxt" value={form.meslek} onChange={(e) => updateField('meslek', e.target.value)} /></td>
                    </tr>
                    <tr>
                      <td align="right"><b>Web Sitesi : </b></td>
                      <td align="left"><input type="text" name="websitesi" size="20" className="inptxt" value={form.websitesi} onChange={(e) => updateField('websitesi', e.target.value)} /></td>
                    </tr>
                    <tr>
                      <td align="right"><b><small>SDAL Mezuniyet Yılı : </small></b></td>
                      <td align="left" style={{ borderLeft: '1px solid #663300', borderBottom: '1px solid #663300' }}>
                        <b><font style={{ color: 'blue' }}>{user?.mezuniyetyili}</font></b>
                      </td>
                    </tr>
                    <tr>
                      <td align="right"><b><small>İlk Üniversite : </small></b></td>
                      <td align="left"><input type="text" name="universite" size="20" className="inptxt" value={form.universite} onChange={(e) => updateField('universite', e.target.value)} /></td>
                    </tr>
                    <tr>
                      <td align="right"><b>Doğumgünü : </b></td>
                      <td align="left">
                        <select name="dogumgun" className="inptxt" value={form.dogumgun} onChange={(e) => updateField('dogumgun', e.target.value)}>
                          {Array.from({ length: 31 }, (_, i) => i + 1).map((d) => <option key={d} value={String(d)}>{d}</option>)}
                        </select>.
                        <select name="dogumay" className="inptxt" value={form.dogumay} onChange={(e) => updateField('dogumay', e.target.value)}>
                          {Array.from({ length: 12 }, (_, i) => i + 1).map((d) => <option key={d} value={String(d)}>{d}</option>)}
                        </select>.
                        <select name="dogumyil" className="inptxt" value={form.dogumyil} onChange={(e) => updateField('dogumyil', e.target.value)}>
                          {years.map((y) => <option key={y} value={y}>{y}</option>)}
                        </select>
                      </td>
                    </tr>
                    <tr>
                      <td align="right"><b><small>Mailim görünsün mü? : </small></b></td>
                      <td align="left">
                        <select name="mailkapali" className="inptxt" value={form.mailkapali} onChange={(e) => updateField('mailkapali', e.target.value)}>
                          <option value="0">Evet</option>
                          <option value="1">Hayır</option>
                        </select>
                      </td>
                    </tr>
                    <tr>
                      <td align="right" valign="top"><b>Açıklama : </b></td>
                      <td align="left"><textarea name="imza" cols="23" rows="5" className="inptxt" value={form.imza} onChange={(e) => updateField('imza', e.target.value)} /></td>
                    </tr>
                    <tr>
                      <td align="right" colSpan="2"><input type="submit" className="sub" value="Kaydet" /></td>
                    </tr>
                  </tbody>
                </table>
                {status ? <div>{status}</div> : null}
                {error ? <div className="hatamsg1">{error}</div> : null}
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
      </form>

      <br />
      <form onSubmit={submitPassword}>
        <table border="0" cellPadding="0" cellSpacing="0" width="330">
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
                  <caption align="top"><font className="inptxt" style={{ color: 'red', fontSize: 12, border: 0 }}>Şifre Değiştir</font></caption>
                  <tbody>
                    <tr>
                      <td align="right"><b>Eski Şifre : </b></td>
                      <td align="left"><input type="password" name="eskisifre" size="20" className="inptxt" value={pwd.eskisifre} onChange={(e) => setPwd((p) => ({ ...p, eskisifre: e.target.value }))} /></td>
                    </tr>
                    <tr>
                      <td align="right"><b>Yeni Şifre : </b></td>
                      <td align="left"><input type="password" name="yenisifre" size="20" className="inptxt" value={pwd.yenisifre} onChange={(e) => setPwd((p) => ({ ...p, yenisifre: e.target.value }))} /></td>
                    </tr>
                    <tr>
                      <td align="right"><b>Yeni Şifre Tekrar : </b></td>
                      <td align="left"><input type="password" name="yenisifretekrar" size="20" className="inptxt" value={pwd.yenisifretekrar} onChange={(e) => setPwd((p) => ({ ...p, yenisifretekrar: e.target.value }))} /></td>
                    </tr>
                    <tr>
                      <td align="right" colSpan="2"><input type="submit" className="sub" value="Kaydet" /></td>
                    </tr>
                  </tbody>
                </table>
                {pwdStatus ? <div>{pwdStatus}</div> : null}
                {pwdError ? <div className="hatamsg1">{pwdError}</div> : null}
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
      </form>

      <br />
      <form onSubmit={uploadPhoto}>
        <table border="0" cellPadding="3" cellSpacing="1">
          <tbody>
            <tr><td style={{ border: '1px solid #663300' }} align="center"><b>Fotoğraf Ekleme/Düzenleme</b></td></tr>
            <tr>
              <td style={{ border: '1px solid #663300' }} align="center">
                <img src={user?.resim && user.resim !== 'yok' ? `/api/media/vesikalik/${user.resim}` : '/legacy/vesikalik/nophoto.jpg'} border="1" alt="" />
              </td>
            </tr>
            <tr>
              <td style={{ border: '1px solid #663300' }} align="center">
                <input type="file" name="file" size="40" className="inptxt" />
                <input type="submit" value="Yükle" className="sub" />
              </td>
            </tr>
          </tbody>
        </table>
      </form>
    </LegacyLayout>
  );
}
