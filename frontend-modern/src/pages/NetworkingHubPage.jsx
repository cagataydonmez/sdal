import React, { useEffect } from 'react';
import { Link, useSearchParams } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { useNetworkingHubState } from '../hooks/useNetworkingHubState.js';
import { useI18n } from '../utils/i18n.jsx';
import { useNotificationNavigationTracking } from '../utils/notificationNavigation.js';
import { NETWORKING_TELEMETRY_EVENTS, sendNetworkingTelemetry } from '../utils/networkingTelemetry.js';
import { avatarAlt } from '../utils/a11y.js';

function getNetworkingMobileMatch() {
  if (typeof window === 'undefined' || typeof window.matchMedia !== 'function') return false;
  return window.matchMedia('(max-width: 760px)').matches;
}

function daysSince(value) {
  if (!value) return null;
  const ts = new Date(value).getTime();
  if (!Number.isFinite(ts)) return null;
  return Math.floor((Date.now() - ts) / (24 * 60 * 60 * 1000));
}

function staleHint(value, t) {
  const age = daysSince(value);
  if (age == null || age < 7) return null;
  if (age >= 30) return t('network_hub_stale_30d');
  return t('network_hub_stale_7d');
}

function readConnectionUserField(item, legacyKey, modernKey) {
  return item?.[legacyKey] || item?.[modernKey] || '';
}

function avatarUrl(photo) {
  return photo ? `/api/media/vesikalik/${photo}` : '/legacy/vesikalik/nophoto.jpg';
}

function PersonLink({ href, photo, name, handle, meta }) {
  const person = { isim: name, kadi: handle };
  return (
    <div className="network-person-block">
      <Link to={href} className="network-avatar-link">
        <img src={avatarUrl(photo)} alt={avatarAlt(person)} />
      </Link>
      <div className="network-person-copy">
        <div className="network-person-name">{name}</div>
        <div className="network-person-handle">@{handle}</div>
        {meta ? <div className="network-person-meta">{meta}</div> : null}
      </div>
    </div>
  );
}

function SectionCard({ sectionId, title, kicker, description, count, actions, children }) {
  return (
    <section id={sectionId} className="panel network-section-card">
      <div className="network-section-head">
        <div>
          <span className="network-section-kicker">{kicker}</span>
          <h3>{title}</h3>
          {description ? <p>{description}</p> : null}
        </div>
        <div className="network-section-tools">
          {typeof count === 'number' ? <span className="chip">{count}</span> : null}
          {actions}
        </div>
      </div>
      <div className="panel-body network-section-body">{children}</div>
    </section>
  );
}

function LoadingState({ label, description }) {
  return (
    <div className="network-empty-state network-loading-state">
      <strong>{label}</strong>
      <span>{description}</span>
    </div>
  );
}

function EmptyState({ title, description, actionLabel, actionHref }) {
  return (
    <div className="network-empty-state">
      <strong>{title}</strong>
      <span>{description}</span>
      {actionLabel && actionHref ? <Link className="btn ghost" to={actionHref}>{actionLabel}</Link> : null}
    </div>
  );
}

function PriorityCard({ label, count, title, description, actionLabel, actionHref, tone = 'neutral' }) {
  return (
    <article className={`network-priority-card network-priority-card-${tone}`}>
      <div className="network-priority-head">
        <span className="network-priority-label">{label}</span>
        <span className="chip">{count}</span>
      </div>
      <strong>{title}</strong>
      <p>{description}</p>
      <Link className="btn ghost" to={actionHref}>{actionLabel}</Link>
    </article>
  );
}

