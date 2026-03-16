import React, { useMemo } from 'react';
import { Link, useSearchParams } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { useOpportunityInboxState } from '../hooks/useOpportunityInboxState.js';
import { useI18n } from '../utils/i18n.jsx';

function normalizeTab(value, tabOptions) {
  const raw = String(value || '').trim().toLowerCase();
  return tabOptions.some((item) => item.key === raw) ? raw : 'all';
}

function EmptyState({ tab, t }) {
  const actionHref = tab === 'jobs' ? '/new/jobs' : tab === 'updates' ? '/new/notifications' : '/new/explore';
  const actionLabel = tab === 'jobs' ? t('opportunity_action_jobs') : tab === 'updates' ? t('opportunity_action_notifications') : t('opportunity_action_discover');
  return (
    <div className="network-empty-state">
      <strong>{t('opportunity_empty_title')}</strong>
      <span>{t('opportunity_empty_description')}</span>
      <Link className="btn ghost" to={actionHref}>{actionLabel}</Link>
    </div>
  );
}

function OpportunityCard({ item, t }) {
  const priorityLabel = item.priority_bucket === 'now' ? t('opportunity_priority_now') : item.priority_bucket === 'soon' ? t('opportunity_priority_soon') : t('opportunity_priority_follow');
  const categoryLabel = item.category === 'jobs' ? t('opportunity_category_job') : item.category === 'updates' ? t('opportunity_category_update') : t('opportunity_category_networking');
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
        <div className="opportunity-actions">
          {item.target?.href ? <Link className="btn primary" to={item.target.href}>{item.primary_action?.label || item.target.label || t('opportunity_action_open')}</Link> : null}
        </div>
      </div>
    </article>
  );
}

export default function OpportunityInboxPage() {
  const { t } = useI18n();
  const [searchParams, setSearchParams] = useSearchParams();

  const TAB_OPTIONS = useMemo(() => [
    { key: 'all', label: t('opportunity_tab_all') },
    { key: 'now', label: t('opportunity_tab_now') },
    { key: 'networking', label: t('opportunity_tab_networking') },
    { key: 'jobs', label: t('opportunity_tab_jobs') },
    { key: 'updates', label: t('opportunity_tab_updates') }
  ], [t]);

  const activeTab = normalizeTab(searchParams.get('tab'), TAB_OPTIONS);
  const { state, actions } = useOpportunityInboxState(activeTab);
  const counts = state.summary || {};

  const heroStats = useMemo(() => ([
    { label: t('opportunity_stat_total'), value: Number(counts.all || 0) },
    { label: t('opportunity_stat_action_now'), value: Number(counts.now || 0) },
    { label: t('opportunity_stat_networking'), value: Number(counts.networking || 0) },
    { label: t('opportunity_stat_jobs'), value: Number(counts.jobs || 0) }
  ]), [counts, t]);

  function selectTab(nextTab) {
    const next = normalizeTab(nextTab, TAB_OPTIONS);
    const params = new URLSearchParams(searchParams);
    if (next === 'all') params.delete('tab');
    else params.set('tab', next);
    setSearchParams(params);
  }

  return (
    <Layout title={t('opportunity_page_title')}>
      <section className="network-hero opportunity-hero">
        <div className="network-hero-copy">
          <span className="network-eyebrow">{t('opportunity_hero_eyebrow')}</span>
          <h2>{t('opportunity_hero_title')}</h2>
          <p>{t('opportunity_hero_description')}</p>
          <div className="network-inline-stats">
            {heroStats.map((stat) => (
              <div className="network-inline-stat" key={stat.label}>
                <strong>{stat.value}</strong>
                <span>{stat.label}</span>
              </div>
            ))}
          </div>
        </div>
        <div className="network-hero-actions">
          <Link className="btn ghost" to="/new/network/hub">{t('opportunity_action_old_hub')}</Link>
          <Link className="btn ghost" to="/new/jobs">{t('opportunity_action_jobs')}</Link>
        </div>
      </section>

      <section className="panel network-section-card">
        <div className="network-section-head">
          <div>
            <span className="network-section-kicker">{t('opportunity_section_filter_kicker')}</span>
            <h3>{t('opportunity_section_filter_title')}</h3>
            <p>{t('opportunity_section_filter_description')}</p>
          </div>
          <div className="network-window-tabs">
            {TAB_OPTIONS.map((tab) => (
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
        </div>
      </section>

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

      <div className="opportunity-grid">
        {state.items.map((item) => <OpportunityCard item={item} key={item.id} t={t} />)}
      </div>

      {!state.loading && state.hasMore ? (
        <div className="opportunity-load-more">
          <button className="btn ghost" disabled={state.loadingMore} onClick={() => actions.loadMore()} type="button">
            {state.loadingMore ? t('loading') : t('opportunity_action_load_more')}
          </button>
        </div>
      ) : null}
    </Layout>
  );
}
