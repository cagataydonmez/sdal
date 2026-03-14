import React, { useEffect, useMemo, useState } from 'react';
import { Link } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { useI18n } from '../utils/i18n.jsx';
import { useAuth } from '../utils/auth.jsx';

async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    credentials: 'include',
    ...options
  });
  if (!res.ok) {
    const body = await res.text();
    let parsed = null;
    try {
      parsed = body ? JSON.parse(body) : null;
    } catch {
      parsed = null;
    }
    if (parsed?.requestUrl) {
      throw new Error(JSON.stringify(parsed));
    }
    const message = parsed?.message || parsed?.error || body;
    throw new Error(message || `Request failed: ${res.status}`);
  }
  return res.json();
}

export default function ProfilePage() {
  const { t } = useI18n();
  const { user, refresh } = useAuth();
  const [profile, setProfile] = useState(null);
  const [stories, setStories] = useState([]);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const [storyBusy, setStoryBusy] = useState('');
  const graduationYears = useMemo(() => {
    const years = [];
    const now = new Date().getFullYear();
    for (let y = now; y >= 1999; y -= 1) years.push(String(y));
    return years;
  }, []);

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
    const cohortValue = String(profile.mezuniyetyili || '').trim().toLowerCase();
    const gradYear = parseInt(cohortValue, 10);
    const isTeacher = cohortValue === 'teacher';
    if ((!Number.isFinite(gradYear) || gradYear < 1999) && !isTeacher) {
      setError(t('profile_error_graduation_required'));
      return;
    }
    if (String(user?.oauth_provider || '').trim()) {
      if (!profile.kvkk_consent) {
        setError('Sosyal üyelik için KVKK Aydınlatma Metni onayı zorunludur.');
        return;
      }
      if (!profile.directory_consent) {
        setError('Sosyal üyelik için Mezun Rehberi açık rıza onayı zorunludur.');
        return;
      }
    }
    try {
      await apiJson('/api/profile', { method: 'PUT', body: JSON.stringify(profile) });
      await refresh();
      setStatus(t('profile_status_updated'));
    } catch (err) {
      const msg = String(err?.message || '');
      if (msg.startsWith('{')) {
        try {
          const parsed = JSON.parse(msg);
          if (parsed?.requestUrl) setStatus(`${parsed.message} (${parsed.requestUrl})`);
          setError(parsed?.message || msg);
          return;
        } catch {
          // fallthrough
        }
      }
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
          {String(user?.state || '').toLowerCase() === 'incomplete' ? <div className="muted">{t('profile_completion_required')}</div> : null}
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
            <input className="input" value={profile.email || ''} disabled />
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
            <label>{t('profile_company')}</label>
            <input className="input" value={profile.sirket || ''} onChange={(e) => setProfile({ ...profile, sirket: e.target.value })} />
          </div>
          <div className="form-row">
            <label>{t('profile_title')}</label>
            <input className="input" value={profile.unvan || ''} onChange={(e) => setProfile({ ...profile, unvan: e.target.value })} />
          </div>
          <div className="form-row">
            <label>{t('profile_expertise')}</label>
            <input className="input" value={profile.uzmanlik || ''} onChange={(e) => setProfile({ ...profile, uzmanlik: e.target.value })} />
          </div>
          <div className="form-row">
            <label>{t('profile_linkedin')}</label>
            <input className="input" value={profile.linkedin_url || ''} onChange={(e) => setProfile({ ...profile, linkedin_url: e.target.value })} placeholder="https://linkedin.com/in/..." />
          </div>
          <div className="form-row">
            <label>{t('profile_university_department')}</label>
            <input className="input" value={profile.universite_bolum || ''} onChange={(e) => setProfile({ ...profile, universite_bolum: e.target.value })} />
          </div>
          <div className="form-row">
            <label>{t('profile_mentor_topics')}</label>
            <textarea className="input" value={profile.mentor_konulari || ''} onChange={(e) => setProfile({ ...profile, mentor_konulari: e.target.value })} />
          </div>
          <label className="chip" style={{ marginBottom: 12 }}>
            <input type="checkbox" checked={Boolean(profile.mentor_opt_in)} onChange={(e) => setProfile({ ...profile, mentor_opt_in: e.target.checked })} />
            {t('profile_mentor_opt_in')}
          </label>
          <div className="form-row">
            <label>{t('profile_graduation')}</label>
            <select className="input" value={String(profile.mezuniyetyili || '0')} onChange={(e) => setProfile({ ...profile, mezuniyetyili: e.target.value })} disabled={Number(user?.verified || 0) === 1}>
              <option value="0">Mezuniyet yılı / grup seçiniz</option>
              <option value="teacher">Öğretmen (SDAL)</option>
              {graduationYears.map((year) => <option key={year} value={year}>{year}</option>)}
            </select>
          </div>
          <div className="form-row">
            <label>{t('profile_signature')}</label>
            <textarea className="input" value={profile.imza || ''} onChange={(e) => setProfile({ ...profile, imza: e.target.value })} />
          </div>
          {String(user?.oauth_provider || '').trim() ? (
            <>
              <label className="chip" style={{ marginBottom: 12, display: 'block' }}>
                <input type="checkbox" checked={Boolean(profile.kvkk_consent)} onChange={(e) => setProfile({ ...profile, kvkk_consent: e.target.checked })} />
                <span>
                  KVKK Aydınlatma Metni'ni okudum ve onaylıyorum (<a href="/kvkk" target="_blank" rel="noreferrer">metni görüntüle</a>).
                </span>
              </label>
              <label className="chip" style={{ marginBottom: 12, display: 'block' }}>
                <input type="checkbox" checked={Boolean(profile.directory_consent)} onChange={(e) => setProfile({ ...profile, directory_consent: e.target.checked })} />
                <span>
                  Mezun Rehberi açık rıza metnini okudum ve onaylıyorum (<a href="/kvkk/acik-riza" target="_blank" rel="noreferrer">metni görüntüle</a>).
                </span>
              </label>
            </>
          ) : null}
          <button className="btn primary" onClick={save}>{t('save')}</button>
          <Link className="btn ghost" to="/new/profile/email-change">{t('profile_email_change_cta')}</Link>
          {Number(user?.verified || 0) === 1 ? <Link className="btn ghost" to="/new/requests?category=graduation_year_change">{t('profile_graduation_change_request_cta')}</Link> : null}
          <Link className="btn ghost" to="/new/profile/photo">{t('profile_photo_title')}</Link>
          {profile?.id ? <Link className="btn ghost" to={`/new/members/${profile.id}`}>{t('profile_preview_members')}</Link> : null}
          {String(profile?.mezuniyetyili || '').toLowerCase() === 'teacher' ? <Link className="btn ghost" to="/new/network/teachers">Öğretmen Ağı Yönetimi</Link> : null}
          {Number(user?.verified || 0) !== 1 ? <Link className="btn ghost" to="/new/profile/verification">{t('profile_verification_page_cta')}</Link> : null}
          {status ? <div className="ok">{status}</div> : null}
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
