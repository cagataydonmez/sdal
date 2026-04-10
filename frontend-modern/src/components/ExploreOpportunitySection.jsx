import React, { useMemo } from 'react';
import { Link, useSearchParams } from '../router.jsx';
import { useOpportunityInboxState } from '../hooks/useOpportunityInboxState.js';
import { useI18n } from '../utils/i18n.jsx';

const TAB_KEYS = ['all', 'now', 'networking', 'jobs', 'updates'];

function normalizeTab(value) {
  const raw = String(value || '').trim().toLowerCase();
  return TAB_KEYS.includes(raw) ? raw : 'all';
}

function EmptyState({ tab, t }) {
  const actionHref = tab === 'jobs'
    ? '/new/jobs'
    : tab === 'updates'
      ? '/new/notifications'
      : '/new/network/hub';
  const actionLabel = tab === 'jobs'
    ? t('opportunity_action_jobs')
    : tab === 'updates'
      ? t('opportunity_action_notifications')
      : t('network_hub_title');
  return (
    <div className="network-empty-state">
      <strong>{t('opportunity_empty_title')}</strong>
      <span>{t('opportunity_empty_description')}</span>
      <Link className="btn ghost" to={actionHref}>{actionLabel}</Link>
    </div>
  );
}

function OpportunityCard({ item, t }) {
  const priorityLabel = item.priority_bucket === 'now'
    ? t('opportunity_priority_now')
    : item.priority_bucket === 'soon'
      ? t('opportunity_priority_soon')
      : t('opportunity_priority_follow');
  const categoryLabel = item.category === 'jobs'
    ? t('opportunity_category_job')
    : item.category === 'updates'
      ? t('opportunity_category_update')
      : t('opportunity_category_networking');
  const actionHref = item.target?.href || '';
  const actionLabel = item.primary_action?.label || item.target?.label || t('opportunity_action_open');

  return (
    <article className="opportunity-card panel">
      <div className="opportunity-card-head">
        <div className="opportunity-chip-row">
          <span className="chip">{priorityLabel}</span>
          <span className="chip">{categoryLabel}</span>
        </div>
        <div className="opportunity-score">{t('opportunity_score_label')}{Math.round(Number(item.score || 0))}</div>
      </div>
      <div className="opportunity-card-body panel-body">
        <h3>{item.title}</h3>
        {item.summary ? <p className="opportunity-summary">{item.summary}</p> : null}
        {item.why_now ? (
          <div className="opportunity-why">
            <strong>{t('opportunity_why_now_label')}</strong>
            <span>{item.why_now}</span>
          </div>
        ) : null}
        {Array.isArray(item.reasons) && item.reasons.length ? (
          <div className="opportunity-reasons">
            {item.reasons.map((reason) => <span className="chip" key={`${item.id}-${reason}`}>{reason}</span>)}
          </div>
        ) : null}
        {actionHref ? (
          <div className="opportunity-actions">
            <Link className="btn primary" to={actionHref}>{actionLabel}</Link>
          </div>
        ) : null}
      </div>
    </article>
  );
}

export default function ExploreOpportunitySection() {
  const { t } = useI18n();
  const [searchParams, setSearchParams] = useSearchParams();
  const activeTab = normalizeTab(searchParams.get('tab'));
  const { state, actions } = useOpportunityInboxState(activeTab);
  const tabOptions = useMemo(() => ([
    { key: 'all', label: t('opportunity_tab_all') },
    { key: 'now', label: t('opportunity_tab_now') },
    { key: 'networking', label: t('opportunity_tab_networking') },
    { key: 'jobs', label: t('opportunity_tab_jobs') },
    { key: 'updates', label: t('opportunity_tab_updates') }
  ]), [t]);
  const activeCount = Number(state.summary?.[activeTab] || state.items.length || 0);

  function selectTab(nextTab) {
    const normalized = normalizeTab(nextTab);
    const params = new URLSearchParams(searchParams);
    if (normalized === 'all') params.delete('tab');
    else params.set('tab', normalized);
    setSearchParams(params);
  }

  return (
    <section className="panel network-section-card explore-opportunity-stage" id="explore-opportunities">
      <div className="network-section-head">
        <div>
          <span className="network-section-kicker">{t('nav_opportunities')}</span>
          <h3>{t('opportunity_section_filter_title')}</h3>
          <p>{t('opportunity_hero_description')}</p>
        </div>
        <div className="network-section-tools">
          <span className="chip">{activeCount}</span>
          <Link className="btn ghost" to="/new/jobs">{t('nav_jobs')}</Link>
        </div>
      </div>
      <div className="panel-body network-section-body">
        <div className="network-window-tabs">
          {tabOptions.map((tab) => (
            <button
              className={`btn ${activeTab === tab.key ? 'primary' : 'ghost'}`}
              key={tab.key}
              onClick={() => selectTab(tab.key)}
              type="button"
            >
              {tab.label}
            </button>
          ))}
        </div>

        {state.error ? (
          <div className="panel error">
            <div className="panel-body opportunity-error-row">
              <span>{state.error}</span>
              <button className="btn ghost" onClick={() => actions.reload()} type="button">{t('opportunity_action_retry')}</button>
            </div>
          </div>
        ) : null}

        {state.loading ? <div className="network-empty-state network-loading-state"><strong>{t('opportunity_loading_preparing')}</strong><span>{t('opportunity_loading_description')}</span></div> : null}
        {!state.loading && state.items.length === 0 ? <EmptyState tab={activeTab} t={t} /> : null}

        {state.items.length ? (
          <div className="opportunity-grid">
            {state.items.map((item) => <OpportunityCard item={item} key={item.id} t={t} />)}
          </div>
        ) : null}

        {!state.loading && state.hasMore ? (
          <div className="opportunity-load-more">
            <button className="btn ghost" disabled={state.loadingMore} onClick={() => actions.loadMore()} type="button">
              {state.loadingMore ? t('loading') : t('opportunity_action_load_more')}
            </button>
          </div>
        ) : null}
      </div>
    </section>
  );
}
