import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';

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
  const { t } = useI18n();
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
    refreshStories();
  }, [profile?.id]);

  async function save() {
    setError('');
    setStatus('');
    try {
      await apiJson('/api/profile', { method: 'PUT', body: JSON.stringify(profile) });
      setStatus(t('profile_status_updated'));
    } catch (err) {
      setError(err.message);
    }
  }

  if (!profile) {
    return <Layout title={t('nav_profile')}><div className="muted">{t('loading')}</div></Layout>;
  }

  const activeStories = stories.filter((s) => !s.isExpired);
  const expiredStories = stories.filter((s) => s.isExpired);

  async function refreshStories() {
    try {
      const payload = await apiJson('/api/new/stories/mine');
      setStories(payload.items || []);
    } catch (err) {
      const msg = String(err?.message || '');
      if (msg.toLowerCase().includes('expected pattern')) {
        setError(t('stories_invalid_media_error'));
      } else {
        setError(msg || t('stories_load_failed'));
      }
    }
  }

  async function editStory(story) {
    const caption = window.prompt(t('story_prompt_edit_caption'), story.caption || '');
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
    if (!window.confirm(t('story_confirm_delete'))) return;
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
    <Layout title={t('nav_profile')}>
      <div className="panel">
        <div className="panel-body">
          <div className="form-row">
            <label>{t('profile_first_name')}</label>
            <input className="input" value={profile.isim || ''} onChange={(e) => setProfile({ ...profile, isim: e.target.value })} />
          </div>
          <div className="form-row">
            <label>{t('profile_last_name')}</label>
            <input className="input" value={profile.soyisim || ''} onChange={(e) => setProfile({ ...profile, soyisim: e.target.value })} />
          </div>
          <div className="form-row">
            <label>{t('auth_email')}</label>
            <input className="input" value={profile.email || ''} onChange={(e) => setProfile({ ...profile, email: e.target.value })} />
          </div>
          <div className="form-row">
            <label>{t('profile_city')}</label>
            <input className="input" value={profile.sehir || ''} onChange={(e) => setProfile({ ...profile, sehir: e.target.value })} />
          </div>
          <div className="form-row">
            <label>{t('profile_job')}</label>
            <input className="input" value={profile.meslek || ''} onChange={(e) => setProfile({ ...profile, meslek: e.target.value })} />
          </div>
          <div className="form-row">
            <label>{t('profile_graduation')}</label>
            <input className="input" value={profile.mezuniyetyili || ''} onChange={(e) => setProfile({ ...profile, mezuniyetyili: e.target.value })} />
          </div>
          <div className="form-row">
            <label>{t('profile_signature')}</label>
            <textarea className="input" value={profile.imza || ''} onChange={(e) => setProfile({ ...profile, imza: e.target.value })} />
          </div>
          <button className="btn primary" onClick={save}>{t('save')}</button>
          <a className="btn ghost" href="/new/profile/photo">{t('profile_photo_title')}</a>
          {profile?.id ? <a className="btn ghost" href={`/new/members/${profile.id}`}>{t('profile_preview_members')}</a> : null}
          <button className="btn ghost" onClick={async () => {
            setVerifyStatus('');
            const res = await fetch('/api/new/verified/request', { method: 'POST', credentials: 'include' });
            if (!res.ok) {
              setVerifyStatus(await res.text());
            } else {
              setVerifyStatus(t('profile_verify_request_received'));
            }
          }}>{t('profile_verify_request')}</button>
          {status ? <div className="ok">{status}</div> : null}
          {verifyStatus ? <div className="muted">{verifyStatus}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>

      <div className="panel">
        <h3>{t('my_stories')}</h3>
        <div className="panel-body">
          <div className="muted">{t('active_stories')}</div>
          <div className="story-profile-grid">
            {activeStories.map((s) => (
              <article key={s.id} className="story-mini-card">
                <img src={s.image} alt="" />
                <div className="meta">{new Date(s.createdAt).toLocaleString()}</div>
                <div className="story-mini-caption">{s.caption || t('no_description')}</div>
                <div className="story-mini-actions">
                  <button className="btn ghost" onClick={() => editStory(s)} disabled={!!storyBusy}>
                    {storyBusy === `edit:${s.id}` ? t('saving') : t('edit')}
                  </button>
                  <button className="btn ghost delete" onClick={() => deleteStory(s)} disabled={!!storyBusy}>
                    {storyBusy === `delete:${s.id}` ? t('deleting') : t('delete')}
                  </button>
                </div>
              </article>
            ))}
            {!activeStories.length ? <div className="muted">{t('active_stories_empty')}</div> : null}
          </div>

          <div className="muted">{t('expired_stories')}</div>
          <div className="story-profile-grid">
            {expiredStories.map((s) => (
              <article key={s.id} className="story-mini-card expired">
                <img src={s.image} alt="" />
                <div className="meta">{new Date(s.createdAt).toLocaleString()}</div>
                <div className="story-mini-caption">{s.caption || t('no_description')}</div>
                <div className="story-mini-actions">
                  <button className="btn ghost" onClick={() => repostStory(s)} disabled={!!storyBusy}>
                    {storyBusy === `repost:${s.id}` ? t('sharing') : t('story_repost')}
                  </button>
                  <button className="btn ghost" onClick={() => editStory(s)} disabled={!!storyBusy}>
                    {storyBusy === `edit:${s.id}` ? t('saving') : t('edit')}
                  </button>
                  <button className="btn ghost delete" onClick={() => deleteStory(s)} disabled={!!storyBusy}>
                    {storyBusy === `delete:${s.id}` ? t('deleting') : t('delete')}
                  </button>
                </div>
              </article>
            ))}
            {!expiredStories.length ? <div className="muted">{t('expired_stories_empty')}</div> : null}
          </div>
        </div>
      </div>
    </Layout>
  );
}
