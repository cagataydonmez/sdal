import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import AdminDataTable from '../../../admin/components/AdminDataTable.jsx';
import AdminBulkActionsBar from '../../../admin/components/AdminBulkActionsBar.jsx';
import { useI18n } from '../../../utils/i18n.jsx';

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
  const { t } = useI18n();
  const photoSortOptions = useMemo(() => ([
    { value: 'aktifazalan', label: t('Durum') },
    { value: 'tarihazalan', label: t('En yeni') },
    { value: 'tarihartan', label: t('En eski') },
    { value: 'baslikartan', label: t('Başlık A-Z') },
    { value: 'baslikazalan', label: t('Başlık Z-A') },
    { value: 'hitazalan', label: t('En çok görüntülenen') }
  ]), [t]);
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
      setError(err.message || t('Albüm fotoğrafları yüklenemedi.'));
    } finally {
      setLoadingPhotos(false);
    }
  }, [categories.length, photoFilters, t]);

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
      setStatus(err.message || t('Fotoğraf yorumları yüklenemedi.'));
    } finally {
      setLoadingComments(false);
    }
  }, [t]);

  useEffect(() => {
    if (!canManageAlbums) return;
    loadCategories().catch((err) => {
      setError(err.message || t('Albüm yönetimi yüklenemedi.'));
    });
  }, [canManageAlbums, loadCategories, t]);

  useEffect(() => {
    if (!canManageAlbums) return;
    loadPhotos().catch((err) => {
      setError(err.message || t('Albüm fotoğrafları yüklenemedi.'));
    });
  }, [canManageAlbums, loadPhotos, t]);

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
      setStatus(err.message || t('Fotoğraf yorumları yüklenemedi.'));
    });
  }, [loadComments, selectedPhotoId, t]);

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
      setStatus(t('Albüm kategorisi eklendi.'));
      await loadCategories();
    } catch (err) {
      setStatus(err.message || t('Albüm kategorisi oluşturulamadı.'));
    }
  }, [categoryForm, loadCategories, t]);

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
      setStatus(t('Albüm kategorisi güncellendi.'));
      await Promise.all([loadCategories(), loadPhotos()]);
    } catch (err) {
      setStatus(err.message || t('Albüm kategorisi güncellenemedi.'));
    }
  }, [editingCategoryForm, editingCategoryId, loadCategories, loadPhotos, t]);

  const deleteCategory = useCallback(async (id) => {
    try {
      await adminClient.del(`/api/admin/album/categories/${id}`);
      if (String(photoFilters.kid || '') === String(id)) {
        setPhotoFilters((prev) => ({ ...prev, scope: 'all', kid: '' }));
      }
      setStatus(t('Albüm kategorisi silindi.'));
      await Promise.all([loadCategories(), loadPhotos()]);
    } catch (err) {
      setStatus(err.message || t('Albüm kategorisi silinemedi.'));
    }
  }, [loadCategories, loadPhotos, photoFilters.kid, t]);

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
      setStatus(action === 'sil' ? t('Seçili fotoğraflar silindi.') : t('Seçili fotoğraflar güncellendi.'));
      await Promise.all([loadCategories(), loadPhotos()]);
      setSelectedPhotoId(null);
    } catch (err) {
      setStatus(err.message || t('Fotoğraf toplu işlemi başarısız.'));
    }
  }, [loadCategories, loadPhotos, selectedIds, t]);

  const savePhoto = useCallback(async () => {
    if (!selectedPhotoId) return;
    try {
      await adminClient.put(`/api/admin/album/photos/${selectedPhotoId}`, {
        baslik: photoForm.baslik,
        aciklama: photoForm.aciklama,
        aktif: photoForm.aktif ? 1 : 0,
        katid: photoForm.katid
      });
      setStatus(t('Fotoğraf güncellendi.'));
      await Promise.all([loadCategories(), loadPhotos()]);
    } catch (err) {
      setStatus(err.message || t('Fotoğraf güncellenemedi.'));
    }
  }, [loadCategories, loadPhotos, photoForm, selectedPhotoId, t]);

  const deletePhoto = useCallback(async (id) => {
    try {
      await adminClient.del(`/api/admin/album/photos/${id}`);
      if (Number(selectedPhotoId) === Number(id)) {
        setSelectedPhotoId(null);
      }
      setStatus(t('Fotoğraf silindi.'));
      await Promise.all([loadCategories(), loadPhotos()]);
    } catch (err) {
      setStatus(err.message || t('Fotoğraf silinemedi.'));
    }
  }, [loadCategories, loadPhotos, selectedPhotoId, t]);

  const deleteComment = useCallback(async (photoId, commentId) => {
    try {
      await adminClient.del(`/api/admin/album/photos/${photoId}/comments/${commentId}`);
      setStatus(t('Yorum silindi.'));
      await Promise.all([loadComments(photoId), loadPhotos()]);
    } catch (err) {
      setStatus(err.message || t('Yorum silinemedi.'));
    }
  }, [loadComments, loadPhotos, t]);

  const categoryColumns = useMemo(() => ([
    { key: 'kategori', label: t('Kategori') },
    { key: 'aciklama', label: t('Açıklama') },
    {
      key: 'aktif',
      label: t('Durum'),
      render: (row) => Number(row.aktif || 0) === 1 ? t('Aktif') : t('Pasif')
    },
    {
      key: 'counts',
      label: t('Fotoğraflar'),
      render: (row) => {
        const summary = counts[row.id] || { activeCount: 0, inactiveCount: 0 };
        return `${summary.activeCount} ${t('aktif')} / ${summary.inactiveCount} ${t('beklemede')}`;
      }
    },
    {
      key: 'actions',
      label: t('Aksiyonlar'),
      render: (row) => (
        <div className="ops-inline-actions">
          <button className="btn ghost" onClick={(e) => { e.stopPropagation(); startCategoryEdit(row); }}>{t('Düzenle')}</button>
          <button className="btn ghost" onClick={(e) => { e.stopPropagation(); deleteCategory(row.id).catch(() => {}); }}>{t('Sil')}</button>
        </div>
      )
    }
  ]), [counts, deleteCategory, startCategoryEdit, t]);

  const photoColumns = useMemo(() => ([
    {
      key: 'preview',
      label: t('Önizleme'),
      render: (row) => (
        row.dosyaadi
          ? <img src={previewUrl(row.dosyaadi)} alt={row.baslik || ''} style={{ width: 72, height: 72, objectFit: 'cover', borderRadius: 12 }} />
          : <span className="muted">{t('Dosya yok')}</span>
      )
    },
    { key: 'id', label: 'ID' },
    {
      key: 'baslik',
      label: t('Başlık'),
      render: (row) => row.baslik || t('(başlıksız)')
    },
    {
      key: 'category',
      label: t('Kategori'),
      render: (row) => categories.find((item) => String(item.id) === String(row.katid))?.kategori || '-'
    },
    {
      key: 'uploader',
      label: t('Yükleyen'),
      render: (row) => row.uploaderName || row.ekleyenid || '-'
    },
    {
      key: 'aktif',
      label: t('Durum'),
      render: (row) => Number(row.aktif || 0) === 1 ? t('Aktif') : t('Beklemede')
    },
    {
      key: 'yorum',
      label: t('Yorumlar'),
      render: (row) => Number(row.commentCount || 0)
    },
    {
      key: 'tarih',
      label: t('Oluşturulma'),
      render: (row) => formatDate(row.tarih)
    },
    {
      key: 'actions',
      label: t('Aksiyonlar'),
      render: (row) => (
        <div className="ops-inline-actions">
          <button className="btn ghost" onClick={(e) => { e.stopPropagation(); setSelectedPhotoId(Number(row.id)); }}>{t('Düzenle')}</button>
          <button className="btn ghost" onClick={(e) => { e.stopPropagation(); deletePhoto(row.id).catch(() => {}); }}>{t('Sil')}</button>
        </div>
      )
    }
  ]), [categories, deletePhoto, t]);

  const photoRows = useMemo(() => photos, [photos]);

  if (!canManageAlbums) {
    return (
      <section className="stack">
        <div className="panel"><div className="panel-body muted">{t('Albüm yönetimi yetkiniz yok.')}</div></div>
      </section>
    );
  }

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>{t('Fotoğraf Albümleri')}</h3>
        <button className="btn ghost" onClick={() => refreshAll().catch(() => {})} disabled={loadingCategories || loadingPhotos}>{t('Yenile')}</button>
      </div>

      {status ? <div className="muted">{status}</div> : null}
      {error ? <div className="muted">{error}</div> : null}

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('Albüm Kategorileri')}</h3>
          <div className="ops-form-grid">
            <label>
              <span>{t('Ad')}</span>
              <input className="input" value={categoryForm.kategori} onChange={(e) => setCategoryForm((prev) => ({ ...prev, kategori: e.target.value }))} />
            </label>
            <label>
              <span>{t('Açıklama')}</span>
              <input className="input" value={categoryForm.aciklama} onChange={(e) => setCategoryForm((prev) => ({ ...prev, aciklama: e.target.value }))} />
            </label>
            <label className="ops-check-row">
              <input type="checkbox" checked={categoryForm.aktif} onChange={(e) => setCategoryForm((prev) => ({ ...prev, aktif: e.target.checked }))} />
              <span>{t('Yüklemelere açık')}</span>
            </label>
          </div>
          <div className="ops-inline-actions">
            <button className="btn" onClick={() => createCategory().catch(() => {})}>{t('Kategori ekle')}</button>
          </div>

          {editingCategoryId ? (
            <div className="panel">
              <div className="panel-body stack">
                <h3>{t('Kategori Düzenle #{id}', { id: editingCategoryId })}</h3>
                <div className="ops-form-grid">
                  <label>
                    <span>{t('Ad')}</span>
                    <input className="input" value={editingCategoryForm.kategori} onChange={(e) => setEditingCategoryForm((prev) => ({ ...prev, kategori: e.target.value }))} />
                  </label>
                  <label>
                    <span>{t('Açıklama')}</span>
                    <input className="input" value={editingCategoryForm.aciklama} onChange={(e) => setEditingCategoryForm((prev) => ({ ...prev, aciklama: e.target.value }))} />
                  </label>
                  <label className="ops-check-row">
                    <input type="checkbox" checked={editingCategoryForm.aktif} onChange={(e) => setEditingCategoryForm((prev) => ({ ...prev, aktif: e.target.checked }))} />
                    <span>{t('Aktif')}</span>
                  </label>
                </div>
                <div className="ops-inline-actions">
                  <button className="btn" onClick={() => saveCategory().catch(() => {})}>{t('Kategoriyi kaydet')}</button>
                  <button className="btn ghost" onClick={() => { setEditingCategoryId(null); setEditingCategoryForm(DEFAULT_CATEGORY_FORM); }}>{t('İptal')}</button>
                </div>
              </div>
            </div>
          ) : null}

          <AdminDataTable
            columns={categoryColumns}
            rows={categories}
            loading={loadingCategories}
            emptyText={t('Albüm kategorisi yok.')}
          />
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('Fotoğraf Moderasyonu')}</h3>
          <div className="ops-filter-bar">
            <div className="ops-filter-extra">
              <select className="input" value={photoFilters.scope} onChange={(e) => setPhotoFilters((prev) => ({
                ...prev,
                scope: e.target.value,
                kid: e.target.value === 'category' ? prev.kid : ''
              }))}>
                <option value="pending">{t('Sadece bekleyenler')}</option>
                <option value="all">{t('Tüm fotoğraflar')}</option>
                <option value="category">{t('Kategoriye göre')}</option>
              </select>
              {photoFilters.scope === 'category' ? (
                <select className="input" value={photoFilters.kid} onChange={(e) => setPhotoFilters((prev) => ({ ...prev, kid: e.target.value }))}>
                  <option value="">{t('Kategori seç')}</option>
                  {categories.map((category) => (
                    <option key={category.id} value={category.id}>{category.kategori}</option>
                  ))}
                </select>
              ) : null}
              <select className="input" value={photoFilters.sort} onChange={(e) => setPhotoFilters((prev) => ({ ...prev, sort: e.target.value }))}>
                {photoSortOptions.map((option) => (
                  <option key={option.value} value={option.value}>{option.label}</option>
                ))}
              </select>
              <button className="btn ghost" onClick={() => loadPhotos().catch(() => {})} disabled={loadingPhotos}>{t('Fotoğrafları yeniden yükle')}</button>
            </div>
          </div>

          <AdminBulkActionsBar selectedCount={selectedIds.size} onClear={() => setSelectedIds(new Set())}>
            <button className="btn" onClick={() => runBulkAction('aktiv').catch(() => {})}>{t('Aktifleştir')}</button>
            <button className="btn" onClick={() => runBulkAction('deaktiv').catch(() => {})}>{t('Pasifleştir')}</button>
            <button className="btn" onClick={() => runBulkAction('sil').catch(() => {})}>{t('Sil')}</button>
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
            emptyText={t('Albüm fotoğrafı yok.')}
          />

          {selectedPhoto ? (
            <div className="panel">
              <div className="panel-body stack">
                <h3>{t('Fotoğraf #{id}', { id: selectedPhoto.id })}</h3>
                {selectedPhoto.dosyaadi ? (
                  <div className="panel">
                    <div className="panel-body stack">
                      <img
                        src={`/api/media/kucukresim?width=1200&file=${encodeURIComponent(selectedPhoto.dosyaadi)}`}
                        alt={selectedPhoto.baslik || ''}
                        style={{ width: '100%', maxHeight: 560, objectFit: 'contain', borderRadius: 16 }}
                      />
                      <div className="ops-inline-actions">
                        <a className="btn ghost" href={`/new/albums/photo/${selectedPhoto.id}`}>{t('Herkese açık fotoğraf sayfasını aç')}</a>
                      </div>
                    </div>
                  </div>
                ) : null}
                <div className="ops-form-grid">
                  <label>
                    <span>{t('Başlık')}</span>
                    <input className="input" value={photoForm.baslik} onChange={(e) => setPhotoForm((prev) => ({ ...prev, baslik: e.target.value }))} />
                  </label>
                  <label>
                    <span>{t('Kategori')}</span>
                    <select className="input" value={photoForm.katid} onChange={(e) => setPhotoForm((prev) => ({ ...prev, katid: e.target.value }))}>
                      <option value="">{t('Kategori seç')}</option>
                      {categories.map((category) => (
                        <option key={category.id} value={category.id}>{category.kategori}</option>
                      ))}
                    </select>
                  </label>
                  <label className="ops-check-row">
                    <input type="checkbox" checked={photoForm.aktif} onChange={(e) => setPhotoForm((prev) => ({ ...prev, aktif: e.target.checked }))} />
                    <span>{t('Üyelere görünür')}</span>
                  </label>
                </div>
                <label>
                  <span>{t('Açıklama')}</span>
                  <textarea className="input" rows={5} value={photoForm.aciklama} onChange={(e) => setPhotoForm((prev) => ({ ...prev, aciklama: e.target.value }))} />
                </label>
                <div className="ops-inline-actions">
                  <button className="btn" onClick={() => savePhoto().catch(() => {})}>{t('Fotoğrafı kaydet')}</button>
                  <button className="btn ghost" onClick={() => setSelectedPhotoId(null)}>{t('Kapat')}</button>
                </div>

                <div className="panel">
                  <div className="panel-body stack">
                    <div className="ops-head-row">
                      <h3>{t('Yorumlar')}</h3>
                      <button className="btn ghost" onClick={() => loadComments(selectedPhoto.id).catch(() => {})} disabled={loadingComments}>
                        {t('Yorumları yeniden yükle')}
                      </button>
                    </div>

                    {loadingComments ? <div className="muted">{t('Yorumlar yükleniyor...')}</div> : null}

                    {!loadingComments && !photoComments.length ? (
                      <div className="muted">{t('Bu fotoğraf için yorum yok.')}</div>
                    ) : null}

                    {!loadingComments && photoComments.length ? (
                      <div className="stack">
                        {photoComments.map((comment) => (
                          <div key={comment.id} className="panel">
                            <div className="panel-body stack">
                              <div className="ops-head-row">
                                <strong>{comment.uyeadi || t('Üye')}</strong>
                                <div className="ops-inline-actions">
                                  <span className="muted">{formatDate(comment.tarih)}</span>
                                  <button className="btn ghost" onClick={() => deleteComment(selectedPhoto.id, comment.id).catch(() => {})}>
                                    {t('Yorumu sil')}
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
