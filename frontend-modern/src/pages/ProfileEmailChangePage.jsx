import React, { useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function ProfileEmailChangePage() {
  const { t } = useI18n();
  const [email, setEmail] = useState('');
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit() {
    setBusy(true);
    setStatus('');
    setError('');
    try {
      const res = await fetch('/api/profile/email-change/request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ email })
      });
      if (!res.ok) throw new Error(await res.text());
      setStatus(t('profile_email_change_sent'));
      setEmail('');
    } catch (err) {
      setError(err?.message || t('profile_email_change_failed'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Layout title={t('profile_email_change_title')}>
      <div className="panel">
        <div className="panel-body">
          <p className="muted">{t('profile_email_change_hint')}</p>
          <div className="form-row">
            <label>{t('profile_email_new_label')}</label>
            <input className="input" type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="ornek@mail.com" />
          </div>
          <button className="btn primary" onClick={submit} disabled={busy}>{busy ? t('sending') : t('profile_email_change_send')}</button>
          <a className="btn ghost" href="/new/profile">{t('back')}</a>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
