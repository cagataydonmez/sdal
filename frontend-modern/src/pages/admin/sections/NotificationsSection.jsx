import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import useAdminQueryState from '../../../admin/hooks/useAdminQueryState.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminFilterBar from '../../../admin/components/AdminFilterBar.jsx';
import AdminDetailDrawer from '../../../admin/components/AdminDetailDrawer.jsx';
import { useI18n } from '../../../utils/i18n.jsx';

function safeJsonParse(value) {
  try {
    return JSON.parse(String(value || '{}'));
  } catch {
    return {};
  }
}

function unwrapData(payload) {
  return payload?.data || payload || {};
}

function formatDate(value) {
  return value ? new Date(value).toLocaleString('tr-TR') : '-';
}

export default function NotificationsSection({ canViewRequests = false, canModerateRequests = false, isAdmin = false }) {
  const { t } = useI18n();
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
  const [ops, setOps] = useState(null);
  const [governance, setGovernance] = useState({ checklist: [], inventory: [] });
  const [experiments, setExperiments] = useState([]);
  const [experimentBusyKey, setExperimentBusyKey] = useState('');

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

  const loadAdminOps = useCallback(async () => {
    if (!isAdmin) return;
    try {
      const [opsPayload, governancePayload, experimentsPayload] = await Promise.all([
        adminClient.get('/api/new/admin/notifications/ops?window=30d'),
        adminClient.get('/api/new/admin/notifications/governance'),
        adminClient.get('/api/new/admin/notifications/experiments')
      ]);
      setOps(unwrapData(opsPayload));
      setGovernance(unwrapData(governancePayload));
      setExperiments(unwrapData(experimentsPayload).items || []);
    } catch {
      setOps(null);
      setGovernance({ checklist: [], inventory: [] });
      setExperiments([]);
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
      setError(err.message || t('Bildirim kuyrukları yüklenemedi.'));
    } finally {
      setLoading(false);
    }
  }, [availableKinds.length, kind, query, t]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    loadCategories();
  }, [loadCategories]);

  useEffect(() => {
    loadAdminOps();
  }, [loadAdminOps]);

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
          label: t('Üye'),
          render: (row) => `@${row.kadi || '-'} (${row.user_id || '-'})`
        },
        {
          key: 'category_label',
          label: t('Kategori'),
          render: (row) => row.category_label || row.category_key || '-'
        },
        { key: 'status', label: t('Durum') },
        {
          key: 'created_at',
          label: t('Oluşturulma'),
          render: (row) => formatDate(row.created_at)
        }
      ];
    }

    return [
      { key: 'id', label: 'ID' },
      {
        key: 'member',
        label: t('Üye'),
        render: (row) => `@${row.kadi || '-'} (${row.user_id || '-'})`
      },
      { key: 'mezuniyetyili', label: t('Mezuniyet Yılı') },
      { key: 'status', label: t('Durum') },
      {
        key: 'created_at',
        label: t('Oluşturulma'),
        render: (row) => formatDate(row.created_at)
      }
    ];
  }, [kind, t]);

  if (!availableKinds.length) {
    return (
      <section className="stack">
        <div className="panel"><div className="panel-body muted">{t('Talep moderasyonu yetkiniz yok.')}</div></div>
      </section>
    );
  }

  const selectedPayload = kind === 'requests' ? safeJsonParse(selectedRow?.payload_json) : null;

  async function saveExperiment(experiment) {
    setExperimentBusyKey(experiment.key);
    await adminClient.put(`/api/new/admin/notifications/experiments/${experiment.key}`, {
      status: experiment.status,
      variants: experiment.variants
    });
    await loadAdminOps();
    setExperimentBusyKey('');
  }

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>{t('Bildirimler')}</h3>
        <button className="btn ghost" onClick={load} disabled={loading}>{t('Yenile')}</button>
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

      {isAdmin && ops ? (
        <>
          <div className="ops-card-grid">
            <div className="ops-kpi-card">
              <span>{t('Eklenen')}</span>
              <b>{Number(ops.delivery_summary?.inserted || 0)}</b>
            </div>
            <div className="ops-kpi-card">
              <span>{t('Atlanan')}</span>
              <b>{Number(ops.delivery_summary?.skipped || 0)}</b>
            </div>
            <div className="ops-kpi-card">
              <span>{t('Başarısız')}</span>
              <b>{Number(ops.delivery_summary?.failed || 0)}</b>
            </div>
            <div className="ops-kpi-card">
              <span>{t('Sessiz mod kullanıcıları')}</span>
              <b>{Number(ops.quiet_mode_enabled_users || 0)}</b>
            </div>
          </div>

          <div className="ops-card-grid">
            <div className="panel">
              <div className="panel-body">
                <strong>{t('Uyarılar')}</strong>
                {(ops.alerts || []).length ? (
                  <div className="stack">
                    {(ops.alerts || []).map((item) => (
                      <div key={`${item.code}-${item.surface || 'global'}`} className="chip">
                        {item.severity || 'info'} · {item.message}
                      </div>
                    ))}
                  </div>
                ) : <div className="muted">Aktif alert yok.</div>}
              </div>
            </div>

            <div className="panel">
              <div className="panel-body">
                <strong>{t('Gürültülü tipler')}</strong>
                {(ops.noisy_types || []).length ? (
                  <div className="stack">
                    {(ops.noisy_types || []).slice(0, 8).map((item) => (
                      <div key={item.type} className="chip">
                        {item.type} · {item.count}
                      </div>
                    ))}
                  </div>
                ) : <div className="muted">Veri yok.</div>}
              </div>
            </div>
          </div>

          <div className="ops-card-grid">
            <div className="panel">
              <div className="panel-body">
                <strong>{t('Okunmamış yaşlanması')}</strong>
                {(ops.unread_aging || []).length ? (
                  <div className="stack">
                    {(ops.unread_aging || []).slice(0, 8).map((item) => (
                      <div key={item.type} className="chip">
                        {item.type} · {t('okunmamış')} {item.unread_count} · 1g {item.older_than_1d} · 7g {item.older_than_7d}
                      </div>
                    ))}
                  </div>
                ) : <div className="muted">Bekleyen okunmamış yük yok.</div>}
              </div>
            </div>

            <div className="panel">
              <div className="panel-body">
                <strong>{t('Yüzey dönüşümü')}</strong>
                {(ops.surface_conversion || []).length ? (
                  <div className="stack">
                    {(ops.surface_conversion || []).map((item) => (
                      <div key={item.surface} className="chip">
                        {item.surface} · {t('açılma')} {(Number(item.open_rate || 0) * 100).toFixed(0)}% · {t('aksiyon')} {(Number(item.action_rate || 0) * 100).toFixed(0)}%
                      </div>
                    ))}
                  </div>
                ) : <div className="muted">Conversion verisi yok.</div>}
              </div>
            </div>
          </div>

          <div className="ops-card-grid">
            <div className="panel">
              <div className="panel-body">
                <strong>{t('Yönetişim kontrol listesi')}</strong>
                <div className="stack">
                  {(governance.checklist || []).map((item) => (
                    <div key={item.key}>
                      <div><b>{item.label}</b></div>
                      <div className="muted">{item.description}</div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <div className="panel">
              <div className="panel-body">
                <strong>{t('Tip envanteri')}</strong>
                <div className="stack">
                  {(governance.inventory || []).slice(0, 10).map((item) => (
                    <div key={item.type} className="chip">
                      {item.type} · {item.category} · {item.priority} {item.has_dedupe_rule ? `· ${t('tekilleştirme')}` : ''}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>

          <div className="panel">
            <div className="panel-body">
              <strong>{t('Deneyler')}</strong>
              <div className="stack">
                {experiments.map((item) => (
                  <div key={item.key} className="notification-admin-experiment-row">
                    <div>
                      <div><b>{item.label || item.key}</b></div>
                      <div className="muted">{item.description}</div>
                    </div>
                    <select
                      className="input"
                      value={item.status}
                      onChange={(e) => setExperiments((prev) => prev.map((row) => (
                        row.key === item.key ? { ...row, status: e.target.value } : row
                      )))}
                    >
                      <option value="active">{t('aktif')}</option>
                      <option value="paused">{t('duraklatıldı')}</option>
                    </select>
                    <input
                      className="input"
                      value={Array.isArray(item.variants) ? item.variants.join(', ') : ''}
                      onChange={(e) => setExperiments((prev) => prev.map((row) => (
                        row.key === item.key
                          ? { ...row, variants: e.target.value.split(',').map((entry) => entry.trim()).filter(Boolean) }
                          : row
                      )))}
                    />
                    <button className="btn ghost" disabled={experimentBusyKey === item.key} onClick={() => saveExperiment(item).catch(() => {})}>
                      {experimentBusyKey === item.key ? t('Kaydediliyor...') : t('Kaydet')}
                    </button>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </>
      ) : null}

      <AdminFilterBar
        searchValue={query.q}
        onSearchChange={setSearch}
        searchPlaceholder={t('Üye veya kategori ara')}
      >
        {availableKinds.length > 1 ? (
          <select className="input" value={kind} onChange={(e) => { setKind(e.target.value); patchQuery({ page: 1 }); }}>
            {availableKinds.includes('requests') ? <option value="requests">{t('Destek Talepleri')}</option> : null}
            {availableKinds.includes('verification') ? <option value="verification">{t('Doğrulama Talepleri')}</option> : null}
          </select>
        ) : null}

        <select className="input" value={query.status || ''} onChange={(e) => patchQuery({ status: e.target.value, page: 1 })}>
          <option value="">{t('Tüm durumlar')}</option>
          <option value="pending">{t('Beklemede')}</option>
          <option value="approved">{t('Onaylandı')}</option>
          <option value="rejected">{t('Reddedildi')}</option>
        </select>

        {kind === 'requests' && isAdmin ? (
          <select className="input" value={query.category || ''} onChange={(e) => patchQuery({ category: e.target.value, page: 1 })}>
            <option value="">{t('Tüm kategoriler')}</option>
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
        emptyText={t('Kuyruk öğesi bulunamadı.')}
      />

      <AdminDetailDrawer
        title={selectedRow ? t('Kuyruk Öğesi #{id}', { id: selectedRow.id }) : t('Kuyruk Öğesi')}
        open={!!selectedRow}
        onClose={() => setSelectedRow(null)}
      >
        {selectedRow ? (
          <div className="stack">
            <div className="chip">{t('Üye')}: @{selectedRow.kadi || '-'}</div>
            <div className="chip">{t('Durum')}: {selectedRow.status || '-'}</div>
            <div className="chip">{t('Oluşturulma')}: {formatDate(selectedRow.created_at)}</div>

            {kind === 'requests' ? (
              <div className="panel">
                <div className="panel-body">
                  <strong>{t('Talep Verisi')}</strong>
                  <pre className="ops-json-preview">{JSON.stringify(selectedPayload, null, 2)}</pre>
                </div>
              </div>
            ) : null}

            {kind === 'verification' ? (
              <>
                <div className="chip">{t('Mezuniyet Yılı')}: {selectedRow.mezuniyetyili || '-'}</div>
                <div className="chip">{t('Kanıt')}: {selectedRow.proof_path ? <a href={selectedRow.proof_path} target="_blank" rel="noreferrer">{t('Kanıtı aç')}</a> : t('Dosya yok')}</div>
              </>
            ) : null}

            {canModerateRequests && selectedRow.status === 'pending' ? (
              <div className="ops-inline-actions">
                {kind === 'requests' ? (
                  <>
                    <button className="btn" onClick={() => reviewRequest(selectedRow.id, 'approved').catch(() => {})}>{t('Onayla')}</button>
                    <button className="btn ghost" onClick={() => reviewRequest(selectedRow.id, 'rejected').catch(() => {})}>{t('Reddet')}</button>
                  </>
                ) : (
                  <>
                    <button className="btn" onClick={() => reviewVerification(selectedRow.id, 'approved').catch(() => {})}>{t('Onayla')}</button>
                    <button className="btn ghost" onClick={() => reviewVerification(selectedRow.id, 'rejected').catch(() => {})}>{t('Reddet')}</button>
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
