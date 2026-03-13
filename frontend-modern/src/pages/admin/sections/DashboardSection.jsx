import React, { useCallback, useEffect, useRef, useState } from 'react';
import { adminClient } from '../../../admin/api/adminClient.js';

function formatInteger(value) {
  return new Intl.NumberFormat('tr-TR', { maximumFractionDigits: 0 }).format(Number(value || 0));
}

function formatSizeFromMb(valueMb) {
  const mb = Number(valueMb || 0);
  if (!Number.isFinite(mb) || mb <= 0) return '0 MB';
  if (mb >= 1024) return `${(mb / 1024).toFixed(2)} GB`;
  return `${mb.toFixed(2)} MB`;
}

function formatPercent(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric < 0) return '-';
  return `%${numeric.toFixed(2)}`;
}

function formatSignedPercent(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return '-';
  const rendered = `%${Math.abs(numeric).toFixed(2)}`;
  if (numeric > 0) return `+${rendered}`;
  if (numeric < 0) return `-${rendered}`;
  return rendered;
}

function evaluationLabel(status) {
  const key = String(status || '').trim().toLowerCase();
  if (key === 'positive') return 'positive';
  if (key === 'negative') return 'negative';
  if (key === 'neutral') return 'neutral';
  if (key === 'insufficient_data') return 'insufficient data';
  return 'unknown';
}

