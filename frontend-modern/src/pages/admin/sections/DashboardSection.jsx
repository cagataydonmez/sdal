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

export default function DashboardSection({ onNavigate }) {
  const [stats, setStats] = useState(null);
  const [live, setLive] = useState({ activity: [], counts: {} });
  const [loadingStats, setLoadingStats] = useState(false);
  const [loadingLive, setLoadingLive] = useState(false);
  const [error, setError] = useState('');
  const requestSeqRef = useRef(0);

  const loading = loadingStats || loadingLive;

  const load = useCallback(async () => {
    const requestSeq = ++requestSeqRef.current;
    setLoadingStats(true);
    setLoadingLive(true);
    setError('');
    const [statsResult, liveResult] = await Promise.allSettled([
      adminClient.get('/api/new/admin/stats'),
      adminClient.get('/api/new/admin/live')
    ]);
    if (requestSeq !== requestSeqRef.current) return;

    if (statsResult.status === 'fulfilled') {
      setStats(statsResult.value || null);
    } else {
      setError(statsResult.reason?.message || 'Dashboard summary could not be loaded.');
    }
    setLoadingStats(false);

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

  const counts = stats?.counts || {};
  const queue = live?.counts || {};
  const storage = stats?.storage || {};

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
