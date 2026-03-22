import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import useAdminQueryState from '../../../admin/hooks/useAdminQueryState.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminFilterBar from '../../../admin/components/AdminFilterBar.jsx';
import AdminDetailDrawer from '../../../admin/components/AdminDetailDrawer.jsx';
import { useI18n } from '../../../utils/i18n.jsx';

function toUserStatus(row) {
  if (Number(row?.yasak || 0) === 1) return 'banned';
  if (Number(row?.aktiv || 0) === 1) return 'active';
  return 'pending';
}

export default function UsersSection({ canManageRoles }) {
  const { t } = useI18n();
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
  const [graduationYearInput, setGraduationYearInput] = useState('');
  const [savingGraduationYear, setSavingGraduationYear] = useState(false);

  const loadUsers = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const data = await adminClient.get(withQuery('/api/admin/users/lists', query));
      setRows(data.users || []);
      setMeta(data.meta || { page: 1, pages: 1, total: 0, limit: Number(query.limit) || 20 });
    } catch (err) {
      setError(err.message || t('Kullanıcılar yüklenemedi.'));
    } finally {
      setLoading(false);
    }
  }, [query, t]);

  useEffect(() => {
    loadUsers();
  }, [loadUsers]);

  const openDetail = useCallback(async (row) => {
    try {
      const data = await adminClient.get(`/api/admin/users/${row.id}`);
      setSelectedUser(row);
      setDetail(data.user || null);
      setGraduationYearInput(String(data.user?.mezuniyetyili || ''));
    } catch (err) {
      setError(err.message || t('Kullanıcı detayı yüklenemedi.'));
    }
  }, [t]);

  const updateRole = useCallback(async (nextRole) => {
    if (!detail?.id) return;
    setRoleBusy(true);
    try {
      await adminClient.post(`/admin/users/${detail.id}/role`, { role: nextRole });
      setDetail((prev) => ({ ...(prev || {}), role: nextRole, admin: nextRole === 'admin' ? 1 : 0 }));
      await loadUsers();
    } catch (err) {
      setError(err.message || t('Rol güncellemesi başarısız.'));
    } finally {
      setRoleBusy(false);
    }
  }, [detail, loadUsers, t]);



  const updateGraduationYear = useCallback(async () => {
    if (!detail?.id) return;
    setSavingGraduationYear(true);
    setError('');
    try {
      await adminClient.put(`/api/new/admin/users/${detail.id}/graduation-year`, { mezuniyetyili: graduationYearInput });
      const nextValue = String(graduationYearInput || '').trim();
      setDetail((prev) => ({ ...(prev || {}), mezuniyetyili: nextValue }));
      await loadUsers();
    } catch (err) {
      setError(err.message || t('Mezuniyet yılı güncellemesi başarısız.'));
    } finally {
      setSavingGraduationYear(false);
    }
  }, [detail, graduationYearInput, loadUsers, t]);

  const columns = useMemo(() => ([
    { key: 'kadi', label: t('Kullanıcı Adı') },
    {
      key: 'name',
      label: t('Ad Soyad'),
      render: (row) => `${row.isim || ''} ${row.soyisim || ''}`.trim() || '-'
    },
    { key: 'mezuniyetyili', label: t('Dönem') },
    {
      key: 'status',
      label: t('Durum'),
      render: (row) => t(toUserStatus(row))
    },
    { key: 'role', label: t('Rol') },
    {
      key: 'engagement_score',
      label: t('Skor'),
      render: (row) => Number(row.engagement_score || 0).toFixed(2)
    }
  ]), [t]);

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>{t('Kullanıcılar')}</h3>
        <button className="btn ghost" onClick={loadUsers} disabled={loading}>{t('Yenile')}</button>
      </div>

      <AdminFilterBar
        searchValue={query.q}
        onSearchChange={setSearch}
        searchPlaceholder={t('Kullanıcı adı, ad, soyad, e-posta ara')}
      >
        <select className="input" value={query.filter} onChange={(e) => patchQuery({ filter: e.target.value, page: 1 })}>
          <option value="all">{t('Tümü')}</option>
          <option value="active">{t('active')}</option>
          <option value="pending">{t('pending')}</option>
          <option value="banned">{t('banned')}</option>
          <option value="online">{t('Online')}</option>
        </select>
        <select className="input" value={query.sort} onChange={(e) => patchQuery({ sort: e.target.value, page: 1 })}>
          <option value="engagement_desc">{t('Skor azalan')}</option>
          <option value="engagement_asc">{t('Skor artan')}</option>
          <option value="recent">{t('En yeni')}</option>
          <option value="name">{t('Ad')}</option>
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
        emptyText={t('Kullanıcı bulunamadı.')}
      />

      <AdminDetailDrawer
        title={detail ? `@${detail.kadi}` : t('Kullanıcı Detayı')}
        open={!!detail}
        onClose={() => { setDetail(null); setSelectedUser(null); setGraduationYearInput(''); }}
      >
        {detail ? (
          <div className="stack">
            <div className="chip">{t('Rol')}: {t(detail.role || 'user')}</div>
            <div className="chip">{t('Doğrulama')}: {Number(detail.verified || 0) === 1 ? t('verified') : t('not verified')}</div>
            <div className="chip">{t('Dönem')}: {detail.mezuniyetyili || '-'}</div>
            <div className="ops-inline-actions">
              <select className="input admin-input-year" value={graduationYearInput} onChange={(e) => setGraduationYearInput(e.target.value)}>
                <option value="teacher">Öğretmen</option>
                {Array.from({ length: new Date().getFullYear() - 1999 + 1 }, (_, i) => String(new Date().getFullYear() - i)).map((year) => <option key={year} value={year}>{year}</option>)}
              </select>
              <button className="btn ghost" disabled={savingGraduationYear} onClick={() => updateGraduationYear()}>
                {savingGraduationYear ? t('saving') : t('Dönemi Güncelle')}
              </button>
            </div>
            <div className="chip">Email: {detail.email || '-'}</div>
            {canManageRoles ? (
              <div className="ops-inline-actions">
                <button className="btn" disabled={roleBusy} onClick={() => updateRole('user')}>{t('Kullanıcı yap')}</button>
                <button className="btn" disabled={roleBusy} onClick={() => updateRole('mod')}>{t('Mod yap')}</button>
                <button className="btn" disabled={roleBusy} onClick={() => updateRole('admin')}>{t('Yönetici yap')}</button>
              </div>
            ) : null}
            {selectedUser ? <div className="meta">{t('Liste satırı ID {id} üzerinden açıldı', { id: selectedUser.id })}</div> : null}
          </div>
        ) : null}
      </AdminDetailDrawer>
    </section>
  );
}
