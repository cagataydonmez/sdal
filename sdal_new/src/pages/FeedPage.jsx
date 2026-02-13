import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import PostComposer from '../components/PostComposer.jsx';
import PostCard from '../components/PostCard.jsx';
import NotificationPanel from '../components/NotificationPanel.jsx';

export default function FeedPage() {
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);

  async function load() {
    setLoading(true);
    const res = await fetch('/api/new/feed', { credentials: 'include' });
    const payload = await res.json();
    setPosts(payload.items || []);
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, []);

  return (
    <Layout title="Akış" right={<a className="btn ghost" href="/">Klasik Görünüm</a>}>
      <div className="grid">
        <div className="col-main">
          <PostComposer onPost={load} />
          {loading ? <div className="muted">Yükleniyor...</div> : null}
          {posts.map((p) => (
            <PostCard key={p.id} post={p} onRefresh={load} />
          ))}
        </div>
        <div className="col-side">
          <NotificationPanel />
          <div className="panel">
            <h3>Hızlı Erişim</h3>
            <div className="panel-body">
              <a href="/new/explore">Üyeleri keşfet</a>
              <a href="/new/events">Yaklaşan etkinlikler</a>
              <a href="/new/announcements">Duyurular</a>
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
}
