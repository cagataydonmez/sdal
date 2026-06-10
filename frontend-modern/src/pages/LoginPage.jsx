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

function safeLoginReturnTo() {
  const params = new URLSearchParams(window.location.search);
  const raw = String(params.get('returnTo') || '').trim();
  if (!raw || !raw.startsWith('/') || raw.startsWith('//')) return '/new';
  if (/[\r\n]/.test(raw)) return '/new';
  if (raw.startsWith('/api/gamehub/authorize?')) return raw;
  if (raw.startsWith('/new/') || raw === '/new') return raw;
  return '/new';
}

function currentLoginPathWithReturnTo() {
  const target = safeLoginReturnTo();
  if (target === '/new') return '/new/login';
  return `/new/login?returnTo=${encodeURIComponent(target)}`;
}

function navigateAfterLogin(navigate) {
  const target = safeLoginReturnTo();
  if (target.startsWith('/api/gamehub/authorize?')) {
    window.location.assign(target);
    return;
  }
  navigate(target);
}

export default function LoginPage() {
  const { t } = useI18n();
  const welcomePoints = [
    t('login_welcome_step_feed'),
    t('login_welcome_step_people'),
    t('login_welcome_step_groups')
  ];
  const oauthReturnTo = currentLoginPathWithReturnTo();
  const fallbackProviders = [
    { provider: 'google', title: 'Google', enabled: true, startUrl: `/api/auth/oauth/google/start?returnTo=${encodeURIComponent(oauthReturnTo)}` },
    { provider: 'x', title: 'X', enabled: true, startUrl: `/api/auth/oauth/x/start?returnTo=${encodeURIComponent(oauthReturnTo)}` }
  ];
  const [oauthProviders, setOauthProviders] = useState(fallbackProviders);
  const { refresh, user } = useAuth();
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
            startUrl: `/api/auth/oauth/${item?.provider}/start?returnTo=${encodeURIComponent(oauthReturnTo)}`,
          }))
          .filter((item) => item.provider);
        if (mounted) setOauthProviders(mapped.length ? mapped : fallbackProviders);
      } catch {
        if (mounted) setOauthProviders(fallbackProviders);
      }
    })();
    return () => { mounted = false; };
  }, [oauthReturnTo]);

  useEffect(() => {
    if (user && safeLoginReturnTo() !== '/new') {
      navigateAfterLogin(navigate);
    }
  }, [navigate, user]);

  async function onSubmit({ kadi, sifre }) {
    try {
      await api.post('/api/auth/login', { kadi, sifre });
      await refresh();
      navigateAfterLogin(navigate);
    } catch (err) {
      setError('root', { message: err.message || t('login_error_failed') });
    }
  }

  return (
    <Layout title={t('login_title')}>
      <section className="auth-entry-shell">
        <section className="auth-entry-story">
          <span className="auth-entry-kicker">SDAL</span>
          <h2 className="auth-entry-title">{t('login_welcome_title')}</h2>
          <p className="auth-entry-copy">{t('login_welcome_subtitle')}</p>
          <div className="auth-entry-points" role="list">
            {welcomePoints.map((item, index) => (
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
              <p className="auth-form-copy">{t('login_welcome_subtitle')}</p>
            </div>

            <form onSubmit={handleSubmit(onSubmit)} className="auth-form-stack">
              <label className="auth-field">
                <span>{t('auth_username')}</span>
                <input
                  className="input"
                  type="text"
                  autoFocus
                  autoComplete="username"
                  autoCapitalize="none"
                  autoCorrect="off"
                  spellCheck="false"
                  enterKeyHint="next"
                  aria-invalid={errors.kadi ? 'true' : 'false'}
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
                  autoComplete="current-password"
                  enterKeyHint="go"
                  aria-invalid={errors.sifre ? 'true' : 'false'}
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
              <div className="auth-entry-links auth-entry-links-minimal">
                <Link className="btn ghost" style={{ flex: 1, justifyContent: 'center' }} to="/new/register">{t('register_submit')}</Link>
                <Link className="btn ghost" style={{ flex: 1, justifyContent: 'center' }} to="/new/activation/code">Aktivasyon Kodu Gir</Link>
              </div>
              <div className="auth-entry-links auth-entry-links-minimal">
                <Link className="linkish" to="/new/password-reset">{t('login_forgot_password')}</Link>
              </div>
            </div>
          </div>
        </div>
      </section>
    </Layout>
  );
}
