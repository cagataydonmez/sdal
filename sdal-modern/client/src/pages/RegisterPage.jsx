import React, { useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function RegisterPage() {
  const [params] = useSearchParams();
  const presetKadi = params.get('kadi') || '';

  const [form, setForm] = useState({
    kadi: presetKadi,
    sifre: '',
    sifre2: '',
    email: '',
    mezuniyetyili: '0',
    isim: '',
    soyisim: '',
    gkodu: ''
  });
  const [step, setStep] = useState('form');
  const [preview, setPreview] = useState(null);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [captchaSrc, setCaptchaSrc] = useState(`/api/captcha?${Date.now()}`);

  useEffect(() => {
    setForm((f) => ({ ...f, kadi: presetKadi || f.kadi }));
  }, [presetKadi]);

  const years = useMemo(() => {
    const now = new Date().getFullYear();
    const out = [];
    for (let y = 1999; y <= now + 4; y += 1) out.push(String(y));
    return out;
  }, []);

  function updateField(name, value) {
    setForm((f) => ({ ...f, [name]: value }));
  }

  async function onPreview(e) {
    e.preventDefault();
    setError('');
    setStatus('');
    const res = await fetch('/api/register/preview', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(form)
    });
    if (!res.ok) {
      setError(await res.text());
      setCaptchaSrc(`/api/captcha?${Date.now()}`);
      return;
    }
    const data = await res.json();
    setPreview(data.fields);
    setStep('confirm');
  }

  async function onConfirm() {
    setError('');
    setStatus('');
    const res = await fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(form)
    });
    if (!res.ok) {
      setError(await res.text());
      setStep('form');
      setCaptchaSrc(`/api/captcha?${Date.now()}`);
      return;
    }
    setStatus('Kaydınız başarıyla tamamlandı! Aktivasyon için e-mailinizi kontrol ediniz.');
    setStep('done');
  }

  if (step === 'done') {
    return (
      <LegacyLayout pageTitle="Üye Kayıt Girişi" showLeftColumn={false}>
        <div style={{ padding: 12 }}>
          <b>Kaydınız başarıyla tamamlandı!</b><br />
          Kayıt işleminizin onaylanması için lütfen mail adresinize gönderdiğimiz linke tıklayınız!<br /><br />
          DİKKAT! Eğer Yahoo, Hotmail, Mynet gibi bir sunucudan mail adresi sahibiyseniz <b>junk</b>, <b>spam</b>, <b>bulk</b> gibi klasörleri mutlaka kontrol ediniz.
        </div>
      </LegacyLayout>
    );
  }

  if (step === 'confirm' && preview) {
    return (
      <LegacyLayout pageTitle="Üye Kayıt Girişi" showLeftColumn={false}>
        <div style={{ padding: 12 }}>
          <font style={{ color: 'red', fontSize: 14 }}><b>ONAYLIYOR MUSUNUZ?</b></font><br /><br />
          <b>{preview.isim} {preview.soyisim}</b>, girdiğin bilgileri onaylıyor musun?<br /><br />
          <b>Kullanıcı Adı : </b> {preview.kadi}<br />
          <b>E-Mail Adresi : </b> {preview.email}<br />
          <b>Mezuniyet Yılı : </b> {preview.mezuniyetyili}<br /><br />
          <input type="button" value="Hayır" onClick={() => setStep('form')} className="sub" />&nbsp;
          <input type="button" value="EVET" onClick={onConfirm} className="sub" />
          {error ? <div className="hatamsg1">{error}</div> : null}
        </div>
      </LegacyLayout>
    );
  }

  return (
    <LegacyLayout pageTitle="Üye Kayıt Girişi" showLeftColumn={false}>
      <form onSubmit={onPreview}>
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
                    <font className="inptxt" style={{ color: 'red', fontSize: 12, border: 0 }}>Bütün alanları eksiksiz doldurunuz.</font>
                    <hr color="#663300" size="1" />
                    <font className="inptxt" style={{ color: 'red', fontSize: 11, border: 0 }}>
                      Eğer daha önce kayıt yaptırdıysanız, lütfen tekrar kaydolmaya çalışmayınız.
                      Şifrenizi <a href="/sifre-hatirla">şifremi unuttum</a> linkiyle hatırlayabilirsiniz.
                    </font>
                  </caption>
                  <tbody>
                    <tr><td align="center" colSpan="2"><hr color="#663300" size="1" /></td></tr>
                    <tr>
                      <td align="right"><b>Kullanıcı Adı : </b></td>
                      <td align="left">
                        <input type="text" name="kadi" size="20" className="inptxt" value={form.kadi} onChange={(e) => updateField('kadi', e.target.value)} /> <font style={{ color: 'red' }}><sup>1</sup></font>
                      </td>
                    </tr>
                    <tr>
                      <td align="right"><b>Şifre : </b></td>
                      <td align="left">
                        <input type="password" name="sifre" size="20" className="inptxt" value={form.sifre} onChange={(e) => updateField('sifre', e.target.value)} />
                      </td>
                    </tr>
                    <tr>
                      <td align="right"><b>Şifre Tekrar : </b></td>
                      <td align="left">
                        <input type="password" name="sifre2" size="20" className="inptxt" value={form.sifre2} onChange={(e) => updateField('sifre2', e.target.value)} />
                      </td>
                    </tr>
                    <tr><td align="center" colSpan="2"><hr color="#663300" size="1" /></td></tr>
                    <tr>
                      <td align="right"><b>E-Mail : </b></td>
                      <td align="left">
                        <input type="text" name="email" size="20" className="inptxt" value={form.email} onChange={(e) => updateField('email', e.target.value)} /> <font style={{ color: 'red' }}><sup>2</sup></font>
                      </td>
                    </tr>
                    <tr>
                      <td align="right"><b><small>SDAL Mezuniyet Yılı : </small></b></td>
                      <td align="left">
                        <select name="mezuniyetyili" className="inptxt" value={form.mezuniyetyili} onChange={(e) => updateField('mezuniyetyili', e.target.value)}>
                          <option value="0">Seçiniz</option>
                          {years.map((y) => <option key={y} value={y}>{y}</option>)}
                        </select> <font style={{ color: 'red' }}><sup>3</sup></font>
                      </td>
                    </tr>
                    <tr><td align="center" colSpan="2"><hr color="#663300" size="1" /></td></tr>
                    <tr>
                      <td align="right"><b>İsim : </b></td>
                      <td align="left"><input type="text" name="isim" size="20" className="inptxt" value={form.isim} onChange={(e) => updateField('isim', e.target.value)} /></td>
                    </tr>
                    <tr>
                      <td align="right"><b>Soyisim : </b></td>
                      <td align="left"><input type="text" name="soyisim" size="20" className="inptxt" value={form.soyisim} onChange={(e) => updateField('soyisim', e.target.value)} /></td>
                    </tr>
                    <tr><td align="center" colSpan="2"><hr color="#663300" size="1" /></td></tr>
                    <tr>
                      <td align="right"></td>
                      <td align="left">
                        <img src={captchaSrc} alt="captcha" />
                        <input type="button" className="sub" value="Yenile" onClick={() => setCaptchaSrc(`/api/captcha?${Date.now()}`)} />
                      </td>
                    </tr>
                    <tr>
                      <td align="right"><b>Güvenlik Kodu : </b></td>
                      <td align="left"><input type="text" name="gkodu" size="20" className="inptxt" value={form.gkodu} onChange={(e) => updateField('gkodu', e.target.value)} /></td>
                    </tr>
                    <tr><td align="center" colSpan="2"><hr color="#663300" size="1" /></td></tr>
                    <tr>
                      <td align="right" colSpan="2"><input type="submit" className="sub" value="Kaydet" /></td>
                    </tr>
                    <tr><td align="center" colSpan="2"><hr color="#663300" size="1" /></td></tr>
                    <tr>
                      <td align="left" colSpan="2" style={{ color: 'red' }}>
                        <sup>1</sup> Kullanıcı adınız 15 karakterden fazla olmamalıdır.
                        <hr color="#663300" size="1" />
                        <sup>2</sup> Sitemize kayıt olmak için e-mail adresinizi doğru girmeniz gerekmektedir.
                        <hr color="#663300" size="1" />
                        <sup>3</sup> Lütfen mezuniyet yılınızı doğru giriniz. Kaydınızdan sonra değiştirilemez.
                      </td>
                    </tr>
                  </tbody>
                </table>
                {error ? <div className="hatamsg1">{error}</div> : null}
                {status ? <div>{status}</div> : null}
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
    </LegacyLayout>
  );
}
