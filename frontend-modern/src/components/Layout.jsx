import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link, NavLink, useLocation, useNavigate } from '../router.jsx';
import { useAuth } from '../utils/auth.jsx';
import { emitAppChange, useLiveRefresh } from '../utils/live.js';
import { useTheme } from '../utils/theme.jsx';
import { useI18n } from '../utils/i18n.jsx';
import { readApiPayload } from '../utils/api.js';
import { openNotification } from '../utils/notificationApi.js';
import { buildNotificationViewModel, shouldToastNotification } from '../utils/notificationRegistry.js';
import { fetchNotificationPreferences, NOTIFICATION_PREFERENCE_DEFAULTS } from '../utils/notificationPreferences.js';
import { getRouteTransitionMeta, syncViewTransitionContext } from '../viewTransitions.js';

export default function Layout({ children, title, right }) {
  const location = useLocation();
  const navigate = useNavigate();
  const { user, logout, refresh } = useAuth();
  const { mode, theme, cycleMode } = useTheme();
  const { t } = useI18n();
  const [menuOpen, setMenuOpen] = useState(false);
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);
  const [unreadNotifications, setUnreadNotifications] = useState(0);
  const [toasts, setToasts] = useState([]);
  const [mobileThemeLabel, setMobileThemeLabel] = useState(false);
  const [moduleAccess, setModuleAccess] = useState({});
  const [notificationPreferences, setNotificationPreferences] = useState(NOTIFICATION_PREFERENCE_DEFAULTS);
  const unreadNotificationsRef = useRef(0);
  const unreadHydratedRef = useRef(false);
  const toastTimersRef = useRef(new Map());
  const notificationToastIdsRef = useRef(new Set());

  const dismissToast = useCallback((toastId) => {
    setToasts((prev) => prev.filter((toast) => toast.id !== toastId));
    const timer = toastTimersRef.current.get(toastId);
    if (timer) window.clearTimeout(timer);
    toastTimersRef.current.delete(toastId);
  }, []);

  const pushToast = useCallback((toast) => {
    if (!toast?.id) return;
    setToasts((prev) => {
      if (prev.some((item) => item.id === toast.id)) return prev;
      return [...prev, toast].slice(-4);
    });
    const timer = window.setTimeout(() => dismissToast(toast.id), toast.durationMs || 6000);
    toastTimersRef.current.set(toast.id, timer);
  }, [dismissToast]);

  const handleToastOpen = useCallback(async (toast) => {
    if (!toast?.href) return;
    if (Number(toast.notificationId || 0) > 0) {
      try {
        await openNotification(toast.notificationId, {
          surface: 'layout_toast',
          notificationType: toast.notificationType || ''
        });
      } catch {
        // ignore notification open failures on toast navigation
      }
    }
    dismissToast(toast.id);
    navigate(toast.href);
  }, [dismissToast, navigate]);

  const profileImage = useMemo(() => {
    if (!user) return '/legacy/vesikalik/nophoto.jpg';
    const version = user._avatarVersion || 0;
    return user.photo ? `/api/media/vesikalik/${user.photo}?v=${version}` : '/legacy/vesikalik/nophoto.jpg';
  }, [user]);

  const loadUnreadCount = useCallback(async () => {
    if (!user) {
      setUnreadCount(0);
      setUnreadNotifications(0);
      unreadNotificationsRef.current = 0;
      unreadHydratedRef.current = false;
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
        const nextUnreadNotifications = Number(payload.count || 0);
        const previousUnreadNotifications = Number(unreadNotificationsRef.current || 0);
        setUnreadNotifications(nextUnreadNotifications);
        unreadNotificationsRef.current = nextUnreadNotifications;
        if (unreadHydratedRef.current && nextUnreadNotifications > previousUnreadNotifications) {
          emitAppChange('notification:new', {
            count: nextUnreadNotifications,
            delta: nextUnreadNotifications - previousUnreadNotifications,
            source: 'layout_poll'
          });
        }
        unreadHydratedRef.current = true;
      }
    } catch {
      // ignore
    }
  }, [user]);

  useLiveRefresh(loadUnreadCount, {
    intervalMs: 12000,
    eventTypes: ['message:created', 'notification:new', 'notification:read', 'notification:opened', 'notification:action'],
    enabled: !!user
  });
  useLiveRefresh(refresh, { intervalMs: 20000, eventTypes: ['profile:updated'], enabled: !!user });

  useEffect(() => {
    if (!user) return;
    loadUnreadCount();
  }, [user, loadUnreadCount]);

  useEffect(() => {
    let cancelled = false;
    if (!user) {
      setNotificationPreferences(NOTIFICATION_PREFERENCE_DEFAULTS);
      return undefined;
    }
    void (async () => {
      const result = await fetchNotificationPreferences();
      if (!cancelled && result.ok) {
        setNotificationPreferences(result.preferences);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [user]);

  useEffect(() => {
    function onAppChange(event) {
      const detail = event?.detail || {};
      const eventType = detail.eventType || detail.type;
      if (eventType === 'toast' && detail.message) {
        pushToast({
          id: `toast-${detail.at || Date.now()}`,
          tone: detail.tone === 'error' ? 'error' : 'info',
          title: detail.title || '',
          message: detail.message,
          durationMs: detail.tone === 'error' ? 7000 : 5000
        });
        return;
      }
      if (eventType === 'notification:preferences-updated' && detail.preferences) {
        setNotificationPreferences(detail.preferences);
        return;
      }
      if (eventType !== 'notification:new' || !user || location.pathname === '/new/notifications') return;
      void (async () => {
        try {
          const res = await fetch('/api/new/notifications?limit=5&sort=priority', { credentials: 'include', cache: 'no-store' });
          if (!res.ok) return;
          const { data } = await readApiPayload(res, '');
          const items = Array.isArray(data?.items) ? data.items.map(buildNotificationViewModel) : [];
          const candidate = items.find((item) => (
            shouldToastNotification(item, { preferences: notificationPreferences })
            && !notificationToastIdsRef.current.has(Number(item.id || 0))
          ));
          if (!candidate) return;
          notificationToastIdsRef.current.add(Number(candidate.id || 0));
          pushToast({
            id: `notification-${candidate.id}`,
            tone: candidate.isActionable ? 'accent' : 'info',
            title: candidate.category === 'events' ? 'Etkinlik bildirimi' : candidate.category === 'jobs' ? 'İlan bildirimi' : candidate.category === 'groups' ? 'Grup bildirimi' : 'Bildirim',
            message: `@${candidate.kadi || 'uye'} ${candidate.message || ''}`.trim(),
            href: candidate.href || '/new/notifications',
            notificationId: Number(candidate.id || 0),
            notificationType: candidate.type || '',
            durationMs: candidate.isActionable ? 9000 : 6500
          });
        } catch {
          // ignore toast fetch failures
        }
      })();
    }

    window.addEventListener('sdal:app-change', onAppChange);
    return () => window.removeEventListener('sdal:app-change', onAppChange);
  }, [location.pathname, notificationPreferences, pushToast, user]);

  useEffect(() => () => {
    for (const timer of toastTimersRef.current.values()) window.clearTimeout(timer);
    toastTimersRef.current.clear();
  }, []);

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
    ? (mode === 'auto' ? 'Otomatik' : (mode === 'dark' ? t('theme_dark') : t('theme_light')))
    : (mode === 'auto'
      ? t('theme_auto_with_current', { current: theme === 'dark' ? t('theme_dark') : t('theme_light') })
      : t('theme_current', { mode: mode === 'dark' ? t('theme_dark') : t('theme_light') }));
  const roleValue = String(user?.role || '').toLowerCase();
  const isAdminUser = Number(user?.admin || 0) === 1 || roleValue === 'admin' || roleValue === 'root';
  const routeMeta = useMemo(() => getRouteTransitionMeta(location.pathname), [location.pathname]);

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
      { to: '/new/opportunities', label: t('nav_opportunities'), module: 'explore' },
      { to: '/new/network/teachers', label: t('nav_teacher_network'), module: 'teachers_network' },
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

  useEffect(() => {
    syncViewTransitionContext(location.pathname);
  }, [location.pathname]);

  return (
    <div className="app-shell" data-route-family={routeMeta.family} data-route-kind={routeMeta.kind}>
      <aside className="side-nav">
        <Link to="/new" className="brand" aria-label="SDAL home">
          <span className="brand-text">SDAL</span>
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
              <Link to="/new/login">{t('login_title')}</Link>
              <Link to="/new/register">{t('register_submit')}</Link>
            </>
          )}
        </div>
      </aside>

	      <main className={`main-area route-family-${routeMeta.family} route-kind-${routeMeta.kind}`}>
        <header className="top-bar">
          <button
            className={`mobile-hamburger mobile-hamburger-left ${mobileNavOpen ? 'open' : ''}`}
            aria-label={mobileNavOpen ? t('close') : t('open')}
            aria-expanded={mobileNavOpen}
            onClick={() => setMobileNavOpen((prev) => !prev)}
          >
            <span></span>
            <span></span>
            <span></span>
          </button>
          <div className="page-title route-title-shell" data-route-family={routeMeta.family} data-route-kind={routeMeta.kind}>
            <h1>{title}</h1>
            <p>{t('layout_subtitle')}</p>
          </div>
	          <div className="top-actions">
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

        <div className="content route-content-shell" data-route-family={routeMeta.family} data-route-kind={routeMeta.kind}>
          {children}
        </div>
      </main>

      <div className={`mobile-nav-overlay ${mobileNavOpen ? 'open' : ''}`} onClick={() => setMobileNavOpen(false)} />
      {toasts.length > 0 ? (
        <div className="app-toast-stack" aria-live="polite">
          {toasts.map((toast) => (
            <div key={toast.id} className={`app-toast app-toast-${toast.tone || 'info'}`}>
              <div className="app-toast-copy">
                {toast.title ? <strong>{toast.title}</strong> : null}
                <span>{toast.message}</span>
              </div>
              <div className="app-toast-actions">
                {toast.href ? (
                  <button className="btn ghost" onClick={() => handleToastOpen(toast)}>Aç</button>
                ) : null}
                <button className="btn ghost" onClick={() => dismissToast(toast.id)}>Kapat</button>
              </div>
            </div>
          ))}
        </div>
      ) : null}
      <aside className={`mobile-nav-drawer ${mobileNavOpen ? 'open' : ''}`} aria-hidden={!mobileNavOpen}>
        <div className="mobile-nav-head">
          <Link to="/new" className="brand" aria-label="SDAL home" onClick={() => setMobileNavOpen(false)}>
            <span className="brand-text">SDAL</span>
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
          <button className="btn ghost" onClick={cycleMode}>{themeLabel}</button>
          <a className="btn ghost" href="/">{t('layout_classic_short')}</a>
          {user ? <button className="btn" onClick={handleLogout}>{t('logout')}</button> : null}
        </div>
      </aside>
    </div>
  );
}
