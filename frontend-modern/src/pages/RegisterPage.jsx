import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Link } from '../router.jsx';
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
  const [busy, setBusy] = useState(false);
  const [uniqueErrors, setUniqueErrors] = useState({ kadi: '', email: '' });
  const [checking, setChecking] = useState({ kadi: false, email: false });
  const [captchaTs, setCaptchaTs] = useState(Date.now());
  const latestCheckId = useRef({ kadi: 0, email: 0 });

  const years = useMemo(() => {
    const list = [];
    const now = new Date().getFullYear();
    for (let y = now; y >= 1999; y -= 1) list.push(String(y));
    return list;
  }, []);

  const passwordHint = useMemo(() => {
    const pass = String(form.sifre || '');
    if (!pass) return t('register_password_strength_none');
    let score = 0;
    if (pass.length >= 8) score += 1;
    if (/[A-ZÇĞİÖŞÜ]/.test(pass) && /[a-zçğıöşü]/.test(pass)) score += 1;
    if (/\d/.test(pass)) score += 1;
    if (/[^A-Za-z0-9çğıöşüÇĞİÖŞÜ]/.test(pass)) score += 1;
    if (score >= 4) return t('register_password_strength_strong');
    if (score >= 2) return t('register_password_strength_medium');
    return t('register_password_strength_weak');
  }, [form.sifre]);

  const passwordMatchError = useMemo(() => {
    if (!form.sifre2) return '';
    return form.sifre === form.sifre2 ? '' : t('register_password_mismatch');
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
    setChecking((prev) => ({ ...prev, [fieldName]: true }));
    try {
      const res = await fetch('/api/register/check', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({
          kadi: fieldName === 'kadi' ? value : '',
          email: fieldName === 'email' ? value : ''
        })
      });
      if (!res.ok) return;
      const data = await res.json();
      if (latestCheckId.current[fieldName] !== checkId) return;
      if (fieldName === 'kadi' && data.kadiExists) {
        setUniqueErrors((prev) => ({ ...prev, kadi: t('register_error_username_exists') }));
      } else if (fieldName === 'email' && data.emailExists) {
        setUniqueErrors((prev) => ({ ...prev, email: t('register_error_email_exists') }));
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

  async function submit(e) {
    e.preventDefault();
    if (busy) return;
    setError('');
    setStatus('');
    if (form.mezuniyetyili === '0') {
      setError(t('register_error_graduation_required'));
      return;
    }
    if (checking.kadi || checking.email) {
      setError(t('register_error_checks_pending'));
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
    if (!form.kvkk_consent) {
      setError(t('register_error_kvkk_required'));
      return;
    }
    if (!form.directory_consent) {
      setError(t('register_error_directory_required'));
      return;
    }
    setBusy(true);
    try {
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
    } catch {
      setError(t('register_status_success_mail_failed'));
      setCaptchaTs(Date.now());
    } finally {
      setBusy(false);
    }
  }

  return (
    <Layout title={t('register_title')}>
      <div className="panel">
        <div className="panel-body">
          <form className="stack" onSubmit={submit}>
            <input className="input" required autoFocus autoComplete="username" autoCapitalize="none" autoCorrect="off" spellCheck="false" maxLength={15} aria-invalid={uniqueErrors.kadi ? 'true' : 'false'} placeholder={t('auth_username')} value={form.kadi} onChange={(e) => setForm({ ...form, kadi: e.target.value })} />
            {checking.kadi ? <div className="muted">{t('register_checking')}</div> : null}
            {uniqueErrors.kadi ? <div className="error" role="alert">{uniqueErrors.kadi}</div> : null}
            <input className="input" type="password" required autoComplete="new-password" maxLength={64} aria-invalid={passwordMatchError ? 'true' : 'false'} placeholder={t('auth_password')} value={form.sifre} onChange={(e) => setForm({ ...form, sifre: e.target.value })} />
            <div className="muted auth-field-note">{passwordHint}</div>
            <input className="input" type="password" required autoComplete="new-password" maxLength={64} aria-invalid={passwordMatchError ? 'true' : 'false'} placeholder={t('register_password_repeat')} value={form.sifre2} onChange={(e) => setForm({ ...form, sifre2: e.target.value })} />
            {passwordMatchError ? <div className="error" role="alert">{passwordMatchError}</div> : null}
            <input className="input" type="email" required autoComplete="email" inputMode="email" maxLength={120} aria-invalid={uniqueErrors.email ? 'true' : 'false'} placeholder={t('auth_email')} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            {checking.email ? <div className="muted">{t('register_checking')}</div> : null}
            {uniqueErrors.email ? <div className="error" role="alert">{uniqueErrors.email}</div> : null}
            <div className="form-row">
              <label>{t('register_graduation_year')}</label>
              <select className="input" value={form.mezuniyetyili} onChange={(e) => setForm({ ...form, mezuniyetyili: e.target.value })} required>
                <option value="0">{t('register_graduation_placeholder')}</option>
                <option value="teacher">{t('register_option_teacher')}</option>
                {years.map((y) => <option key={y} value={y}>{y}</option>)}
              </select>
            </div>
            <input className="input" required autoComplete="given-name" maxLength={80} placeholder={t('profile_first_name')} value={form.isim} onChange={(e) => setForm({ ...form, isim: e.target.value })} />
            <input className="input" required autoComplete="family-name" maxLength={80} placeholder={t('profile_last_name')} value={form.soyisim} onChange={(e) => setForm({ ...form, soyisim: e.target.value })} />
            <div className="form-row">
              <label>{t('register_captcha_label')}</label>
              <img src={`/api/captcha?ts=${captchaTs}`} alt={t('register_captcha_label')} style={{ width: 200, height: 40, borderRadius: 8 }} />
              <input
                className="input"
                required
                autoComplete="one-time-code"
                inputMode="numeric"
                pattern="[0-9]*"
                maxLength={8}
                placeholder={t('register_captcha_placeholder')}
                value={form.gkodu}
                onChange={(e) => setForm({ ...form, gkodu: e.target.value.replace(/\D/g, '') })}
              />
              <button className="btn ghost" type="button" onClick={() => setCaptchaTs(Date.now())}>{t('register_captcha_refresh')}</button>
            </div>

            <div className="auth-consent-row" style={{ marginTop: '16px' }}>
               <input className="auth-consent-checkbox" type="checkbox" id="kvkk" checked={form.kvkk_consent} onChange={(e) => setForm({ ...form, kvkk_consent: e.target.checked })} />
               <label className="auth-consent-label" htmlFor="kvkk">
                 Okudum ve anladım: <a href="/kvkk" target="_blank" rel="noreferrer" style={{ textDecoration: 'underline' }}>Kişisel Verilerin Korunması ve Aydınlatma Metni</a> (Zorunlu)
               </label>
            </div>

            <div className="auth-consent-row" style={{ marginBottom: '16px' }}>
               <input className="auth-consent-checkbox" type="checkbox" id="directory_consent" checked={form.directory_consent} onChange={(e) => setForm({ ...form, directory_consent: e.target.checked })} />
               <label className="auth-consent-label" htmlFor="directory_consent">
                 Mezuniyet yılı, okul ve ad-soyad bilgilerimin yalnızca SDAL mezunlarına özel <strong>Mezun Rehberi'nde (Alumni Directory)</strong> listelenmesine açık rıza veriyorum. <a href="/kvkk/acik-riza" target="_blank" rel="noreferrer" style={{ textDecoration: 'underline' }}>Açık rıza metnini</a> okudum. (Zorunlu)
               </label>
            </div>

            <button className="btn primary" type="submit" disabled={busy || checking.kadi || checking.email || Boolean(passwordMatchError)}>{busy ? t('loading') : t('register_submit')}</button>
            {status ? <div className="ok">{status}</div> : null}
            {error ? <div className="error prominent-alert" role="alert">{error}</div> : null}
          </form>
          <div className="muted">
            {t('register_activation_resend_prefix')} <Link to="/new/activation/resend">{t('register_activation_resend_link')}</Link> {t('register_activation_resend_suffix')}
          </div>
        </div>
      </div>
    </Layout>
  );
}
