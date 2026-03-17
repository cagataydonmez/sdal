import React, { useEffect, useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Link, useNavigate } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';
import { useI18n } from '../utils/i18n.jsx';
import { api } from '../utils/apiClient.js';

const LoginSchema = z.object({
  kadi: z.string().min(1, 'auth_username_required').max(15),
  sifre: z.string().min(1, 'auth_password_required').max(20),
});

export default function LoginPage() {
  const { t } = useI18n();
  const fallbackProviders = [
    { provider: 'google', title: 'Google', enabled: true, startUrl: '/api/auth/oauth/google/start?returnTo=/new/login' },
    { provider: 'x', title: 'X', enabled: true, startUrl: '/api/auth/oauth/x/start?returnTo=/new/login' }
  ];
  const [oauthProviders, setOauthProviders] = useState(fallbackProviders);
  const { refresh } = useAuth();
  const navigate = useNavigate();

  const {
    register,
    handleSubmit,
    setError,
    formState: { errors, isSubmitting },
  } = useForm({ resolver: zodResolver(LoginSchema) });

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    if (params.get('oauth')) {
      setError('root', { message: t('login_error_oauth_failed') });
    }
  }, [t, setError]);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const data = await api.get('/api/auth/oauth/providers');
        if (!mounted) return;
        const remote = Array.isArray(data?.providers) ? data.providers : [];
        if (!remote.length) return;
        const mapped = remote
          .map((item) => ({
            provider: String(item?.provider || ''),
            title: String(item?.title || ''),
            enabled: item?.enabled !== false,
            startUrl: String(item?.startUrl || `/api/auth/oauth/${item?.provider}/start?returnTo=/new/login`),
          }))
          .filter((item) => item.provider);
        if (mounted) setOauthProviders(mapped.length ? mapped : fallbackProviders);
      } catch {
        if (mounted) setOauthProviders(fallbackProviders);
      }
    })();
    return () => { mounted = false; };
  }, []);

  async function onSubmit({ kadi, sifre }) {
    try {
      await api.post('/api/auth/login', { kadi, sifre });
      await refresh();
      navigate('/new');
    } catch (err) {
      setError('root', { message: err.message || t('login_error_failed') });
    }
  }

  return (
    <Layout title={t('login_title')}>
      <div className="panel">
        <div className="panel-body">
          <form onSubmit={handleSubmit(onSubmit)} className="stack">
            <input
              className="input"
              placeholder={t('auth_username')}
              {...register('kadi')}
            />
            {errors.kadi && <div className="error">{t(errors.kadi.message)}</div>}
            <input
              className="input"
              type="password"
              placeholder={t('auth_password')}
              {...register('sifre')}
            />
            {errors.sifre && <div className="error">{t(errors.sifre.message)}</div>}
            <button className="btn primary" type="submit" disabled={isSubmitting}>
              {t('login_submit')}
            </button>
            {errors.root && <div className="error">{errors.root.message}</div>}
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
            <Link className="btn ghost" to="/new/register">{t('register_submit')}</Link>
            <Link className="btn ghost" to="/new/password-reset">{t('login_forgot_password')}</Link>
          </div>
        </div>
      </div>
    </Layout>
  );
}
