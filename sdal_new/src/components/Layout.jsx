import React, { useCallback, useMemo, useState } from 'react';
import { Link, NavLink } from 'react-router-dom';
import { useAuth } from '../utils/auth.jsx';
import { useLiveRefresh } from '../utils/live.js';

export default function Layout({ children, title, right }) {
  const { user, logout, refresh } = useAuth();
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
          <NavLink to="/new" end>Akış</NavLink>
          <NavLink to="/new/explore">Keşfet</NavLink>
          <NavLink to="/new/groups">Gruplar</NavLink>
          <NavLink to="/new/messages">Mesajlar</NavLink>
          <NavLink to="/new/albums">Fotoğraflar</NavLink>
          <NavLink to="/new/events">Etkinlikler</NavLink>
          <NavLink to="/new/announcements">Duyurular</NavLink>
          <NavLink to="/new/profile">Profil</NavLink>
          <NavLink to="/new/admin">Yönetim</NavLink>
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
        <NavLink to="/new" end>Akış</NavLink>
        <NavLink to="/new/explore">Keşfet</NavLink>
        <NavLink to="/new/groups">Gruplar</NavLink>
        <NavLink to="/new/messages">
          Mesajlar {unreadCount > 0 ? <span className="mini-badge">{unreadCount}</span> : null}
        </NavLink>
        <NavLink to="/new/albums">Fotoğraflar</NavLink>
        <NavLink to="/new/events">Etkinlikler</NavLink>
        <NavLink to="/new/announcements">Duyurular</NavLink>
        <NavLink to="/new/profile">Profil</NavLink>
        <NavLink to="/new/admin">Yönetim</NavLink>
        {user ? <button className="linkish bottom-link" onClick={handleLogout}>Çıkış</button> : null}
      </nav>
    </div>
  );
}
