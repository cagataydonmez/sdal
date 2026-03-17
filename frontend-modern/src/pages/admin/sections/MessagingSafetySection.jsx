import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import useAdminQueryState from '../../../admin/hooks/useAdminQueryState.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminFilterBar from '../../../admin/components/AdminFilterBar.jsx';
import { useI18n } from '../../../utils/i18n.jsx';

export default function MessagingSafetySection({
  canViewChat = false,
  canDeleteChat = false,
  canViewDirectMessages = false,
  canDeleteDirectMessages = false,
  canManageTerms = false
}) {
  const { t } = useI18n();
  const availableKinds = useMemo(() => {
    const next = [];
    if (canViewChat) next.push('chat');
    if (canViewDirectMessages) next.push('messages');
    if (canManageTerms) next.push('terms');
    return next;
  }, [canManageTerms, canViewChat, canViewDirectMessages]);
  const [kind, setKind] = useState(availableKinds[0] || 'chat');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState({ page: 1, pages: 1, total: 0, limit: 80 });
  const [termInput, setTermInput] = useState('');
  const { query, setSearch, setPage } = useAdminQueryState({ q: '', page: 1, limit: 80 });

  const endpointMap = {
    chat: '/api/new/admin/chat/messages',
    messages: '/api/new/admin/messages',
    terms: '/api/new/admin/filters'
  };

  useEffect(() => {
    if (!availableKinds.includes(kind)) {
      setKind(availableKinds[0] || 'chat');
    }
  }, [availableKinds, kind]);

  const load = useCallback(async () => {
    if (!availableKinds.length) return;
    setLoading(true);
    setError('');
    try {
      const endpoint = endpointMap[kind];
      const data = await adminClient.get(withQuery(endpoint, query));
      setRows(data.items || []);
      setMeta(data.meta || { page: 1, pages: 1, total: (data.items || []).length, limit: query.limit });
    } catch (err) {
      setError(err.message || t('Mesajlaşma ve güvenlik verisi yüklenemedi.'));
    } finally {
      setLoading(false);
    }
  }, [availableKinds.length, kind, query, t]);

  useEffect(() => {
    load();
  }, [load]);

  const removeOne = useCallback(async (id) => {
    if (kind === 'chat') {
      if (!canDeleteChat) return;
      await adminClient.del(`/api/new/admin/chat/messages/${id}`);
    }
    if (kind === 'messages') {
      if (!canDeleteDirectMessages) return;
      await adminClient.del(`/api/new/admin/messages/${id}`);
    }
    if (kind === 'terms') {
      if (!canManageTerms) return;
      await adminClient.del(`/api/new/admin/filters/${id}`);
    }
    await load();
  }, [canDeleteChat, canDeleteDirectMessages, canManageTerms, kind, load]);

  const addTerm = useCallback(async () => {
    if (!canManageTerms) return;
    const kufur = String(termInput || '').trim();
    if (!kufur) return;
    try {
      await adminClient.post('/api/new/admin/filters', { kufur });
      setTermInput('');
      if (kind !== 'terms') setKind('terms');
      await load();
    } catch (err) {
      setError(err.message || t('Engellenen terim eklenemedi.'));
    }
  }, [canManageTerms, kind, load, termInput, t]);

  const columns = useMemo(() => {
    if (kind === 'chat') {
      return [
        { key: 'id', label: 'ID' },
        { key: 'kadi', label: t('Kullanıcı') },
        { key: 'message', label: t('Mesaj') },
        {
          key: 'created_at',
          label: t('Oluşturuldu'),
          render: (row) => row.created_at ? new Date(row.created_at).toLocaleString('tr-TR') : '-'
        },
        {
          key: 'actions',
          label: canDeleteChat ? t('İşlemler') : t('Erişim'),
          render: (row) => (canDeleteChat
            ? <button className="btn ghost" onClick={(e) => { e.stopPropagation(); removeOne(row.id).catch(() => {}); }}>{t('delete')}</button>
            : <span className="muted">{t('Salt okunur')}</span>)
        }
      ];
    }
    if (kind === 'messages') {
      return [
        { key: 'id', label: 'ID' },
        { key: 'kimden_kadi', label: t('Kimden') },
        { key: 'kime_kadi', label: t('Kime') },
        { key: 'konu', label: t('Konu') },
        {
          key: 'tarih',
          label: t('Tarih'),
          render: (row) => row.tarih ? new Date(row.tarih).toLocaleString('tr-TR') : '-'
        },
        {
          key: 'actions',
          label: canDeleteDirectMessages ? t('İşlemler') : t('Erişim'),
          render: (row) => (canDeleteDirectMessages
            ? <button className="btn ghost" onClick={(e) => { e.stopPropagation(); removeOne(row.id).catch(() => {}); }}>{t('delete')}</button>
            : <span className="muted">{t('Salt okunur')}</span>)
        }
      ];
    }
    return [
      { key: 'id', label: 'ID' },
      { key: 'kufur', label: t('Engellenen Terim') },
      {
        key: 'actions',
        label: canManageTerms ? t('İşlemler') : t('Erişim'),
        render: (row) => (canManageTerms
          ? <button className="btn ghost" onClick={(e) => { e.stopPropagation(); removeOne(row.id).catch(() => {}); }}>{t('delete')}</button>
          : <span className="muted">{t('Salt okunur')}</span>)
      }
    ];
  }, [canDeleteChat, canDeleteDirectMessages, canManageTerms, kind, removeOne, t]);

  if (!availableKinds.length) {
    return (
      <section className="stack">
        <div className="panel"><div className="panel-body muted">{t('Mesajlaşma moderasyonu için yetki yok.')}</div></div>
      </section>
    );
  }

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>{t('Mesajlaşma ve Güvenlik')}</h3>
        <button className="btn ghost" onClick={load} disabled={loading}>{t('Yenile')}</button>
      </div>

      <AdminFilterBar
        searchValue={query.q}
        onSearchChange={setSearch}
        searchPlaceholder={t('Metin veya kullanıcı adına göre ara')}
        actions={(
          kind === 'terms' && canManageTerms ? (
            <div className="ops-inline-actions">
              <input className="input" value={termInput} onChange={(e) => setTermInput(e.target.value)} placeholder={t('Engellenen terim ekle')} />
              <button className="btn" onClick={addTerm}>{t('Ekle')}</button>
            </div>
          ) : null
        )}
      >
        {availableKinds.length > 1 ? (
          <select className="input" value={kind} onChange={(e) => setKind(e.target.value)}>
            {availableKinds.includes('chat') ? <option value="chat">{t('Sohbet Mesajları')}</option> : null}
            {availableKinds.includes('messages') ? <option value="messages">{t('Direkt Mesajlar')}</option> : null}
            {availableKinds.includes('terms') ? <option value="terms">{t('Engellenen Terimler')}</option> : null}
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
