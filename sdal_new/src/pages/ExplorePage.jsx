import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';

export default function ExplorePage() {
  const [members, setMembers] = useState([]);
  const [query, setQuery] = useState('');

  async function load() {
    const res = await fetch(`/api/members?page=1&pageSize=50&term=${encodeURIComponent(query)}`, { credentials: 'include' });
    const payload = await res.json();
    setMembers(payload.rows || []);
  }

  useEffect(() => {
    load();
  }, []);

  async function follow(id) {
    await fetch(`/api/new/follow/${id}`, { method: 'POST', credentials: 'include' });
  }

  return (
    <Layout title="Keşfet">
      <div className="panel">
        <div className="panel-body">
          <input
            className="search"
            placeholder="Üye ara..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <button className="btn" onClick={load}>Ara</button>
        </div>
      </div>
      <div className="card-grid">
        {members.map((m) => (
          <div className="member-card" key={m.id}>
            <a href={`/new/members/${m.id}`}>
              <img src={m.resim ? `/api/media/vesikalik/${m.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
            </a>
            <div>
              <div className="name">
                {m.isim} {m.soyisim}
                {m.verified ? <span className="badge">✓</span> : null}
              </div>
              <div className="handle">@{m.kadi}</div>
              <div className="meta">{m.mezuniyetyili || ''}</div>
            </div>
            <button className="btn ghost" onClick={() => follow(m.id)}>Takip</button>
          </div>
        ))}
      </div>
    </Layout>
  );
}
