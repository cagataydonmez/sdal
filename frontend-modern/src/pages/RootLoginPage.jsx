import React, { useState } from 'react';
import { Link, useNavigate } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function RootLoginPage() {
  const { t } = useI18n();
  const { refresh } = useAuth();
  const navigate = useNavigate();
  const [password, setPassword] = useState('');
  const [status, setStatus] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setStatus('');
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ kadi: 'root', sifre: password })
      });
      if (!res.ok) {
        setStatus((await res.text()) || t('root_login_failed'));
        return;
      }
      await refresh();
      navigate('/new/admin');
    } catch {
      setStatus(t('root_login_failed'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Layout title={t('root_login_page_title')}>
      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('root_login_heading')}</h3>
          <div className="muted">{t('root_login_description')}</div>
          <form className="stack" onSubmit={submit}>
            <input
              className="input"
              type="password"
              value={password}
              placeholder="ROOT_BOOTSTRAP_PASSWORD"
              onChange={(e) => setPassword(e.target.value)}
            />
            <button className="btn primary" type="submit" disabled={busy}>{busy ? t('root_login_submitting') : t('root_login_submit')}</button>
            {status ? <div className="error">{status}</div> : null}
          </form>
          <Link className="btn ghost" to="/new/login">{t('root_login_back_link')}</Link>
        </div>
      </div>
    </Layout>
  );
}
