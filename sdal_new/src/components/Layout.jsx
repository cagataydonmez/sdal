import React, { useCallback, useMemo, useState } from 'react';
import { Link, NavLink } from 'react-router-dom';
import { useAuth } from '../utils/auth.jsx';
import { useLiveRefresh } from '../utils/live.js';
import { useTheme } from '../utils/theme.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function Layout({ children, title, right }) {
  const { user, logout, refresh } = useAuth();
  const { mode, theme, cycleMode } = useTheme();
  const { lang, setLang, t } = useI18n();
  const [menuOpen, setMenuOpen] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);

  const profileImage = useMemo(() => {
    if (!user) return '/legacy/vesikalik/nophoto.jpg';
    const version = user._avatarVersion || 0;
    return user.photo ? `/api/media/vesikalik/${user.photo}?v=${version}` : '/legacy/vesikalik/nophoto.jpg';
  }, [user]);

  const loadUnreadCount = useCallback(async () => {
    if (!user) {
      setUnreadCount(0);
      return;
    }
    try {
      const res = await fetch('/api/new/messages/unread', { credentials: 'include' });
      if (!res.ok) return;
      const payload = await res.json();
      setUnreadCount(payload.count || 0);
    } catch {
      // ignore
    }
  }, [user]);

  useLiveRefresh(loadUnreadCount, { intervalMs: 7000, eventTypes: ['message:created', '*'], enabled: !!user });
  useLiveRefresh(refresh, { intervalMs: 20000, eventTypes: ['profile:updated'], enabled: !!user });

  async function handleLogout() {
    await logout();
    window.location.href = '/new/login';
  }

  return (
    <div className="app-shell">
      <aside className="side-nav">
        <div className="brand">
          <div className="brand-mark">SDAL</div>
          <div className="brand-sub">Yeni</div>
        </div>
        <nav>
          <NavLink to="/new" end>{t('nav_feed')}</NavLink>
          <NavLink to="/new/explore">{t('nav_explore')}</NavLink>
          <NavLink to="/new/following">{t('nav_following')}</NavLink>
          <NavLink to="/new/groups">{t('nav_groups')}</NavLink>
          <NavLink to="/new/messages">{t('nav_messages')}</NavLink>
          <NavLink to="/new/notifications">{t('nav_notifications')}</NavLink>
          <NavLink to="/new/albums">{t('nav_photos')}</NavLink>
          <NavLink to="/new/games">{t('nav_games')}</NavLink>
          <NavLink to="/new/events">{t('nav_events')}</NavLink>
          <NavLink to="/new/announcements">{t('nav_announcements')}</NavLink>
          <NavLink to="/new/profile">{t('nav_profile')}</NavLink>
          <NavLink to="/new/help">{t('nav_help')}</NavLink>
          {user?.admin === 1 ? <NavLink to="/new/admin">{t('nav_admin')}</NavLink> : null}
        </nav>
        <div className="side-footer">
          <a href="/" className="ghost">Klasik Görünüm</a>
          {user ? <button className="linkish" onClick={handleLogout}>Çıkış</button> : (
            <>
              <a href="/new/login">Giriş</a>
              <a href="/new/register">Üye Ol</a>
            </>
          )}
        </div>
      </aside>

      <main className="main-area">
	        <header className="top-bar">
          <div className="page-title">
            <h1>{title}</h1>
            <p>SDAL sosyal hub</p>
          </div>
	          <div className="top-actions">
            <select className="input language-select" value={lang} onChange={(e) => setLang(e.target.value)} aria-label="Dil seçimi">
              <option value="tr">{t('lang_tr')}</option>
              <option value="en">{t('lang_en')}</option>
              <option value="de">{t('lang_de')}</option>
              <option value="fr">{t('lang_fr')}</option>
            </select>
            <button className="btn ghost theme-toggle" onClick={cycleMode} title="Tema modu: Otomatik -> Koyu -> Acik">
              {mode === 'auto' ? `Tema: Otomatik (${theme === 'dark' ? 'Koyu' : 'Acik'})` : `Tema: ${mode === 'dark' ? 'Koyu' : 'Acik'}`}
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
                    <Link to="/new/profile" onClick={() => setMenuOpen(false)}>Profili Gör</Link>
                    <Link to="/new/profile/photo" onClick={() => setMenuOpen(false)}>Fotoğraf Güncelle</Link>
                    <Link to="/new/messages/compose" onClick={() => setMenuOpen(false)}>Mesaj Gönder</Link>
                    <button className="linkish" onClick={handleLogout}>Çıkış Yap</button>
                  </div>
                ) : null}
              </div>
            ) : (
              <Link className="btn" to="/new/login">Giriş</Link>
            )}
          </div>
        </header>

        <div className="content">
          {children}
        </div>
      </main>

      <nav className="bottom-nav">
        <NavLink to="/new" end>{t('nav_feed')}</NavLink>
        <NavLink to="/new/explore">{t('nav_explore')}</NavLink>
        <NavLink to="/new/following">{t('nav_following')}</NavLink>
        <NavLink to="/new/groups">{t('nav_groups')}</NavLink>
        <NavLink to="/new/messages">
          {t('nav_messages')} {unreadCount > 0 ? <span className="mini-badge">{unreadCount}</span> : null}
        </NavLink>
        <NavLink to="/new/notifications">{t('nav_notifications')}</NavLink>
        <NavLink to="/new/albums">{t('nav_photos')}</NavLink>
        <NavLink to="/new/games">{t('nav_games')}</NavLink>
        <NavLink to="/new/events">{t('nav_events')}</NavLink>
        <NavLink to="/new/announcements">{t('nav_announcements')}</NavLink>
        <NavLink to="/new/profile">{t('nav_profile')}</NavLink>
        <NavLink to="/new/help">{t('nav_help')}</NavLink>
        <select className="input language-select" value={lang} onChange={(e) => setLang(e.target.value)} aria-label="Dil seçimi">
          <option value="tr">{t('lang_tr')}</option>
          <option value="en">{t('lang_en')}</option>
          <option value="de">{t('lang_de')}</option>
          <option value="fr">{t('lang_fr')}</option>
        </select>
        <button className="linkish bottom-link" onClick={cycleMode}>
          {mode === 'auto' ? `Tema: Otomatik (${theme === 'dark' ? 'Koyu' : 'Acik'})` : `Tema: ${mode === 'dark' ? 'Koyu' : 'Acik'}`}
        </button>
        <a className="bottom-link" href="/">Klasik</a>
        {user?.admin === 1 ? <NavLink to="/new/admin">{t('nav_admin')}</NavLink> : null}
        {user ? <button className="linkish bottom-link" onClick={handleLogout}>Çıkış</button> : null}
      </nav>
    </div>
  );
}
