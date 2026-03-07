import React, { useCallback, useEffect, useRef, useState } from 'react';
import { adminClient } from '../../../admin/api/adminClient.js';

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
    try {
      const statsData = await adminClient.get('/api/new/admin/stats');
      if (requestSeq === requestSeqRef.current) {
        setStats(statsData || null);
      }
    } catch (err) {
      if (requestSeq === requestSeqRef.current) {
        setError(err.message || 'Dashboard summary could not be loaded.');
      }
    } finally {
      if (requestSeq === requestSeqRef.current) {
        setLoadingStats(false);
      }
    }

    try {
      const liveData = await adminClient.get('/api/new/admin/live');
      if (requestSeq === requestSeqRef.current) {
        setLive(liveData || { activity: [], counts: {} });
      }
    } catch (err) {
      if (requestSeq === requestSeqRef.current) {
        setError((prev) => prev || err.message || 'Live activity could not be loaded.');
      }
    } finally {
      if (requestSeq === requestSeqRef.current) {
        setLoadingLive(false);
      }
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const counts = stats?.counts || {};
  const queue = live?.counts || {};

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
