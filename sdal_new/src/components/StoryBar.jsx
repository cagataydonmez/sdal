import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { emitAppChange, useLiveRefresh } from '../utils/live.js';
import { useAuth } from '../utils/auth.jsx';

export default function StoryBar() {
  const { user } = useAuth();
  const [stories, setStories] = useState([]);
  const [activeIndex, setActiveIndex] = useState(null);
  const [progress, setProgress] = useState(0);
  const [busyAction, setBusyAction] = useState('');
  const durationMs = 5000;

  const load = useCallback(async () => {
    const res = await fetch('/api/new/stories', { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    setStories(payload.items || []);
  }, []);

  async function markViewed(story) {
    if (!story?.id) return;
    await fetch(`/api/new/stories/${story.id}/view`, { method: 'POST', credentials: 'include' });
  }

  async function openStory(story, index) {
    setActiveIndex(index);
    setProgress(0);
    await markViewed(story);
  }

  useEffect(() => {
    load();
  }, [load]);
  useLiveRefresh(load, { intervalMs: 12000, eventTypes: ['story:created', '*'] });

  useEffect(() => {
    if (activeIndex === null) return;
    if (!stories[activeIndex]) {
      setActiveIndex(null);
      return;
    }
    let start = Date.now();
    setProgress(0);
    const timer = setInterval(() => {
      const ratio = Math.min((Date.now() - start) / durationMs, 1);
      setProgress(ratio);
      if (ratio >= 1) {
        clearInterval(timer);
        const nextIndex = activeIndex + 1;
        if (nextIndex < stories.length) {
          setActiveIndex(nextIndex);
          markViewed(stories[nextIndex]);
          start = Date.now();
        } else {
          setActiveIndex(null);
        }
      }
    }, 60);
    return () => clearInterval(timer);
  }, [activeIndex, stories]);

  const active = useMemo(() => (activeIndex !== null ? stories[activeIndex] : null), [activeIndex, stories]);
  const activeAuthorId = Number(active?.author?.id || 0);
  const currentUserId = Number(user?.id || 0);
  const isOwnActiveStory = !!active && !!currentUserId && activeAuthorId === currentUserId;

  function goNext() {
    if (activeIndex === null) return;
    const nextIndex = activeIndex + 1;
    if (nextIndex < stories.length) {
      setActiveIndex(nextIndex);
      markViewed(stories[nextIndex]);
    } else {
      setActiveIndex(null);
    }
  }

  function goPrev() {
    if (activeIndex === null) return;
    const prevIndex = activeIndex - 1;
    if (prevIndex >= 0) {
      setActiveIndex(prevIndex);
      markViewed(stories[prevIndex]);
    } else {
      setActiveIndex(null);
    }
  }

  async function upload(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    const form = new FormData();
    form.append('image', file);
    form.append('caption', '');
    await fetch('/api/new/stories/upload', { method: 'POST', credentials: 'include', body: form });
    emitAppChange('story:created');
    load();
  }

  async function editActiveStory() {
    if (!active?.id || !isOwnActiveStory || busyAction) return;
    const nextCaption = window.prompt('Hikaye açıklamasını güncelle:', active.caption || '');
    if (nextCaption === null) return;
    setBusyAction('edit');
    try {
      const res = await fetch(`/api/new/stories/${active.id}/edit`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ caption: nextCaption })
      });
      if (!res.ok) throw new Error(await res.text());
      await load();
      emitAppChange('story:created');
    } catch (err) {
      window.alert(err?.message || 'Hikaye güncellenemedi.');
    } finally {
      setBusyAction('');
    }
  }

  async function deleteActiveStory() {
    if (!active?.id || !isOwnActiveStory || busyAction) return;
    const ok = window.confirm('Bu hikayeyi silmek istediğine emin misin?');
    if (!ok) return;
    setBusyAction('delete');
    try {
      const res = await fetch(`/api/new/stories/${active.id}/delete`, {
        method: 'POST',
        credentials: 'include'
      });
      if (!res.ok) throw new Error(await res.text());
      setActiveIndex(null);
      await load();
      emitAppChange('story:created');
    } catch (err) {
      window.alert(err?.message || 'Hikaye silinemedi.');
    } finally {
      setBusyAction('');
    }
  }

  return (
    <div className="story-bar">
      <label className="story add">
        <input type="file" accept="image/*" onChange={upload} />
        <div className="ring">+</div>
        <span>Hikaye</span>
      </label>
      {stories.map((s, idx) => (
        <button key={s.id} className={s.viewed ? 'story viewed' : 'story'} onClick={() => openStory(s, idx)}>
          <img src={s.author?.resim ? `/api/media/vesikalik/${s.author.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
          <span>@{s.author?.kadi}</span>
        </button>
      ))}

      {active ? (
        <div className="story-modal" onClick={() => setActiveIndex(null)}>
          <div className="story-frame" onClick={(e) => e.stopPropagation()}>
            <div className="story-progress">
              {stories.map((s, idx) => {
                const width = idx < activeIndex ? 100 : idx === activeIndex ? Math.round(progress * 100) : 0;
                return (
                  <div key={s.id} className="story-bar-track">
                    <span className="story-bar-fill" style={{ width: `${width}%` }}></span>
                  </div>
                );
              })}
            </div>
            <img src={active.image} alt="" />
            <div className="story-caption">
              <b>@{active.author?.kadi}</b> {active.caption}
            </div>
            <div className="story-actions">
              <button className="btn ghost" onClick={goPrev}>Geri</button>
              <button className="btn ghost" onClick={goNext}>İleri</button>
              {isOwnActiveStory ? (
                <>
                  <button className="btn ghost" onClick={editActiveStory} disabled={!!busyAction}>
                    {busyAction === 'edit' ? 'Kaydediliyor...' : 'Düzenle'}
                  </button>
                  <button className="btn ghost delete" onClick={deleteActiveStory} disabled={!!busyAction}>
                    {busyAction === 'delete' ? 'Siliniyor...' : 'Sil'}
                  </button>
                </>
              ) : null}
              <button className="btn ghost" onClick={() => setActiveIndex(null)}>Kapat</button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
