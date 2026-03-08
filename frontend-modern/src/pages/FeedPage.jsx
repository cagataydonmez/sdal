import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import PostComposer from '../components/PostComposer.jsx';
import PostCard from '../components/PostCard.jsx';
import NotificationPanel from '../components/NotificationPanel.jsx';
import StoryBar from '../components/StoryBar.jsx';
import LiveChatPanel from '../components/LiveChatPanel.jsx';
import { useLiveRefresh } from '../utils/live.js';
import { useI18n } from '../utils/i18n.jsx';
import { useAuth } from '../utils/auth.jsx';
import { FEED_FILTER_CONTRACT, FEED_SCOPE_CONTRACT, FEED_TAB_CONTRACT } from '../contracts/feedUiContract.js';

function FeedIcon({ name }) {
  const common = { width: 16, height: 16, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: '1.9', strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (name) {
    case 'feed':
      return <svg aria-hidden="true" {...common}><rect x="3" y="3" width="7" height="7" /><rect x="14" y="3" width="7" height="7" /><rect x="3" y="14" width="7" height="7" /><rect x="14" y="14" width="7" height="7" /></svg>;
    case 'notifications':
      return <svg aria-hidden="true" {...common}><path d="M15 17h5l-1.4-1.4a2 2 0 0 1-.6-1.4V11a6 6 0 1 0-12 0v3.2c0 .5-.2 1-.6 1.4L4 17h5" /><path d="M9.5 17a2.5 2.5 0 0 0 5 0" /></svg>;
    case 'livechat':
      return <svg aria-hidden="true" {...common}><path d="M4 5h16v10H8l-4 4V5z" /></svg>;
    case 'online':
      return <svg aria-hidden="true" {...common}><circle cx="12" cy="12" r="7" /><circle cx="12" cy="12" r="2.2" fill="currentColor" stroke="none" /></svg>;
    case 'messages':
      return <svg aria-hidden="true" {...common}><rect x="3" y="5" width="18" height="14" rx="2" /><path d="M3 8l9 6 9-6" /></svg>;
    case 'quick':
      return <svg aria-hidden="true" {...common}><path d="M12 3l2.4 4.9L20 9l-4 3.8.9 5.5-4.9-2.6-4.9 2.6.9-5.5L4 9l5.6-1.1L12 3z" /></svg>;
    case 'main':
      return <svg aria-hidden="true" {...common}><path d="M3 11.5L12 4l9 7.5" /><path d="M6.5 10.5V20h11V10.5" /></svg>;
    case 'community':
      return <svg aria-hidden="true" {...common}><circle cx="8" cy="10" r="3" /><circle cx="16" cy="10" r="3" /><path d="M3.5 19c.8-2.8 3.1-4 4.5-4" /><path d="M20.5 19c-.8-2.8-3.1-4-4.5-4" /><path d="M9 18c.8-2.4 2.2-3.5 3-3.5.8 0 2.2 1.1 3 3.5" /></svg>;
    case 'latest':
      return <svg aria-hidden="true" {...common}><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 3" /></svg>;
    case 'popular':
      return <svg aria-hidden="true" {...common}><path d="M12 3l2.6 5.3L20.5 9l-4.2 4 .9 6-5.2-2.9L6.8 19l.9-6-4.2-4 5.9-.7L12 3z" /></svg>;
    case 'following':
      return <svg aria-hidden="true" {...common}><circle cx="8" cy="8" r="3" /><path d="M3 19c1-3 3.3-4.5 5-4.5 1.7 0 4 1.5 5 4.5" /><path d="M16 8h5" /><path d="M18.5 5.5v5" /></svg>;
    default:
      return <svg aria-hidden="true" {...common}><circle cx="12" cy="12" r="8" /></svg>;
  }
}

function SkeletonRows({ count = 3 }) {
  return (
    <div className="skeleton-stack" aria-hidden="true">
      {Array.from({ length: count }).map((_, idx) => (
        <span key={`sk-row-${idx}`} className="skeleton-line" />
      ))}
    </div>
  );
}

function EmptyPanelState({ message, actionLabel, href, onRetry }) {
  return (
    <div className="feed-panel-state">
      <div className="muted">{message}</div>
      {href ? <a className="btn ghost" href={href}>{actionLabel}</a> : null}
      {onRetry ? <button className="btn ghost" onClick={onRetry}>{actionLabel}</button> : null}
    </div>
  );
}

export default function FeedPage() {
  const { t } = useI18n();
  const { user } = useAuth();
  const [mobileTab, setMobileTab] = useState('posts');
  const [posts, setPosts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [unreadMessages, setUnreadMessages] = useState(0);
  const [unreadNotifications, setUnreadNotifications] = useState(0);
  const [pendingPostsCount, setPendingPostsCount] = useState(0);
  const [pendingItems, setPendingItems] = useState(null);
  const [feedType, setFeedType] = useState('main');
  const [filter, setFilter] = useState('latest');
  const [mainFeedOpen, setMainFeedOpen] = useState(true);
  const [quickUsers, setQuickUsers] = useState([]);
  const [onlineMembers, setOnlineMembers] = useState([]);
  const [hasMore, setHasMore] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [onlineMembersLoading, setOnlineMembersLoading] = useState(true);
  const [onlineMembersError, setOnlineMembersError] = useState('');
  const [quickAccessLoading, setQuickAccessLoading] = useState(true);
  const [quickAccessError, setQuickAccessError] = useState('');
  const [unreadMessagesLoading, setUnreadMessagesLoading] = useState(true);
  const [unreadMessagesError, setUnreadMessagesError] = useState('');
  const [searchParams] = useSearchParams();
  const focusPostId = Number(searchParams.get('post') || 0) || null;
  const postsRef = useRef([]);
  const loadingRef = useRef(false);
  const requestSeqRef = useRef(0);
  const sentinelRef = useRef(null);
  const initializedRef = useRef(false);
  const sideDataInitializedRef = useRef(false);
  const [mountLiveChat, setMountLiveChat] = useState(false);

  const scopeOptions = useMemo(() => ([
    ...FEED_SCOPE_CONTRACT
      .filter((item) => item.key !== 'main' || mainFeedOpen)
      .map((item) => ({ ...item, label: t(item.labelKey) }))
  ]), [mainFeedOpen, t]);

  const filterOptions = useMemo(() => ([
    ...FEED_FILTER_CONTRACT.map((item) => ({ ...item, label: t(item.labelKey) }))
  ]), [t]);

  const feedTabOptions = useMemo(() => ([
    ...FEED_TAB_CONTRACT.map((item) => ({
      ...item,
      label: t(item.labelKey),
      badge:
        item.key === 'notifications'
          ? Math.max(0, Number(unreadNotifications) || 0)
          : item.key === 'online'
            ? Math.max(0, Number(onlineMembers.length) || 0)
            : item.key === 'messages'
              ? Math.max(0, Number(unreadMessages) || 0)
              : 0
    }))
  ]), [t, unreadNotifications, onlineMembers.length, unreadMessages]);
  const activeScopeLabel = scopeOptions.find((item) => item.key === feedType)?.label || t('main_feed');
  const activeFilterLabel = filterOptions.find((item) => item.key === filter)?.label || t('latest');
  const activeFeedTabLabel = feedTabOptions.find((item) => item.key === mobileTab)?.label || t('nav_feed');

  useEffect(() => {
    postsRef.current = posts;
  }, [posts]);

  useEffect(() => {
    let mounted = true;
    fetch('/api/site-access?path=/new', { credentials: 'include' })
      .then((r) => r.ok ? r.json() : null)
      .then((payload) => {
        if (!mounted) return;
        const isOpen = payload?.modules?.main_feed !== false;
        setMainFeedOpen(isOpen);
        if (!isOpen && feedType === 'main') setFeedType('community');
      })
      .catch(() => {});
    return () => { mounted = false; };
  }, [feedType]);

  useEffect(() => {
    if (!mainFeedOpen && feedType === 'main') setFeedType('community');
  }, [mainFeedOpen, feedType]);

  const load = useCallback(async ({ silent = false, force = false } = {}) => {
    if (loadingRef.current && !force) return;
    const requestSeq = ++requestSeqRef.current;
    loadingRef.current = true;
    try {
      if (!silent) setLoading(true);
      const res = await fetch(`/api/new/feed?limit=20&offset=0&feedType=${feedType}&filter=${filter}`, { credentials: 'include' });
      const payload = await res.json();
      if (requestSeq !== requestSeqRef.current) return;
      let items = payload.items || [];
      if (filter === 'following' && user?.id) {
        items = items.filter((p) => Number(p?.author?.id || p?.user_id || 0) !== Number(user.id));
      }
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
      if (requestSeq === requestSeqRef.current) {
        if (!silent) setLoading(false);
        loadingRef.current = false;
      }
    }
  }, [feedType, filter, user?.id]);

  const loadMore = useCallback(async () => {
    if (loadingMore || !hasMore || loadingRef.current) return;
    setLoadingMore(true);
    try {
      const offset = postsRef.current.length;
      const res = await fetch(`/api/new/feed?limit=20&offset=${offset}&feedType=${feedType}&filter=${filter}`, { credentials: 'include' });
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
  }, [feedType, filter, hasMore, loadingMore]);

  const loadUnreadMessages = useCallback(async ({ background = true } = {}) => {
    if (!background) {
      setUnreadMessagesLoading(true);
      setUnreadMessagesError('');
    }
    try {
      const res = await fetch('/api/new/messages/unread', { credentials: 'include', cache: 'no-store' });
      if (!res.ok) throw new Error('messages');
      const payload = await res.json();
      setUnreadMessages(payload.count || 0);
      if (!background) setUnreadMessagesError('');
    } catch {
      if (!background) setUnreadMessagesError('messages');
    } finally {
      if (!background) setUnreadMessagesLoading(false);
    }
  }, []);

  const loadUnreadNotifications = useCallback(async () => {
    try {
      const res = await fetch('/api/new/notifications/unread', { credentials: 'include', cache: 'no-store' });
      if (!res.ok) return;
      const payload = await res.json();
      setUnreadNotifications(payload.count || 0);
    } catch {
      // ignore background errors
    }
  }, []);

  const loadQuickAccess = useCallback(async ({ background = true } = {}) => {
    if (!background) {
      setQuickAccessLoading(true);
      setQuickAccessError('');
    }
    try {
      const res = await fetch('/api/quick-access', { credentials: 'include', cache: 'no-store' });
      if (!res.ok) throw new Error('quick');
      const payload = await res.json();
      setQuickUsers(payload.users || []);
      if (!background) setQuickAccessError('');
    } catch {
      if (!background) setQuickAccessError('quick');
    } finally {
      if (!background) setQuickAccessLoading(false);
    }
  }, []);

  const loadOnlineMembers = useCallback(async ({ background = true } = {}) => {
    if (!background) {
      setOnlineMembersLoading(true);
      setOnlineMembersError('');
    }
    try {
      const res = await fetch('/api/new/online-members?limit=10&excludeSelf=1', { credentials: 'include', cache: 'no-store' });
      if (!res.ok) throw new Error('online');
      const payload = await res.json();
      setOnlineMembers(payload.items || []);
      if (!background) setOnlineMembersError('');
    } catch {
      if (!background) setOnlineMembersError('online');
    } finally {
      if (!background) setOnlineMembersLoading(false);
    }
  }, []);

  const refreshFeedSilently = useCallback(() => {
    load({ silent: true });
  }, [load]);

  useEffect(() => {
    const isSubsequentScopeLoad = initializedRef.current;
    load({ silent: isSubsequentScopeLoad, force: isSubsequentScopeLoad });
    initializedRef.current = true;
  }, [load]);

  useEffect(() => {
    if (sideDataInitializedRef.current) return;
    sideDataInitializedRef.current = true;
    const timer = setTimeout(() => {
      Promise.allSettled([
        loadUnreadMessages({ background: false }),
        loadUnreadNotifications(),
        loadQuickAccess({ background: false }),
        loadOnlineMembers({ background: false })
      ]).catch(() => {});
    }, 180);
    return () => clearTimeout(timer);
  }, [loadUnreadMessages, loadUnreadNotifications, loadQuickAccess, loadOnlineMembers]);

  useEffect(() => {
    const timer = setTimeout(() => setMountLiveChat(true), 1200);
    return () => clearTimeout(timer);
  }, []);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return undefined;
    const io = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) loadMore();
    }, { rootMargin: '400px 0px' });
    io.observe(node);
    return () => io.disconnect();
  }, [loadMore]);

  useLiveRefresh(refreshFeedSilently, { intervalMs: 9000, eventTypes: ['post:created', 'post:liked', 'post:commented', 'story:created'] });
  useLiveRefresh(loadUnreadMessages, { intervalMs: 12000, eventTypes: ['message:created'] });
  useLiveRefresh(loadUnreadNotifications, { intervalMs: 12000, eventTypes: ['notification:new'] });
  useLiveRefresh(loadQuickAccess, { intervalMs: 20000, eventTypes: [] });
  useLiveRefresh(loadOnlineMembers, { intervalMs: 12000, eventTypes: [] });

  return (
    <Layout title={t('nav_feed')}>
      <div className="feed-mobile-sticky-stack">
        <div className="panel feed-mobile-stories-wrap">
          <StoryBar title={t('stories_title')} />
        </div>

        <div className="panel feed-mobile-tabs-wrap">
          <div className="panel-body feed-mobile-tabs" role="tablist" aria-label={t('nav_feed')}>
            {feedTabOptions.map((tabItem) => (
              <button
                key={`feed-tab-${tabItem.key}`}
                className={`btn feed-tab-btn ${mobileTab === tabItem.key ? 'primary' : 'ghost'}`}
                onClick={() => setMobileTab(tabItem.key)}
                title={tabItem.label}
                aria-label={tabItem.label}
                role="tab"
                aria-selected={mobileTab === tabItem.key}
              >
                <span className="feed-tab-btn-icon" aria-hidden="true"><FeedIcon name={tabItem.icon} /></span>
                <span className="feed-tab-btn-label">{tabItem.label}</span>
                {tabItem.badge > 0 ? <span className="mini-badge feed-tab-badge">{tabItem.badge}</span> : null}
              </button>
            ))}
          </div>
          <div className="feed-mobile-selected-title">{activeFeedTabLabel}</div>
        </div>
      </div>

      <div className="grid">
        <div className={`col-main feed-main feed-tab-panel ${mobileTab === 'posts' ? 'is-active' : ''}`}>
          <div className="panel">
            <div className="panel-body scope-tabs scope-tabs-feedtype">
              {scopeOptions.map((scopeItem) => (
                <button
                  key={`scope-${scopeItem.key}`}
                  className={`btn scope-btn ${feedType === scopeItem.key ? 'primary' : 'ghost'}`}
                  onClick={() => setFeedType(scopeItem.key)}
                  title={scopeItem.label}
                  aria-label={scopeItem.label}
                >
                  <span className="scope-btn-icon" aria-hidden="true"><FeedIcon name={scopeItem.icon} /></span>
                  <span className="scope-btn-label">{scopeItem.label}</span>
                </button>
              ))}
            </div>
            <div className="scope-mobile-selected-title">{activeScopeLabel}</div>

            <div className="panel-body scope-tabs scope-tabs-filter">
              {filterOptions.map((filterItem) => (
                <button
                  key={`filter-${filterItem.key}`}
                  className={`btn scope-btn ${filter === filterItem.key ? 'primary' : 'ghost'}`}
                  onClick={() => setFilter(filterItem.key)}
                  title={filterItem.label}
                  aria-label={filterItem.label}
                >
                  <span className="scope-btn-icon" aria-hidden="true"><FeedIcon name={filterItem.icon} /></span>
                  <span className="scope-btn-label">{filterItem.label}</span>
                </button>
              ))}
            </div>
            <div className="scope-mobile-selected-title">{activeFilterLabel}</div>
            <div className="muted feed-note">{feedType === 'main' ? t('main_feed_public_note') : t('community_feed_note')}</div>
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
              {t('feed_new_posts_refresh', { count: pendingPostsCount })}
            </button>
          ) : null}

          <PostComposer onPost={() => load({ silent: true, force: true })} />

          {loading && posts.length === 0 ? (
            <div className="feed-skeleton-list" aria-label={t('loading')}>
              <div className="post-card post-card-skeleton">
                <div className="post-header-skeleton">
                  <span className="skeleton-dot skeleton-avatar" />
                  <SkeletonRows count={2} />
                </div>
                <SkeletonRows count={3} />
              </div>
              <div className="post-card post-card-skeleton">
                <div className="post-header-skeleton">
                  <span className="skeleton-dot skeleton-avatar" />
                  <SkeletonRows count={2} />
                </div>
                <SkeletonRows count={4} />
              </div>
            </div>
          ) : null}

          {posts.map((p) => (
            <PostCard key={p.id} post={p} onRefresh={() => load({ silent: true, force: true })} focused={focusPostId === p.id} />
          ))}
          <div ref={sentinelRef} />
          {loadingMore ? <div className="muted">{t('feed_loading_more')}</div> : null}
          {!hasMore && posts.length > 0 ? <div className="muted">{t('feed_end')}</div> : null}
        </div>

        <div className="col-side feed-side">
          <div className={`feed-tab-panel ${mobileTab === 'notifications' ? 'is-active' : ''}`}>
            <NotificationPanel limit={3} showAllLink showEmptyCta onReload={loadUnreadNotifications} />
          </div>

          <div className={`panel feed-tab-panel ${mobileTab === 'online' ? 'is-active' : ''}`}>
            <h3>{t('online_members')}</h3>
            <div className="panel-body">
              {onlineMembersLoading ? <SkeletonRows count={2} /> : null}
              {!onlineMembersLoading && onlineMembersError ? (
                <EmptyPanelState message={t('online_members_empty')} actionLabel={t('games_refresh')} onRetry={() => loadOnlineMembers({ background: false })} />
              ) : null}
              {!onlineMembersLoading && !onlineMembersError && onlineMembers.map((u) => (
                <a key={u.id} className="verify-user" href={`/new/members/${u.id}`}>
                  <img className="avatar" src={u.resim ? `/api/media/vesikalik/${u.resim}` : '/legacy/vesikalik/nophoto.jpg'} loading="lazy" decoding="async" alt="" />
                  <div>
                    <div>@{u.kadi}</div>
                    <div className="meta">{t('status_online')}</div>
                  </div>
                </a>
              ))}
              {!onlineMembersLoading && !onlineMembersError && !onlineMembers.length ? <div className="muted">{t('online_members_empty')}</div> : null}
            </div>
          </div>

          <div className={`panel feed-tab-panel ${mobileTab === 'messages' ? 'is-active' : ''}`}>
            <h3>{t('new_messages')}</h3>
            <div className="panel-body">
              {unreadMessagesLoading ? <SkeletonRows count={1} /> : null}
              {!unreadMessagesLoading && unreadMessagesError ? (
                <EmptyPanelState message={t('no_new_messages')} actionLabel={t('games_refresh')} onRetry={() => loadUnreadMessages({ background: false })} />
              ) : null}
              {!unreadMessagesLoading && !unreadMessagesError ? (
                <a href="/new/messages">
                  {unreadMessages > 0 ? t('unread_messages_count', { count: unreadMessages }) : t('no_new_messages')}
                </a>
              ) : null}
            </div>
          </div>

          <div className={`feed-tab-panel ${mobileTab === 'livechat' ? 'is-active' : ''}`}>
            {mountLiveChat || mobileTab === 'livechat' ? (
              <LiveChatPanel />
            ) : (
              <div className="panel"><div className="panel-body"><SkeletonRows count={4} /></div></div>
            )}
          </div>

          <div className={`panel feed-tab-panel ${mobileTab === 'quick' ? 'is-active' : ''}`}>
            <h3>{t('quick_access')}</h3>
            <div className="panel-body">
              {quickAccessLoading ? <SkeletonRows count={3} /> : null}
              {!quickAccessLoading && quickAccessError ? (
                <EmptyPanelState message={t('feed_discover_members')} actionLabel={t('games_refresh')} onRetry={() => loadQuickAccess({ background: false })} />
              ) : null}
              {!quickAccessLoading && !quickAccessError && quickUsers.map((u) => (
                <a key={u.id} className="verify-user" href={`/new/members/${u.id}`}>
                  <img className="avatar" src={u.resim ? `/api/media/vesikalik/${u.resim}` : '/legacy/vesikalik/nophoto.jpg'} loading="lazy" decoding="async" alt="" />
                  <div>
                    <div>@{u.kadi}</div>
                    <div className="meta">{Number(u.online) === 1 ? t('status_online') : t('status_offline')}</div>
                  </div>
                </a>
              ))}
              <a href="/new/explore">{t('feed_discover_members')}</a>
              <a href="/new/events">{t('feed_upcoming_events')}</a>
              <a href="/new/announcements">{t('nav_announcements')}</a>
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
}
