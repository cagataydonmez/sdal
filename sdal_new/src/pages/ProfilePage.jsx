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

export default function ProfilePage() {
  const [profile, setProfile] = useState(null);
  const [stories, setStories] = useState([]);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const [verifyStatus, setVerifyStatus] = useState('');
  const [storyBusy, setStoryBusy] = useState('');

  useEffect(() => {
    apiJson('/api/profile').then((p) => setProfile(p.user || null)).catch(() => {});
  }, []);

  useEffect(() => {
    if (!profile?.id) return;
    refreshStories(profile.id);
  }, [profile?.id]);

  async function save() {
    setError('');
    setStatus('');
    try {
      await apiJson('/api/profile', { method: 'PUT', body: JSON.stringify(profile) });
      setStatus('Profil güncellendi.');
    } catch (err) {
      setError(err.message);
    }
  }

  if (!profile) {
    return <Layout title="Profil"><div className="muted">Yükleniyor...</div></Layout>;
  }

  const activeStories = stories.filter((s) => !s.isExpired);
  const expiredStories = stories.filter((s) => s.isExpired);

  async function refreshStories(targetUserId = profile?.id) {
    if (!targetUserId) return;
    try {
      const payload = await apiJson(`/api/new/stories/user/${targetUserId}?includeExpired=1`);
      setStories(payload.items || []);
    } catch (err) {
      try {
        const fallback = await apiJson('/api/new/stories/mine');
        setStories(fallback.items || []);
      } catch (innerErr) {
        setError(innerErr.message || err.message || 'Hikayeler yüklenemedi.');
      }
    }
  }

  async function editStory(story) {
    const caption = window.prompt('Hikaye açıklamasını güncelle:', story.caption || '');
    if (caption === null) return;
    setStoryBusy(`edit:${story.id}`);
    try {
      try {
        await apiJson(`/api/new/stories/${story.id}/edit`, {
          method: 'POST',
          body: JSON.stringify({ caption })
        });
      } catch {
        try {
          await apiJson(`/api/new/stories/${story.id}`, {
            method: 'PATCH',
            body: JSON.stringify({ caption })
          });
        } catch {
          await apiJson(`/api/new/stories/${story.id}`, {
            method: 'POST',
            body: JSON.stringify({ caption })
          });
        }
      }
      await refreshStories();
    } catch (err) {
      setError(err.message);
    } finally {
      setStoryBusy('');
    }
  }

  async function deleteStory(story) {
    if (!window.confirm('Bu hikayeyi silmek istediğine emin misin?')) return;
    setStoryBusy(`delete:${story.id}`);
    try {
      try {
        await apiJson(`/api/new/stories/${story.id}/delete`, { method: 'POST' });
      } catch {
        try {
          await apiJson(`/api/new/stories/${story.id}`, { method: 'DELETE' });
        } catch {
          await apiJson(`/api/new/stories/${story.id}/remove`, { method: 'POST' });
        }
      }
      await refreshStories();
    } catch (err) {
      setError(err.message);
    } finally {
      setStoryBusy('');
    }
  }

  async function repostStory(story) {
    setStoryBusy(`repost:${story.id}`);
    try {
      await apiJson(`/api/new/stories/${story.id}/repost`, { method: 'POST' });
      await refreshStories();
    } catch (err) {
      setError(err.message);
    } finally {
      setStoryBusy('');
    }
  }

  return (
    <Layout title="Profil">
      <div className="panel">
        <div className="panel-body">
          <div className="form-row">
            <label>İsim</label>
            <input className="input" value={profile.isim || ''} onChange={(e) => setProfile({ ...profile, isim: e.target.value })} />
          </div>
          <div className="form-row">
            <label>Soyisim</label>
            <input className="input" value={profile.soyisim || ''} onChange={(e) => setProfile({ ...profile, soyisim: e.target.value })} />
          </div>
          <div className="form-row">
            <label>Email</label>
            <input className="input" value={profile.email || ''} onChange={(e) => setProfile({ ...profile, email: e.target.value })} />
          </div>
          <div className="form-row">
            <label>Şehir</label>
            <input className="input" value={profile.sehir || ''} onChange={(e) => setProfile({ ...profile, sehir: e.target.value })} />
          </div>
          <div className="form-row">
            <label>Meslek</label>
            <input className="input" value={profile.meslek || ''} onChange={(e) => setProfile({ ...profile, meslek: e.target.value })} />
          </div>
          <div className="form-row">
            <label>Mezuniyet</label>
            <input className="input" value={profile.mezuniyetyili || ''} onChange={(e) => setProfile({ ...profile, mezuniyetyili: e.target.value })} />
          </div>
          <div className="form-row">
            <label>İmza</label>
            <textarea className="input" value={profile.imza || ''} onChange={(e) => setProfile({ ...profile, imza: e.target.value })} />
          </div>
          <button className="btn primary" onClick={save}>Kaydet</button>
          <a className="btn ghost" href="/new/profile/photo">Fotoğraf Düzenle</a>
          <button className="btn ghost" onClick={async () => {
            setVerifyStatus('');
            const res = await fetch('/api/new/verified/request', { method: 'POST', credentials: 'include' });
            if (!res.ok) {
              setVerifyStatus(await res.text());
            } else {
              setVerifyStatus('Doğrulama talebiniz alındı.');
            }
          }}>Doğrulama Talebi</button>
          {status ? <div className="ok">{status}</div> : null}
          {verifyStatus ? <div className="muted">{verifyStatus}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>

      <div className="panel">
        <h3>Hikayelerim</h3>
        <div className="panel-body">
          <div className="muted">Aktif Hikayeler</div>
          <div className="story-profile-grid">
            {activeStories.map((s) => (
              <article key={s.id} className="story-mini-card">
                <img src={s.image} alt="" />
                <div className="meta">{new Date(s.createdAt).toLocaleString()}</div>
                <div className="story-mini-caption">{s.caption || 'Açıklama yok'}</div>
                <div className="story-mini-actions">
                  <button className="btn ghost" onClick={() => editStory(s)} disabled={!!storyBusy}>
                    {storyBusy === `edit:${s.id}` ? 'Kaydediliyor...' : 'Düzenle'}
                  </button>
                  <button className="btn ghost delete" onClick={() => deleteStory(s)} disabled={!!storyBusy}>
                    {storyBusy === `delete:${s.id}` ? 'Siliniyor...' : 'Sil'}
                  </button>
                </div>
              </article>
            ))}
            {!activeStories.length ? <div className="muted">Aktif hikayen yok.</div> : null}
          </div>

          <div className="muted">Süresi Dolan Hikayeler</div>
          <div className="story-profile-grid">
            {expiredStories.map((s) => (
              <article key={s.id} className="story-mini-card expired">
                <img src={s.image} alt="" />
                <div className="meta">{new Date(s.createdAt).toLocaleString()}</div>
                <div className="story-mini-caption">{s.caption || 'Açıklama yok'}</div>
                <div className="story-mini-actions">
                  <button className="btn ghost" onClick={() => repostStory(s)} disabled={!!storyBusy}>
                    {storyBusy === `repost:${s.id}` ? 'Paylaşılıyor...' : 'Yeniden Paylaş'}
                  </button>
                  <button className="btn ghost" onClick={() => editStory(s)} disabled={!!storyBusy}>
                    {storyBusy === `edit:${s.id}` ? 'Kaydediliyor...' : 'Düzenle'}
                  </button>
                  <button className="btn ghost delete" onClick={() => deleteStory(s)} disabled={!!storyBusy}>
                    {storyBusy === `delete:${s.id}` ? 'Siliniyor...' : 'Sil'}
                  </button>
                </div>
              </article>
            ))}
            {!expiredStories.length ? <div className="muted">Süresi dolan hikaye yok.</div> : null}
          </div>
        </div>
      </div>
    </Layout>
  );
}
