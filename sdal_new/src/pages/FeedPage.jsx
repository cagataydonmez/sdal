import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import PostComposer from '../components/PostComposer.jsx';
import PostCard from '../components/PostCard.jsx';
import NotificationPanel from '../components/NotificationPanel.jsx';
import StoryBar from '../components/StoryBar.jsx';
import LiveChatPanel from '../components/LiveChatPanel.jsx';
import { useLiveRefresh } from '../utils/live.js';
import { useI18n } from '../utils/i18n.jsx';

export default function FeedPage() {
  const { t } = useI18n();
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [unreadMessages, setUnreadMessages] = useState(0);
  const [pendingPostsCount, setPendingPostsCount] = useState(0);
  const [pendingItems, setPendingItems] = useState(null);
  const [scope, setScope] = useState('all');
  const [quickUsers, setQuickUsers] = useState([]);
  const [onlineMembers, setOnlineMembers] = useState([]);
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [searchParams] = useSearchParams();
  const focusPostId = Number(searchParams.get('post') || 0) || null;
  const postsRef = useRef([]);
  const loadingRef = useRef(false);
  const sentinelRef = useRef(null);

  useEffect(() => {
    postsRef.current = posts;
  }, [posts]);

  const load = useCallback(async ({ silent = false, force = false } = {}) => {
    if (loadingRef.current) return;
    loadingRef.current = true;
    try {
      if (!silent) setLoading(true);
      const res = await fetch(`/api/new/feed?limit=20&offset=0&scope=${scope}`, { credentials: 'include' });
      const payload = await res.json();
      const items = payload.items || [];
      const prev = postsRef.current;
      const prevMap = new Map(prev.map((p) => [p.id, p]));
      const hasNewPosts = items.some((p) => !prevMap.has(p.id));
      const changed =
        prev.length !== items.length ||
        items.some((p) => {
          const old = prevMap.get(p.id);
          if (!old) return true;
          return old.likeCount !== p.likeCount || old.commentCount !== p.commentCount || old.liked !== p.liked || old.content !== p.content;
        });

      const userReadingOldFeed = window.scrollY > 140;
      if (silent && hasNewPosts && userReadingOldFeed && !force) {
        const newCount = items.filter((p) => !prevMap.has(p.id)).length;
        setPendingItems(items);
        setPendingPostsCount(newCount);
      } else if (changed || force) {
        setPendingItems(null);
        setPendingPostsCount(0);
        setPosts(items);
        setHasMore(!!payload.hasMore);
      }
    } catch {
      // ignore fetch errors in background refresh
    } finally {
      if (!silent) setLoading(false);
      loadingRef.current = false;
    }
  }, [scope]);

  const loadMore = useCallback(async () => {
    if (loadingMore || !hasMore || loadingRef.current) return;
    setLoadingMore(true);
    try {
      const offset = postsRef.current.length;
      const res = await fetch(`/api/new/feed?limit=20&offset=${offset}&scope=${scope}`, { credentials: 'include' });
      if (!res.ok) return;
      const payload = await res.json();
      const next = payload.items || [];
      if (next.length) {
        setPosts((prev) => {
          const ids = new Set(prev.map((p) => p.id));
          const merged = [...prev];
          for (const n of next) {
            if (!ids.has(n.id)) merged.push(n);
          }
          return merged;
        });
      }
      setHasMore(!!payload.hasMore);
    } finally {
      setLoadingMore(false);
    }
  }, [scope, hasMore, loadingMore]);

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

  const loadQuickAccess = useCallback(async () => {
    try {
      const res = await fetch('/api/quick-access', { credentials: 'include' });
      if (!res.ok) return;
      const payload = await res.json();
      setQuickUsers(payload.users || []);
    } catch {
      // ignore
    }
  }, []);

  const loadOnlineMembers = useCallback(async () => {
    try {
      const res = await fetch('/api/new/online-members?limit=10&excludeSelf=1', { credentials: 'include' });
      if (!res.ok) return;
      const payload = await res.json();
      setOnlineMembers(payload.items || []);
    } catch {
      // ignore
    }
  }, []);

  const refreshFeedSilently = useCallback(() => {
    load({ silent: true });
  }, [load]);

  useEffect(() => {
    load({ silent: false });
    loadUnreadMessages();
    loadQuickAccess();
    loadOnlineMembers();
  }, [load, loadUnreadMessages, loadQuickAccess, loadOnlineMembers, scope]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) loadMore();
    }, { rootMargin: '400px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [loadMore]);

  useLiveRefresh(refreshFeedSilently, { intervalMs: 7000, eventTypes: ['post:created', 'post:liked', 'post:commented', 'story:created', '*'] });
  useLiveRefresh(loadUnreadMessages, { intervalMs: 7000, eventTypes: ['message:created', '*'] });
  useLiveRefresh(loadOnlineMembers, { intervalMs: 8000, eventTypes: ['*'] });

  return (
    <Layout title="Akış">
      <div className="panel">
        <StoryBar title="Hikayeler" />
      </div>
      <div className="grid">
        <div className="col-main">
          <div className="panel">
            <div className="panel-body scope-tabs">
              <button className={`btn ${scope === 'all' ? 'primary' : 'ghost'}`} onClick={() => setScope('all')}>{t('all')}</button>
              <button className={`btn ${scope === 'following' ? 'primary' : 'ghost'}`} onClick={() => setScope('following')}>{t('following')}</button>
              <button className={`btn ${scope === 'popular' ? 'primary' : 'ghost'}`} onClick={() => setScope('popular')}>{t('popular')}</button>
            </div>
          </div>
          {pendingPostsCount > 0 ? (
            <button
              className="btn primary"
              onClick={() => {
                if (pendingItems) setPosts(pendingItems);
                setPendingItems(null);
                setPendingPostsCount(0);
              }}
            >
              {pendingPostsCount} yeni gönderi var, yenile
            </button>
          ) : null}
          <PostComposer onPost={() => load({ silent: true, force: true })} />
          {loading ? <div className="muted">Yükleniyor...</div> : null}
          {posts.map((p) => (
            <PostCard key={p.id} post={p} onRefresh={() => load({ silent: true, force: true })} focused={focusPostId === p.id} />
          ))}
          <div ref={sentinelRef} />
          {loadingMore ? <div className="muted">Daha fazla yükleniyor...</div> : null}
          {!hasMore && posts.length > 0 ? <div className="muted">Sonuna ulaştın.</div> : null}
        </div>
        <div className="col-side">
          <NotificationPanel limit={5} showAllLink />
          <div className="panel">
            <h3>{t('online_members')}</h3>
            <div className="panel-body">
              {onlineMembers.map((u) => (
                <a key={u.id} className="verify-user" href={`/new/members/${u.id}`}>
                  <img className="avatar" src={u.resim ? `/api/media/vesikalik/${u.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                  <div>
                    <div>@{u.kadi}</div>
                    <div className="meta">Online</div>
                  </div>
                </a>
              ))}
              {!onlineMembers.length ? <div className="muted">Şu an çevrimiçi üye yok.</div> : null}
            </div>
          </div>
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
              {quickUsers.map((u) => (
                <a key={u.id} className="verify-user" href={`/new/members/${u.id}`}>
                  <img className="avatar" src={u.resim ? `/api/media/vesikalik/${u.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt="" />
                  <div>
                    <div>@{u.kadi}</div>
                    <div className="meta">{Number(u.online) === 1 ? 'Çevrimiçi' : 'Offline'}</div>
                  </div>
                </a>
              ))}
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
