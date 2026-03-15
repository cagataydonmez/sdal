import React, { useMemo } from 'react';
import { Link, useSearchParams } from '../router.jsx';
import Layout from '../components/Layout.jsx';
import { useOpportunityInboxState } from '../hooks/useOpportunityInboxState.js';

const TAB_OPTIONS = [
  { key: 'all', label: 'Tümü' },
  { key: 'now', label: 'Şimdi' },
  { key: 'networking', label: 'Networking' },
  { key: 'jobs', label: 'İşler' },
  { key: 'updates', label: 'Güncellemeler' }
];

function normalizeTab(value) {
  const raw = String(value || '').trim().toLowerCase();
  return TAB_OPTIONS.some((item) => item.key === raw) ? raw : 'all';
}

function priorityLabel(value) {
  if (value === 'now') return 'Şimdi';
  if (value === 'soon') return 'Sıradaki';
  return 'Takipte tut';
}

function categoryLabel(value) {
  if (value === 'jobs') return 'İş';
  if (value === 'updates') return 'Güncelleme';
  return 'Networking';
}

function EmptyState({ tab }) {
  const actionHref = tab === 'jobs' ? '/new/jobs' : tab === 'updates' ? '/new/notifications' : '/new/explore';
  const actionLabel = tab === 'jobs' ? 'İş ilanlarına git' : tab === 'updates' ? 'Bildirimleri aç' : 'Yeni kişileri keşfet';
  return (
    <div className="network-empty-state">
      <strong>Şu anda bu sekmede bir fırsat görünmüyor.</strong>
      <span>Yeni hareketler geldikçe bu alan tek bir aksiyon kuyruğu gibi güncellenecek.</span>
      <Link className="btn ghost" to={actionHref}>{actionLabel}</Link>
    </div>
  );
}

function OpportunityCard({ item }) {
  return (
    <article className="opportunity-card panel">
      <div className="opportunity-card-head">
        <div className="opportunity-chip-row">
          <span className="chip">{priorityLabel(item.priority_bucket)}</span>
          <span className="chip">{categoryLabel(item.category)}</span>
        </div>
        <div className="opportunity-score">Skor {Math.round(Number(item.score || 0))}</div>
      </div>
      <div className="opportunity-card-body panel-body">
        <h3>{item.title}</h3>
        {item.summary ? <p className="opportunity-summary">{item.summary}</p> : null}
        {item.why_now ? (
          <div className="opportunity-why">
            <strong>Neden şimdi?</strong>
            <span>{item.why_now}</span>
          </div>
        ) : null}
        {Array.isArray(item.reasons) && item.reasons.length ? (
          <div className="opportunity-reasons">
            {item.reasons.map((reason) => <span className="chip" key={`${item.id}-${reason}`}>{reason}</span>)}
          </div>
        ) : null}
        <div className="opportunity-actions">
          {item.target?.href ? <Link className="btn primary" to={item.target.href}>{item.primary_action?.label || item.target.label || 'Aç'}</Link> : null}
        </div>
      </div>
    </article>
  );
}

export default function OpportunityInboxPage() {
  const [searchParams, setSearchParams] = useSearchParams();
  const activeTab = normalizeTab(searchParams.get('tab'));
  const { state, actions } = useOpportunityInboxState(activeTab);
  const counts = state.summary || {};

  const heroStats = useMemo(() => ([
    { label: 'Toplam fırsat', value: Number(counts.all || 0) },
    { label: 'Şimdi aksiyon', value: Number(counts.now || 0) },
    { label: 'Networking', value: Number(counts.networking || 0) },
    { label: 'İşler', value: Number(counts.jobs || 0) }
  ]), [counts]);

  function selectTab(nextTab) {
    const next = normalizeTab(nextTab);
    const params = new URLSearchParams(searchParams);
    if (next === 'all') params.delete('tab');
    else params.set('tab', next);
    setSearchParams(params);
  }

  return (
    <Layout title="Fırsat Merkezi">
      <section className="network-hero opportunity-hero">
        <div className="network-hero-copy">
          <span className="network-eyebrow">Opportunity inbox</span>
          <h2>En yüksek değerli bir sonraki hamleni tek yerde gör</h2>
          <p>Networking, mentorluk, iş fırsatları ve kritik güncellemeler tek bir sıralı aksiyon akışı olarak burada birleşir.</p>
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
          <Link className="btn ghost" to="/new/network/hub">Eski ağ merkezini aç</Link>
          <Link className="btn ghost" to="/new/jobs">İş ilanlarına git</Link>
        </div>
      </section>

      <section className="panel network-section-card">
        <div className="network-section-head">
          <div>
            <span className="network-section-kicker">Öncelik filtresi</span>
            <h3>Bugün neye odaklanacağını seç</h3>
            <p>Bu sekmeler aynı veriyi farklı operasyon lensleriyle gösterir.</p>
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
            <button className="btn ghost" onClick={() => actions.reload()} type="button">Tekrar dene</button>
          </div>
        </div>
      ) : null}

      {state.loading ? <div className="network-empty-state network-loading-state"><strong>Fırsatlar hazırlanıyor...</strong><span>Veriler networking, işler ve güncellemeler arasından toplanıyor.</span></div> : null}

      {!state.loading && state.items.length === 0 ? <EmptyState tab={activeTab} /> : null}

      <div className="opportunity-grid">
        {state.items.map((item) => <OpportunityCard item={item} key={item.id} />)}
      </div>

      {!state.loading && state.hasMore ? (
        <div className="opportunity-load-more">
          <button className="btn ghost" disabled={state.loadingMore} onClick={() => actions.loadMore()} type="button">
            {state.loadingMore ? 'Yükleniyor...' : 'Daha fazla fırsat göster'}
          </button>
        </div>
      ) : null}
    </Layout>
  );
}
