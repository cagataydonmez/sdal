import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import useAdminQueryState from '../../../admin/hooks/useAdminQueryState.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminFilterBar from '../../../admin/components/AdminFilterBar.jsx';
import AdminDetailDrawer from '../../../admin/components/AdminDetailDrawer.jsx';

function safeJsonParse(value) {
  try {
    return JSON.parse(String(value || '{}'));
  } catch {
    return {};
  }
}

function formatDate(value) {
  return value ? new Date(value).toLocaleString('tr-TR') : '-';
}

export default function NotificationsSection({ canViewRequests = false, canModerateRequests = false, isAdmin = false }) {
  const availableKinds = useMemo(() => {
    const kinds = [];
    if (canViewRequests) kinds.push('requests');
    if (canViewRequests) kinds.push('verification');
    return kinds;
  }, [canViewRequests]);

  const [kind, setKind] = useState(availableKinds[0] || 'requests');
  const { query, patchQuery, setSearch, setPage } = useAdminQueryState({
    q: '',
    page: 1,
    limit: 40,
    status: 'pending',
    category: ''
  });
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState({ page: 1, pages: 1, total: 0, limit: 40 });
  const [categories, setCategories] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [selectedRow, setSelectedRow] = useState(null);

  useEffect(() => {
    if (!availableKinds.includes(kind)) {
      setKind(availableKinds[0] || 'requests');
    }
  }, [availableKinds, kind]);

  const loadCategories = useCallback(async () => {
    if (!isAdmin) return;
    try {
      const data = await adminClient.get('/api/new/admin/requests/notifications');
      setCategories(data.items || []);
    } catch {
      setCategories([]);
    }
  }, [isAdmin]);

  const load = useCallback(async () => {
    if (!availableKinds.length) return;
    setLoading(true);
    setError('');
    try {
      if (kind === 'requests') {
        const data = await adminClient.get(withQuery('/api/new/admin/requests', query));
        setRows(data.items || []);
        setMeta(data.meta || { page: 1, pages: 1, total: 0, limit: Number(query.limit) || 40 });
      } else {
        const data = await adminClient.get(withQuery('/api/new/admin/verification-requests', {
          q: query.q,
          page: query.page,
          limit: query.limit,
          status: query.status
        }));
        setRows(data.items || []);
        setMeta(data.meta || { page: 1, pages: 1, total: 0, limit: Number(query.limit) || 40 });
      }
    } catch (err) {
      setError(err.message || 'Notification queues could not be loaded.');
    } finally {
      setLoading(false);
    }
  }, [availableKinds.length, kind, query]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    loadCategories();
  }, [loadCategories]);

  const reviewRequest = useCallback(async (id, status) => {
    if (!canModerateRequests) return;
    await adminClient.post(`/api/new/admin/requests/${id}/review`, { status, resolution_note: '' });
    await load();
    setSelectedRow(null);
  }, [canModerateRequests, load]);

  const reviewVerification = useCallback(async (id, status) => {
    if (!canModerateRequests) return;
    await adminClient.post(`/api/new/admin/verification-requests/${id}`, { status });
    await load();
    setSelectedRow(null);
  }, [canModerateRequests, load]);

  const columns = useMemo(() => {
    if (kind === 'requests') {
      return [
        { key: 'id', label: 'ID' },
        {
          key: 'member',
          label: 'Member',
          render: (row) => `@${row.kadi || '-'} (${row.user_id || '-'})`
        },
        {
          key: 'category_label',
          label: 'Category',
          render: (row) => row.category_label || row.category_key || '-'
        },
        { key: 'status', label: 'Status' },
        {
          key: 'created_at',
          label: 'Created',
          render: (row) => formatDate(row.created_at)
        }
      ];
    }

    return [
      { key: 'id', label: 'ID' },
      {
        key: 'member',
        label: 'Member',
        render: (row) => `@${row.kadi || '-'} (${row.user_id || '-'})`
      },
      { key: 'mezuniyetyili', label: 'Cohort' },
      { key: 'status', label: 'Status' },
      {
        key: 'created_at',
        label: 'Created',
        render: (row) => formatDate(row.created_at)
      }
    ];
  }, [kind]);

  if (!availableKinds.length) {
    return (
      <section className="stack">
        <div className="panel"><div className="panel-body muted">No request moderation permissions.</div></div>
      </section>
    );
  }

  const selectedPayload = kind === 'requests' ? safeJsonParse(selectedRow?.payload_json) : null;

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>Notifications</h3>
        <button className="btn ghost" onClick={load} disabled={loading}>Refresh</button>
      </div>

      {isAdmin && categories.length ? (
        <div className="ops-card-grid">
          {categories.map((item) => (
            <button
              key={item.category_key}
              className="ops-kpi-card"
              onClick={() => {
                setKind('requests');
                patchQuery({ category: item.category_key, status: 'pending', page: 1 });
              }}
            >
              <span>{item.label || item.category_key}</span>
              <b>{Number(item.pending_count || 0)}</b>
            </button>
          ))}
        </div>
      ) : null}

      <AdminFilterBar
        searchValue={query.q}
        onSearchChange={setSearch}
        searchPlaceholder="Search by member or category"
      >
        {availableKinds.length > 1 ? (
          <select className="input" value={kind} onChange={(e) => { setKind(e.target.value); patchQuery({ page: 1 }); }}>
            {availableKinds.includes('requests') ? <option value="requests">Support Requests</option> : null}
            {availableKinds.includes('verification') ? <option value="verification">Verification Requests</option> : null}
          </select>
        ) : null}

        <select className="input" value={query.status || ''} onChange={(e) => patchQuery({ status: e.target.value, page: 1 })}>
          <option value="">All statuses</option>
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
        </select>

        {kind === 'requests' && isAdmin ? (
          <select className="input" value={query.category || ''} onChange={(e) => patchQuery({ category: e.target.value, page: 1 })}>
            <option value="">All categories</option>
            {categories.map((item) => (
              <option key={item.category_key} value={item.category_key}>{item.label || item.category_key}</option>
            ))}
          </select>
        ) : null}
      </AdminFilterBar>

      {error ? <div className="muted">{error}</div> : null}

      <AdminDataTable
        columns={columns}
        rows={rows}
        loading={loading}
        pagination={meta}
        onPageChange={setPage}
        onRowClick={setSelectedRow}
        emptyText="No queue items."
      />

      <AdminDetailDrawer
        title={selectedRow ? `Queue Item #${selectedRow.id}` : 'Queue Item'}
        open={!!selectedRow}
        onClose={() => setSelectedRow(null)}
      >
        {selectedRow ? (
          <div className="stack">
            <div className="chip">Member: @{selectedRow.kadi || '-'}</div>
            <div className="chip">Status: {selectedRow.status || '-'}</div>
            <div className="chip">Created: {formatDate(selectedRow.created_at)}</div>

            {kind === 'requests' ? (
              <div className="panel">
                <div className="panel-body">
                  <strong>Request Payload</strong>
                  <pre className="ops-json-preview">{JSON.stringify(selectedPayload, null, 2)}</pre>
                </div>
              </div>
            ) : null}

            {kind === 'verification' ? (
              <>
                <div className="chip">Cohort: {selectedRow.mezuniyetyili || '-'}</div>
                <div className="chip">Proof: {selectedRow.proof_path ? <a href={selectedRow.proof_path} target="_blank" rel="noreferrer">Open proof</a> : 'No file'}</div>
              </>
            ) : null}

            {canModerateRequests && selectedRow.status === 'pending' ? (
              <div className="ops-inline-actions">
                {kind === 'requests' ? (
                  <>
                    <button className="btn" onClick={() => reviewRequest(selectedRow.id, 'approved').catch(() => {})}>Approve</button>
                    <button className="btn ghost" onClick={() => reviewRequest(selectedRow.id, 'rejected').catch(() => {})}>Reject</button>
                  </>
                ) : (
                  <>
                    <button className="btn" onClick={() => reviewVerification(selectedRow.id, 'approved').catch(() => {})}>Approve</button>
                    <button className="btn ghost" onClick={() => reviewVerification(selectedRow.id, 'rejected').catch(() => {})}>Reject</button>
                  </>
                )}
              </div>
            ) : null}
          </div>
        ) : null}
      </AdminDetailDrawer>
    </section>
  );
}
