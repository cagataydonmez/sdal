import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';

async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    credentials: 'include',
    ...options
  });
  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Request failed: ${res.status}`);
  }
  return res.json();
}

export default function GroupsPage() {
  const [groups, setGroups] = useState([]);
  const [form, setForm] = useState({ name: '', description: '' });
  const [error, setError] = useState('');

  async function load() {
    const data = await apiJson('/api/new/groups');
    setGroups(data.items || []);
  }

  useEffect(() => {
    load();
  }, []);

  async function create() {
    setError('');
    try {
      await apiJson('/api/new/groups', { method: 'POST', body: JSON.stringify(form) });
      setForm({ name: '', description: '' });
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function toggleJoin(id) {
    await apiJson(`/api/new/groups/${id}/join`, { method: 'POST' });
    load();
  }

  return (
    <Layout title="Gruplar">
      <div className="panel">
        <h3>Yeni Grup</h3>
        <div className="panel-body">
          <input className="input" placeholder="Grup adı" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
          <textarea className="input" placeholder="Açıklama" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
          <button className="btn primary" onClick={create}>Oluştur</button>
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>

      <div className="card-grid">
        {groups.map((g) => (
          <div className="member-card" key={g.id}>
            {g.cover_image ? <img src={g.cover_image} alt="" /> : <div className="group-cover-empty">Kapak</div>}
            <div>
              <div className="name">{g.name}</div>
              <div className="meta">{g.description}</div>
              <div className="meta">{g.members} üye</div>
              <a className="btn ghost" href={`/new/groups/${g.id}`}>Aç</a>
            </div>
            <button className="btn" onClick={() => toggleJoin(g.id)}>{g.joined ? 'Ayrıl' : 'Katıl'}</button>
          </div>
        ))}
      </div>
    </Layout>
  );
}
