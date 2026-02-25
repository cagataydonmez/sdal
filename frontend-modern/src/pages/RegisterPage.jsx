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
    mezuniyetyili: ''
  });
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

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
    const res = await fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(form)
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setStatus(t('register_status_success'));
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
              <select className="input" value={form.mezuniyetyili} onChange={(e) => setForm({ ...form, mezuniyetyili: e.target.value })}>
                <option value="">{t('select')}</option>
                {years.map((y) => <option key={y} value={y}>{y}</option>)}
              </select>
            </div>
            <input className="input" placeholder={t('profile_first_name')} value={form.isim} onChange={(e) => setForm({ ...form, isim: e.target.value })} />
            <input className="input" placeholder={t('profile_last_name')} value={form.soyisim} onChange={(e) => setForm({ ...form, soyisim: e.target.value })} />
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
