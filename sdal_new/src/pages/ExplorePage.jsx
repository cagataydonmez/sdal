import React, { useCallback, useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { emitAppChange } from '../utils/live.js';

export default function ExplorePage() {
  const [members, setMembers] = useState([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(false);

  const load = useCallback(async (term = '') => {
    setLoading(true);
    const res = await fetch(`/api/members?page=1&pageSize=50&term=${encodeURIComponent(term)}`, { credentials: 'include' });
    const payload = await res.json();
    setMembers(payload.rows || []);
    setLoading(false);
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => {
      load(query);
    }, 250);
    return () => clearTimeout(timer);
  }, [query, load]);

  async function follow(id) {
    await fetch(`/api/new/follow/${id}`, { method: 'POST', credentials: 'include' });
    emitAppChange('follow:changed', { userId: id });
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
          {loading ? <div className="muted">Aranıyor...</div> : null}
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