export default function DashboardSection({ onNavigate }) {
  const [stats, setStats] = useState(null);
  const [analytics, setAnalytics] = useState(null);
  const [live, setLive] = useState({ activity: [], counts: {} });
  const [applyState, setApplyState] = useState({ key: '', message: '', error: '', confirmKey: '' });
  const [loadingStats, setLoadingStats] = useState(false);
  const [loadingAnalytics, setLoadingAnalytics] = useState(false);
  const [loadingLive, setLoadingLive] = useState(false);
  const [error, setError] = useState('');
  const requestSeqRef = useRef(0);

  const loading = loadingStats || loadingAnalytics || loadingLive;

  const load = useCallback(async () => {
    const requestSeq = ++requestSeqRef.current;
    setLoadingStats(true);
    setLoadingAnalytics(true);
    setLoadingLive(true);
    setError('');
    const [statsResult, analyticsResult, liveResult] = await Promise.allSettled([
      adminClient.get('/api/admin/dashboard/summary'),
      adminClient.get('/api/new/admin/network/analytics?window=30d'),
      adminClient.get('/api/admin/dashboard/activity')
    ]);
    if (requestSeq !== requestSeqRef.current) return;

    if (statsResult.status === 'fulfilled') {
      setStats(statsResult.value || null);
    } else {
      setError(statsResult.reason?.message || 'Dashboard summary could not be loaded.');
    }
    setLoadingStats(false);

    if (analyticsResult.status === 'fulfilled') {
      setAnalytics(analyticsResult.value || null);
    } else {
      setError((prev) => prev || analyticsResult.reason?.message || 'Networking analytics could not be loaded.');
    }
    setLoadingAnalytics(false);

    if (liveResult.status === 'fulfilled') {
      setLive(liveResult.value || { activity: [], counts: {} });
    } else {
      setError((prev) => prev || liveResult.reason?.message || 'Live activity could not be loaded.');
    }
    setLoadingLive(false);
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const applySuggestionRecommendation = useCallback(async (index) => {
    const key = `recommendation:${index}`;
    if (applyState.confirmKey !== key) {
      setApplyState({ key: '', message: '', error: '', confirmKey: key });
      return;
    }
    setApplyState({ key, message: '', error: '', confirmKey: key });
    try {
      const result = await adminClient.post('/api/new/admin/network-suggestion-ab/apply', {
        index,
        window: '30d',
        cohort: 'all',
        confirmation: 'apply'
      });
      setApplyState({
        key: '',
        message: result?.message || 'Recommendation applied.',
        error: '',
        confirmKey: ''
      });
      await load();
    } catch (err) {
      setApplyState({
        key: '',
        message: '',
        error: err?.message || 'Recommendation could not be applied.',
        confirmKey: ''
      });
    }
  }, [applyState.confirmKey, load]);

  const rollbackSuggestionChange = useCallback(async (changeId) => {
    const key = `rollback:${changeId}`;
    setApplyState({ key, message: '', error: '', confirmKey: '' });
    try {
      const result = await adminClient.post(`/api/new/admin/network-suggestion-ab/rollback/${changeId}`, {});
      setApplyState({
        key: '',
        message: result?.message || 'Recommendation change rolled back.',
        error: '',
        confirmKey: ''
      });
      await load();
    } catch (err) {
      setApplyState({
        key: '',
        message: '',
        error: err?.message || 'Rollback could not be completed.',
        confirmKey: ''
      });
    }
  }, [load]);

  const counts = stats?.counts || {};
  const networking = stats?.networking || {};
  const connection = networking.connections || {};
  const mentorship = networking.mentorship || {};
  const teacherLinks = networking.teacherLinks || {};
  const analyticsNetworking = analytics?.networking || {};
  const analyticsConnections = analyticsNetworking.connections || {};
  const analyticsMentorship = analyticsNetworking.mentorship || {};
  const analyticsTeacherLinks = analyticsNetworking.teacher_links || {};
  const analyticsTelemetry = analyticsNetworking.telemetry || {};
  const analyticsAlerts = Array.isArray(analyticsNetworking.alerts) ? analyticsNetworking.alerts : [];
  const suggestionExperiment = analyticsNetworking.experiments?.network_suggestions || {};
  const suggestionRecommendations = Array.isArray(suggestionExperiment.recommendations) ? suggestionExperiment.recommendations : [];
  const suggestionRecentChanges = Array.isArray(suggestionExperiment.recent_changes) ? suggestionExperiment.recent_changes : [];
  const telemetryFrontend = analyticsTelemetry.frontend || {};
  const telemetryActions = analyticsTelemetry.actions || {};
  const analyticsSummary = analytics?.summary || {};
  const mentorSupply = Array.isArray(analyticsNetworking.mentor_supply_vs_demand?.supply) ? analyticsNetworking.mentor_supply_vs_demand.supply : [];
  const mentorDemand = Array.isArray(analyticsNetworking.mentor_supply_vs_demand?.demand) ? analyticsNetworking.mentor_supply_vs_demand.demand : [];
  const topCohorts = Array.isArray(analyticsNetworking.top_active_graduation_years) ? analyticsNetworking.top_active_graduation_years : [];
  const teacherRelationshipBreakdown = Object.entries(teacherLinks.byRelationshipType || {})
    .sort((a, b) => Number(b[1] || 0) - Number(a[1] || 0));
  const topEvents = Array.isArray(analyticsTelemetry.top_events) ? analyticsTelemetry.top_events.slice(0, 6) : [];
  const suggestionVariants = Array.isArray(suggestionExperiment.variants) ? suggestionExperiment.variants : [];
  const leadingSuggestionVariant = suggestionExperiment.leading_variant || null;
  const queue = live?.counts || {};
  const storage = stats?.storage || {};
  const mentorshipAcceptanceRate = Number(analyticsMentorship.requested || 0) > 0
    ? (Number(analyticsMentorship.accepted || 0) / Number(analyticsMentorship.requested || 0)) * 100
    : 0;
  const connectionAcceptanceRate = Number(analyticsConnections.acceptance_rate || 0) * 100;
  const lastRebuiltLabel = analyticsSummary.last_rebuilt_at
    ? new Date(analyticsSummary.last_rebuilt_at).toLocaleString('tr-TR')
    : '-';
  const demandPressureRows = mentorDemand.slice(0, 5).map((demandRow) => {
    const cohortKey = String(demandRow?.cohort || '').trim().toLowerCase();
    const supplyRow = mentorSupply.find((item) => String(item?.cohort || '').trim().toLowerCase() === cohortKey);
    return {
      cohort: cohortKey || 'unknown',
      demand: Number(demandRow?.count || 0),
      supply: Number(supplyRow?.count || 0),
      gap: Number(demandRow?.count || 0) - Number(supplyRow?.count || 0)
    };
  });

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>Dashboard</h3>
        <button className="btn ghost" onClick={load} disabled={loading}>Refresh</button>
      </div>

      {error ? <div className="panel"><div className="panel-body muted">{error}</div></div> : null}

      <div className="ops-kpi-grid">
        <button className="ops-kpi-card" onClick={() => onNavigate?.('users')}><span>Total Users</span><b>{counts.users || 0}</b></button>
        <button className="ops-kpi-card" onClick={() => onNavigate?.('content')}><span>Total Posts</span><b>{counts.posts || 0}</b></button>
        <button className="ops-kpi-card" onClick={() => onNavigate?.('content')}><span>Total Stories</span><b>{counts.stories || 0}</b></button>
        <button className="ops-kpi-card" onClick={() => onNavigate?.('groups')}><span>Total Groups</span><b>{counts.groups || 0}</b></button>
      </div>

      <div className="ops-kpi-grid">
        <button className="ops-kpi-card" onClick={() => onNavigate?.('notifications')}><span>Pending Verifications</span><b>{queue.pendingVerifications || 0}</b></button>
        <button className="ops-kpi-card" onClick={() => onNavigate?.('groups')}><span>Pending Events</span><b>{queue.pendingEvents || 0}</b></button>
        <button className="ops-kpi-card" onClick={() => onNavigate?.('groups')}><span>Pending Announcements</span><b>{queue.pendingAnnouncements || 0}</b></button>
        <button className="ops-kpi-card" onClick={() => onNavigate?.('content')}><span>Pending Photos</span><b>{queue.pendingPhotos || 0}</b></button>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>Social Hub Networking Funnel</h3>
          <div className="ops-kpi-grid">
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Bağlantı İstekleri (Bekliyor)</span>
              <b>{formatInteger(connection.requested)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Bağlantı İstekleri (Kabul)</span>
              <b>{formatInteger(connection.accepted)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Mentorluk İstekleri (Bekliyor)</span>
              <b>{formatInteger(mentorship.requested)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Mentorluk İstekleri (Kabul)</span>
              <b>{formatInteger(mentorship.accepted)}</b>
            </div>
          </div>
          <div className="ops-kpi-grid">
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Mentorluk İstekleri (Reddedildi)</span>
              <b>{formatInteger(mentorship.declined)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Bağlantı İstekleri (Yoksayıldı)</span>
              <b>{formatInteger(connection.ignored)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Bağlantı İstekleri (Reddedildi)</span>
              <b>{formatInteger(connection.declined)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Öğretmen-Ağ Link Toplamı</span>
              <b>{formatInteger(teacherLinks.total)}</b>
            </div>
          </div>
          {teacherRelationshipBreakdown.length ? (
            <div className="muted">
              Öğretmen ilişki kırılımı:{' '}
              {teacherRelationshipBreakdown.map(([type, value]) => `${type}: ${formatInteger(value)}`).join(' · ')}
            </div>
          ) : (
            <div className="muted">Öğretmen ilişki kırılımı henüz oluşmadı.</div>
          )}
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <div className="ops-head-row">
            <h3>Networking Visibility Panel</h3>
            <div className="muted">
              {analyticsSummary.source || 'direct'} · last rebuilt {lastRebuiltLabel}
            </div>
          </div>
          <div className="ops-kpi-grid">
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Connection Acceptance Rate</span>
              <b>{formatPercent(connectionAcceptanceRate)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Mentorship Acceptance Rate</span>
              <b>{formatPercent(mentorshipAcceptanceRate)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Teacher Links Created (30d)</span>
              <b>{formatInteger(analyticsTeacherLinks.created)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Teacher Links Read (30d)</span>
              <b>{formatInteger(telemetryActions.teacher_links_read)}</b>
            </div>
          </div>
          <div className="ops-kpi-grid">
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Hub Views</span>
              <b>{formatInteger(telemetryFrontend.hub_views)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Explore Views</span>
              <b>{formatInteger(telemetryFrontend.explore_views)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Teacher Network Views</span>
              <b>{formatInteger(telemetryFrontend.teacher_network_views)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Summary Refresh</span>
              <b>{analyticsSummary.skipped_refresh ? 'cached' : 'rebuilt'}</b>
            </div>
          </div>
          <div className="ops-kpi-grid">
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Follow Created</span>
              <b>{formatInteger(telemetryActions.follow_created)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Follow Removed</span>
              <b>{formatInteger(telemetryActions.follow_removed)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Connections Cancelled</span>
              <b>{formatInteger(analyticsConnections.cancelled)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Hub Suggestion Loads</span>
              <b>{formatInteger(telemetryFrontend.hub_suggestion_loads)}</b>
            </div>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>Networking Alerts</h3>
          <div className="list">
            {analyticsAlerts.length ? analyticsAlerts.map((alert) => (
              <div key={alert.code} className="list-item">
                <div>
                  <div className="name">{alert.title}</div>
                  <div className="meta">{String(alert.severity || 'info').toUpperCase()} · {alert.description}</div>
                </div>
                <b>{alert.metric != null ? formatInteger(alert.metric) : '-'}</b>
              </div>
            )) : <div className="muted">No networking alerts in the current 30 day window.</div>}
          </div>
        </div>
      </div>

      <div className="ops-kpi-grid">
        <div className="panel">
          <div className="panel-body stack">
            <h3>Top Active Cohorts</h3>
            <div className="list">
              {topCohorts.length ? topCohorts.map((row) => (
                <div key={row.cohort} className="list-item">
                  <div>
                    <div className="name">{row.cohort}</div>
                    <div className="meta">Networking actions in last 30 days</div>
                  </div>
                  <b>{formatInteger(row.actions)}</b>
                </div>
              )) : <div className="muted">No cohort activity yet.</div>}
            </div>
          </div>
        </div>

        <div className="panel">
          <div className="panel-body stack">
            <h3>Mentor Supply vs Demand</h3>
            <div className="list">
              {demandPressureRows.length ? demandPressureRows.map((row) => (
                <div key={row.cohort} className="list-item">
                  <div>
                    <div className="name">{row.cohort}</div>
                    <div className="meta">Demand {formatInteger(row.demand)} · Supply {formatInteger(row.supply)}</div>
                  </div>
                  <b>{row.gap > 0 ? `+${formatInteger(row.gap)}` : formatInteger(row.gap)}</b>
                </div>
              )) : <div className="muted">Mentor demand pressure not detected.</div>}
            </div>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>Top Networking Events</h3>
          <div className="list">
            {topEvents.length ? topEvents.map((row) => (
              <div key={row.event_name} className="list-item">
                <div>
                  <div className="name">{row.event_name}</div>
                  <div className="meta">Last 30 day aggregated count</div>
                </div>
                <b>{formatInteger(row.count)}</b>
              </div>
            )) : <div className="muted">Telemetry has not produced top events yet.</div>}
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <div className="ops-head-row">
            <h3>Suggestion Experiment Panel</h3>
            <div className="muted">
              Exposure users {formatInteger(suggestionExperiment.total_exposure_users || 0)} · load events {formatInteger(suggestionExperiment.total_exposure_events || 0)}
            </div>
          </div>
          {leadingSuggestionVariant ? (
            <div className="muted">
              Leading variant: {leadingSuggestionVariant.variant} · activation rate {formatPercent(Number(leadingSuggestionVariant.activation_rate || 0) * 100)}
            </div>
          ) : (
            <div className="muted">Suggestion experiment has not produced enough exposure data yet.</div>
          )}
          {applyState.message ? <div className="muted">{applyState.message}</div> : null}
          {applyState.error ? <div className="muted">{applyState.error}</div> : null}
          <div className="list">
            {suggestionVariants.length ? suggestionVariants.map((row) => (
              <div key={row.variant} className="list-item">
                <div>
                  <div className="name">{row.variant} · {row.name}</div>
                  <div className="meta">
                    Exposure users {formatInteger(row.exposure_users)} · activated users {formatInteger(row.activated_users)} · follows {formatInteger(row.follow_created)} · connections {formatInteger(row.connection_requested)}
                  </div>
                  <div className="meta">
                    Mentorship {formatInteger(row.mentorship_requested)} · teacher links {formatInteger(row.teacher_link_created)} · assignments {formatInteger(row.assignment_count)}
                  </div>
                </div>
                <b>{formatPercent(Number(row.activation_rate || 0) * 100)}</b>
              </div>
            )) : <div className="muted">No variant level recommendation data yet.</div>}
          </div>
          <div className="list">
            {suggestionRecommendations.length ? suggestionRecommendations.slice(0, 3).map((row, index) => (
              <div key={`${row.variant}-${index}`} className="list-item">
                <div>
                  <div className="name">{row.variant} recommendation</div>
                  <div className="meta">{Array.isArray(row.reasons) ? row.reasons.join(' · ') : 'No rationale provided.'}</div>
                  <div className="meta">
                    {row.guardrails?.can_apply
                      ? `Ready to apply · min exposure ${formatInteger(row.guardrails?.observed_minimum_exposure_users)}`
                      : (row.guardrails?.blockers || []).join(' · ') || 'Guardrail blocked'}
                  </div>
                  <div className="meta">
                    {row.patch
                      ? `Patch: ${Object.entries(row.patch).map(([key, value]) => `${key}=${value}`).join(', ')}`
                      : row.trafficPatch
                        ? `Traffic: ${Object.entries(row.trafficPatch).map(([key, value]) => `${key}=${value}%`).join(', ')}`
                        : 'No patch payload'}
                  </div>
                </div>
                <div className="stack" style={{ alignItems: 'flex-end' }}>
                  <b>{formatPercent(Number(row.confidence || 0) * 100)}</b>
                  <button
                    className="btn ghost"
                    onClick={() => applySuggestionRecommendation(index)}
                    disabled={loading || applyState.key === `recommendation:${index}` || row.guardrails?.can_apply === false}
                  >
                    {applyState.key === `recommendation:${index}`
                      ? 'Applying...'
                      : applyState.confirmKey === `recommendation:${index}`
                        ? 'Confirm apply'
                        : 'Apply'}
                  </button>
                </div>
              </div>
            )) : <div className="muted">No tuning or rebalance recommendation has been generated yet.</div>}
          </div>
          <div className="list">
            {suggestionRecentChanges.length ? suggestionRecentChanges.map((row) => (
              <div key={row.id} className="list-item">
                <div>
                  <div className="name">#{row.id} · {row.action_type}</div>
                  <div className="meta">
                    {(row.payload?.variant || row.payload?.source_change_id || 'n/a')} · {row.created_at ? new Date(row.created_at).toLocaleString('tr-TR') : '-'}
                  </div>
                  <div className="meta">
                    {Array.isArray(row.after_snapshot) && row.after_snapshot.length
                      ? row.after_snapshot.map((item) => `${item.variant}:${item.trafficPct}%`).join(' · ')
                      : 'No snapshot'}
                  </div>
                  {row.evaluation ? (
                    <div className="meta">
                      {evaluationLabel(row.evaluation.status)}
                      {' · '}
                      activation {formatSignedPercent(Number(row.evaluation.delta?.activation_rate_delta || 0) * 100)}
                      {' · '}
                      connection {formatSignedPercent(Number(row.evaluation.delta?.connection_request_rate_delta || 0) * 100)}
                      {' · '}
                      mentorship {formatSignedPercent(Number(row.evaluation.delta?.mentorship_request_rate_delta || 0) * 100)}
                    </div>
                  ) : null}
                </div>
                <div className="stack" style={{ alignItems: 'flex-end' }}>
                  <b>{row.rolled_back_at ? 'rolled back' : 'active'}</b>
                  {row.action_type === 'apply' && !row.rolled_back_at ? (
                    <button
                      className="btn ghost"
                      onClick={() => rollbackSuggestionChange(row.id)}
                      disabled={loading || applyState.key === `rollback:${row.id}`}
                    >
                      {applyState.key === `rollback:${row.id}` ? 'Rolling back...' : 'Rollback'}
                    </button>
                  ) : null}
                </div>
              </div>
            )) : <div className="muted">No suggestion config change history yet.</div>}
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>System & Storage</h3>
          <div className="ops-kpi-grid">
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>CPU Usage</span>
              <b>{storage.cpuSupported ? formatPercent(storage.cpuUsagePct) : '-'}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Disk Space (Total)</span>
              <b>{storage.diskSupported ? formatSizeFromMb(storage.diskTotalMb) : '-'}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Disk Usage</span>
              <b>
                {storage.diskSupported
                  ? `${formatSizeFromMb(storage.diskUsedMb)} (${formatPercent(storage.diskUsedPct)})`
                  : '-'}
              </b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Disk Free</span>
              <b>
                {storage.diskSupported
                  ? `${formatSizeFromMb(storage.diskFreeMb)} (${formatPercent(storage.diskFreePct)})`
                  : '-'}
              </b>
            </div>
          </div>
          <div className="ops-kpi-grid">
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Toplam Fotoğraf Media Sayısı</span>
              <b>{formatInteger(storage.uploadedPhotoCount)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>Media Kapladığı Yer</span>
              <b>{formatSizeFromMb(storage.uploadedPhotoSizeMb)}</b>
            </div>
            <div className="ops-kpi-card" role="status" aria-live="polite">
              <span>DB Kapladığı Yer</span>
              <b>{formatSizeFromMb(storage.databaseSizeMb)}</b>
            </div>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body">
          <h3>Live Activity</h3>
          {loadingLive ? <div className="muted">Loading live stream...</div> : null}
          <div className="list">
            {(live?.activity || []).slice(0, 20).map((row) => (
              <div key={row.id} className="list-item">
                <div>
                  <div className="name">{row.message || row.type}</div>
                  <div className="meta">{row.at ? new Date(row.at).toLocaleString('tr-TR') : '-'}</div>
                </div>
              </div>
            ))}
            {!loading && (!live?.activity || !live.activity.length) ? <div className="muted">No live activity.</div> : null}
          </div>
        </div>
      </div>
    </section>
  );
}
