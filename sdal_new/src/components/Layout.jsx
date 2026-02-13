import React from 'react';
import { Link, NavLink } from 'react-router-dom';
import { useAuth } from '../utils/auth.jsx';

export default function Layout({ children, title, right }) {
  const { user } = useAuth();

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
          {user ? <a href="/logout">Çıkış</a> : <a href="/login">Giriş</a>}
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
              <div className="user-chip">
                <img src={user.photo ? `/api/media/vesikalik/${user.photo}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                <span>{user.kadi}</span>
              </div>
            ) : (
              <Link className="btn" to="/login">Giriş</Link>
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
        <NavLink to="/new/messages">Mesaj</NavLink>
        <NavLink to="/new/profile">Profil</NavLink>
      </nav>
    </div>
  );
}
