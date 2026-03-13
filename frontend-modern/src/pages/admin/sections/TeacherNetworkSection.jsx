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

const REVIEW_STATUSES = [
  { value: '', label: 'All review states' },
  { value: 'pending', label: 'Pending' },
  { value: 'confirmed', label: 'Confirmed' },
  { value: 'flagged', label: 'Flagged' },
  { value: 'rejected', label: 'Rejected' },
  { value: 'merged', label: 'Merged' }
];

function reviewStatusLabel(value) {
  const status = String(value || '').trim().toLowerCase();
  if (status === 'confirmed') return 'Confirmed';
  if (status === 'flagged') return 'Flagged';
  if (status === 'rejected') return 'Rejected';
  if (status === 'merged') return 'Merged';
  return 'Pending';
}

function confidenceLabel(value) {
  const score = Number(value || 0);
  if (!Number.isFinite(score) || score <= 0) return '-';
  return `${(score * 100).toFixed(0)}%`;
}

function riskLevelLabel(value) {
  const level = String(value || '').trim().toLowerCase();
  if (level === 'high') return 'High risk';
  if (level === 'medium') return 'Medium risk';
  return 'Low risk';
}

function formatAssessmentSignals(items) {
  if (!Array.isArray(items) || !items.length) return '-';
  return items.map((item) => item?.label).filter(Boolean).join(' • ');
}

export default function TeacherNetworkSection() {
  const { query, patchQuery, setSearch, setPage } = useAdminQueryState({
    q: '',
    page: 1,
    limit: 40,
    relationship_type: '',
    review_status: ''
  });
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState({ page: 1, pages: 1, total: 0, limit: 40 });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [busyId, setBusyId] = useState(null);
  const [reviewDrafts, setReviewDrafts] = useState({});

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

  const updateReviewStatus = useCallback(async (rowId, status) => {
    setBusyId(rowId);
    setError('');
    try {
      const result = await adminClient.post(`/api/new/admin/teacher-network/links/${rowId}/review`, {
        status,
        note: reviewDrafts[rowId] || ''
      });
      setRows((prev) => prev.map((row) => (
        Number(row.id) === Number(rowId)
          ? {
            ...row,
            review_status: status,
            confidence_score: result?.confidence_score ?? row.confidence_score,
            review_note: result?.review_note ?? reviewDrafts[rowId] ?? row.review_note,
            reviewed_at: result?.reviewed_at ?? row.reviewed_at,
            merged_into_link_id: result?.merged_into_link_id ?? row.merged_into_link_id,
            moderation_event_count: Number(row.moderation_event_count || 0) + 1,
            last_event_type: status === 'merged' ? 'teacher_link_merged' : 'teacher_link_reviewed',
            last_event_at: result?.reviewed_at ?? row.last_event_at
          }
          : row
      )));
      setReviewDrafts((prev) => {
        const next = { ...prev };
        delete next[rowId];
        return next;
      });
      load();
    } catch (err) {
      setError(err.message || 'Teacher network review could not be updated.');
    } finally {
      setBusyId(null);
    }
  }, [load, reviewDrafts]);

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
      key: 'audit',
      label: 'Audit Trail',
      render: (row) => (
        <div className="stack">
          <span>{reviewStatusLabel(row.review_status)}</span>
          <span className="muted">confidence {confidenceLabel(row.confidence_score)}</span>
          <span className="muted">{row.created_via || '-'}</span>
          <span className="muted">{row.source_surface || '-'}</span>
          <span className="muted">{row.reviewer_kadi ? `reviewed by @${row.reviewer_kadi}` : 'not reviewed yet'}</span>
          <span className="muted">{row.reviewed_at ? `reviewed ${formatDate(row.reviewed_at)}` : 'review time missing'}</span>
          <span className="muted">{row.review_note ? `note: ${row.review_note}` : 'no review note'}</span>
          <span className="muted">{row.merged_into_link_id ? `merged into #${row.merged_into_link_id}` : 'not merged'}</span>
          <span className="muted">{Number(row.moderation_event_count || 0)} moderation events</span>
          <span className="muted">{row.last_event_type ? `${row.last_event_type} at ${formatDate(row.last_event_at)}` : 'no moderation log yet'}</span>
          <span className="muted">{riskLevelLabel(row.moderation_assessment?.risk_level)} • suggested {row.moderation_assessment?.recommended_action_label || 'Keep pending'}</span>
          <span className="muted">{row.moderation_assessment?.decision_hint || 'No decision hint available.'}</span>
          <span className="muted">Risks: {formatAssessmentSignals(row.moderation_assessment?.risk_signals)}</span>
          <span className="muted">Positives: {formatAssessmentSignals(row.moderation_assessment?.positive_signals)}</span>
        </div>
      )
    },
    {
      key: 'created_at',
      label: 'Created',
      render: (row) => formatDate(row.created_at)
    },
    {
      key: 'actions',
      label: 'Actions',
      render: (row) => (
        <div className="stack">
          <input
            className="input"
            value={reviewDrafts[row.id] || ''}
            placeholder="Optional review note"
            onClick={(e) => e.stopPropagation()}
            onChange={(e) => {
              const value = e.target.value;
              setReviewDrafts((prev) => ({ ...prev, [row.id]: value }));
            }}
          />
          <div className="composer-actions">
            <button className="btn ghost" disabled={busyId === row.id || row.review_status === 'confirmed'} onClick={(e) => { e.stopPropagation(); updateReviewStatus(row.id, 'confirmed'); }}>
              Confirm
            </button>
            <button className="btn ghost" disabled={busyId === row.id || row.review_status === 'flagged'} onClick={(e) => { e.stopPropagation(); updateReviewStatus(row.id, 'flagged'); }}>
              Flag
            </button>
            <button className="btn ghost" disabled={busyId === row.id || row.review_status === 'rejected'} onClick={(e) => { e.stopPropagation(); updateReviewStatus(row.id, 'rejected'); }}>
              Reject
            </button>
            <button className="btn ghost" disabled={busyId === row.id || row.review_status === 'merged'} onClick={(e) => { e.stopPropagation(); updateReviewStatus(row.id, 'merged'); }}>
              Merge
            </button>
            <button className="btn ghost" disabled={busyId === row.id || row.review_status === 'pending'} onClick={(e) => { e.stopPropagation(); updateReviewStatus(row.id, 'pending'); }}>
              Reset
            </button>
          </div>
        </div>
      )
    }
  ]), [busyId, reviewDrafts, updateReviewStatus]);

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
        <select className="input" value={query.review_status || ''} onChange={(e) => patchQuery({ review_status: e.target.value, page: 1 })}>
          {REVIEW_STATUSES.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
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
