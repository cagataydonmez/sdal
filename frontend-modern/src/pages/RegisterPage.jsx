import React, { useMemo, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function RegisterPage() {
  const { t } = useI18n();
  const [form, setForm] = useState({
    kadi: '',
    sifre: '',
    sifre2: '',
    email: '',
    isim: '',
    soyisim: '',
    mezuniyetyili: '0',
    gkodu: '',
    kvkk_consent: false,
    directory_consent: false
  });
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const [captchaTs, setCaptchaTs] = useState(Date.now());

  const years = useMemo(() => {
    const list = [];
    const now = new Date().getFullYear();
    for (let y = now; y >= 1960; y -= 1) list.push(String(y));
    return list;
  }, []);

  async function submit(e) {
    e.preventDefault();
    setError('');
    setStatus('');
    if (!form.kvkk_consent) {
      setError('KVKK Aydınlatma Metni\'ni okumanız ve onaylamanız gerekmektedir.');
      return;
    }
    if (!form.directory_consent) {
      setError('Mezun Rehberi açık rıza onayı gerekmektedir.');
      return;
    }
    const res = await fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(form)
    });
    const text = await res.text();
    let payload = null;
    try {
      payload = text ? JSON.parse(text) : null;
    } catch {
      payload = null;
    }
    if (!res.ok) {
      setError(text || payload?.message || payload?.error || t('register_status_success_mail_failed'));
      setCaptchaTs(Date.now());
      return;
    }
    if (payload?.mailSent === false) {
      setStatus(t('register_status_success_mail_failed'));
      return;
    }
    setStatus(payload?.message || t('register_status_success'));
  }

  return (
    <Layout title={t('register_title')}>
      <div className="panel">
        <div className="panel-body">
          <form className="stack" onSubmit={submit}>
            <input className="input" placeholder={t('auth_username')} value={form.kadi} onChange={(e) => setForm({ ...form, kadi: e.target.value })} />
            <input className="input" type="password" placeholder={t('auth_password')} value={form.sifre} onChange={(e) => setForm({ ...form, sifre: e.target.value })} />
            <input className="input" type="password" placeholder={t('register_password_repeat')} value={form.sifre2} onChange={(e) => setForm({ ...form, sifre2: e.target.value })} />
            <input className="input" placeholder={t('auth_email')} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            <div className="form-row">
              <label>{t('register_graduation_year')}</label>
              <select className="input" value={form.mezuniyetyili} onChange={(e) => setForm({ ...form, mezuniyetyili: e.target.value })} required>
                <option value="0">Mezuniyet yılı seçiniz (Zorunlu)</option>
                {years.map((y) => <option key={y} value={y}>{y}</option>)}
              </select>
            </div>
            <input className="input" placeholder={t('profile_first_name')} value={form.isim} onChange={(e) => setForm({ ...form, isim: e.target.value })} />
            <input className="input" placeholder={t('profile_last_name')} value={form.soyisim} onChange={(e) => setForm({ ...form, soyisim: e.target.value })} />
            <div className="form-row">
              <label>{t('register_captcha_label')}</label>
              <img src={`/api/captcha?ts=${captchaTs}`} alt="captcha" style={{ width: 200, height: 40, borderRadius: 8 }} />
              <input className="input" placeholder={t('register_captcha_placeholder')} value={form.gkodu} onChange={(e) => setForm({ ...form, gkodu: e.target.value })} />
              <button className="btn ghost" type="button" onClick={() => setCaptchaTs(Date.now())}>{t('register_captcha_refresh')}</button>
            </div>

            <div className="form-row" style={{ display: 'flex', gap: '8px', alignItems: 'flex-start', marginTop: '16px' }}>
               <input type="checkbox" id="kvkk" checked={form.kvkk_consent} onChange={(e) => setForm({ ...form, kvkk_consent: e.target.checked })} style={{ marginTop: '4px' }} />
               <label htmlFor="kvkk" style={{ fontSize: '0.9em', lineHeight: '1.4', fontWeight: 'normal' }}>
                 Okudum ve anladım: <a href="/kvkk" target="_blank" rel="noreferrer" style={{ textDecoration: 'underline' }}>Kişisel Verilerin Korunması ve Aydınlatma Metni</a> (Zorunlu)
               </label>
            </div>

            <div className="form-row" style={{ display: 'flex', gap: '8px', alignItems: 'flex-start', marginBottom: '16px' }}>
               <input type="checkbox" id="directory_consent" checked={form.directory_consent} onChange={(e) => setForm({ ...form, directory_consent: e.target.checked })} style={{ marginTop: '4px' }} />
               <label htmlFor="directory_consent" style={{ fontSize: '0.9em', lineHeight: '1.4', fontWeight: 'normal' }}>
                 Mezuniyet yılı, okul ve ad-soyad bilgilerimin yalnızca SDAL mezunlarına özel <strong>Mezun Rehberi'nde (Alumni Directory)</strong> listelenmesine açık rıza veriyorum. (Zorunlu)
               </label>
            </div>

            <button className="btn primary" type="submit">{t('register_submit')}</button>
            {status ? <div className="ok">{status}</div> : null}
            {error ? <div className="error">{error}</div> : null}
          </form>
          <div className="muted">
            {t('register_activation_resend_prefix')} <a href="/new/activation/resend">{t('register_activation_resend_link')}</a> {t('register_activation_resend_suffix')}
          </div>
        </div>
      </div>
    </Layout>
  );
}
