import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminBulkActionsBar from '../../../admin/components/AdminBulkActionsBar.jsx';

const DEFAULT_CATEGORY_FORM = {
  kategori: '',
  aciklama: '',
  aktif: true
};

const DEFAULT_PHOTO_FORM = {
  baslik: '',
  aciklama: '',
  aktif: true,
  katid: ''
};

const PHOTO_SORT_OPTIONS = [
  { value: 'aktifazalan', label: 'Status' },
  { value: 'tarihazalan', label: 'Newest' },
  { value: 'tarihartan', label: 'Oldest' },
  { value: 'baslikartan', label: 'Title A-Z' },
  { value: 'baslikazalan', label: 'Title Z-A' },
  { value: 'hitazalan', label: 'Most viewed' }
];

function formatDate(value) {
  if (!value) return '-';
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? String(value) : parsed.toLocaleString('tr-TR');
}

function buildPhotoQuery(filters) {
  const query = { diz: filters.sort };
  if (filters.scope === 'pending') {
    query.krt = 'onaybekleyen';
  } else if (filters.scope === 'category' && filters.kid) {
    query.krt = 'kategori';
    query.kid = filters.kid;
  }
  return query;
}

function previewUrl(fileName) {
  if (!fileName) return '';
  return `/api/media/kucukresim?width=120&file=${encodeURIComponent(fileName)}`;
}

