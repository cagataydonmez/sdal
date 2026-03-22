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
      <section className="auth-entry-shell">
        <section className="auth-entry-story">
          <h2 className="auth-entry-title">{t('login_welcome_title')}</h2>
          <p className="auth-entry-copy">{t('login_welcome_subtitle')}</p>
          <div className="auth-entry-points" role="list">
            {[t('login_welcome_step_feed'), t('login_welcome_step_people'), t('login_welcome_step_groups')].map((item, index) => (
              <div className="auth-entry-point" key={item} role="listitem">
                <span className="auth-entry-point-index" aria-hidden="true">{String(index + 1).padStart(2, '0')}</span>
                <span>{item}</span>
              </div>
            ))}
          </div>
        </section>

        <div className="panel auth-entry-panel">
          <div className="panel-body auth-entry-panel-body">
            <div className="auth-form-head">
              <h3>{t('login_title')}</h3>
            </div>

            <form onSubmit={handleSubmit(onSubmit)} className="auth-form-stack">
              <label className="auth-field">
                <span>{t('auth_username')}</span>
                <input
                  className="input"
                  placeholder={t('auth_username')}
                  {...register('kadi')}
                />
              </label>
              {errors.kadi && <div className="error">{t(errors.kadi.message)}</div>}
              <label className="auth-field">
                <span>{t('auth_password')}</span>
                <input
                  className="input"
                  type="password"
                  placeholder={t('auth_password')}
                  {...register('sifre')}
                />
              </label>
              {errors.sifre && <div className="error">{t(errors.sifre.message)}</div>}
              <button className="btn primary auth-submit" type="submit" disabled={isSubmitting}>
                {t('login_submit')}
              </button>
              {errors.root && <div className="error">{errors.root.message}</div>}
            </form>

            {oauthProviders.length ? (
              <div className="auth-alt-stack">
                <div className="auth-alt-title">{t('login_oauth_title')}</div>
                <div className="auth-provider-list">
                  {oauthProviders.map((p) => (
                    <a key={p.provider} className="btn ghost" href={p.startUrl}>
                      {p.provider === 'google' ? t('login_social_google') : t('login_social_x')}
                    </a>
                  ))}
                </div>
              </div>
            ) : null}

            <div className="auth-entry-footer">
              <div className="auth-entry-links">
                <Link className="btn ghost" to="/new/register">{t('register_submit')}</Link>
                <Link className="btn ghost" to="/new/password-reset">{t('login_forgot_password')}</Link>
              </div>
            </div>
          </div>
        </div>
      </section>
    </Layout>
  );
}
