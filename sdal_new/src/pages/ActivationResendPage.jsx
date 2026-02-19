import React, { useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function ActivationResendPage() {
  const { t } = useI18n();
  const [form, setForm] = useState({ id: '', email: '' });
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  async function submit(e) {
    e.preventDefault();
    setStatus('');
    setError('');
    const res = await fetch('/api/activation/resend', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify(form)
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setStatus(t('activation_resend_status_sent'));
  }

  return (
    <Layout title={t('activation_resend_title')}>
      <div className="panel">
        <div className="panel-body">
          <form className="stack" onSubmit={submit}>
            <input className="input" placeholder={t('activation_resend_member_id')} value={form.id} onChange={(e) => setForm({ ...form, id: e.target.value })} />
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
