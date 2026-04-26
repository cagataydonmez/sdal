import React, { useState } from 'react';
import { Link } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function ActivationCodePage() {
  const { t } = useI18n();
  const [form, setForm] = useState({ kadi: '', sifre: '', akt: '' });
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  function updateField(name, value) {
    setForm((prev) => ({ ...prev, [name]: value }));
  }

  async function submit(e) {
    e.preventDefault();
    setStatus('');
    setError('');
    const res = await fetch('/api/activate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(form)
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    const data = await res.json();
    setStatus(t('activation_status_success', { username: data.kadi }));
  }

  return (
    <Layout title={t('activation_title')}>
      <div className="panel">
        <div className="panel-body">
          <form className="stack" onSubmit={submit}>
            <input className="input" required autoComplete="username" placeholder={t('auth_username')} value={form.kadi} onChange={(e) => updateField('kadi', e.target.value)} />
            <input className="input" type="password" required autoComplete="current-password" placeholder={t('auth_password')} value={form.sifre} onChange={(e) => updateField('sifre', e.target.value)} />
            <input className="input" required autoComplete="one-time-code" placeholder="Aktivasyon Kodu" value={form.akt} onChange={(e) => updateField('akt', e.target.value.trim())} />
            <button className="btn primary" type="submit">Aktivasyonu Tamamla</button>
          </form>
          {status ? <div className="ok" role="status">{status}<br /><Link to="/new/login">{t('login_submit')}</Link></div> : null}
          {error ? <div className="error prominent-alert" role="alert">{error}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
