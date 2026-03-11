import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import useAdminQueryState from '../../../admin/hooks/useAdminQueryState.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminFilterBar from '../../../admin/components/AdminFilterBar.jsx';

function formatDate(value) {
  return value ? new Date(value).toLocaleString('tr-TR') : '-';
}

const RELATIONSHIP_TYPES = [
  { value: '', label: 'All relationship types' },
  { value: 'taught_in_class', label: 'Aynı sınıfta ders aldım' },
  { value: 'mentor', label: 'Mentor' },
  { value: 'advisor', label: 'Danışman' }
];

export default function TeacherNetworkSection() {
  const { query, patchQuery, setSearch, setPage } = useAdminQueryState({
    q: '',
    page: 1,
    limit: 40,
    relationship_type: ''
  });
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState({ page: 1, pages: 1, total: 0, limit: 40 });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const data = await adminClient.get(withQuery('/api/new/admin/teacher-network/links', query));
      setRows(data.items || []);
      setMeta(data.meta || { page: 1, pages: 1, total: 0, limit: Number(query.limit) || 40 });
    } catch (err) {
      setError(err.message || 'Teacher network moderation data could not be loaded.');
    } finally {
      setLoading(false);
    }
  }, [query]);

  useEffect(() => {
    load();
  }, [load]);

  const columns = useMemo(() => ([
    { key: 'id', label: 'ID' },
    {
      key: 'teacher',
      label: 'Teacher',
      render: (row) => `@${row.teacher_kadi || '-'} (${row.teacher_isim || ''} ${row.teacher_soyisim || ''})`
    },
    {
      key: 'alumni',
      label: 'Alumni',
      render: (row) => `@${row.alumni_kadi || '-'} (${row.alumni_isim || ''} ${row.alumni_soyisim || ''})`
    },
    { key: 'alumni_mezuniyetyili', label: 'Alumni Cohort' },
    { key: 'relationship_type', label: 'Relationship' },
    { key: 'class_year', label: 'Class Year' },
    {
      key: 'created_at',
      label: 'Created',
      render: (row) => formatDate(row.created_at)
    }
  ]), []);

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>Teacher Network Moderation</h3>
        <button className="btn ghost" onClick={load} disabled={loading}>Refresh</button>
      </div>

      <AdminFilterBar
        searchValue={query.q}
        onSearchChange={setSearch}
        searchPlaceholder="Search teacher or alumni"
      >
        <select className="input" value={query.relationship_type || ''} onChange={(e) => patchQuery({ relationship_type: e.target.value, page: 1 })}>
          {RELATIONSHIP_TYPES.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
        </select>
      </AdminFilterBar>

      {error ? <div className="muted">{error}</div> : null}

      <AdminDataTable
        columns={columns}
        rows={rows}
        loading={loading}
        pagination={meta}
        onPageChange={setPage}
        emptyText="No teacher network links found."
      />
    </section>
  );
}
