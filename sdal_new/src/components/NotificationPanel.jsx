import React, { useEffect, useState } from 'react';

export default function NotificationPanel() {
  const [items, setItems] = useState([]);

  async function load() {
    const res = await fetch('/api/new/notifications', { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    setItems(payload.items || []);
  }

  useEffect(() => {
    load();
  }, []);

  return (
    <div className="panel">
      <h3>Bildirimler</h3>
      <div className="panel-body">
        {items.length === 0 ? <div className="muted">Bildirim yok.</div> : null}
        {items.map((n) => (
          <div key={n.id} className="notif">
            <img className="avatar" src={n.resim ? `/api/media/vesikalik/${n.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
            <div>
              <b>@{n.kadi}</b> {n.message}
              <div className="meta">{new Date(n.created_at).toLocaleString()}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
