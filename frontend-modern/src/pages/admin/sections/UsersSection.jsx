import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import useAdminQueryState from '../../../admin/hooks/useAdminQueryState.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminFilterBar from '../../../admin/components/AdminFilterBar.jsx';
import AdminDetailDrawer from '../../../admin/components/AdminDetailDrawer.jsx';

function toUserStatus(row) {
  if (Number(row?.yasak || 0) === 1) return 'banned';
  if (Number(row?.aktiv || 0) === 1) return 'active';
  return 'pending';
}

export default function UsersSection({ canManageRoles }) {
  const { query, patchQuery, setSearch, setPage } = useAdminQueryState({
    filter: 'active',
    q: '',
    page: 1,
    limit: 20,
    sort: 'engagement_desc'
  });
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState({ page: 1, pages: 1, total: 0, limit: 20 });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [selectedUser, setSelectedUser] = useState(null);
  const [detail, setDetail] = useState(null);
  const [roleBusy, setRoleBusy] = useState(false);

  const loadUsers = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const data = await adminClient.get(withQuery('/api/admin/users/lists', query));
      setRows(data.users || []);
      setMeta(data.meta || { page: 1, pages: 1, total: 0, limit: Number(query.limit) || 20 });
    } catch (err) {
      setError(err.message || 'Users could not be loaded.');
    } finally {
      setLoading(false);
    }
  }, [query]);

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  const openDetail = useCallback(async (row) => {
    try {
      const data = await adminClient.get(`/api/admin/users/${row.id}`);
      setSelectedUser(row);
      setDetail(data.user || null);
    } catch (err) {
      setError(err.message || 'User detail could not be loaded.');
    }
  }, []);

  const updateRole = useCallback(async (nextRole) => {
    if (!detail?.id) return;
    setRoleBusy(true);
    try {
      await adminClient.post(`/admin/users/${detail.id}/role`, { role: nextRole });
      setDetail((prev) => ({ ...(prev || {}), role: nextRole, admin: nextRole === 'admin' ? 1 : 0 }));
      await loadUsers();
    } catch (err) {
      setError(err.message || 'Role update failed.');
    } finally {
      setRoleBusy(false);
    }
  }, [detail, loadUsers]);

  const columns = useMemo(() => ([
    { key: 'kadi', label: 'Username' },
    {
      key: 'name',
      label: 'Name',
      render: (row) => `${row.isim || ''} ${row.soyisim || ''}`.trim() || '-'
    },
    { key: 'mezuniyetyili', label: 'Cohort' },
    {
      key: 'status',
      label: 'Status',
      render: (row) => toUserStatus(row)
    },
    { key: 'role', label: 'Role' },
    {
      key: 'engagement_score',
      label: 'Score',
      render: (row) => Number(row.engagement_score || 0).toFixed(2)
    }
  ]), []);

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>Users</h3>
        <button className="btn ghost" onClick={loadUsers} disabled={loading}>Refresh</button>
      </div>

      <AdminFilterBar
        searchValue={query.q}
        onSearchChange={setSearch}
        searchPlaceholder="Search username, name, surname, email"
      >
        <select className="input" value={query.filter} onChange={(e) => patchQuery({ filter: e.target.value, page: 1 })}>
          <option value="all">All</option>
          <option value="active">Active</option>
          <option value="pending">Pending</option>
          <option value="banned">Banned</option>
          <option value="online">Online</option>
        </select>
        <select className="input" value={query.sort} onChange={(e) => patchQuery({ sort: e.target.value, page: 1 })}>
          <option value="engagement_desc">Score desc</option>
          <option value="engagement_asc">Score asc</option>
          <option value="recent">Recent</option>
          <option value="name">Name</option>
        </select>
      </AdminFilterBar>

      {error ? <div className="muted">{error}</div> : null}

      <AdminDataTable
        columns={columns}
        rows={rows}
        loading={loading}
        pagination={meta}
        onPageChange={setPage}
        onRowClick={openDetail}
        emptyText="No users found."
      />

      <AdminDetailDrawer
        title={detail ? `@${detail.kadi}` : 'User Detail'}
        open={!!detail}
        onClose={() => { setDetail(null); setSelectedUser(null); }}
      >
        {detail ? (
          <div className="stack">
            <div className="chip">Role: {detail.role || 'user'}</div>
            <div className="chip">Verification: {Number(detail.verified || 0) === 1 ? 'verified' : 'not verified'}</div>
            <div className="chip">Cohort: {detail.mezuniyetyili || '-'}</div>
            <div className="chip">Email: {detail.email || '-'}</div>
            {canManageRoles ? (
              <div className="ops-inline-actions">
                <button className="btn" disabled={roleBusy} onClick={() => updateRole('user')}>Set user</button>
                <button className="btn" disabled={roleBusy} onClick={() => updateRole('mod')}>Set mod</button>
                <button className="btn" disabled={roleBusy} onClick={() => updateRole('admin')}>Set admin</button>
              </div>
            ) : null}
            {selectedUser ? <div className="meta">Opened from list row ID {selectedUser.id}</div> : null}
          </div>
        ) : null}
      </AdminDetailDrawer>
    </section>
  );
}
