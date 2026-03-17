import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import useAdminQueryState from '../../../admin/hooks/useAdminQueryState.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminFilterBar from '../../../admin/components/AdminFilterBar.jsx';
import { useI18n } from '../../../utils/i18n.jsx';

function formatDate(value) {
  return value ? new Date(value).toLocaleString('tr-TR') : '-';
}

function reviewStatusLabel(value, t) {
  const status = String(value || '').trim().toLowerCase();
  if (status === 'confirmed') return t('Onaylandı');
  if (status === 'flagged') return t('İşaretlendi');
  if (status === 'rejected') return t('Reddedildi');
  if (status === 'merged') return t('Birleştirildi');
  return t('Beklemede');
}

function confidenceLabel(value) {
  const score = Number(value || 0);
  if (!Number.isFinite(score) || score <= 0) return '-';
  return `${(score * 100).toFixed(0)}%`;
}

function riskLevelLabel(value, t) {
  const level = String(value || '').trim().toLowerCase();
  if (level === 'high') return t('Yüksek risk');
  if (level === 'medium') return t('Orta risk');
  return t('Düşük risk');
}

function formatAssessmentSignals(items) {
  if (!Array.isArray(items) || !items.length) return '-';
  return items.map((item) => item?.label).filter(Boolean).join(' • ');
}

