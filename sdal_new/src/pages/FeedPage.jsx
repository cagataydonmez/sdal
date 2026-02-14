import React, { useCallback, useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import PostComposer from '../components/PostComposer.jsx';
import PostCard from '../components/PostCard.jsx';
import NotificationPanel from '../components/NotificationPanel.jsx';
import StoryBar from '../components/StoryBar.jsx';
import LiveChatPanel from '../components/LiveChatPanel.jsx';
import { useLiveRefresh } from '../utils/live.js';

export default function FeedPage() {
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [unreadMessages, setUnreadMessages] = useState(0);
  const [searchParams] = useSearchParams();
  const focusPostId = Number(searchParams.get('post') || 0) || null;

  const load = useCallback(async () => {
    setLoading(true);
    const res = await fetch('/api/new/feed', { credentials: 'include' });
    const payload = await res.json();
    setPosts(payload.items || []);
    setLoading(false);
  }, []);

  const loadUnreadMessages = useCallback(async () => {
    try {
      const res = await fetch('/api/new/messages/unread', { credentials: 'include' });
      if (!res.ok) return;
      const payload = await res.json();
      setUnreadMessages(payload.count || 0);
    } catch {
      // ignore
    }
  }, []);

  useEffect(() => {
    load();
    loadUnreadMessages();
  }, [load, loadUnreadMessages]);

  useLiveRefresh(load, { intervalMs: 7000, eventTypes: ['post:created', 'post:liked', 'post:commented', 'story:created', '*'] });
  useLiveRefresh(loadUnreadMessages, { intervalMs: 7000, eventTypes: ['message:created', '*'] });

  return (
    <Layout title="Akış">
      <div className="grid">
        <div className="col-main">
          <StoryBar />
          <PostComposer onPost={load} />
          {loading ? <div className="muted">Yükleniyor...</div> : null}
          {posts.map((p) => (
            <PostCard key={p.id} post={p} onRefresh={load} focused={focusPostId === p.id} />
          ))}
        </div>
        <div className="col-side">
          <NotificationPanel />
          <div className="panel">
            <h3>Yeni Mesajlar</h3>
            <div className="panel-body">
              <a href="/new/messages">
                {unreadMessages > 0 ? `${unreadMessages} okunmamış mesajın var.` : 'Yeni mesaj yok.'}
              </a>
            </div>
          </div>
          <LiveChatPanel />
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
