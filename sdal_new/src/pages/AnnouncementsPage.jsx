import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';

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

export default function AnnouncementsPage() {
  const { user } = useAuth();
  const [items, setItems] = useState([]);
  const [form, setForm] = useState({ title: '', body: '' });
  const [error, setError] = useState('');

  async function load() {
    const data = await apiJson('/api/new/announcements');
    setItems(data.items || []);
  }

  useEffect(() => {
    load();
  }, []);

  async function create() {
    setError('');
    try {
      await apiJson('/api/new/announcements', { method: 'POST', body: JSON.stringify(form) });
      setForm({ title: '', body: '' });
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function remove(id) {
    await apiJson(`/api/new/announcements/${id}`, { method: 'DELETE' });
    load();
  }

  return (
    <Layout title="Duyurular">
      {user?.admin === 1 ? (
        <div className="panel">
          <h3>Yeni Duyuru</h3>
          <div className="panel-body">
            <input className="input" placeholder="Başlık" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
            <textarea className="input" placeholder="Duyuru metni" value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} />
            <button className="btn primary" onClick={create}>Yayınla</button>
            {error ? <div className="error">{error}</div> : null}
          </div>
        </div>
      ) : null}

      <div className="stack">
        {items.map((a) => (
          <div key={a.id} className="panel">
            <h3>{a.title}</h3>
            <div className="panel-body">
              <div className="body">{a.body}</div>
              <div className="meta">{a.created_at ? new Date(a.created_at).toLocaleString() : ''}</div>
              {user?.admin === 1 ? <button className="btn ghost" onClick={() => remove(a.id)}>Sil</button> : null}
            </div>
          </div>
        ))}
      </div>
    </Layout>
  );
}