export default function TeacherNetworkSection() {
  const { t } = useI18n();
  const relationshipTypes = useMemo(() => ([
    { value: '', label: t('Tüm ilişki tipleri') },
    { value: 'taught_in_class', label: t('Aynı sınıfta ders aldım') },
    { value: 'mentor', label: t('Mentor') },
    { value: 'advisor', label: t('Danışman') }
  ]), [t]);
  const reviewStatuses = useMemo(() => ([
    { value: '', label: t('Tüm inceleme durumları') },
    { value: 'pending', label: t('Beklemede') },
    { value: 'confirmed', label: t('Onaylandı') },
    { value: 'flagged', label: t('İşaretlendi') },
    { value: 'rejected', label: t('Reddedildi') },
    { value: 'merged', label: t('Birleştirildi') }
  ]), [t]);
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
      setError(err.message || t('Öğretmen ağı moderasyon verisi yüklenemedi.'));
    } finally {
      setLoading(false);
    }
  }, [query, t]);

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
      setError(err.message || t('Öğretmen ağı incelemesi güncellenemedi.'));
    } finally {
      setBusyId(null);
    }
  }, [load, reviewDrafts, t]);

  const columns = useMemo(() => ([
    { key: 'id', label: 'ID' },
    {
      key: 'teacher',
      label: t('Öğretmen'),
      render: (row) => `@${row.teacher_kadi || '-'} (${row.teacher_isim || ''} ${row.teacher_soyisim || ''})`
    },
    {
      key: 'alumni',
      label: t('Mezun'),
      render: (row) => `@${row.alumni_kadi || '-'} (${row.alumni_isim || ''} ${row.alumni_soyisim || ''})`
    },
    { key: 'alumni_mezuniyetyili', label: t('Mezuniyet Yılı') },
    { key: 'relationship_type', label: t('İlişki') },
    { key: 'class_year', label: t('Sınıf Yılı') },
    {
      key: 'audit',
      label: t('Denetim Kaydı'),
      render: (row) => (
        <div className="stack">
          <span>{reviewStatusLabel(row.review_status, t)}</span>
          <span className="muted">{t('güven')} {confidenceLabel(row.confidence_score)}</span>
          <span className="muted">{row.created_via || '-'}</span>
          <span className="muted">{row.source_surface || '-'}</span>
          <span className="muted">{row.reviewer_kadi ? t('@{kadi} tarafından incelendi', { kadi: row.reviewer_kadi }) : t('Henüz incelenmedi')}</span>
          <span className="muted">{row.reviewed_at ? t('İncelenme: {date}', { date: formatDate(row.reviewed_at) }) : t('İnceleme zamanı eksik')}</span>
          <span className="muted">{row.review_note ? t('Not: {note}', { note: row.review_note }) : t('İnceleme notu yok')}</span>
          <span className="muted">{row.merged_into_link_id ? t('#{id} içine birleştirildi', { id: row.merged_into_link_id }) : t('Birleştirilmedi')}</span>
          <span className="muted">{t('{count} moderasyon olayı', { count: Number(row.moderation_event_count || 0) })}</span>
          <span className="muted">{row.last_event_type ? t('{event} @ {date}', { event: row.last_event_type, date: formatDate(row.last_event_at) }) : t('Henüz moderasyon kaydı yok')}</span>
          <span className="muted">{riskLevelLabel(row.moderation_assessment?.risk_level, t)} • {t('öneri')} {row.moderation_assessment?.recommended_action_label || t('Beklemede tut')}</span>
          <span className="muted">{row.moderation_assessment?.decision_hint || t('Karar önerisi yok.')}</span>
          <span className="muted">{t('Riskler')}: {formatAssessmentSignals(row.moderation_assessment?.risk_signals)}</span>
          <span className="muted">{t('Pozitifler')}: {formatAssessmentSignals(row.moderation_assessment?.positive_signals)}</span>
        </div>
      )
    },
    {
      key: 'created_at',
      label: t('Oluşturulma'),
      render: (row) => formatDate(row.created_at)
    },
    {
      key: 'actions',
      label: t('Aksiyonlar'),
      render: (row) => (
        <div className="stack">
          <input
            className="input"
            value={reviewDrafts[row.id] || ''}
            placeholder={t('İsteğe bağlı inceleme notu')}
            onClick={(e) => e.stopPropagation()}
            onChange={(e) => {
              const value = e.target.value;
              setReviewDrafts((prev) => ({ ...prev, [row.id]: value }));
            }}
          />
          <div className="composer-actions">
            <button className="btn ghost" disabled={busyId === row.id || row.review_status === 'confirmed'} onClick={(e) => { e.stopPropagation(); updateReviewStatus(row.id, 'confirmed'); }}>
              {t('Onayla')}
            </button>
            <button className="btn ghost" disabled={busyId === row.id || row.review_status === 'flagged'} onClick={(e) => { e.stopPropagation(); updateReviewStatus(row.id, 'flagged'); }}>
              {t('İşaretle')}
            </button>
            <button className="btn ghost" disabled={busyId === row.id || row.review_status === 'rejected'} onClick={(e) => { e.stopPropagation(); updateReviewStatus(row.id, 'rejected'); }}>
              {t('Reddet')}
            </button>
            <button className="btn ghost" disabled={busyId === row.id || row.review_status === 'merged'} onClick={(e) => { e.stopPropagation(); updateReviewStatus(row.id, 'merged'); }}>
              {t('Birleştir')}
            </button>
            <button className="btn ghost" disabled={busyId === row.id || row.review_status === 'pending'} onClick={(e) => { e.stopPropagation(); updateReviewStatus(row.id, 'pending'); }}>
              {t('Sıfırla')}
            </button>
          </div>
        </div>
      )
    }
  ]), [busyId, reviewDrafts, t, updateReviewStatus]);

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>{t('Öğretmen Ağı Moderasyonu')}</h3>
        <button className="btn ghost" onClick={load} disabled={loading}>{t('Yenile')}</button>
      </div>

      <AdminFilterBar
        searchValue={query.q}
        onSearchChange={setSearch}
        searchPlaceholder={t('Öğretmen veya mezun ara')}
      >
        <select className="input" value={query.relationship_type || ''} onChange={(e) => patchQuery({ relationship_type: e.target.value, page: 1 })}>
          {relationshipTypes.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
        </select>
        <select className="input" value={query.review_status || ''} onChange={(e) => patchQuery({ review_status: e.target.value, page: 1 })}>
          {reviewStatuses.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
        </select>
      </AdminFilterBar>

      {error ? <div className="muted">{error}</div> : null}

      <AdminDataTable
        columns={columns}
        rows={rows}
        loading={loading}
        pagination={meta}
        onPageChange={setPage}
        emptyText={t('Öğretmen ağı bağlantısı bulunamadı.')}
      />
    </section>
  );
}
