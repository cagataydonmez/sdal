import React, { useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function PasswordResetPage() {
  const { t } = useI18n();
  const [form, setForm] = useState({ kadi: '', email: '' });
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  async function submit(e) {
    e.preventDefault();
    setStatus('');
    setError('');
    const res = await fetch('/api/password-reset', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(form)
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setStatus(t('password_reset_status_sent'));
  }

  return (
    <Layout title={t('password_reset_title')}>
      <div className="panel">
        <div className="panel-body">
          <form className="stack" onSubmit={submit}>
            <input className="input" placeholder={t('auth_username')} value={form.kadi} onChange={(e) => setForm({ ...form, kadi: e.target.value })} />
            <input className="input" placeholder={t('auth_email')} value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
            <button className="btn primary" type="submit">{t('send')}</button>
          </form>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
