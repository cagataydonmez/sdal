import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import useAdminQueryState from '../../../admin/hooks/useAdminQueryState.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminFilterBar from '../../../admin/components/AdminFilterBar.jsx';
import { useI18n } from '../../../utils/i18n.jsx';

function formatDate(value) {
  return value ? new Date(value).toLocaleString('tr-TR') : '-';
}

export default function GroupsEventsSection({ canViewGroups = false, canDeleteGroups = false, isAdmin = false }) {
  const { t } = useI18n();
  const availableKinds = useMemo(() => {
    const kinds = [];
    if (canViewGroups) kinds.push('groups');
    if (isAdmin) {
      kinds.push('events');
      kinds.push('announcements');
    }
    return kinds;
  }, [canViewGroups, isAdmin]);

  const [kind, setKind] = useState(availableKinds[0] || 'groups');
  const { query, patchQuery, setSearch, setPage } = useAdminQueryState({ q: '', page: 1, limit: 40 });
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState({ page: 1, pages: 1, total: 0, limit: 40 });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!availableKinds.includes(kind)) {
      setKind(availableKinds[0] || 'groups');
    }
  }, [availableKinds, kind]);

  const load = useCallback(async () => {
    if (!availableKinds.length) return;
    setLoading(true);
    setError('');
    try {
      if (kind === 'groups') {
        const data = await adminClient.get(withQuery('/api/new/admin/groups', query));
        setRows(data.items || []);
        setMeta(data.meta || { page: 1, pages: 1, total: 0, limit: Number(query.limit) || 40 });
        return;
      }

      if (kind === 'events') {
        const limit = Number(query.limit) || 40;
        const page = Number(query.page) || 1;
        const offset = (page - 1) * limit;
        const data = await adminClient.get(withQuery('/api/new/events', { limit, offset }));
        const items = (data.items || []).filter((row) => {
          if (!query.q) return true;
          const haystack = `${row.title || ''} ${row.description || ''} ${row.location || ''} ${row.creator_kadi || ''}`.toLowerCase();
          return haystack.includes(String(query.q || '').toLowerCase());
        });
        setRows(items);
        setMeta({
          page,
          pages: data.hasMore ? page + 1 : page,
          total: null,
          limit
        });
        return;
      }

      const limit = Number(query.limit) || 40;
      const page = Number(query.page) || 1;
      const offset = (page - 1) * limit;
      const data = await adminClient.get(withQuery('/api/new/announcements', { limit, offset }));
      const items = (data.items || []).filter((row) => {
        if (!query.q) return true;
        const haystack = `${row.title || ''} ${row.body || ''} ${row.creator_kadi || ''}`.toLowerCase();
        return haystack.includes(String(query.q || '').toLowerCase());
      });
      setRows(items);
      setMeta({
        page,
        pages: data.hasMore ? page + 1 : page,
        total: null,
        limit
      });
    } catch (err) {
      setError(err.message || t('Grup ve etkinlik verileri yüklenemedi.'));
    } finally {
      setLoading(false);
    }
  }, [availableKinds.length, kind, query, t]);

  useEffect(() => {
    load();
  }, [load]);

  const removeGroup = useCallback(async (groupId) => {
    if (!canDeleteGroups) return;
    await adminClient.del(`/api/new/admin/groups/${groupId}`);
    await load();
  }, [canDeleteGroups, load]);

  const moderateEvent = useCallback(async (eventId, approved) => {
    await adminClient.post(`/api/new/events/${eventId}/approve`, { approved: approved ? '1' : '0' });
    await load();
  }, [load]);

  const removeEvent = useCallback(async (eventId) => {
    await adminClient.del(`/api/new/events/${eventId}`);
    await load();
  }, [load]);

  const moderateAnnouncement = useCallback(async (announcementId, approved) => {
    await adminClient.post(`/api/new/announcements/${announcementId}/approve`, { approved: approved ? '1' : '0' });
    await load();
  }, [load]);

  const removeAnnouncement = useCallback(async (announcementId) => {
    await adminClient.del(`/api/new/announcements/${announcementId}`);
    await load();
  }, [load]);

  const columns = useMemo(() => {
    if (kind === 'groups') {
      return [
        { key: 'id', label: 'ID' },
        { key: 'name', label: t('Grup') },
        {
          key: 'owner_kadi',
          label: t('Sahip'),
          render: (row) => `@${row.owner_kadi || '-'}`
        },
        { key: 'owner_mezuniyetyili', label: t('Sahip Dönemi') },
        {
          key: 'created_at',
          label: t('Oluşturuldu'),
          render: (row) => formatDate(row.created_at)
        },
        {
          key: 'actions',
          label: canDeleteGroups ? t('İşlemler') : t('Erişim'),
          render: (row) => (canDeleteGroups
            ? <button className="btn ghost" onClick={(e) => { e.stopPropagation(); removeGroup(row.id).catch(() => {}); }}>{t('delete')}</button>
            : <span className="muted">{t('Salt okunur')}</span>)
        }
      ];
    }

    if (kind === 'events') {
      return [
        { key: 'id', label: 'ID' },
        { key: 'title', label: t('Başlık') },
        { key: 'creator_kadi', label: t('Oluşturan') },
        {
          key: 'starts_at',
          label: t('Başlangıç'),
          render: (row) => formatDate(row.starts_at)
        },
        {
          key: 'approved',
          label: t('Durum'),
          render: (row) => Number(row.approved || 0) === 1 ? t('approved') : t('pending')
        },
        {
          key: 'actions',
          label: t('İşlemler'),
          render: (row) => (
            <div className="ops-inline-actions">
              <button className="btn ghost" onClick={(e) => { e.stopPropagation(); moderateEvent(row.id, true).catch(() => {}); }}>{t('Onayla')}</button>
              <button className="btn ghost" onClick={(e) => { e.stopPropagation(); moderateEvent(row.id, false).catch(() => {}); }}>{t('Reddet')}</button>
              <button className="btn ghost" onClick={(e) => { e.stopPropagation(); removeEvent(row.id).catch(() => {}); }}>{t('delete')}</button>
            </div>
          )
        }
      ];
    }

    return [
      { key: 'id', label: 'ID' },
      { key: 'title', label: t('Başlık') },
      { key: 'creator_kadi', label: t('Oluşturan') },
      {
        key: 'created_at',
        label: t('Oluşturuldu'),
        render: (row) => formatDate(row.created_at)
      },
      {
        key: 'approved',
        label: t('Durum'),
        render: (row) => Number(row.approved || 0) === 1 ? t('approved') : t('pending')
      },
      {
        key: 'actions',
        label: t('İşlemler'),
        render: (row) => (
          <div className="ops-inline-actions">
            <button className="btn ghost" onClick={(e) => { e.stopPropagation(); moderateAnnouncement(row.id, true).catch(() => {}); }}>{t('Onayla')}</button>
            <button className="btn ghost" onClick={(e) => { e.stopPropagation(); moderateAnnouncement(row.id, false).catch(() => {}); }}>{t('Reddet')}</button>
            <button className="btn ghost" onClick={(e) => { e.stopPropagation(); removeAnnouncement(row.id).catch(() => {}); }}>{t('delete')}</button>
          </div>
        )
      }
    ];
  }, [canDeleteGroups, kind, moderateAnnouncement, moderateEvent, removeAnnouncement, removeEvent, removeGroup, t]);

  if (!availableKinds.length) {
    return (
      <section className="stack">
        <div className="panel"><div className="panel-body muted">{t('Grup/etkinlik işlemleri için yetki yok.')}</div></div>
      </section>
    );
  }

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>{t('Gruplar / Etkinlikler')}</h3>
        <button className="btn ghost" onClick={load} disabled={loading}>{t('Yenile')}</button>
      </div>

      <AdminFilterBar
        searchValue={query.q}
        onSearchChange={setSearch}
        searchPlaceholder={t('Başlık, sahip veya açıklama ara')}
      >
        {availableKinds.length > 1 ? (
          <select
            className="input"
            value={kind}
            onChange={(e) => {
              setKind(e.target.value);
              patchQuery({ page: 1 });
            }}
          >
            {availableKinds.includes('groups') ? <option value="groups">{t('Gruplar')}</option> : null}
            {availableKinds.includes('events') ? <option value="events">{t('Etkinlikler')}</option> : null}
            {availableKinds.includes('announcements') ? <option value="announcements">{t('Duyurular')}</option> : null}
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
        emptyText={t('Kayıt yok.')}
      />
    </section>
  );
}
