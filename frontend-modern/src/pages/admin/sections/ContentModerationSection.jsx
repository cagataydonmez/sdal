import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import useAdminQueryState from '../../../admin/hooks/useAdminQueryState.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminFilterBar from '../../../admin/components/AdminFilterBar.jsx';
import AdminBulkActionsBar from '../../../admin/components/AdminBulkActionsBar.jsx';

export default function ContentModerationSection({
  canViewPosts = false,
  canViewStories = false,
  canDeletePosts = false,
  canDeleteStories = false
}) {
  const availableKinds = useMemo(() => {
    const kinds = [];
    if (canViewPosts) kinds.push('posts');
    if (canViewStories) kinds.push('stories');
    return kinds;
  }, [canViewPosts, canViewStories]);
  const [kind, setKind] = useState(availableKinds[0] || 'posts');
  const { query, setSearch, setPage } = useAdminQueryState({ q: '', page: 1, limit: 50 });
  const [rows, setRows] = useState([]);
  const [meta, setMeta] = useState({ page: 1, pages: 1, total: 0, limit: 50 });
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const endpoint = kind === 'posts' ? '/api/new/admin/posts' : '/api/new/admin/stories';
  const canDeleteCurrentKind = kind === 'posts' ? canDeletePosts : canDeleteStories;

  useEffect(() => {
    if (!availableKinds.includes(kind)) {
      setKind(availableKinds[0] || 'posts');
    }
  }, [availableKinds, kind]);

  const load = useCallback(async () => {
    if (!availableKinds.length) return;
    setLoading(true);
    setError('');
    try {
      const data = await adminClient.get(withQuery(endpoint, query));
      setRows(data.items || []);
      setMeta(data.meta || { page: 1, pages: 1, total: (data.items || []).length, limit: query.limit });
      setSelectedIds(new Set());
    } catch (err) {
      setError(err.message || 'Content could not be loaded.');
    } finally {
      setLoading(false);
    }
  }, [availableKinds.length, endpoint, query]);

  useEffect(() => {
    load();
  }, [load]);

  useEffect(() => {
    setSelectedIds(new Set());
  }, [kind]);

  const toggleRow = useCallback((row, checked) => {
    const id = Number(row.id);
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (checked) next.add(id);
      else next.delete(id);
      return next;
    });
  }, []);

  const toggleAll = useCallback((checked) => {
    if (!checked) {
      setSelectedIds(new Set());
      return;
    }
    setSelectedIds(new Set((rows || []).map((row) => Number(row.id))));
  }, [rows]);

  const removeOne = useCallback(async (id) => {
    if (!canDeleteCurrentKind) return;
    const path = kind === 'posts' ? `/api/new/admin/posts/${id}` : `/api/new/admin/stories/${id}`;
    await adminClient.del(path);
    await load();
  }, [canDeleteCurrentKind, kind, load]);

  const removeSelected = useCallback(async () => {
    if (!selectedIds.size || !canDeleteCurrentKind) return;
    const pathPrefix = kind === 'posts' ? '/api/new/admin/posts/' : '/api/new/admin/stories/';
    await Promise.all([...selectedIds].map((id) => adminClient.del(`${pathPrefix}${id}`)));
    await load();
  }, [canDeleteCurrentKind, kind, load, selectedIds]);

  const columns = useMemo(() => {
    if (kind === 'posts') {
      return [
        { key: 'id', label: 'ID' },
        { key: 'kadi', label: 'Author' },
        {
          key: 'content',
          label: 'Content',
          render: (row) => (row.content || '').replace(/<[^>]+>/g, ' ').trim().slice(0, 160) || '(empty)'
        },
        {
          key: 'created_at',
          label: 'Created',
          render: (row) => row.created_at ? new Date(row.created_at).toLocaleString('tr-TR') : '-'
        },
        {
          key: 'actions',
          label: canDeleteCurrentKind ? 'Actions' : 'Access',
          render: (row) => (canDeleteCurrentKind
            ? <button className="btn ghost" onClick={(e) => { e.stopPropagation(); removeOne(row.id).catch(() => {}); }}>Delete</button>
            : <span className="muted">Read only</span>)
        }
      ];
    }
    return [
      { key: 'id', label: 'ID' },
      { key: 'kadi', label: 'Author' },
      { key: 'caption', label: 'Caption' },
      {
        key: 'created_at',
        label: 'Created',
        render: (row) => row.created_at ? new Date(row.created_at).toLocaleString('tr-TR') : '-'
      },
      {
        key: 'actions',
        label: canDeleteCurrentKind ? 'Actions' : 'Access',
        render: (row) => (canDeleteCurrentKind
          ? <button className="btn ghost" onClick={(e) => { e.stopPropagation(); removeOne(row.id).catch(() => {}); }}>Delete</button>
          : <span className="muted">Read only</span>)
      }
    ];
  }, [canDeleteCurrentKind, kind, removeOne]);

  if (!availableKinds.length) {
    return (
      <section className="stack">
        <div className="panel"><div className="panel-body muted">No moderation permissions for posts or stories.</div></div>
      </section>
    );
  }

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>Content Moderation</h3>
        <button className="btn ghost" onClick={load} disabled={loading}>Refresh</button>
      </div>

      <AdminFilterBar
        searchValue={query.q}
        onSearchChange={setSearch}
        searchPlaceholder="Search by author or text"
      >
        {availableKinds.length > 1 ? (
          <select className="input" value={kind} onChange={(e) => setKind(e.target.value)}>
            {availableKinds.includes('posts') ? <option value="posts">Posts</option> : null}
            {availableKinds.includes('stories') ? <option value="stories">Stories</option> : null}
          </select>
        ) : null}
      </AdminFilterBar>

      {error ? <div className="muted">{error}</div> : null}

      {canDeleteCurrentKind ? (
        <AdminBulkActionsBar selectedCount={selectedIds.size} onClear={() => setSelectedIds(new Set())}>
          <button className="btn" onClick={() => removeSelected().catch(() => {})}>Delete selected</button>
        </AdminBulkActionsBar>
      ) : null}

      <AdminDataTable
        columns={columns}
        rows={rows}
        loading={loading}
        selectable={canDeleteCurrentKind}
        selectedIds={selectedIds}
        onToggleRow={toggleRow}
        onToggleAll={toggleAll}
        pagination={meta}
        onPageChange={setPage}
        emptyText="No moderation items."
      />
    </section>
  );
}
