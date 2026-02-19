import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
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
  const [imageReady, setImageReady] = useState(false);
  const loadedImagesRef = useRef(new Set());
  const touchStartRef = useRef({ x: 0, y: 0 });
  const durationMs = 5000;

  const storyRequest = useCallback(async (url, init = {}) => {
    return fetch(url, { credentials: 'include', ...init });
  }, []);

  const preloadImage = useCallback((url) => {
    if (!url) return Promise.resolve();
    let safeUrl = '';
    try {
      safeUrl = new URL(String(url), window.location.origin).toString();
    } catch {
      return Promise.resolve();
    }
    if (loadedImagesRef.current.has(safeUrl)) return Promise.resolve();
    return new Promise((resolve) => {
      const img = new window.Image();
      img.onload = () => {
        loadedImagesRef.current.add(safeUrl);
        resolve();
      };
      img.onerror = () => resolve();
      img.src = safeUrl;
    });
  }, []);

  const load = useCallback(async () => {
    try {
      const res = await fetch(endpoint, { credentials: 'include' });
      if (res.ok) {
        const payload = await res.json();
        setStories(payload.items || []);
        return;
      }
      throw new Error(`endpoint_failed_${res.status}`);
    } catch {
      const m = String(endpoint).match(/\/api\/new\/stories\/user\/(\d+)/);
      if (!m) return;
      const userId = Number(m[1] || 0);
      if (!userId) return;
      const fallback = await fetch('/api/new/stories', { credentials: 'include' });
      if (!fallback.ok) return;
      const payload = await fallback.json();
      const items = (payload.items || []).filter((s) => Number(s?.author?.id || 0) === userId);
      setStories(items);
    }
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

  const goNext = useCallback(() => {
    if (activeGroupIndex === null || !activeGroup) return;
    const nextStoryIndex = activeStoryIndex + 1;
    if (nextStoryIndex < activeGroup.items.length) {
      setActiveStoryIndex(nextStoryIndex);
      return;
    }
    const nextGroupIndex = activeGroupIndex + 1;
    if (nextGroupIndex < groups.length) {
      const nextStart = firstUnviewedIndex(groups[nextGroupIndex].items);
      setActiveGroupIndex(nextGroupIndex);
      setActiveStoryIndex(nextStart);
    } else {
      setActiveGroupIndex(null);
    }
  }, [activeGroupIndex, activeGroup, activeStoryIndex, groups]);

  const goPrev = useCallback(() => {
    if (activeGroupIndex === null || !activeGroup) return;
    const prevStoryIndex = activeStoryIndex - 1;
    if (prevStoryIndex >= 0) {
      setActiveStoryIndex(prevStoryIndex);
      return;
    }
    const prevGroupIndex = activeGroupIndex - 1;
    if (prevGroupIndex >= 0) {
      const prevGroup = groups[prevGroupIndex];
      const idx = Math.max(0, prevGroup.items.length - 1);
      setActiveGroupIndex(prevGroupIndex);
      setActiveStoryIndex(idx);
    } else {
      setActiveGroupIndex(null);
    }
  }, [activeGroupIndex, activeGroup, activeStoryIndex, groups]);

  async function markViewed(story) {
    if (!story?.id) return;
    await storyRequest(`/api/new/stories/${story.id}/view`, { method: 'POST' });
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
    if (!groups.length) return;
    groups.forEach((g) => {
      if (g.items[0]?.image) preloadImage(g.items[0].image);
    });
  }, [groups, preloadImage]);

  useEffect(() => {
    if (!active) {
      setImageReady(false);
      return;
    }
    let cancelled = false;
    setImageReady(loadedImagesRef.current.has(active.image));
    preloadImage(active.image).then(() => {
      if (!cancelled) setImageReady(true);
    });

    const nextInGroup = activeGroup?.items?.[activeStoryIndex + 1]?.image;
    const firstNextGroup = groups?.[Number(activeGroupIndex) + 1]?.items?.[0]?.image;
    if (nextInGroup) preloadImage(nextInGroup);
    if (firstNextGroup) preloadImage(firstNextGroup);

    return () => {
      cancelled = true;
    };
  }, [active, activeGroup, activeStoryIndex, activeGroupIndex, groups, preloadImage]);

  useEffect(() => {
    if (!active || !imageReady) return;
    let start = Date.now();
    setProgress(0);
    const timer = setInterval(() => {
      const ratio = Math.min((Date.now() - start) / durationMs, 1);
      setProgress(ratio);
      if (ratio >= 1) {
        clearInterval(timer);
        goNext();
        start = Date.now();
      }
    }, 60);
    return () => clearInterval(timer);
  }, [active, imageReady, goNext]);

  useEffect(() => {
    if (!active) return undefined;
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    document.body.classList.add('story-view-open');
    return () => {
      document.body.style.overflow = prev;
      document.body.classList.remove('story-view-open');
    };
  }, [active]);

  useEffect(() => {
    if (!active) return;
    markViewed(active);
  }, [active]);

  const activeAuthorId = Number(active?.author?.id || 0);
  const currentUserId = Number(user?.id || 0);
  const isOwnActiveStory = !!active && !!currentUserId && activeAuthorId === currentUserId;

  async function upload(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    const caption = window.prompt('Hikaye açıklaması (opsiyonel):', '') || '';
    const form = new FormData();
    form.append('image', file);
    form.append('caption', caption);
    await storyRequest('/api/new/stories/upload', { method: 'POST', body: form });
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
      let res = await storyRequest(`/api/new/stories/${active.id}/edit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ caption: nextCaption })
      });
      if (!res.ok && (res.status === 404 || res.status === 405)) {
        res = await storyRequest(`/api/new/stories/${active.id}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ caption: nextCaption })
        });
      }
      if (!res.ok && (res.status === 404 || res.status === 405)) {
        res = await storyRequest(`/api/new/stories/${active.id}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ caption: nextCaption })
        });
      }
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
      let res = await storyRequest(`/api/new/stories/${active.id}/delete`, { method: 'POST' });
      if (!res.ok && (res.status === 404 || res.status === 405)) {
        res = await storyRequest(`/api/new/stories/${active.id}`, { method: 'DELETE' });
      }
      if (!res.ok && (res.status === 404 || res.status === 405)) {
        res = await storyRequest(`/api/new/stories/${active.id}/remove`, { method: 'POST' });
      }
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

  function onTouchStart(e) {
    const t = e.changedTouches?.[0];
    if (!t) return;
    touchStartRef.current = { x: t.clientX, y: t.clientY };
  }

  function onTouchEnd(e) {
    const t = e.changedTouches?.[0];
    if (!t) return;
    const dx = t.clientX - touchStartRef.current.x;
    const dy = t.clientY - touchStartRef.current.y;
    if (Math.abs(dx) < 40 || Math.abs(dx) < Math.abs(dy)) return;
    if (dx < 0) goNext();
    else goPrev();
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
          <div className="story-frame" onClick={(e) => e.stopPropagation()} onTouchStart={onTouchStart} onTouchEnd={onTouchEnd}>
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
            {!imageReady ? <div className="story-loading">Yükleniyor...</div> : null}
            <div className="story-media">
              <button className="story-tap-zone story-tap-left" onClick={goPrev} aria-label="Önceki hikaye" />
              <button className="story-tap-zone story-tap-right" onClick={goNext} aria-label="Sonraki hikaye" />
              <img src={active.image} alt="" onLoad={() => setImageReady(true)} className={imageReady ? 'story-photo ready' : 'story-photo'} />
            </div>
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
