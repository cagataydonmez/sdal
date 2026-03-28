import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { Link, useSearchParams } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import PostComposer from '../components/PostComposer.jsx';
import PostCard from '../components/PostCard.jsx';
import NotificationPanel from '../components/NotificationPanel.jsx';
import StoryBar from '../components/StoryBar.jsx';
import LiveChatPanel from '../components/LiveChatPanel.jsx';
import AnimatedIcon from '../components/AnimatedIcon.jsx';
import { useLiveRefresh } from '../utils/live.js';
import { useI18n } from '../utils/i18n.jsx';
import { useAuth } from '../utils/auth.jsx';
import { FEED_FILTER_CONTRACT, FEED_SCOPE_CONTRACT, FEED_TAB_CONTRACT } from '../contracts/feedUiContract.js';
import { avatarAlt } from '../utils/a11y.js';
import { fetchSiteAccess, getCachedSiteAccess } from '../utils/siteAccess.js';

const FEED_ICON_MAP = {
  feed: 'home',
  notifications: 'bell',
  livechat: 'message-circle',
  online: 'users',
  messages: 'mailbox',
  quick: 'sparkles',
  main: 'home',
  community: 'users',
  latest: 'clock',
  popular: 'flame',
  following: 'user'
};

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

function getFeedMobileMatch() {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return false;
  return window.matchMedia('(max-width: 760px)').matches;
}

