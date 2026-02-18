import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { emitAppChange, useLiveRefresh } from '../utils/live.js';
import { useAuth } from '../utils/auth.jsx';

function firstUnviewedIndex(items = []) {
  const idx = items.findIndex((s) => !s.viewed);
  return idx >= 0 ? idx : 0;
}

export default function StoryBar({ endpoint = '/api/new/stories', showUpload = true, title = '' }) {
  const { user } = useAuth();
  const [stories, setStories] = useState([]);
  const [activeGroupIndex, setActiveGroupIndex] = useState(null);
  const [activeStoryIndex, setActiveStoryIndex] = useState(0);
  const [progress, setProgress] = useState(0);
  const [busyAction, setBusyAction] = useState('');
  const durationMs = 5000;

  const load = useCallback(async () => {
    const res = await fetch(endpoint, { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    setStories(payload.items || []);
  }, [endpoint]);

  const groups = useMemo(() => {
    const map = new Map();
    for (const s of stories) {
      const authorId = Number(s?.author?.id || 0);
      if (!authorId) continue;
      if (!map.has(authorId)) {
        map.set(authorId, { author: s.author, items: [] });
      }
      map.get(authorId).items.push(s);
    }
    const arr = Array.from(map.values()).map((g) => ({
      ...g,
      // Keep latest first to match feed recency.
      items: [...g.items].sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || ''))),
      viewed: g.items.every((s) => !!s.viewed),
      latestAt: g.items.reduce((acc, s) => (String(s.createdAt || '') > acc ? String(s.createdAt || '') : acc), '')
    }));
    arr.sort((a, b) => {
      if (a.viewed !== b.viewed) return a.viewed ? 1 : -1;
      return String(b.latestAt).localeCompare(String(a.latestAt));
    });
    return arr;
  }, [stories]);

  const activeGroup = activeGroupIndex !== null ? groups[activeGroupIndex] : null;
  const active = activeGroup?.items?.[activeStoryIndex] || null;

  async function markViewed(story) {
    if (!story?.id) return;
    await fetch(`/api/new/stories/${story.id}/view`, { method: 'POST', credentials: 'include' });
  }

  async function openGroup(group, groupIndex) {
    const startIndex = firstUnviewedIndex(group?.items || []);
    setActiveGroupIndex(groupIndex);
    setActiveStoryIndex(startIndex);
    setProgress(0);
    await markViewed(group?.items?.[startIndex]);
  }

  useEffect(() => {
    load();
  }, [load]);
  useLiveRefresh(load, { intervalMs: 12000, eventTypes: ['story:created', '*'] });

  useEffect(() => {
    if (activeGroupIndex === null || !activeGroup || !active) return;
    if (!activeGroup.items[activeStoryIndex]) {
      setActiveGroupIndex(null);
      return;
    }
    let start = Date.now();
    setProgress(0);
    const timer = setInterval(() => {
      const ratio = Math.min((Date.now() - start) / durationMs, 1);
      setProgress(ratio);
      if (ratio >= 1) {
        clearInterval(timer);
        const nextStoryIndex = activeStoryIndex + 1;
        if (nextStoryIndex < activeGroup.items.length) {
          setActiveStoryIndex(nextStoryIndex);
          markViewed(activeGroup.items[nextStoryIndex]);
          start = Date.now();
        } else {
          const nextGroupIndex = activeGroupIndex + 1;
          if (nextGroupIndex < groups.length) {
            const nextStart = firstUnviewedIndex(groups[nextGroupIndex].items);
            setActiveGroupIndex(nextGroupIndex);
            setActiveStoryIndex(nextStart);
            markViewed(groups[nextGroupIndex].items[nextStart]);
            start = Date.now();
          } else {
            setActiveGroupIndex(null);
          }
        }
      }
    }, 60);
    return () => clearInterval(timer);
  }, [activeGroupIndex, activeGroup, activeStoryIndex, active, groups]);
  const activeAuthorId = Number(active?.author?.id || 0);
  const currentUserId = Number(user?.id || 0);
  const isOwnActiveStory = !!active && !!currentUserId && activeAuthorId === currentUserId;

  function goNext() {
    if (activeGroupIndex === null || !activeGroup) return;
    const nextStoryIndex = activeStoryIndex + 1;
    if (nextStoryIndex < activeGroup.items.length) {
      setActiveStoryIndex(nextStoryIndex);
      markViewed(activeGroup.items[nextStoryIndex]);
    } else {
      const nextGroupIndex = activeGroupIndex + 1;
      if (nextGroupIndex < groups.length) {
        const nextStart = firstUnviewedIndex(groups[nextGroupIndex].items);
        setActiveGroupIndex(nextGroupIndex);
        setActiveStoryIndex(nextStart);
        markViewed(groups[nextGroupIndex].items[nextStart]);
      } else {
        setActiveGroupIndex(null);
      }
    }
  }

  function goPrev() {
    if (activeGroupIndex === null || !activeGroup) return;
    const prevStoryIndex = activeStoryIndex - 1;
    if (prevStoryIndex >= 0) {
      setActiveStoryIndex(prevStoryIndex);
      markViewed(activeGroup.items[prevStoryIndex]);
    } else {
      const prevGroupIndex = activeGroupIndex - 1;
      if (prevGroupIndex >= 0) {
        const prevGroup = groups[prevGroupIndex];
        const idx = Math.max(0, prevGroup.items.length - 1);
        setActiveGroupIndex(prevGroupIndex);
        setActiveStoryIndex(idx);
        markViewed(prevGroup.items[idx]);
      } else {
        setActiveGroupIndex(null);
      }
    }
  }

  async function upload(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    const caption = window.prompt('Hikaye açıklaması (opsiyonel):', '') || '';
    const form = new FormData();
    form.append('image', file);
    form.append('caption', caption);
    await fetch('/api/new/stories/upload', { method: 'POST', credentials: 'include', body: form });
    e.target.value = '';
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
      setActiveGroupIndex(null);
      await load();
      emitAppChange('story:created');
    } catch (err) {
      window.alert(err?.message || 'Hikaye silinemedi.');
    } finally {
      setBusyAction('');
    }
  }

  return (
    <div className="story-wrap">
      {title ? <h3>{title}</h3> : null}
      <div className="story-bar">
        {showUpload ? (
          <label className="story add">
            <input type="file" accept="image/*" onChange={upload} />
            <div className="ring">+</div>
            <span>Hikaye Ekle</span>
          </label>
        ) : null}
        {groups.map((g, idx) => (
          <button key={g.author?.id || idx} className={g.viewed ? 'story viewed' : 'story'} onClick={() => openGroup(g, idx)}>
            <img src={g.author?.resim ? `/api/media/vesikalik/${g.author.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
            <span>@{g.author?.kadi}</span>
          </button>
        ))}
        {!groups.length ? <div className="muted">Gösterilecek hikaye yok.</div> : null}
      </div>

      {active ? (
        <div className="story-modal" onClick={() => setActiveGroupIndex(null)}>
          <div className="story-frame" onClick={(e) => e.stopPropagation()}>
            <div className="story-progress">
              {activeGroup.items.map((s, idx) => {
                const width = idx < activeStoryIndex ? 100 : idx === activeStoryIndex ? Math.round(progress * 100) : 0;
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
              <button className="btn ghost" onClick={() => setActiveGroupIndex(null)}>Kapat</button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
