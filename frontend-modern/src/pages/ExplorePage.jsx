import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import AnimatedIcon from '../components/AnimatedIcon.jsx';
import { emitAppChange } from '../utils/live.js';
import { readApiPayload, unwrapApiData } from '../utils/api.js';
import { useI18n } from '../utils/i18n.jsx';
import { useAuth } from '../utils/auth.jsx';
import { NETWORKING_TELEMETRY_EVENTS, sendNetworkingTelemetry } from '../utils/networkingTelemetry.js';
import {
  getConnectionActionEvent,
  NETWORKING_EVENTS,
  NETWORKING_MESSAGES
} from '../utils/networkingRegistry.js';
import { avatarAlt } from '../utils/a11y.js';
import { openAlert } from '../utils/dialogs.js';

const EXPLORE_ICON_MAP = {
  compass: 'compass',
  spark: 'sparkles',
  people: 'users',
  online: 'users',
  filter: 'sliders-horizontal',
  search: 'search'
};

function getExploreMobileMatch() {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return false;
  return window.matchMedia('(max-width: 680px)').matches;
}

export default function ExplorePage({ fullMode = false }) {
  const { t, lang } = useI18n();
  const { user, loading: authLoading } = useAuth();
  const [members, setMembers] = useState([]);
  const [suggestions, setSuggestions] = useState([]);
  const [followingIds, setFollowingIds] = useState(() => new Set());
  const [incomingConnectionMap, setIncomingConnectionMap] = useState({});
  const [outgoingConnectionMap, setOutgoingConnectionMap] = useState({});
  const [pendingFollow, setPendingFollow] = useState({});
  const [pendingConnection, setPendingConnection] = useState({});
  const [isMobile, setIsMobile] = useState(getExploreMobileMatch);
  const [mobileFiltersOpen, setMobileFiltersOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [filters, setFilters] = useState({
    relation: 'all',
    verified: false,
    withPhoto: false,
    online: false,
    gradYear: '',
    location: '',
    profession: '',
    expertise: '',
    title: '',
    mentors: false,
    sort: 'recommended'
  });
  const [loading, setLoading] = useState(false);
  const [loadingSuggestions, setLoadingSuggestions] = useState(false);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(1);
  const suggestionTelemetrySentRef = useRef(false);
  const defaultGradYearAppliedRef = useRef(false);

  const yearNow = new Date().getFullYear();
  const yearOptions = useMemo(() => {
    const items = [];
    for (let y = yearNow + 1; y >= 1970; y -= 1) items.push(y);
    return items;
  }, [yearNow]);
  const todayLabel = useMemo(() => {
    try {
      return new Intl.DateTimeFormat(lang || undefined, {
        weekday: 'long',
        month: 'long',
        day: 'numeric'
      }).format(new Date());
    } catch {
      return '';
    }
  }, [lang]);
  const defaultGradYear = useMemo(() => {
    const raw = String(user?.mezuniyetyili || '').trim();
    return /^\d{4}$/.test(raw) ? raw : '';
  }, [user?.mezuniyetyili]);
  const discoveryLinks = useMemo(() => ([
    { to: '/new/network/hub', label: t('network_hub_title'), note: t('hub_section_priority_desc') },
    { to: '/new/following', label: t('nav_following'), note: t('following_connections_note') },
    { to: '/new/network/teachers', label: t('nav_teacher_network'), note: t('trust_badge_teacher_network') },
    { to: '/new/messenger', label: t('nav_messenger'), note: t('messenger_private_note') }
  ]), [t]);

  const load = useCallback(async (term = '', nextPage = 1, activeFilters = filters) => {
    setLoading(true);
    const params = new URLSearchParams();
    params.set('page', String(nextPage));
    params.set('pageSize', '30');
    params.set('excludeSelf', '1');
    params.set('term', term || '');
    params.set('sort', activeFilters.sort || 'recommended');
    if (activeFilters.relation !== 'all') params.set('relation', activeFilters.relation);
    if (activeFilters.verified) params.set('verified', '1');
    if (activeFilters.withPhoto) params.set('withPhoto', '1');
    if (activeFilters.online) params.set('online', '1');
    if (activeFilters.gradYear && Number(activeFilters.gradYear) > 0) params.set('gradYear', String(activeFilters.gradYear));
    if (activeFilters.location && activeFilters.location.trim()) params.set('location', activeFilters.location.trim());
    if (activeFilters.profession && activeFilters.profession.trim()) params.set('profession', activeFilters.profession.trim());
    if (activeFilters.expertise && activeFilters.expertise.trim()) params.set('expertise', activeFilters.expertise.trim());
    if (activeFilters.title && activeFilters.title.trim()) params.set('title', activeFilters.title.trim());
    if (activeFilters.mentors) params.set('mentors', '1');

    const res = await fetch(`/api/members?${params.toString()}`, { credentials: 'include' });
    const payload = await res.json();
    setMembers(payload.rows || []);
    setPage(payload.page || nextPage);
    setPages(payload.pages || 1);
    setLoading(false);
  }, [filters]);

  const loadSuggestions = useCallback(async () => {
    setLoadingSuggestions(true);
    try {
      const res = await fetch('/api/new/explore/suggestions?limit=24&offset=0', { credentials: 'include' });
      if (!res.ok) {
        setSuggestions([]);
        return;
      }
      const payload = await res.json();
      const data = unwrapApiData(payload) || payload;
      setSuggestions(data.items || []);
      if (!suggestionTelemetrySentRef.current) {
        suggestionTelemetrySentRef.current = true;
        void sendNetworkingTelemetry({
          eventName: NETWORKING_TELEMETRY_EVENTS.exploreSuggestionsLoaded,
          sourceSurface: 'explore_page',
          entityType: 'suggestion_batch',
          metadata: {
            suggestion_count: Array.isArray(data.items) ? data.items.length : 0,
            experiment_variant: String(data.experiment_variant || 'A')
          }
        });
      }
    } finally {
      setLoadingSuggestions(false);
    }
  }, []);

  const loadFollows = useCallback(async () => {
    const res = await fetch('/api/new/follows', { credentials: 'include' });
    if (!res.ok) return;
    const payload = await res.json();
    const next = new Set((payload.items || []).map((item) => Number(item.following_id)));
    setFollowingIds(next);
  }, []);

  const loadConnectionRequests = useCallback(async () => {
    const [incomingRes, outgoingRes] = await Promise.all([
      fetch('/api/new/connections/requests?direction=incoming&status=pending&limit=100&offset=0', { credentials: 'include' }),
      fetch('/api/new/connections/requests?direction=outgoing&status=pending&limit=100&offset=0', { credentials: 'include' })
    ]);
    if (!incomingRes.ok || !outgoingRes.ok) return;
    const [incomingRaw, outgoingRaw] = await Promise.all([incomingRes.json(), outgoingRes.json()]);
    const incomingPayload = unwrapApiData(incomingRaw) || incomingRaw;
    const outgoingPayload = unwrapApiData(outgoingRaw) || outgoingRaw;
    const incoming = {};
    for (const item of (incomingPayload.items || [])) {
      incoming[Number(item.sender_id)] = Number(item.id);
    }
    setIncomingConnectionMap(incoming);
    const outgoing = {};
    for (const item of (outgoingPayload.items || [])) {
      const receiverId = Number(item.receiver_id || 0);
      if (!receiverId) continue;
      outgoing[receiverId] = Number(item.id || 0);
    }
    setOutgoingConnectionMap(outgoing);
  }, []);

  useEffect(() => {
    if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return undefined;
    const mq = window.matchMedia('(max-width: 680px)');
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
    if (!isMobile) return;
    setMobileFiltersOpen(false);
  }, [isMobile]);

  useEffect(() => {
    if (authLoading || defaultGradYearAppliedRef.current) return;
    defaultGradYearAppliedRef.current = true;
    if (!defaultGradYear) return;
    setFilters((prev) => (prev.gradYear ? prev : { ...prev, gradYear: defaultGradYear }));
  }, [authLoading, defaultGradYear]);

  useEffect(() => {
    void sendNetworkingTelemetry({
      eventName: NETWORKING_TELEMETRY_EVENTS.exploreViewed,
      sourceSurface: 'explore_page',
      metadata: { full_mode: Boolean(fullMode) }
    });
    loadFollows();
    loadConnectionRequests();
    loadSuggestions();
  }, [fullMode, loadFollows, loadSuggestions, loadConnectionRequests]);

  useEffect(() => {
    if (authLoading) return undefined;
    const timer = setTimeout(() => {
      load(query, 1, filters);
    }, 280);
    return () => clearTimeout(timer);
  }, [authLoading, query, filters, load]);

  async function toggleFollow(id) {
    const key = Number(id);
    if (pendingFollow[key]) return;
    setPendingFollow((prev) => ({ ...prev, [key]: true }));
    try {
      const res = await fetch(`/api/new/follow/${id}`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ source_surface: 'explore_page' })
      });
      if (!res.ok) return;
      setFollowingIds((prev) => {
        const next = new Set(prev);
        if (next.has(key)) next.delete(key);
        else next.add(key);
        return next;
      });
      setSuggestions((prev) => prev.filter((u) => Number(u.id) !== key));
      emitAppChange(NETWORKING_EVENTS.followChanged, { userId: id });
      loadSuggestions();
    } finally {
      setPendingFollow((prev) => ({ ...prev, [key]: false }));
    }
  }

  async function sendConnectionRequest(id) {
    const key = Number(id);
    if (pendingConnection[key]) return;
    setPendingConnection((prev) => ({ ...prev, [key]: true }));
    try {
      const incomingRequestId = Number(incomingConnectionMap[key] || 0);
      const outgoingRequestId = Number(outgoingConnectionMap[key] || 0);
      const endpoint = incomingRequestId
        ? `/api/new/connections/accept/${incomingRequestId}`
        : outgoingRequestId
          ? `/api/new/connections/cancel/${outgoingRequestId}`
          : `/api/new/connections/request/${id}`;
      const res = await fetch(endpoint, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ source_surface: 'explore_page' })
      });
      if (!res.ok) {
        const { message } = await readApiPayload(res, NETWORKING_MESSAGES.errors.connectionActionFailed);
        if (res.status === 409 && message.toLowerCase().includes('zaten bekleyen bir bağlantı isteği')) {
          await loadConnectionRequests();
        }
        await openAlert({ title: t('connection_request'), message, tone: 'error' });
        return;
      }
      emitAppChange(getConnectionActionEvent({ incomingRequestId, outgoingRequestId }), { userId: id });
      if (incomingRequestId) {
        setIncomingConnectionMap((prev) => {
          const next = { ...prev };
          delete next[key];
          return next;
        });
        setOutgoingConnectionMap((prev) => {
          const next = { ...prev };
          delete next[key];
          return next;
        });
      } else if (outgoingRequestId) {
        setOutgoingConnectionMap((prev) => {
          const next = { ...prev };
          delete next[key];
          return next;
        });
      }
      loadFollows();
      loadConnectionRequests();
    } finally {
      setPendingConnection((prev) => ({ ...prev, [key]: false }));
    }
  }

  function setFilter(key, value) {
    setFilters((prev) => ({ ...prev, [key]: value }));
  }

  function renderTrustBadges(member) {
    const badges = Array.isArray(member?.trust_badges) ? member.trust_badges : [];
    if (!badges.length) return null;
    return (
      <div className="composer-actions">
        {badges.includes('verified_alumni') ? <span className="chip">{t('trust_badge_verified_alumni')}</span> : null}
        {badges.includes('mentor') ? <span className="chip">{t('trust_badge_mentor')}</span> : null}
        {badges.includes('teacher_network') ? <span className="chip">{t('trust_badge_teacher_network')}</span> : null}
      </div>
    );
  }

  function renderMemberCard(m, showReasons = false) {
    return (
      <div
        className={`explore-member-card ${showReasons ? 'is-suggested' : ''} ${Number(m.online || 0) === 1 ? 'is-online' : ''}`}
        key={`${showReasons ? 's' : 'm'}-${m.id}`}
      >
        <div className="explore-member-media">
          <Link to={`/new/members/${m.id}`}>
            <img src={m.resim ? `/api/media/vesikalik/${m.resim}` : '/legacy/vesikalik/nophoto.jpg'} alt={avatarAlt(m)} />
          </Link>
          <span className={`explore-member-presence ${Number(m.online || 0) === 1 ? 'is-online' : 'is-offline'}`} aria-hidden="true" />
        </div>
        <div className="explore-member-body">
          <div className="name">
            {m.isim} {m.soyisim}
            {m.verified ? <span className="badge">✓</span> : null}
          </div>
          <div className="handle">@{m.kadi}</div>
          <div className="meta">{m.mezuniyetyili || ''}{Number(m.online || 0) === 1 ? ` · ${t('status_online')}` : ''}</div>
          {m.unvan || m.sirket ? <div className="meta">{[m.unvan, m.sirket].filter(Boolean).join(' @ ')}</div> : null}
          {m.uzmanlik ? <div className="meta">{m.uzmanlik}</div> : null}
          {renderTrustBadges(m)}
          {showReasons && Array.isArray(m.reasons) && m.reasons.length ? (
            <div className="explore-chip-row explore-reason-row">
              {m.reasons.slice(0, 2).map((r) => <span className="chip explore-reason-chip" key={`${m.id}-${r}`}>{r}</span>)}
            </div>
          ) : null}
        </div>
        <div className="composer-actions explore-member-actions">
          {Boolean(m.verified) ? (
            <button
              className="btn ghost"
              onClick={() => sendConnectionRequest(m.id)}
              disabled={Boolean(pendingConnection[Number(m.id)])}
            >
              {incomingConnectionMap[Number(m.id)]
                ? t('connection_accept')
                : outgoingConnectionMap[Number(m.id)]
                  ? t('connection_withdraw')
                  : t('connection_request')}
            </button>
          ) : null}
          {String(m.role || '').toLowerCase() === 'teacher' ? (
            <Link className="btn ghost" to={`/new/network/teachers?teacherId=${m.id}`}>
              Öğretmen Ağına Ekle
            </Link>
          ) : null}
          <button
            className="btn ghost"
            onClick={() => toggleFollow(m.id)}
            disabled={Boolean(pendingFollow[Number(m.id)])}
          >
            {followingIds.has(Number(m.id)) ? t('unfollow') : t('follow')}
          </button>
        </div>
      </div>
    );
  }

  const suggestionItems = fullMode ? suggestions : suggestions.slice(0, 6);
  const spotlightSuggestion = suggestionItems[0] || null;
  const suggestionRailItems = spotlightSuggestion ? (fullMode ? suggestionItems.slice(1) : suggestionItems.slice(1, 5)) : [];
  const visibleMembers = fullMode ? members : members.slice(0, 18);
  const activeFilterTags = useMemo(() => {
    const items = [];
    if (query.trim()) items.push(query.trim());
    if (filters.relation !== 'all') {
      items.push(filters.relation === 'following' ? t('nav_following') : t('explore_relation_not_following'));
    }
    if (filters.verified) items.push(t('verified'));
    if (filters.withPhoto) items.push(t('with_photo'));
    if (filters.online) items.push(t('status_online'));
    if (filters.mentors) items.push(t('mentors'));
    if (filters.gradYear) items.push(String(filters.gradYear));
    if (filters.location.trim()) items.push(filters.location.trim());
    if (filters.profession.trim()) items.push(filters.profession.trim());
    if (filters.expertise.trim()) items.push(filters.expertise.trim());
    if (filters.title.trim()) items.push(filters.title.trim());
    if (filters.sort !== 'recommended') {
      const sortLabelMap = {
        engagement: t('sort_engagement'),
        name: t('sort_name'),
        recent: t('sort_recent_members'),
        online: t('sort_online_first'),
        year: t('sort_graduation_year')
      };
      items.push(sortLabelMap[filters.sort] || t('sort_recommended'));
    }
    return items;
  }, [filters, query, t]);
  const mobileFilterSummary = activeFilterTags.length ? activeFilterTags.slice(0, 2).join(' · ') : t('explore_filtered_hint');
  const showFilterBody = !isMobile || mobileFiltersOpen;
  const goToPage = useCallback((nextPage) => {
    if (!fullMode || loading || nextPage < 1 || nextPage > pages || nextPage === page) return;
    load(query, nextPage, filters);
  }, [filters, fullMode, load, loading, page, pages, query]);
  const suggestionsPanel = (
    <div className="panel explore-panel explore-panel-suggestions">
      <div className="explore-panel-heading">
        <div>
          <span className="explore-panel-eyebrow">{t('explore_suggestions_title')}</span>
          <h3>{t('explore_suggestions_title')}</h3>
        </div>
        <span className="explore-panel-count">{suggestions.length}</span>
      </div>
      <div className="panel-body">
        {loadingSuggestions ? <div className="explore-inline-state">{t('explore_suggestions_loading')}</div> : null}
        {!loadingSuggestions && suggestions.length === 0 ? (
          <div className="network-empty-state">
            <strong>{t('explore_suggestions_empty')}</strong>
            <span>{t('explore_filtered_hint')}</span>
          </div>
        ) : null}
        {spotlightSuggestion ? (
          <div className="explore-suggestion-layout">
            <div className="explore-suggestion-spotlight">
              {renderMemberCard(spotlightSuggestion, true)}
            </div>
            <div className="explore-suggestion-rail">
              {suggestionRailItems.map((m) => (
                <div key={`suggestion-rail-${m.id}`} className="explore-suggestion-rail-item">
                  {renderMemberCard(m, true)}
                </div>
              ))}
            </div>
          </div>
        ) : null}
        {!fullMode ? <Link className="btn ghost explore-panel-link" to="/new/explore/suggestions">{t('see_all')}</Link> : null}
      </div>
    </div>
  );
  const filterPanel = (
    <div className="panel explore-panel explore-filter-panel">
      <div className="explore-panel-heading">
        <div>
          <span className="explore-panel-eyebrow">{t('explore_filtered_title')}</span>
          <h3>{t('explore_filtered_title')}</h3>
        </div>
        <span className="explore-panel-count">{activeFilterTags.length}</span>
      </div>
      {isMobile ? (
        <button
          type="button"
          className={`btn ghost explore-panel-toggle ${mobileFiltersOpen ? 'is-open' : ''}`}
          onClick={() => setMobileFiltersOpen((prev) => !prev)}
          aria-expanded={mobileFiltersOpen}
        >
          <span className="explore-panel-toggle-copy">
            <strong>{mobileFiltersOpen ? t('close') : t('open')}</strong>
            <span>{mobileFilterSummary}</span>
          </span>
          <span className={`explore-panel-toggle-icon ${mobileFiltersOpen ? 'is-open' : ''}`} aria-hidden="true">
            <AnimatedIcon name="chevron-down" size={18} />
          </span>
        </button>
      ) : null}
      {showFilterBody ? (
        <div className="panel-body stack">
          <div className="muted">{t('explore_filtered_hint')}</div>
          <label className="explore-search-shell">
            <span className="explore-search-icon" aria-hidden="true"><AnimatedIcon name={EXPLORE_ICON_MAP.search} size={18} /></span>
            <input className="search explore-search-input" placeholder={t('member_search_short')} value={query} onChange={(e) => setQuery(e.target.value)} />
          </label>
          <div className="explore-filter-row">
            <select className="input explore-filter-input" value={filters.relation} onChange={(e) => setFilter('relation', e.target.value)}>
              <option value="all">{t('everyone')}</option>
              <option value="not_following">{t('explore_relation_not_following')}</option>
              <option value="following">{t('nav_following')}</option>
            </select>
            <select className="input explore-filter-input" value={filters.sort} onChange={(e) => setFilter('sort', e.target.value)}>
              <option value="recommended">{t('sort_recommended')}</option>
              <option value="engagement">{t('sort_engagement')}</option>
              <option value="name">{t('sort_name')}</option>
              <option value="recent">{t('sort_recent_members')}</option>
              <option value="online">{t('sort_online_first')}</option>
              <option value="year">{t('sort_graduation_year')}</option>
            </select>
            <select className="input explore-filter-input" value={filters.gradYear} onChange={(e) => setFilter('gradYear', e.target.value)}>
              <option value="">{t('all_years')}</option>
              {yearOptions.map((y) => <option key={y} value={y}>{y}</option>)}
            </select>
          </div>
          <div className="explore-chip-row">
            <label className={`chip explore-filter-chip ${filters.verified ? 'is-active' : ''}`}>
              <input type="checkbox" checked={filters.verified} onChange={(e) => setFilter('verified', e.target.checked)} />
              {t('verified')}
            </label>
            <label className={`chip explore-filter-chip ${filters.withPhoto ? 'is-active' : ''}`}>
              <input type="checkbox" checked={filters.withPhoto} onChange={(e) => setFilter('withPhoto', e.target.checked)} />
              {t('with_photo')}
            </label>
            <label className={`chip explore-filter-chip ${filters.online ? 'is-active' : ''}`}>
              <input type="checkbox" checked={filters.online} onChange={(e) => setFilter('online', e.target.checked)} />
              {t('status_online')}
            </label>
            <label className={`chip explore-filter-chip ${filters.mentors ? 'is-active' : ''}`}>
              <input type="checkbox" checked={filters.mentors} onChange={(e) => setFilter('mentors', e.target.checked)} />
              {t('mentors')}
            </label>
          </div>
          <div className="explore-filter-row">
            <input className="input explore-filter-input" placeholder={t('location')} value={filters.location} onChange={(e) => setFilter('location', e.target.value)} />
            <input className="input explore-filter-input" placeholder={t('profession')} value={filters.profession} onChange={(e) => setFilter('profession', e.target.value)} />
            <input className="input explore-filter-input" placeholder={t('profile_expertise')} value={filters.expertise} onChange={(e) => setFilter('expertise', e.target.value)} />
            <input className="input explore-filter-input" placeholder={t('profile_title')} value={filters.title} onChange={(e) => setFilter('title', e.target.value)} />
          </div>
          {activeFilterTags.length ? (
            <div className="explore-active-filter-list">
              {activeFilterTags.slice(0, 8).map((tag) => <span key={`active-filter-${tag}`} className="explore-active-filter">{tag}</span>)}
            </div>
          ) : null}
          {loading ? <div className="explore-inline-state">{t('searching')}</div> : null}
          {!fullMode ? <Link className="btn ghost explore-panel-link" to="/new/explore/members">{t('see_all')}</Link> : null}
        </div>
      ) : null}
    </div>
  );
  return (
    <Layout title={t('nav_explore')}>
      <div className="explore-page-shell">
        <section className="panel explore-hero-panel">
          <div className="explore-hero-copy">
            <div className="explore-hero-kicker">
              <span className="explore-hero-mark"><AnimatedIcon name={EXPLORE_ICON_MAP.compass} size={18} />{t('nav_explore')}</span>
              {todayLabel ? <span className="explore-hero-date">{todayLabel}</span> : null}
            </div>
            <div className="explore-hero-heading">
              <div>
                <h2 className="explore-hero-title">{t('explore_connections_title')}</h2>
                <p className="explore-hero-subtitle">{t('explore_connections_note')}</p>
              </div>
              <div className="explore-hero-tags">
                {(activeFilterTags.length ? activeFilterTags : [t('everyone'), t('sort_recommended')]).slice(0, 4).map((tag) => (
                  <span key={`explore-tag-${tag}`} className="explore-hero-tag">{tag}</span>
                ))}
              </div>
            </div>
          </div>
          <div className="network-hero-actions">
            <Link className="btn ghost" to="/new/network/hub">{t('network_hub_title')}</Link>
            <Link className="btn ghost" to="/new/following">{t('nav_following')}</Link>
          </div>
        </section>

        <section className="panel category-map-panel">
          <div className="category-map-head">
            <div>
              <span className="category-map-kicker">{t('network_category_title')}</span>
              <h3>{t('explore_connections_title')}</h3>
              <p>{t('explore_connections_note')}</p>
            </div>
            <span className="chip">{t('connection_request')}</span>
          </div>
          <div className="category-map-grid">
            {discoveryLinks.map((item) => (
              <Link key={item.to} className="category-map-card" to={item.to}>
                <strong>{item.label}</strong>
                <span>{item.note}</span>
              </Link>
            ))}
          </div>
        </section>

        <div className="explore-discovery-grid">
          {!isMobile ? suggestionsPanel : null}
          {filterPanel}
        </div>

        <section className="panel explore-results-stage">
          <div className="explore-results-head">
            <div>
              <h3>{t('members')}</h3>
              <div className="muted">{t('explore_filtered_hint')}</div>
            </div>
            <span className="explore-panel-count">{visibleMembers.length}</span>
          </div>

          {visibleMembers.length > 0 ? (
            <div className="explore-card-grid">
              {visibleMembers.map((m) => renderMemberCard(m, false))}
            </div>
          ) : null}
          {!loading && visibleMembers.length === 0 ? (
            <div className="network-empty-state explore-empty-state">
              <strong>{t('no_results')}</strong>
              <span>{t('explore_filtered_hint')}</span>
            </div>
          ) : null}
          {fullMode && pages > 1 ? (
            <div className="explore-pagination">
              <button className="btn ghost" onClick={() => goToPage(page - 1)} disabled={loading || page <= 1}>{t('back')}</button>
              <span className="chip explore-pagination-status">{page} / {pages}</span>
              <button className="btn ghost" onClick={() => goToPage(page + 1)} disabled={loading || page >= pages}>{t('next')}</button>
            </div>
          ) : null}
        </section>
        {isMobile ? suggestionsPanel : null}
        {fullMode && loading ? <div className="explore-inline-state">{t('loading')}</div> : null}
      </div>
    </Layout>
  );
}