export default function FeedPage() {
  const { t } = useI18n();
  const { user } = useAuth();
  const [isMobile, setIsMobile] = useState(getFeedMobileMatch);
  const [mobileTab, setMobileTab] = useState('posts');
  const [mobileTabsExpanded, setMobileTabsExpanded] = useState(false);
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
  const mobileTabsWrapRef = useRef(null);

  const scopeOptions = useMemo(() => ([
    ...FEED_SCOPE_CONTRACT
      .filter((item) => item.key !== 'main' || mainFeedOpen)
      .map((item) => ({ ...item, label: t(item.labelKey) }))
  ]), [mainFeedOpen, t]);

  const filterOptions = useMemo(() => ([
    ...FEED_FILTER_CONTRACT.map((item) => ({ ...item, label: t(item.labelKey) }))
  ]), [t]);
  const activeScopeLabel = scopeOptions.find((item) => item.key === feedType)?.label || '';
  const activeFilterLabel = filterOptions.find((item) => item.key === filter)?.label || '';

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
  const activeFeedTabLabel = feedTabOptions.find((item) => item.key === mobileTab)?.label || t('nav_feed');
  const quickLinks = useMemo(() => ([
    { to: '/new/explore', icon: 'community', label: t('feed_discover_members') },
    { to: '/new/events', icon: 'latest', label: t('feed_upcoming_events') },
    { to: '/new/announcements', icon: 'notifications', label: t('nav_announcements') }
  ]), [t]);

  const mobileTabToggleLabel = mobileTabsExpanded
    ? `${t('close')} • ${activeFeedTabLabel}`
    : activeFeedTabLabel;

  useEffect(() => {
    postsRef.current = posts;
  }, [posts]);

  useEffect(() => {
    if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return undefined;
    const mq = window.matchMedia('(max-width: 760px)');
    const sync = () => setIsMobile(mq.matches);
    sync();
    if (typeof mq.addEventListener === 'function') {
      mq.addEventListener('change', sync);
      return () => mq.removeEventListener('change', sync);
    }
    mq.addListener(sync);
    return () => mq.removeListener(sync);
  }, []);

  useEffect(() => {
    setMobileTabsExpanded(false);
  }, [mobileTab]);

  useEffect(() => {
    if (!mobileTabsExpanded || typeof document === 'undefined') return undefined;
    const closeOnOutside = (event) => {
      if (!mobileTabsWrapRef.current) return;
      if (mobileTabsWrapRef.current.contains(event.target)) return;
      setMobileTabsExpanded(false);
    };
    document.addEventListener('pointerdown', closeOnOutside);
    return () => document.removeEventListener('pointerdown', closeOnOutside);
  }, [mobileTabsExpanded]);

  useEffect(() => {
    const cached = getCachedSiteAccess('/new');
    if (cached?.data) {
      const isOpen = cached.data?.modules?.main_feed !== false;
      setMainFeedOpen(isOpen);
      if (!isOpen && feedType === 'main') setFeedType('community');
      if (!cached.stale) return;
    }
    let mounted = true;
    fetchSiteAccess('/new', { force: Boolean(cached?.stale) })
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
      const res = await fetch('/api/new/messages/unread', { credentials: 'include' });
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
      const res = await fetch('/api/new/notifications/unread', { credentials: 'include' });
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
      const res = await fetch('/api/quick-access', { credentials: 'include' });
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
      const res = await fetch('/api/new/online-members?limit=10&excludeSelf=1', { credentials: 'include' });
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

  const refreshFeedSignals = useCallback(() => {
    Promise.allSettled([
      loadUnreadMessages(),
      loadUnreadNotifications()
    ]).catch(() => {});
  }, [loadUnreadMessages, loadUnreadNotifications]);

  const refreshFeedDirectory = useCallback(() => {
    Promise.allSettled([
      loadQuickAccess(),
      loadOnlineMembers()
    ]).catch(() => {});
  }, [loadQuickAccess, loadOnlineMembers]);

  useEffect(() => {
    const isSubsequentScopeLoad = initializedRef.current;
    load({ silent: isSubsequentScopeLoad, force: isSubsequentScopeLoad });
    initializedRef.current = true;
  }, [load]);

  useEffect(() => {
    if (sideDataInitializedRef.current) return;
    sideDataInitializedRef.current = true;
    Promise.allSettled([
      loadUnreadMessages({ background: false }),
      loadUnreadNotifications(),
      loadQuickAccess({ background: false }),
      loadOnlineMembers({ background: false })
    ]).catch(() => {});
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

  useLiveRefresh(refreshFeedSilently, {
    intervalMs: 15000,
    hiddenIntervalMs: 60000,
    eventDebounceMs: 500,
    eventTypes: ['post:created', 'post:liked', 'post:commented', 'story:created']
  });
  useLiveRefresh(refreshFeedSignals, {
    intervalMs: 20000,
    hiddenIntervalMs: 60000,
    eventDebounceMs: 400,
    eventTypes: ['message:created', 'notification:new', 'notification:read', 'notification:opened', 'notification:action']
  });
  useLiveRefresh(refreshFeedDirectory, {
    intervalMs: 30000,
    hiddenIntervalMs: 90000,
    eventTypes: []
  });

  return (
    <Layout title={t('nav_feed')}>
      <div className="feed-mobile-sticky-stack">
        <div className="panel feed-control-strip">
          <div className="feed-control-group">
            <div className="scope-tabs feed-control-scope" aria-label={t('feed_scope_prompt')}>
              {scopeOptions.map((scopeItem) => (
                <button
                  key={`scope-${scopeItem.key}`}
                  className={`btn scope-btn ${feedType === scopeItem.key ? 'primary' : 'ghost'}`}
                  onClick={() => setFeedType(scopeItem.key)}
                  title={scopeItem.label}
                  aria-label={scopeItem.label}
                  aria-pressed={feedType === scopeItem.key}
                >
                  <span className="scope-btn-icon" aria-hidden="true"><AnimatedIcon name={FEED_ICON_MAP[scopeItem.icon] || 'home'} size={16} /></span>
                  <span className="scope-btn-label">{scopeItem.label}</span>
                </button>
              ))}
            </div>
            <div className="feed-control-selected" aria-live="polite">
              <span>{t('feed_scope_selected')}</span>
              <strong>{activeScopeLabel}</strong>
            </div>
          </div>
          <span className="feed-control-divider" aria-hidden="true" />
          <div className="feed-control-group">
            <div className="scope-tabs feed-control-filter" aria-label={t('feed_filter_prompt')}>
              {filterOptions.map((filterItem) => (
                <button
                  key={`filter-${filterItem.key}`}
                  className={`btn scope-btn ${filter === filterItem.key ? 'primary' : 'ghost'}`}
                  onClick={() => setFilter(filterItem.key)}
                  title={filterItem.label}
                  aria-label={filterItem.label}
                  aria-pressed={filter === filterItem.key}
                >
                  <span className="scope-btn-icon" aria-hidden="true"><AnimatedIcon name={FEED_ICON_MAP[filterItem.icon] || 'home'} size={16} /></span>
                  <span className="scope-btn-label">{filterItem.label}</span>
                </button>
              ))}
            </div>
            <div className="feed-control-selected" aria-live="polite">
              <span>{t('feed_filter_selected')}</span>
              <strong>{activeFilterLabel}</strong>
            </div>
          </div>
        </div>
        <div className="panel feed-mobile-stories-wrap">
          <StoryBar title={t('stories_title')} variant={isMobile ? 'feed-mobile' : 'default'} feedType={feedType} />
        </div>
      </div>

      {createPortal(
        <div ref={mobileTabsWrapRef} className={`panel feed-mobile-tabs-wrap ${mobileTabsExpanded ? 'is-expanded' : ''}`}>
          <div
            id="feed-mobile-tabs-menu"
            className={`feed-mobile-tabs ${mobileTabsExpanded ? 'open' : ''}`}
            role="tablist"
            aria-label={t('nav_feed')}
          >
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
                <span className="feed-tab-btn-icon" aria-hidden="true"><AnimatedIcon name={FEED_ICON_MAP[tabItem.icon] || 'home'} size={16} /></span>
                <span className="feed-tab-btn-label">{tabItem.label}</span>
                {tabItem.badge > 0 ? <span className="mini-badge feed-tab-badge">{tabItem.badge}</span> : null}
              </button>
            ))}
          </div>
          <button
            className="btn ghost feed-mobile-tabs-toggle"
            type="button"
            onClick={() => setMobileTabsExpanded((prev) => !prev)}
            aria-expanded={mobileTabsExpanded}
            aria-controls="feed-mobile-tabs-menu"
            aria-label={mobileTabsExpanded ? t('close') : t('open')}
          >
            <span className="feed-mobile-tabs-toggle-label">{mobileTabToggleLabel}</span>
            <span className={`feed-mobile-tabs-toggle-icon ${mobileTabsExpanded ? 'open' : ''}`} aria-hidden="true">
              <AnimatedIcon name="menu" size={18} />
            </span>
          </button>
          <div className="feed-mobile-selected-title">{activeFeedTabLabel}</div>
        </div>,
        document.body
      )}

      <div className="grid">
        <div className={`col-main feed-main feed-tab-panel ${mobileTab === 'posts' ? 'is-active' : ''}`}>
          <div className="feed-primary-stack">
            <div className="feed-composer-shell">
              {pendingPostsCount > 0 ? (
                <button
                  className="btn primary feed-refresh-banner"
                  onClick={() => {
                    if (pendingItems) setPosts(pendingItems);
                    setPendingItems(null);
                    setPendingPostsCount(0);
                  }}
                >
                  <span className="feed-refresh-banner-dot" aria-hidden="true" />
                  {t('feed_new_posts_refresh', { count: pendingPostsCount })}
                </button>
              ) : null}
              <PostComposer feedType={feedType} onPost={() => load({ silent: true, force: true })} />
            </div>
          </div>

          <div className="feed-post-stream">
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
        </div>

        <div className="col-side feed-side">
          <div className={`feed-tab-panel feed-side-notification-wrap ${mobileTab === 'notifications' ? 'is-active' : ''}`}>
            <NotificationPanel limit={3} showAllLink showEmptyCta onReload={loadUnreadNotifications} />
          </div>

          <div className="feed-side-pair">
            <div className={`panel feed-tab-panel feed-side-panel feed-side-panel-muted ${mobileTab === 'online' ? 'is-active' : ''}`}>
              <div className="feed-side-panel-heading">
                <h3>{t('online_members')}</h3>
                <span className="feed-side-panel-count">{onlineMembers.length}</span>
              </div>
              <div className="panel-body">
                {onlineMembersLoading ? <SkeletonRows count={2} /> : null}
                {!onlineMembersLoading && onlineMembersError ? (
                  <EmptyPanelState message={t('online_members_empty')} actionLabel={t('games_refresh')} onRetry={() => loadOnlineMembers({ background: false })} />
                ) : null}
                {!onlineMembersLoading && !onlineMembersError && onlineMembers.map((u) => (
                  <Link key={u.id} className="verify-user feed-member-row" to={`/new/members/${u.id}`}>
                    <img className="avatar" src={u.resim ? `/api/media/vesikalik/${u.resim}` : '/legacy/vesikalik/nophoto.jpg'} loading="lazy" decoding="async" alt={avatarAlt(u)} />
                    <div>
                      <div>@{u.kadi}</div>
                      <div className="meta"><span className="feed-member-status-dot" aria-hidden="true" />{t('status_online')}</div>
                    </div>
                  </Link>
                ))}
                {!onlineMembersLoading && !onlineMembersError && !onlineMembers.length ? <div className="muted">{t('online_members_empty')}</div> : null}
              </div>
            </div>

            <div className={`panel feed-tab-panel feed-side-panel feed-side-panel-compact feed-side-panel-muted ${mobileTab === 'messages' ? 'is-active' : ''}`}>
              <div className="feed-side-panel-heading">
                <h3>{t('new_messages')}</h3>
                <span className="feed-side-panel-count">{unreadMessages}</span>
              </div>
              <div className="panel-body">
                {unreadMessagesLoading ? <SkeletonRows count={1} /> : null}
                {!unreadMessagesLoading && unreadMessagesError ? (
                  <EmptyPanelState message={t('no_new_messages')} actionLabel={t('games_refresh')} onRetry={() => loadUnreadMessages({ background: false })} />
                ) : null}
                {!unreadMessagesLoading && !unreadMessagesError ? (
                  <Link to="/new/messages">
                    {unreadMessages > 0 ? t('unread_messages_count', { count: unreadMessages }) : t('no_new_messages')}
                  </Link>
                ) : null}
              </div>
            </div>
          </div>

          <div className={`feed-tab-panel feed-side-livechat ${mobileTab === 'livechat' ? 'is-active' : ''}`}>
            {mountLiveChat || mobileTab === 'livechat' ? (
              <LiveChatPanel />
            ) : (
              <div className="panel"><div className="panel-body"><SkeletonRows count={4} /></div></div>
            )}
          </div>

          <div className={`panel feed-tab-panel feed-side-panel feed-side-panel-muted ${mobileTab === 'quick' ? 'is-active' : ''}`}>
            <div className="feed-side-panel-heading">
              <h3>{t('quick_access')}</h3>
              <span className="feed-side-panel-count">{quickUsers.length}</span>
            </div>
            <div className="panel-body">
              {quickAccessLoading ? <SkeletonRows count={3} /> : null}
              {!quickAccessLoading && quickAccessError ? (
                <EmptyPanelState message={t('feed_discover_members')} actionLabel={t('games_refresh')} onRetry={() => loadQuickAccess({ background: false })} />
              ) : null}
              {!quickAccessLoading && !quickAccessError && quickUsers.map((u) => (
                <Link key={u.id} className="verify-user feed-member-row" to={`/new/members/${u.id}`}>
                  <img className="avatar" src={u.resim ? `/api/media/vesikalik/${u.resim}` : '/legacy/vesikalik/nophoto.jpg'} loading="lazy" decoding="async" alt={avatarAlt(u)} />
                  <div>
                    <div>@{u.kadi}</div>
                    <div className="meta">
                      <span className={`feed-member-status-dot ${Number(u.online) === 1 ? 'is-online' : 'is-offline'}`} aria-hidden="true" />
                      {Number(u.online) === 1 ? t('status_online') : t('status_offline')}
                    </div>
                  </div>
                </Link>
              ))}
              <div className="feed-quick-links">
                {quickLinks.map((item) => (
                  <Link key={item.to} className="feed-quick-link" to={item.to}>
                    <span className="feed-quick-link-icon" aria-hidden="true"><AnimatedIcon name={FEED_ICON_MAP[item.icon] || 'home'} size={16} /></span>
                    <span>{item.label}</span>
                  </Link>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layout>
  );
}
