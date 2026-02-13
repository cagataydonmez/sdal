import React, { useEffect, useState } from 'react';

export default function StoryBar() {
  const [stories, setStories] = useState([]);
  const [active, setActive] = useState(null);

  async function load() {
    const res = await fetch('/api/new/stories', { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    setStories(payload.items || []);
  }

  useEffect(() => {
    load();
  }, []);

  async function openStory(story) {
    setActive(story);
    await fetch(`/api/new/stories/${story.id}/view`, { method: 'POST', credentials: 'include' });
  }

  async function upload(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    const form = new FormData();
    form.append('image', file);
    form.append('caption', '');
    await fetch('/api/new/stories/upload', { method: 'POST', credentials: 'include', body: form });
    load();
  }

  return (
    <div className="story-bar">
      <label className="story add">
        <input type="file" accept="image/*" onChange={upload} />
        <div className="ring">+</div>
        <span>Hikaye</span>
      </label>
      {stories.map((s) => (
        <button key={s.id} className={s.viewed ? 'story viewed' : 'story'} onClick={() => openStory(s)}>
          <img src={s.author?.resim ? `/api/media/vesikalik/${s.author.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
          <span>@{s.author?.kadi}</span>
        </button>
      ))}

      {active ? (
        <div className="story-modal" onClick={() => setActive(null)}>
          <div className="story-frame" onClick={(e) => e.stopPropagation()}>
            <img src={active.image} alt="" />
            <div className="story-caption">
              <b>@{active.author?.kadi}</b> {active.caption}
            </div>
            <button className="btn ghost" onClick={() => setActive(null)}>Kapat</button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
