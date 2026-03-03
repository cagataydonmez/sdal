import React, { useEffect, useMemo, useRef, useState } from 'react';
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
    gkodu: '',
    kvkk_consent: false,
    directory_consent: false
  });
  const [step, setStep] = useState('form');
  const [preview, setPreview] = useState(null);
  const [error, setError] = useState('');
  const [uniqueErrors, setUniqueErrors] = useState({ kadi: '', email: '' });
  const [status, setStatus] = useState('');
  const [checking, setChecking] = useState({ kadi: false, email: false });
  const [captchaSrc, setCaptchaSrc] = useState(`/api/captcha?${Date.now()}`);
  const latestCheckId = useRef({ kadi: 0, email: 0 });

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

  const passwordHint = useMemo(() => {
    const pass = String(form.sifre || '');
    if (!pass) return 'Şifre gücü: -';
    let score = 0;
    if (pass.length >= 8) score += 1;
    if (/[A-ZÇĞİÖŞÜ]/.test(pass) && /[a-zçğıöşü]/.test(pass)) score += 1;
    if (/\d/.test(pass)) score += 1;
    if (/[^A-Za-z0-9çğıöşüÇĞİÖŞÜ]/.test(pass)) score += 1;
    if (score >= 4) return 'Şifre gücü: Güçlü';
    if (score >= 2) return 'Şifre gücü: Orta';
    return 'Şifre gücü: Zayıf';
  }, [form.sifre]);

  const passwordMatchError = useMemo(() => {
    if (!form.sifre2) return '';
    return form.sifre === form.sifre2 ? '' : 'Şifre tekrar alanı şifreyle aynı olmalıdır.';
  }, [form.sifre, form.sifre2]);

  async function checkUnique(fieldName, rawValue) {
    const value = String(rawValue || '').trim();
    if (!value) {
      setUniqueErrors((prev) => ({ ...prev, [fieldName]: '' }));
      setChecking((prev) => ({ ...prev, [fieldName]: false }));
      return;
    }
    const checkId = latestCheckId.current[fieldName] + 1;
    latestCheckId.current[fieldName] = checkId;
    const payload = {
      kadi: fieldName === 'kadi' ? value : '',
      email: fieldName === 'email' ? value : ''
    };
    setChecking((prev) => ({ ...prev, [fieldName]: true }));
    try {
      const res = await fetch('/api/register/check', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify(payload)
      });
      if (!res.ok) return;
      const data = await res.json();
      if (latestCheckId.current[fieldName] !== checkId) return;
      if (fieldName === 'kadi' && data.kadiExists) {
        setUniqueErrors((prev) => ({ ...prev, kadi: 'Girdiğiniz kullanıcı adı zaten kayıtlıdır.' }));
      } else if (fieldName === 'email' && data.emailExists) {
        setUniqueErrors((prev) => ({ ...prev, email: 'Girdiğiniz e-mail adresi zaten kayıtlıdır.' }));
      } else {
        setUniqueErrors((prev) => ({ ...prev, [fieldName]: '' }));
      }
    } finally {
      if (latestCheckId.current[fieldName] === checkId) {
        setChecking((prev) => ({ ...prev, [fieldName]: false }));
      }
    }
  }

  useEffect(() => {
    const handle = setTimeout(() => {
      checkUnique('kadi', form.kadi);
    }, 450);
    return () => clearTimeout(handle);
  }, [form.kadi]);

  useEffect(() => {
    const handle = setTimeout(() => {
      checkUnique('email', form.email);
    }, 450);
    return () => clearTimeout(handle);
  }, [form.email]);

  async function onPreview(e) {
    e.preventDefault();
    setError('');
    setUniqueErrors({ kadi: '', email: '' });
    setStatus('');
    if (!form.kadi || !form.sifre || !form.sifre2 || !form.email || !form.isim || !form.soyisim || !form.gkodu) {
      setError('Lütfen zorunlu alanların tamamını doldurunuz.');
      return;
    }
    if (checking.kadi || checking.email) {
      setError('Kullanıcı adı ve e-mail kontrollerinin tamamlanmasını bekleyiniz.');
      return;
    }
    if (uniqueErrors.kadi || uniqueErrors.email) {
      setError(uniqueErrors.kadi || uniqueErrors.email);
      return;
    }
    if (passwordMatchError) {
      setError(passwordMatchError);
      return;
    }
    if (form.mezuniyetyili === '0') {
      setError('Bir mezuniyet yılı seçmeniz gerekmektedir.');
      return;
    }
    if (!form.kvkk_consent) {
      setError('KVKK Aydınlatma Metni\'ni okumanız ve onaylamanız gerekmektedir.');
      return;
    }
    if (!form.directory_consent) {
      setError('Mezun Rehberi açık rıza onayı gerekmektedir.');
      return;
    }
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
    setUniqueErrors({ kadi: '', email: '' });
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
          {error ? <div className="sdal-alert sdal-alert-error" role="alert">{error}</div> : null}
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
                        <input type="text" name="kadi" size="20" className="inptxt" required value={form.kadi} onChange={(e) => updateField('kadi', e.target.value)} /> <font style={{ color: 'red' }}><sup>1</sup></font>
                        {checking.kadi ? <div style={{ fontSize: 10 }}>Kontrol ediliyor...</div> : null}
                        {uniqueErrors.kadi ? <div style={{ fontSize: 10, color: 'red' }}>{uniqueErrors.kadi}</div> : null}
                      </td>
                    </tr>
                    <tr>
                      <td align="right"><b>Şifre : </b></td>
                      <td align="left">
                        <input type="password" name="sifre" size="20" className="inptxt" required value={form.sifre} onChange={(e) => updateField('sifre', e.target.value)} />
                        <div style={{ fontSize: 10, color: '#444' }}>{passwordHint}</div>
                      </td>
                    </tr>
                    <tr>
                      <td align="right"><b>Şifre Tekrar : </b></td>
                      <td align="left">
                        <input type="password" name="sifre2" size="20" className="inptxt" required value={form.sifre2} onChange={(e) => updateField('sifre2', e.target.value)} />
                        {passwordMatchError ? <div style={{ fontSize: 10, color: 'red' }}>{passwordMatchError}</div> : null}
                      </td>
                    </tr>
                    <tr><td align="center" colSpan="2"><hr color="#663300" size="1" /></td></tr>
                    <tr>
                      <td align="right"><b>E-Mail : </b></td>
                      <td align="left">
                        <input type="email" name="email" size="20" className="inptxt" required value={form.email} onChange={(e) => updateField('email', e.target.value)} /> <font style={{ color: 'red' }}><sup>2</sup></font>
                        {checking.email ? <div style={{ fontSize: 10 }}>Kontrol ediliyor...</div> : null}
                        {uniqueErrors.email ? <div style={{ fontSize: 10, color: 'red' }}>{uniqueErrors.email}</div> : null}
                      </td>
                    </tr>
                    <tr>
                      <td align="right"><b><small>SDAL Mezuniyet Yılı : </small></b></td>
                      <td align="left">
                        <select name="mezuniyetyili" className="inptxt" required value={form.mezuniyetyili} onChange={(e) => updateField('mezuniyetyili', e.target.value)}>
                          <option value="0">Seçiniz</option>
                          {years.map((y) => <option key={y} value={y}>{y}</option>)}
                        </select> <font style={{ color: 'red' }}><sup>3</sup></font>
                      </td>
                    </tr>
                    <tr><td align="center" colSpan="2"><hr color="#663300" size="1" /></td></tr>
                    <tr>
                      <td align="right"><b>İsim : </b></td>
                      <td align="left"><input type="text" name="isim" size="20" className="inptxt" required value={form.isim} onChange={(e) => updateField('isim', e.target.value)} /></td>
                    </tr>
                    <tr>
                      <td align="right"><b>Soyisim : </b></td>
                      <td align="left"><input type="text" name="soyisim" size="20" className="inptxt" required value={form.soyisim} onChange={(e) => updateField('soyisim', e.target.value)} /></td>
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
                      <td align="left"><input type="text" name="gkodu" size="20" className="inptxt" required inputMode="numeric" pattern="[0-9]*" maxLength={8} value={form.gkodu} onChange={(e) => updateField('gkodu', e.target.value.replace(/\D/g, ''))} /></td>
                    </tr>
                    <tr><td align="center" colSpan="2"><hr color="#663300" size="1" /></td></tr>
                    <tr>
                      <td align="left" colSpan="2" style={{ fontSize: 10 }}>
                        <input type="checkbox" id="kvkk_legacy" checked={form.kvkk_consent} onChange={(e) => updateField('kvkk_consent', e.target.checked)} />
                        <label htmlFor="kvkk_legacy"> <a href="/kvkk" target="_blank" rel="noreferrer">KVKK Aydınlatma Metni</a>ni okudum, anladım. (Zorunlu)</label>
                      </td>
                    </tr>
                    <tr>
                      <td align="left" colSpan="2" style={{ fontSize: 10 }}>
                        <input type="checkbox" id="dir_legacy" checked={form.directory_consent} onChange={(e) => updateField('directory_consent', e.target.checked)} />
                        <label htmlFor="dir_legacy"> Mezun Rehberi&apos;nde listelenmesine açık rıza veriyorum. <a href="/kvkk/acik-riza" target="_blank" rel="noreferrer">Açık rıza metnini</a> okudum. (Zorunlu)</label>
                      </td>
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
                {error ? <div className="sdal-alert sdal-alert-error" role="alert">{error}</div> : null}
                {status ? <div className="sdal-alert sdal-alert-success" role="status">{status}</div> : null}
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