export default function AlbumSection({ canManageAlbums = false }) {
  const [categories, setCategories] = useState([]);
  const [counts, setCounts] = useState({});
  const [categoryForm, setCategoryForm] = useState(DEFAULT_CATEGORY_FORM);
  const [editingCategoryId, setEditingCategoryId] = useState(null);
  const [editingCategoryForm, setEditingCategoryForm] = useState(DEFAULT_CATEGORY_FORM);
  const [photos, setPhotos] = useState([]);
  const [photoFilters, setPhotoFilters] = useState({ scope: 'pending', kid: '', sort: 'aktifazalan' });
  const [selectedIds, setSelectedIds] = useState(new Set());
  const [selectedPhotoId, setSelectedPhotoId] = useState(null);
  const [photoForm, setPhotoForm] = useState(DEFAULT_PHOTO_FORM);
  const [photoComments, setPhotoComments] = useState([]);
  const [loadingCategories, setLoadingCategories] = useState(false);
  const [loadingPhotos, setLoadingPhotos] = useState(false);
  const [loadingComments, setLoadingComments] = useState(false);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  const selectedPhoto = useMemo(
    () => photos.find((row) => Number(row.id) === Number(selectedPhotoId)) || null,
    [photos, selectedPhotoId]
  );

  const loadCategories = useCallback(async () => {
    setLoadingCategories(true);
    try {
      const data = await adminClient.get('/api/admin/album/categories');
      setCategories(data.categories || []);
      setCounts(data.counts || {});
    } finally {
      setLoadingCategories(false);
    }
  }, []);

  const loadPhotos = useCallback(async () => {
    setLoadingPhotos(true);
    setError('');
    try {
      const data = await adminClient.get(withQuery('/api/admin/album/photos', buildPhotoQuery(photoFilters)));
      const commentCounts = data.commentCounts || {};
      const userMap = data.userMap || {};
      const nextPhotos = (data.photos || []).map((row) => ({
        ...row,
        commentCount: Number(commentCounts[row.id] || 0),
        uploaderName: userMap[row.ekleyenid] || ''
      }));
      setPhotos(nextPhotos);
      setSelectedIds(new Set());
      if (!categories.length && Array.isArray(data.categories)) {
        setCategories(data.categories);
      }
    } catch (err) {
      setError(err.message || 'Album photos could not be loaded.');
    } finally {
      setLoadingPhotos(false);
    }
  }, [categories.length, photoFilters]);

  const refreshAll = useCallback(async () => {
    setStatus('');
    await Promise.all([loadCategories(), loadPhotos()]);
  }, [loadCategories, loadPhotos]);

  const loadComments = useCallback(async (photoId) => {
    if (!photoId) {
      setPhotoComments([]);
      return;
    }
    setLoadingComments(true);
    try {
      const data = await adminClient.get(`/api/admin/album/photos/${photoId}/comments`);
      setPhotoComments(data.comments || []);
    } catch (err) {
      setStatus(err.message || 'Photo comments could not be loaded.');
    } finally {
      setLoadingComments(false);
    }
  }, []);

  useEffect(() => {
    if (!canManageAlbums) return;
    loadCategories().catch((err) => {
      setError(err.message || 'Album administration could not be loaded.');
    });
  }, [canManageAlbums, loadCategories]);

  useEffect(() => {
    if (!canManageAlbums) return;
    loadPhotos().catch((err) => {
      setError(err.message || 'Album photos could not be loaded.');
    });
  }, [canManageAlbums, loadPhotos]);

  useEffect(() => {
    if (!selectedPhoto) {
      setPhotoForm(DEFAULT_PHOTO_FORM);
      setPhotoComments([]);
      return;
    }
    setPhotoForm({
      baslik: selectedPhoto.baslik || '',
      aciklama: selectedPhoto.aciklama || '',
      aktif: Number(selectedPhoto.aktif || 0) === 1,
      katid: String(selectedPhoto.katid || '')
    });
  }, [selectedPhoto]);

  useEffect(() => {
    if (!selectedPhotoId) {
      setPhotoComments([]);
      return;
    }
    loadComments(selectedPhotoId).catch((err) => {
      setStatus(err.message || 'Photo comments could not be loaded.');
    });
  }, [loadComments, selectedPhotoId]);

  const startCategoryEdit = useCallback((row) => {
    setEditingCategoryId(Number(row.id));
    setEditingCategoryForm({
      kategori: row.kategori || '',
      aciklama: row.aciklama || '',
      aktif: Number(row.aktif || 0) === 1
    });
  }, []);

  const createCategory = useCallback(async () => {
    try {
      await adminClient.post('/api/admin/album/categories', {
        kategori: categoryForm.kategori,
        aciklama: categoryForm.aciklama,
        aktif: categoryForm.aktif ? 1 : 0
      });
      setCategoryForm(DEFAULT_CATEGORY_FORM);
      setStatus('Album category added.');
      await loadCategories();
    } catch (err) {
      setStatus(err.message || 'Album category create failed.');
    }
  }, [categoryForm, loadCategories]);

  const saveCategory = useCallback(async () => {
    if (!editingCategoryId) return;
    try {
      await adminClient.put(`/api/admin/album/categories/${editingCategoryId}`, {
        kategori: editingCategoryForm.kategori,
        aciklama: editingCategoryForm.aciklama,
        aktif: editingCategoryForm.aktif ? 1 : 0
      });
      setEditingCategoryId(null);
      setEditingCategoryForm(DEFAULT_CATEGORY_FORM);
      setStatus('Album category updated.');
      await Promise.all([loadCategories(), loadPhotos()]);
    } catch (err) {
      setStatus(err.message || 'Album category update failed.');
    }
  }, [editingCategoryForm, editingCategoryId, loadCategories, loadPhotos]);

  const deleteCategory = useCallback(async (id) => {
    try {
      await adminClient.del(`/api/admin/album/categories/${id}`);
      if (String(photoFilters.kid || '') === String(id)) {
        setPhotoFilters((prev) => ({ ...prev, scope: 'all', kid: '' }));
      }
      setStatus('Album category deleted.');
      await Promise.all([loadCategories(), loadPhotos()]);
    } catch (err) {
      setStatus(err.message || 'Album category delete failed.');
    }
  }, [loadCategories, loadPhotos, photoFilters.kid]);

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
    setSelectedIds(new Set((photos || []).map((row) => Number(row.id))));
  }, [photos]);

  const runBulkAction = useCallback(async (action) => {
    if (!selectedIds.size) return;
    try {
      await adminClient.post('/api/admin/album/photos/bulk', {
        ids: Array.from(selectedIds),
        action
      });
      setStatus(action === 'sil' ? 'Selected photos deleted.' : 'Selected photos updated.');
      await Promise.all([loadCategories(), loadPhotos()]);
      setSelectedPhotoId(null);
    } catch (err) {
      setStatus(err.message || 'Photo bulk action failed.');
    }
  }, [loadCategories, loadPhotos, selectedIds]);

  const savePhoto = useCallback(async () => {
    if (!selectedPhotoId) return;
    try {
      await adminClient.put(`/api/admin/album/photos/${selectedPhotoId}`, {
        baslik: photoForm.baslik,
        aciklama: photoForm.aciklama,
        aktif: photoForm.aktif ? 1 : 0,
        katid: photoForm.katid
      });
      setStatus('Photo updated.');
      await Promise.all([loadCategories(), loadPhotos()]);
    } catch (err) {
      setStatus(err.message || 'Photo update failed.');
    }
  }, [loadCategories, loadPhotos, photoForm, selectedPhotoId]);

  const deletePhoto = useCallback(async (id) => {
    try {
      await adminClient.del(`/api/admin/album/photos/${id}`);
      if (Number(selectedPhotoId) === Number(id)) {
        setSelectedPhotoId(null);
      }
      setStatus('Photo deleted.');
      await Promise.all([loadCategories(), loadPhotos()]);
    } catch (err) {
      setStatus(err.message || 'Photo delete failed.');
    }
  }, [loadCategories, loadPhotos, selectedPhotoId]);

  const deleteComment = useCallback(async (photoId, commentId) => {
    try {
      await adminClient.del(`/api/admin/album/photos/${photoId}/comments/${commentId}`);
      setStatus('Comment deleted.');
      await Promise.all([loadComments(photoId), loadPhotos()]);
    } catch (err) {
      setStatus(err.message || 'Comment delete failed.');
    }
  }, [loadComments, loadPhotos]);

  const categoryColumns = useMemo(() => ([
    { key: 'kategori', label: 'Category' },
    { key: 'aciklama', label: 'Description' },
    {
      key: 'aktif',
      label: 'Status',
      render: (row) => Number(row.aktif || 0) === 1 ? 'Active' : 'Inactive'
    },
    {
      key: 'counts',
      label: 'Photos',
      render: (row) => {
        const summary = counts[row.id] || { activeCount: 0, inactiveCount: 0 };
        return `${summary.activeCount} active / ${summary.inactiveCount} pending`;
      }
    },
    {
      key: 'actions',
      label: 'Actions',
      render: (row) => (
        <div className="ops-inline-actions">
          <button className="btn ghost" onClick={(e) => { e.stopPropagation(); startCategoryEdit(row); }}>Edit</button>
          <button className="btn ghost" onClick={(e) => { e.stopPropagation(); deleteCategory(row.id).catch(() => {}); }}>Delete</button>
        </div>
      )
    }
  ]), [counts, deleteCategory, startCategoryEdit]);

  const photoColumns = useMemo(() => ([
    {
      key: 'preview',
      label: 'Preview',
      render: (row) => (
        row.dosyaadi
          ? <img src={previewUrl(row.dosyaadi)} alt={row.baslik || ''} style={{ width: 72, height: 72, objectFit: 'cover', borderRadius: 12 }} />
          : <span className="muted">No file</span>
      )
    },
    { key: 'id', label: 'ID' },
    {
      key: 'baslik',
      label: 'Title',
      render: (row) => row.baslik || '(untitled)'
    },
    {
      key: 'category',
      label: 'Category',
      render: (row) => categories.find((item) => String(item.id) === String(row.katid))?.kategori || '-'
    },
    {
      key: 'uploader',
      label: 'Uploader',
      render: (row) => row.uploaderName || row.ekleyenid || '-'
    },
    {
      key: 'aktif',
      label: 'Status',
      render: (row) => Number(row.aktif || 0) === 1 ? 'Active' : 'Pending'
    },
    {
      key: 'yorum',
      label: 'Comments',
      render: (row) => Number(row.commentCount || 0)
    },
    {
      key: 'tarih',
      label: 'Created',
      render: (row) => formatDate(row.tarih)
    },
    {
      key: 'actions',
      label: 'Actions',
      render: (row) => (
        <div className="ops-inline-actions">
          <button className="btn ghost" onClick={(e) => { e.stopPropagation(); setSelectedPhotoId(Number(row.id)); }}>Edit</button>
          <button className="btn ghost" onClick={(e) => { e.stopPropagation(); deletePhoto(row.id).catch(() => {}); }}>Delete</button>
        </div>
      )
    }
  ]), [categories, deletePhoto]);

  const photoRows = useMemo(() => photos, [photos]);

  if (!canManageAlbums) {
    return (
      <section className="stack">
        <div className="panel"><div className="panel-body muted">No album administration permissions.</div></div>
      </section>
    );
  }

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>Photo Albums</h3>
        <button className="btn ghost" onClick={() => refreshAll().catch(() => {})} disabled={loadingCategories || loadingPhotos}>Refresh</button>
      </div>

      {status ? <div className="muted">{status}</div> : null}
      {error ? <div className="muted">{error}</div> : null}

      <div className="panel">
        <div className="panel-body stack">
          <h3>Album Categories</h3>
          <div className="ops-form-grid">
            <label>
              <span>Name</span>
              <input className="input" value={categoryForm.kategori} onChange={(e) => setCategoryForm((prev) => ({ ...prev, kategori: e.target.value }))} />
            </label>
            <label>
              <span>Description</span>
              <input className="input" value={categoryForm.aciklama} onChange={(e) => setCategoryForm((prev) => ({ ...prev, aciklama: e.target.value }))} />
            </label>
            <label className="ops-check-row">
              <input type="checkbox" checked={categoryForm.aktif} onChange={(e) => setCategoryForm((prev) => ({ ...prev, aktif: e.target.checked }))} />
              <span>Active for uploads</span>
            </label>
          </div>
          <div className="ops-inline-actions">
            <button className="btn" onClick={() => createCategory().catch(() => {})}>Add category</button>
          </div>

          {editingCategoryId ? (
            <div className="panel">
              <div className="panel-body stack">
                <h3>Edit Category #{editingCategoryId}</h3>
                <div className="ops-form-grid">
                  <label>
                    <span>Name</span>
                    <input className="input" value={editingCategoryForm.kategori} onChange={(e) => setEditingCategoryForm((prev) => ({ ...prev, kategori: e.target.value }))} />
                  </label>
                  <label>
                    <span>Description</span>
                    <input className="input" value={editingCategoryForm.aciklama} onChange={(e) => setEditingCategoryForm((prev) => ({ ...prev, aciklama: e.target.value }))} />
                  </label>
                  <label className="ops-check-row">
                    <input type="checkbox" checked={editingCategoryForm.aktif} onChange={(e) => setEditingCategoryForm((prev) => ({ ...prev, aktif: e.target.checked }))} />
                    <span>Active</span>
                  </label>
                </div>
                <div className="ops-inline-actions">
                  <button className="btn" onClick={() => saveCategory().catch(() => {})}>Save category</button>
                  <button className="btn ghost" onClick={() => { setEditingCategoryId(null); setEditingCategoryForm(DEFAULT_CATEGORY_FORM); }}>Cancel</button>
                </div>
              </div>
            </div>
          ) : null}

          <AdminDataTable
            columns={categoryColumns}
            rows={categories}
            loading={loadingCategories}
            emptyText="No album categories."
          />
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>Photo Moderation</h3>
          <div className="ops-filter-bar">
            <div className="ops-filter-extra">
              <select className="input" value={photoFilters.scope} onChange={(e) => setPhotoFilters((prev) => ({
                ...prev,
                scope: e.target.value,
                kid: e.target.value === 'category' ? prev.kid : ''
              }))}>
                <option value="pending">Pending only</option>
                <option value="all">All photos</option>
                <option value="category">By category</option>
              </select>
              {photoFilters.scope === 'category' ? (
                <select className="input" value={photoFilters.kid} onChange={(e) => setPhotoFilters((prev) => ({ ...prev, kid: e.target.value }))}>
                  <option value="">Choose category</option>
                  {categories.map((category) => (
                    <option key={category.id} value={category.id}>{category.kategori}</option>
                  ))}
                </select>
              ) : null}
              <select className="input" value={photoFilters.sort} onChange={(e) => setPhotoFilters((prev) => ({ ...prev, sort: e.target.value }))}>
                {PHOTO_SORT_OPTIONS.map((option) => (
                  <option key={option.value} value={option.value}>{option.label}</option>
                ))}
              </select>
              <button className="btn ghost" onClick={() => loadPhotos().catch(() => {})} disabled={loadingPhotos}>Reload photos</button>
            </div>
          </div>

          <AdminBulkActionsBar selectedCount={selectedIds.size} onClear={() => setSelectedIds(new Set())}>
            <button className="btn" onClick={() => runBulkAction('aktiv').catch(() => {})}>Activate</button>
            <button className="btn" onClick={() => runBulkAction('deaktiv').catch(() => {})}>Deactivate</button>
            <button className="btn" onClick={() => runBulkAction('sil').catch(() => {})}>Delete</button>
          </AdminBulkActionsBar>

          <AdminDataTable
            columns={photoColumns}
            rows={photoRows}
            loading={loadingPhotos}
            selectable
            selectedIds={selectedIds}
            onToggleRow={toggleRow}
            onToggleAll={toggleAll}
            onRowClick={(row) => setSelectedPhotoId(Number(row.id))}
            emptyText="No album photos."
          />

          {selectedPhoto ? (
            <div className="panel">
              <div className="panel-body stack">
                <h3>Photo #{selectedPhoto.id}</h3>
                {selectedPhoto.dosyaadi ? (
                  <div className="panel">
                    <div className="panel-body stack">
                      <img
                        src={`/api/media/kucukresim?width=1200&file=${encodeURIComponent(selectedPhoto.dosyaadi)}`}
                        alt={selectedPhoto.baslik || ''}
                        style={{ width: '100%', maxHeight: 560, objectFit: 'contain', borderRadius: 16 }}
                      />
                      <div className="ops-inline-actions">
                        <a className="btn ghost" href={`/new/albums/photo/${selectedPhoto.id}`}>Open public photo page</a>
                      </div>
                    </div>
                  </div>
                ) : null}
                <div className="ops-form-grid">
                  <label>
                    <span>Title</span>
                    <input className="input" value={photoForm.baslik} onChange={(e) => setPhotoForm((prev) => ({ ...prev, baslik: e.target.value }))} />
                  </label>
                  <label>
                    <span>Category</span>
                    <select className="input" value={photoForm.katid} onChange={(e) => setPhotoForm((prev) => ({ ...prev, katid: e.target.value }))}>
                      <option value="">Choose category</option>
                      {categories.map((category) => (
                        <option key={category.id} value={category.id}>{category.kategori}</option>
                      ))}
                    </select>
                  </label>
                  <label className="ops-check-row">
                    <input type="checkbox" checked={photoForm.aktif} onChange={(e) => setPhotoForm((prev) => ({ ...prev, aktif: e.target.checked }))} />
                    <span>Visible to members</span>
                  </label>
                </div>
                <label>
                  <span>Description</span>
                  <textarea className="input" rows={5} value={photoForm.aciklama} onChange={(e) => setPhotoForm((prev) => ({ ...prev, aciklama: e.target.value }))} />
                </label>
                <div className="ops-inline-actions">
                  <button className="btn" onClick={() => savePhoto().catch(() => {})}>Save photo</button>
                  <button className="btn ghost" onClick={() => setSelectedPhotoId(null)}>Close</button>
                </div>

                <div className="panel">
                  <div className="panel-body stack">
                    <div className="ops-head-row">
                      <h3>Comments</h3>
                      <button className="btn ghost" onClick={() => loadComments(selectedPhoto.id).catch(() => {})} disabled={loadingComments}>
                        Reload comments
                      </button>
                    </div>

                    {loadingComments ? <div className="muted">Loading comments...</div> : null}

                    {!loadingComments && !photoComments.length ? (
                      <div className="muted">No comments for this photo.</div>
                    ) : null}

                    {!loadingComments && photoComments.length ? (
                      <div className="stack">
                        {photoComments.map((comment) => (
                          <div key={comment.id} className="panel">
                            <div className="panel-body stack">
                              <div className="ops-head-row">
                                <strong>{comment.uyeadi || 'Member'}</strong>
                                <div className="ops-inline-actions">
                                  <span className="muted">{formatDate(comment.tarih)}</span>
                                  <button className="btn ghost" onClick={() => deleteComment(selectedPhoto.id, comment.id).catch(() => {})}>
                                    Delete comment
                                  </button>
                                </div>
                              </div>
                              <div>{comment.yorum || '-'}</div>
                            </div>
                          </div>
                        ))}
                      </div>
                    ) : null}
                  </div>
                </div>
              </div>
            </div>
          ) : null}
        </div>
      </div>
    </section>
  );
}
