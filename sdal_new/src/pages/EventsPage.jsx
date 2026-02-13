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

export default function EventsPage() {
  const { user } = useAuth();
  const [events, setEvents] = useState([]);
  const [form, setForm] = useState({ title: '', description: '', location: '', starts_at: '', ends_at: '' });
  const [error, setError] = useState('');

  async function load() {
    const data = await apiJson('/api/new/events');
    setEvents(data.items || []);
  }

  useEffect(() => {
    load();
  }, []);

  async function create() {
    setError('');
    try {
      await apiJson('/api/new/events', { method: 'POST', body: JSON.stringify(form) });
      setForm({ title: '', description: '', location: '', starts_at: '', ends_at: '' });
      load();
    } catch (err) {
      setError(err.message);
    }
  }

  async function remove(id) {
    await apiJson(`/api/new/events/${id}`, { method: 'DELETE' });
    load();
  }

  return (
    <Layout title="Etkinlikler">
      {user?.admin === 1 ? (
        <div className="panel">
          <h3>Yeni Etkinlik</h3>
          <div className="panel-body">
            <input className="input" placeholder="Başlık" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
            <input className="input" placeholder="Konum" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} />
            <textarea className="input" placeholder="Açıklama" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
            <input className="input" placeholder="Başlangıç (YYYY-MM-DD HH:MM)" value={form.starts_at} onChange={(e) => setForm({ ...form, starts_at: e.target.value })} />
            <input className="input" placeholder="Bitiş (YYYY-MM-DD HH:MM)" value={form.ends_at} onChange={(e) => setForm({ ...form, ends_at: e.target.value })} />
            <button className="btn primary" onClick={create}>Ekle</button>
            {error ? <div className="error">{error}</div> : null}
          </div>
        </div>
      ) : null}

      <div className="list">
        {events.map((e) => (
          <div key={e.id} className="list-item">
            <div>
              <div className="name">{e.title}</div>
              <div className="meta">{e.location} · {e.starts_at}</div>
              <div className="body">{e.description}</div>
            </div>
            {user?.admin === 1 ? (
              <button className="btn ghost" onClick={() => remove(e.id)}>Sil</button>
            ) : null}
          </div>
        ))}
      </div>
    </Layout>
  );
}
