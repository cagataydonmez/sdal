import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, NavLink, useLocation } from 'react-router-dom';
import { useAuth } from '../utils/auth.jsx';
import { useLiveRefresh } from '../utils/live.js';
import { useTheme } from '../utils/theme.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function Layout({ children, title, right }) {
  const location = useLocation();
  const { user, logout, refresh } = useAuth();
  const { mode, theme, cycleMode } = useTheme();
  const { lang, setLang, t } = useI18n();
  const [menuOpen, setMenuOpen] = useState(false);
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [unreadNotifications, setUnreadNotifications] = useState(0);
  const [mobileThemeLabel, setMobileThemeLabel] = useState(false);
  const [moduleAccess, setModuleAccess] = useState({});

  const profileImage = useMemo(() => {
    if (!user) return '/legacy/vesikalik/nophoto.jpg';
    const version = user._avatarVersion || 0;
    return user.photo ? `/api/media/vesikalik/${user.photo}?v=${version}` : '/legacy/vesikalik/nophoto.jpg';
  }, [user]);

  const loadUnreadCount = useCallback(async () => {
    if (!user) {
      setUnreadCount(0);
      setUnreadNotifications(0);
      return;
    }
    try {
      const [messagesRes, notificationsRes] = await Promise.all([
        fetch('/api/new/messages/unread', { credentials: 'include' }),
        fetch('/api/new/notifications/unread', { credentials: 'include' })
      ]);
      if (messagesRes.ok) {
        const payload = await messagesRes.json();
        setUnreadCount(payload.count || 0);
      }
      if (notificationsRes.ok) {
        const payload = await notificationsRes.json();
        setUnreadNotifications(payload.count || 0);
      }
    } catch {
      // ignore
    }
  }, [user]);

  useLiveRefresh(loadUnreadCount, { intervalMs: 7000, eventTypes: ['message:created', 'notification:new', '*'], enabled: !!user });
  useLiveRefresh(refresh, { intervalMs: 20000, eventTypes: ['profile:updated'], enabled: !!user });

  useEffect(() => {
    if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return;
    const mq = window.matchMedia('(max-width: 760px)');
    const sync = () => setMobileThemeLabel(mq.matches);
    sync();
    if (typeof mq.addEventListener === 'function') {
      mq.addEventListener('change', sync);
      return () => mq.removeEventListener('change', sync);
    }
    mq.addListener(sync);
    return () => mq.removeListener(sync);
  }, []);

  useEffect(() => {
    let mounted = true;
    fetch(`/api/site-access?path=${encodeURIComponent(location.pathname)}`, { credentials: 'include' })
      .then((r) => r.ok ? r.json() : null)
      .then((payload) => {
        if (!mounted || !payload?.modules) return;
        setModuleAccess(payload.modules || {});
      })
      .catch(() => {});
    return () => { mounted = false; };
  }, [location.pathname]);

  const themeLabel = mobileThemeLabel
    ? (mode === 'auto' ? 'Auto' : (mode === 'dark' ? t('theme_dark') : t('theme_light')))
    : (mode === 'auto'
      ? t('theme_auto_with_current', { current: theme === 'dark' ? t('theme_dark') : t('theme_light') })
      : t('theme_current', { mode: mode === 'dark' ? t('theme_dark') : t('theme_light') }));
  const roleValue = String(user?.role || '').toLowerCase();
  const isAdminUser = Number(user?.admin || 0) === 1 || roleValue === 'admin' || roleValue === 'root';

  const navItems = useMemo(() => {
    const allItems = [
      { to: '/new', label: t('nav_feed'), end: true, module: 'feed' },
      { to: '/new/explore', label: t('nav_explore'), module: 'explore' },
      { to: '/new/following', label: t('nav_following'), module: 'following' },
      { to: '/new/groups', label: t('nav_groups'), module: 'groups' },
      { to: '/new/messages', label: t('nav_messages'), module: 'messages', badge: unreadCount },
      { to: '/new/messenger', label: t('nav_messenger'), module: 'messenger' },
      { to: '/new/notifications', label: t('nav_notifications'), module: 'notifications', badge: unreadNotifications },
      { to: '/new/albums', label: t('nav_photos'), module: 'albums' },
      { to: '/new/games', label: t('nav_games'), module: 'games' },
      { to: '/new/events', label: t('nav_events'), module: 'events' },
      { to: '/new/announcements', label: t('nav_announcements'), module: 'announcements' },
      { to: '/new/jobs', label: t('nav_jobs'), module: 'jobs' },
      { to: '/new/profile', label: t('nav_profile'), module: 'profile' },
      { to: '/new/help', label: t('nav_help'), module: 'help' }
    ];
    return allItems.filter((item) => moduleAccess[item.module] !== false);
  }, [t, unreadCount, unreadNotifications, moduleAccess]);

  async function handleLogout() {
    await logout();
    window.location.href = '/new/login';
  }

  useEffect(() => {
    setMenuOpen(false);
    setMobileNavOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    if (typeof document === 'undefined') return undefined;
    const previous = document.body.style.overflow;
    if (mobileNavOpen) document.body.style.overflow = 'hidden';
    else document.body.style.overflow = previous || '';
    return () => {
      document.body.style.overflow = previous;
    };
  }, [mobileNavOpen]);

  return (
    <div className="app-shell">
      <aside className="side-nav">
        <Link to="/new" className="brand" aria-label="SDAL home">
          <img
            className="brand-logo"
            src="/assets/logo.svg"
            alt="SDAL logo"
            width={160}
            height={40}
            loading="eager"
            decoding="async"
          />
          <span className="brand-sub">Yeni</span>
        </Link>
        <nav>
          {navItems.map((item) => (
            <NavLink key={item.to} to={item.to} end={item.end}>{item.label}{item.badge > 0 ? <span className="mini-badge">{item.badge}</span> : null}</NavLink>
          ))}
          {isAdminUser ? <NavLink to="/new/admin">{t('nav_admin')}</NavLink> : null}
        </nav>
        <div className="side-footer">
          <a href="/" className="ghost">{t('layout_classic_view')}</a>
          {user ? <button className="linkish" onClick={handleLogout}>{t('logout')}</button> : (
            <>
              <a href="/new/login">{t('login_title')}</a>
              <a href="/new/register">{t('register_submit')}</a>
            </>
          )}
        </div>
      </aside>

	      <main className="main-area">
	        <header className="top-bar">
          <div className="page-title">
            <h1>{title}</h1>
            <p>{t('layout_subtitle')}</p>
          </div>
	          <div className="top-actions">
            <button
              className={`mobile-hamburger ${mobileNavOpen ? 'open' : ''}`}
              aria-label={mobileNavOpen ? t('close') : t('open')}
              aria-expanded={mobileNavOpen}
              onClick={() => setMobileNavOpen((prev) => !prev)}
            >
              <span></span>
              <span></span>
              <span></span>
            </button>
            <select className="input language-select" value={lang} onChange={(e) => setLang(e.target.value)} aria-label={t('language_selector_aria')}>
              <option value="tr">{t('lang_tr')}</option>
              <option value="en">{t('lang_en')}</option>
              <option value="de">{t('lang_de')}</option>
              <option value="fr">{t('lang_fr')}</option>
            </select>
            <button className="btn ghost theme-toggle" onClick={cycleMode} title={t('theme_mode_title')}>
              {themeLabel}
            </button>
	            {right}
	            {user ? (
              <div className="user-menu">
                <button className="user-chip" onClick={() => setMenuOpen((v) => !v)}>
                  <img src={profileImage} alt="" />
                  <span>{user.kadi}</span>
                </button>
                {menuOpen ? (
                  <div className="user-dropdown">
                    <Link to="/new/profile" onClick={() => setMenuOpen(false)}>{t('profile_view')}</Link>
                    <Link to="/new/profile/photo" onClick={() => setMenuOpen(false)}>{t('profile_photo_update')}</Link>
                    {moduleAccess.requests !== false ? <Link to="/new/requests" onClick={() => setMenuOpen(false)}>{t('member_requests_title')}</Link> : null}
                    <Link to="/new/messages/compose" onClick={() => setMenuOpen(false)}>{t('member_send_message')}</Link>
                    <button className="linkish" onClick={handleLogout}>{t('logout')}</button>
                  </div>
                ) : null}
              </div>
            ) : (
              <Link className="btn" to="/new/login">{t('login_title')}</Link>
            )}
          </div>
        </header>

        <div className="content">
          {children}
        </div>
      </main>

      <div className={`mobile-nav-overlay ${mobileNavOpen ? 'open' : ''}`} onClick={() => setMobileNavOpen(false)} />
      <aside className={`mobile-nav-drawer ${mobileNavOpen ? 'open' : ''}`} aria-hidden={!mobileNavOpen}>
        <div className="mobile-nav-head">
          <Link to="/new" className="brand" aria-label="SDAL home" onClick={() => setMobileNavOpen(false)}>
            <img
              className="brand-logo"
              src="/assets/logo.svg"
              alt="SDAL logo"
              width={160}
              height={40}
              loading="eager"
              decoding="async"
            />
            <span className="brand-sub">Yeni</span>
          </Link>
          <button className="btn ghost" onClick={() => setMobileNavOpen(false)}>{t('close')}</button>
        </div>
        <nav className="mobile-nav-links">
          {navItems.map((item) => (
            <NavLink key={item.to} to={item.to} end={item.end}>{item.label}{item.badge > 0 ? <span className="mini-badge">{item.badge}</span> : null}</NavLink>
          ))}
          {isAdminUser ? <NavLink to="/new/admin">{t('nav_admin')}</NavLink> : null}
        </nav>
        <div className="mobile-nav-foot">
          <select className="input language-select" value={lang} onChange={(e) => setLang(e.target.value)} aria-label={t('language_selector_aria')}>
            <option value="tr">{t('lang_tr')}</option>
            <option value="en">{t('lang_en')}</option>
            <option value="de">{t('lang_de')}</option>
            <option value="fr">{t('lang_fr')}</option>
          </select>
          <button className="btn ghost" onClick={cycleMode}>{themeLabel}</button>
          <a className="btn ghost" href="/">{t('layout_classic_short')}</a>
          {user ? <button className="btn" onClick={handleLogout}>{t('logout')}</button> : null}
        </div>
      </aside>
    </div>
  );
}
