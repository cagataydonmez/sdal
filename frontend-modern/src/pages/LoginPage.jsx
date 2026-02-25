import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function LoginPage() {
  const { t } = useI18n();
  const [kadi, setKadi] = useState('');
  const [sifre, setSifre] = useState('');
  const [error, setError] = useState('');
  const [oauthProviders, setOauthProviders] = useState([]);
  const { refresh } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get('oauth')) {
      setError(t('login_error_oauth_failed'));
    }
  }, [t]);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const res = await fetch('/api/auth/oauth/providers', { credentials: 'include' });
        if (!res.ok) return;
        const data = await res.json();
        if (!mounted) return;
        setOauthProviders(Array.isArray(data?.providers) ? data.providers : []);
      } catch {
        // no-op
      }
    })();
    return () => {
      mounted = false;
    };
  }, []);

  async function submit(e) {
    e.preventDefault();
    setError('');
    const res = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ kadi, sifre })
    });
    if (!res.ok) {
      const msg = await res.text();
      setError(msg || t('login_error_failed'));
      return;
    }
    await refresh();
    navigate('/new');
  }

  return (
    <Layout title={t('login_title')}>
      <div className="panel">
        <div className="panel-body">
          <form onSubmit={submit} className="stack">
            <input className="input" placeholder={t('auth_username')} value={kadi} onChange={(e) => setKadi(e.target.value)} />
            <input className="input" type="password" placeholder={t('auth_password')} value={sifre} onChange={(e) => setSifre(e.target.value)} />
            <button className="btn primary" type="submit">{t('login_submit')}</button>
            {error ? <div className="error">{error}</div> : null}
          </form>
          {oauthProviders.length ? (
            <div className="stack">
              <div className="muted">{t('login_social_divider')}</div>
              {oauthProviders.map((p) => (
                <a key={p.provider} className="btn ghost" href={p.startUrl}>
                  {p.provider === 'google' ? t('login_social_google') : t('login_social_x')}
                </a>
              ))}
            </div>
          ) : null}
          <div className="panel-body">
            <a className="btn ghost" href="/new/register">{t('register_submit')}</a>
            <a className="btn ghost" href="/new/password-reset">{t('login_forgot_password')}</a>
          </div>
        </div>
      </div>
    </Layout>
  );
}