export default function NetworkingHubPage() {
  const { t } = useI18n();
  const [isMobile, setIsMobile] = React.useState(getNetworkingMobileMatch);
  const [mobileHeroToolsOpen, setMobileHeroToolsOpen] = React.useState(false);
  const [mobileMetricsOpen, setMobileMetricsOpen] = React.useState(false);
  const [mobilePriorityOpen, setMobilePriorityOpen] = React.useState(false);
  const [searchParams] = useSearchParams();
  const { state, actions } = useNetworkingHubState(t);
  const {
    bootstrapping,
    hubRefreshing,
    discoveryLoading,
    metricsWindow,
    metrics,
    loadError,
    loadNotice,
    feedback,
    incoming,
    outgoing,
    incomingMentorship,
    outgoingMentorship,
    teacherEvents,
    teacherUnreadCount,
    suggestions,
    followingIds,
    incomingConnectionMap,
    outgoingConnectionMap,
    pendingAction
  } = state;
  const actionableCount = incoming.length + incomingMentorship.length + teacherUnreadCount;
  const focusedSection = String(searchParams.get('section') || '').trim();
  const focusedRequestId = Number(searchParams.get('request') || 0);
  const focusedNotificationId = Number(searchParams.get('notification') || 0);
  const notificationLandingResolved = !focusedNotificationId || (
    focusedSection === 'incoming-connections'
      ? incoming.some((item) => Number(item.id || 0) === focusedRequestId)
      : focusedSection === 'incoming-mentorship'
        ? incomingMentorship.some((item) => Number(item.id || 0) === focusedRequestId)
        : focusedSection === 'outgoing-connections'
          ? outgoing.some((item) => Number(item.id || 0) === focusedRequestId)
          : focusedSection === 'outgoing-mentorship'
            ? outgoingMentorship.some((item) => Number(item.id || 0) === focusedRequestId)
            : focusedSection === 'teacher-notifications'
              ? teacherEvents.some((item) => Number(item.id || 0) === focusedNotificationId)
              : Boolean(focusedSection)
  );

  useNotificationNavigationTracking(focusedNotificationId, {
    surface: 'network_hub',
    resolved: notificationLandingResolved
  });

  useEffect(() => {
    void sendNetworkingTelemetry({
      eventName: NETWORKING_TELEMETRY_EVENTS.hubViewed,
      sourceSurface: 'network_hub'
    });
  }, []);

  useEffect(() => {
    if (!focusedSection || typeof document === 'undefined') return;
    const timer = window.setTimeout(() => {
      const node = document.getElementById(focusedSection);
      node?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }, 180);
    return () => window.clearTimeout(timer);
  }, [focusedSection, bootstrapping]);

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
    if (!isMobile) {
      setMobileHeroToolsOpen(false);
      setMobileMetricsOpen(false);
      setMobilePriorityOpen(false);
    }
  }, [isMobile]);

  const priorityCards = [
    incoming.length > 0
      ? {
          key: 'incoming',
          tone: 'hot',
          label: t('hub_priority_connections_label'),
          count: incoming.length,
          title: t('hub_priority_connections_title', { count: incoming.length }),
          description: t('hub_priority_connections_desc'),
          actionLabel: t('hub_priority_action_review'),
          actionHref: '#incoming-connections'
        }
      : {
          key: 'incoming',
          tone: 'calm',
          label: t('hub_priority_connections_label'),
          count: 0,
          title: t('hub_priority_clean_title'),
          description: t('hub_priority_clean_desc'),
          actionLabel: t('hub_priority_action_suggestions'),
          actionHref: '#network-suggestions'
        },
    incomingMentorship.length > 0
      ? {
          key: 'mentorship',
          tone: 'warm',
          label: t('hub_priority_mentorship_label'),
          count: incomingMentorship.length,
          title: t('hub_priority_mentorship_title', { count: incomingMentorship.length }),
          description: t('hub_priority_mentorship_desc'),
          actionLabel: t('hub_priority_action_mentorship'),
          actionHref: '#incoming-mentorship'
        }
      : {
          key: 'mentorship',
          tone: 'calm',
          label: t('hub_priority_mentorship_label'),
          count: 0,
          title: t('hub_priority_no_mentorship_title'),
          description: t('hub_priority_no_mentorship_desc'),
          actionLabel: t('hub_priority_action_profile'),
          actionHref: '/new/profile'
        },
    teacherUnreadCount > 0
      ? {
          key: 'teacher',
          tone: 'accent',
          label: t('hub_priority_teacher_label'),
          count: teacherUnreadCount,
          title: t('hub_priority_teacher_title', { count: teacherUnreadCount }),
          description: t('hub_priority_teacher_desc'),
          actionLabel: t('hub_priority_action_notifications'),
          actionHref: '#teacher-notifications'
        }
      : {
          key: 'teacher',
          tone: 'calm',
          label: t('hub_priority_teacher_label'),
          count: 0,
          title: t('hub_priority_no_teacher_title'),
          description: t('hub_priority_no_teacher_desc'),
          actionLabel: t('hub_priority_action_teacher_network'),
          actionHref: '/new/network/teachers'
        }
  ];
  const visiblePriorityCards = isMobile && !mobilePriorityOpen
    ? (() => {
        const actionableCards = priorityCards.filter((card) => Number(card.count || 0) > 0);
        return actionableCards.length ? actionableCards.slice(0, 1) : priorityCards.slice(0, 1);
      })()
    : priorityCards;
  const hasNetworkFeedback = Boolean(feedback.message || loadError || loadNotice);

  return (
    <Layout title={t('network_hub_title')}>
      <div className="network-mobile-lead">
        <section className={`network-hero ${isMobile ? 'is-mobile-condensed' : ''}`}>
          <div className="network-hero-copy">
            <span className="network-eyebrow">Ağ merkezi</span>
            <h2>{t('network_hub_intro_title')}</h2>
            {!isMobile ? <p>{t('network_hub_intro_subtitle')}</p> : null}
          </div>
          <div className="network-hero-actions">
            <Link className="btn primary" to="/new/explore">{t('hub_action_discover')}</Link>
            {isMobile ? (
              <button className="btn ghost" type="button" onClick={() => setMobileHeroToolsOpen((value) => !value)} aria-expanded={mobileHeroToolsOpen}>
                {mobileHeroToolsOpen ? 'Araçları kapat' : 'Araçlar'}
              </button>
            ) : null}
            {!isMobile || mobileHeroToolsOpen ? (
              <>
                <Link className="btn ghost" to="/new/network/teachers">{t('hub_action_teacher_network')}</Link>
                <Link className="btn ghost" to="/new/messages">{t('hub_action_messages')}</Link>
                {hubRefreshing ? <span className="chip">{t('hub_status_updating')}</span> : null}
              </>
            ) : null}
          </div>
        </section>

        {hasNetworkFeedback ? (
          <div className="network-feedback-slot">
            {feedback.message ? <div className={feedback.type === 'error' ? 'error' : 'ok'}>{feedback.message}</div> : null}
            {loadError ? <div className="error">{loadError}</div> : null}
            {loadNotice ? <div className="network-soft-alert">{loadNotice}</div> : null}
          </div>
        ) : null}

        <section className="panel network-priority-strip">
          <div className="network-section-head">
            <div>
              <span className="network-section-kicker">{t('hub_section_priority_kicker')}</span>
              <h3>{t('hub_section_priority_title')}</h3>
              <p>{t('hub_section_priority_desc')}</p>
            </div>
            <div className="network-section-tools">
              <span className="chip">{t('hub_tools_open_count', { count: actionableCount })}</span>
              {isMobile && priorityCards.length > 1 ? (
                <button className="btn ghost" type="button" onClick={() => setMobilePriorityOpen((value) => !value)} aria-expanded={mobilePriorityOpen}>
                  {mobilePriorityOpen ? 'Öncelikleri kapat' : 'Öncelikleri aç'}
                </button>
              ) : null}
            </div>
          </div>
          <div className="panel-body network-section-body">
            <div className="network-priority-grid">
              {visiblePriorityCards.map((card) => (
                <PriorityCard key={card.key} {...card} />
              ))}
            </div>
          </div>
        </section>
      </div>

      <section id="health-snapshot" className="panel network-section-card">
        <div className="network-section-head">
          <div>
            <span className="network-section-kicker">Sağlık özeti</span>
            <h3>{t('network_hub_metrics_title')}</h3>
            {!isMobile ? <p>{t('hub_metrics_description')}</p> : null}
          </div>
          <div className="network-section-tools">
            {isMobile ? (
              <button className="btn ghost" type="button" onClick={() => setMobileMetricsOpen((value) => !value)} aria-expanded={mobileMetricsOpen}>
                {mobileMetricsOpen ? 'Özeti kapat' : 'Özeti aç'}
              </button>
            ) : null}
            {!isMobile || mobileMetricsOpen ? (
              <div className="network-window-tabs">
                {['7d', '30d', '90d'].map((windowValue) => (
                  <button
                    key={windowValue}
                    className={`btn ${metricsWindow === windowValue ? 'primary' : 'ghost'}`}
                    onClick={() => actions.setMetricsWindow(windowValue)}
                  >
                    {t('network_hub_window_days', { days: windowValue.replace('d', '') })}
                  </button>
                ))}
              </div>
            ) : null}
          </div>
        </div>
        {!isMobile || mobileMetricsOpen ? (
          <div className="panel-body network-section-body">
          {bootstrapping ? <LoadingState label={t('loading')} description={t('hub_loading_description')} /> : (
            <div className="network-metric-grid">
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_connections')}</span>
                <strong>{metrics.connections?.accepted || 0}</strong>
                <p>{t('network_hub_metric_requested_short', { count: metrics.connections?.requested || 0 })}</p>
              </div>
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_pending')}</span>
                <strong>{metrics.connections?.pending_incoming || 0}</strong>
                <p>{t('network_hub_metric_outgoing_short', { count: metrics.connections?.pending_outgoing || 0 })}</p>
              </div>
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_mentorship')}</span>
                <strong>{metrics.mentorship?.accepted || 0}</strong>
                <p>{t('network_hub_metric_requested_short', { count: metrics.mentorship?.requested || 0 })}</p>
              </div>
              <div className="network-metric-card">
                <span className="network-metric-label">{t('network_hub_metric_teacher_links')}</span>
                <strong>{metrics.teacherLinks?.created || 0}</strong>
                <p>
                  {metrics.time_to_first_network_success_days == null
                    ? t('network_hub_metric_ttf_empty')
                    : t('network_hub_metric_ttf_value', { days: metrics.time_to_first_network_success_days })}
                </p>
              </div>
            </div>
          )}
          </div>
        ) : null}
      </section>

      <div className="network-dashboard">
        <div className="network-column">
          <SectionCard
            sectionId="incoming-connections"
            title={t('network_hub_incoming_title')}
            kicker="Priority queue"
            description={t('hub_section_incoming_desc')}
            count={incoming.length}
          >
            {bootstrapping ? <LoadingState label={t('loading')} description={t('hub_loading_description')} /> : null}
            {!bootstrapping && incoming.length === 0 ? (
              <EmptyState
                title={t('hub_empty_incoming_title')}
                description={t('hub_empty_incoming_desc')}
                actionLabel={t('hub_empty_incoming_action')}
                actionHref="#network-suggestions"
              />
            ) : null}
            {!bootstrapping ? (
              <div className="network-list">
                {incoming.map((item) => (
                  <article
                    className={`network-action-card${focusedSection === 'incoming-connections' && focusedRequestId === Number(item.id || 0) ? ' network-focus-card' : ''}`}
                    key={item.id}
                  >
                    <PersonLink
                      href={`/new/members/${item.sender_id}`}
                      photo={readConnectionUserField(item, 'user_resim', 'resim')}
                      name={`${readConnectionUserField(item, 'user_isim', 'isim')} ${readConnectionUserField(item, 'user_soyisim', 'soyisim')}`}
                      handle={readConnectionUserField(item, 'user_kadi', 'kadi')}
                    />
                    <div className="network-card-actions">
                      <button className="btn primary" onClick={() => actions.acceptRequest(item.id)} disabled={Boolean(pendingAction[`accept-${item.id}`])}>{t('connection_accept')}</button>
                      <button className="btn ghost" onClick={() => actions.ignoreRequest(item.id)} disabled={Boolean(pendingAction[`ignore-${item.id}`])}>{t('ignore')}</button>
                    </div>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>

          <SectionCard
            sectionId="incoming-mentorship"
            title={t('network_hub_mentorship_incoming_title')}
            kicker="Mentor queue"
            description={t('hub_section_mentorship_incoming_desc')}
            count={incomingMentorship.length}
          >
            {bootstrapping ? <LoadingState label={t('loading')} description={t('hub_loading_description')} /> : null}
            {!bootstrapping && incomingMentorship.length === 0 ? (
              <EmptyState
                title={t('hub_empty_mentorship_incoming_title')}
                description={t('hub_empty_mentorship_incoming_desc')}
                actionLabel={t('hub_empty_mentorship_incoming_action')}
                actionHref="/new/profile"
              />
            ) : null}
            {!bootstrapping ? (
              <div className="network-list">
                {incomingMentorship.map((item) => (
                  <article
                    className={`network-action-card${focusedSection === 'incoming-mentorship' && focusedRequestId === Number(item.id || 0) ? ' network-focus-card' : ''}`}
                    key={`mi-${item.id}`}
                  >
                    <PersonLink
                      href={`/new/members/${item.requester_id}`}
                      photo={item.resim}
                      name={`${item.isim} ${item.soyisim}`}
                      handle={item.kadi}
                      meta={item.focus_area || staleHint(item.created_at, t)}
                    />
                    <div className="network-card-actions">
                      <button className="btn primary" onClick={() => actions.acceptMentorship(item.id)} disabled={Boolean(pendingAction[`mentorship-accept-${item.id}`])}>{t('connection_accept')}</button>
                      <button className="btn ghost" onClick={() => actions.declineMentorship(item.id)} disabled={Boolean(pendingAction[`mentorship-decline-${item.id}`])}>{t('network_hub_decline')}</button>
                    </div>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>
        </div>

        <div className="network-column">
          <SectionCard
            sectionId="teacher-notifications"
            title={t('network_hub_teacher_links_title')}
            kicker="Verified graph"
            description={t('hub_section_teacher_desc')}
            count={teacherUnreadCount}
            actions={teacherUnreadCount > 0 ? (
              <button className="btn ghost" onClick={() => actions.markTeacherLinksRead()} disabled={Boolean(pendingAction['teacher-links-read'])}>
                {t('network_hub_mark_teacher_links_read')}
              </button>
            ) : null}
          >
            {bootstrapping ? <LoadingState label={t('loading')} description={t('hub_loading_description')} /> : null}
            {!bootstrapping && teacherEvents.length === 0 ? (
              <EmptyState
                title={t('hub_empty_teacher_title')}
                description={t('hub_empty_teacher_desc')}
                actionLabel={t('hub_empty_teacher_action')}
                actionHref="/new/network/teachers"
              />
            ) : null}
            {!bootstrapping ? (
              <div className="network-list">
                {teacherEvents.map((item) => (
                  <article
                    className={`network-action-card${focusedSection === 'teacher-notifications' && focusedNotificationId === Number(item.id || 0) ? ' network-focus-card' : ''}`}
                    key={`tl-${item.id}`}
                  >
                    <PersonLink
                      href={`/new/members/${item.source_user_id}`}
                      photo={item.resim}
                      name={`${item.isim} ${item.soyisim}`}
                      handle={item.kadi}
                      meta={item.message || t('network_hub_teacher_links_default_message')}
                    />
                    {!item.read_at ? <span className="chip">{t('hub_chip_new')}</span> : null}
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>

          <SectionCard
            sectionId="outgoing-connections"
            title={t('network_hub_outgoing_title')}
            kicker="Pipeline"
            description={t('hub_section_outgoing_desc')}
            count={outgoing.length}
          >
            {bootstrapping ? <LoadingState label={t('loading')} description={t('hub_loading_description')} /> : null}
            {!bootstrapping && outgoing.length === 0 ? (
              <EmptyState
                title={t('hub_empty_outgoing_title')}
                description={t('hub_empty_outgoing_desc')}
                actionLabel={t('hub_empty_outgoing_action')}
                actionHref="/new/explore"
              />
            ) : null}
            {!bootstrapping ? (
              <div className="network-list">
                {outgoing.map((item) => (
                  <article
                    className={`network-action-card${focusedSection === 'outgoing-connections' && focusedRequestId === Number(item.id || 0) ? ' network-focus-card' : ''}`}
                    key={item.id}
                  >
                    <PersonLink
                      href={`/new/members/${item.receiver_id}`}
                      photo={readConnectionUserField(item, 'user_resim', 'resim')}
                      name={`${readConnectionUserField(item, 'user_isim', 'isim')} ${readConnectionUserField(item, 'user_soyisim', 'soyisim')}`}
                      handle={readConnectionUserField(item, 'user_kadi', 'kadi')}
                    />
                    <span className="chip">{t('connection_pending')}</span>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>

          <SectionCard
            sectionId="outgoing-mentorship"
            title={t('network_hub_mentorship_outgoing_title')}
            kicker="Outbound mentor asks"
            description={t('hub_section_mentorship_outgoing_desc')}
            count={outgoingMentorship.length}
          >
            {bootstrapping ? <LoadingState label={t('loading')} description={t('hub_loading_description')} /> : null}
            {!bootstrapping && outgoingMentorship.length === 0 ? (
              <EmptyState
                title={t('hub_empty_mentorship_outgoing_title')}
                description={t('hub_empty_mentorship_outgoing_desc')}
                actionLabel={t('hub_empty_mentorship_outgoing_action')}
                actionHref="#network-suggestions"
              />
            ) : null}
            {!bootstrapping ? (
              <div className="network-list">
                {outgoingMentorship.map((item) => (
                  <article
                    className={`network-action-card${focusedSection === 'outgoing-mentorship' && focusedRequestId === Number(item.id || 0) ? ' network-focus-card' : ''}`}
                    key={`mo-${item.id}`}
                  >
                    <PersonLink
                      href={`/new/members/${item.mentor_id}`}
                      photo={item.resim}
                      name={`${item.isim} ${item.soyisim}`}
                      handle={item.kadi}
                      meta={item.focus_area || staleHint(item.created_at, t)}
                    />
                    <Link className="btn ghost" to="/new/messages">{t('member_send_message')}</Link>
                  </article>
                ))}
              </div>
            ) : null}
          </SectionCard>
        </div>
      </div>

      <SectionCard
        sectionId="network-suggestions"
        title={t('network_hub_suggestions_title')}
        kicker="Discovery engine"
        description={t('hub_section_suggestions_desc')}
        count={suggestions.length}
      >
        {discoveryLoading ? <LoadingState label={t('hub_loading_suggestions')} description={t('hub_loading_description')} /> : null}
        {!discoveryLoading && suggestions.length === 0 ? (
          <EmptyState
            title={t('hub_empty_suggestions_title')}
            description={t('hub_empty_suggestions_desc')}
            actionLabel={t('hub_empty_suggestions_action')}
            actionHref="/new/explore"
          />
        ) : null}
        {!discoveryLoading ? (
          <div className="network-suggestion-grid">
            {suggestions.map((item) => {
              const key = Number(item.id || 0);
              const incomingRequestId = Number(incomingConnectionMap[key] || 0);
              const outgoingRequestId = Number(outgoingConnectionMap[key] || 0);
              const outgoingPending = outgoingRequestId > 0;
              const label = incomingRequestId
                ? t('connection_accept')
                : outgoingPending
                  ? t('connection_withdraw')
                  : t('connection_request');
              return (
                <article className="network-suggestion-card" key={item.id}>
                  <PersonLink
                    href={`/new/members/${item.id}`}
                    photo={item.resim}
                    name={`${item.isim} ${item.soyisim}${item.verified ? ' ✓' : ''}`}
                    handle={item.kadi}
                    meta={Array.isArray(item.reasons) && item.reasons.length > 0 ? item.reasons[0] : ''}
                  />
                  <div className="network-card-actions">
                    <button
                      className="btn ghost"
                      onClick={() => actions.connectUser(item.id)}
                      disabled={Boolean(pendingAction[`connect-${item.id}`])}
                    >
                      {label}
                    </button>
                    <button
                      className="btn ghost"
                      onClick={() => actions.toggleFollow(item.id)}
                      disabled={Boolean(pendingAction[`follow-${item.id}`])}
                    >
                      {followingIds.has(Number(item.id)) ? t('unfollow') : t('follow')}
                    </button>
                  </div>
                </article>
              );
            })}
          </div>
        ) : null}
      </SectionCard>
    </Layout>
  );
}
