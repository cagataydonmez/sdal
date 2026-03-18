import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { adminClient } from '../../../admin/api/adminClient.js';
import { useI18n } from '../../../utils/i18n.jsx';

const DEFAULT_MEDIA_FORM = {
  storage_provider: 'local',
  thumb_width: 320,
  feed_width: 1280,
  full_width: 1920,
  webp_quality: 82,
  max_upload_bytes: 10485760,
  avif_enabled: false,
  album_uploads_require_approval: false
};

const DEFAULT_PAGE_FORM = { sayfaismi: '', sayfaurl: '', menugorun: 1, babaid: '0', yonlendir: 0, mozellik: 0, resim: 'yok' };

export default function SettingsSection({ isAdmin = false }) {
  const { t } = useI18n();
  const [siteForm, setSiteForm] = useState(null);
  const [moduleKeys, setModuleKeys] = useState([]);
  const [mediaForm, setMediaForm] = useState(DEFAULT_MEDIA_FORM);
  const [mediaConnectionInfo, setMediaConnectionInfo] = useState({ spacesConfigured: false, spacesRegion: '', spacesBucket: '', spacesEndpoint: '' });
  const [emailCategories, setEmailCategories] = useState([]);
  const [emailTemplates, setEmailTemplates] = useState([]);
  const [categoryForm, setCategoryForm] = useState({ ad: '', tur: 'all', deger: '', aciklama: '' });
  const [templateForm, setTemplateForm] = useState({ ad: '', konu: '', icerik: '' });
  const [pages, setPages] = useState([]);
  const [pageForm, setPageForm] = useState(DEFAULT_PAGE_FORM);
  const [editingPage, setEditingPage] = useState(null);
  const [dragIndex, setDragIndex] = useState(null);
  const [dragOverIndex, setDragOverIndex] = useState(null);
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(false);
  const dragItemRef = useRef(null);
  const pointerDragRef = useRef({ active: false, pointerId: null });

  const loadSite = useCallback(async () => {
    const data = await adminClient.get('/api/admin/site-controls');
    const modules = data.modules || {};
    setModuleKeys(Object.keys(modules));
    setSiteForm({
      siteOpen: !!data.siteOpen,
      maintenanceMessage: data.maintenanceMessage || '',
      defaultLandingPage: data.defaultLandingPage || '',
      modules
    });
  }, []);

  const loadMedia = useCallback(async () => {
    const data = await adminClient.get('/api/admin/media-settings');
    const settings = data.settings || {};
    setMediaForm({
      storage_provider: settings.storage_provider || 'local',
      thumb_width: Number(settings.thumb_width || DEFAULT_MEDIA_FORM.thumb_width),
      feed_width: Number(settings.feed_width || DEFAULT_MEDIA_FORM.feed_width),
      full_width: Number(settings.full_width || DEFAULT_MEDIA_FORM.full_width),
      webp_quality: Number(settings.webp_quality || DEFAULT_MEDIA_FORM.webp_quality),
      max_upload_bytes: Number(settings.max_upload_bytes || DEFAULT_MEDIA_FORM.max_upload_bytes),
      avif_enabled: Number(settings.avif_enabled || 0) === 1 || settings.avif_enabled === true,
      album_uploads_require_approval: Number(settings.album_uploads_require_approval || 0) === 1 || settings.album_uploads_require_approval === true
    });
    setMediaConnectionInfo({
      spacesConfigured: !!data.spacesConfigured,
      spacesRegion: data.spacesRegion || '',
      spacesBucket: data.spacesBucket || '',
      spacesEndpoint: data.spacesEndpoint || ''
    });
  }, []);

  const loadEmail = useCallback(async () => {
    const [categoriesData, templatesData] = await Promise.all([
      adminClient.get('/api/admin/email/categories'),
      adminClient.get('/api/admin/email/templates')
    ]);
    setEmailCategories(categoriesData.categories || []);
    setEmailTemplates(templatesData.templates || []);
  }, []);

  const loadPages = useCallback(async () => {
    const data = await adminClient.get('/api/admin/pages');
    setPages(data.pages || []);
  }, []);

  const loadAll = useCallback(async () => {
    setLoading(true);
    setStatus('');
    try {
      await Promise.all([loadSite(), loadMedia(), loadEmail(), loadPages()]);
    } catch (err) {
      setStatus(err.message || t('Ayarlar yüklenemedi.'));
    } finally {
      setLoading(false);
    }
  }, [loadEmail, loadMedia, loadPages, loadSite, t]);

  useEffect(() => {
    if (!isAdmin) return;
    loadAll();
  }, [isAdmin, loadAll]);

  const saveSite = useCallback(async () => {
    if (!siteForm) return;
    try {
      await adminClient.put('/api/admin/site-controls', siteForm);
      setStatus(t('Site ve modül ayarları kaydedildi.'));
      await loadSite();
    } catch (err) {
      setStatus(err.message || t('Site ayarları kaydedilemedi.'));
    }
  }, [loadSite, siteForm, t]);

  const saveMedia = useCallback(async () => {
    try {
      await adminClient.put('/api/admin/media-settings', mediaForm);
      setStatus(t('Medya ayarları kaydedildi.'));
      await loadMedia();
    } catch (err) {
      setStatus(err.message || t('Medya ayarları kaydedilemedi.'));
    }
  }, [loadMedia, mediaForm, t]);

  const testMediaConnection = useCallback(async () => {
    try {
      const data = await adminClient.post('/api/admin/media-settings/test', {});
      if (data?.ok) setStatus(data.message || t('Medya depolama bağlantı testi başarılı.'));
      else setStatus(data?.error || t('Medya depolama bağlantı testi başarısız.'));
    } catch (err) {
      setStatus(err.message || t('Medya depolama bağlantı testi başarısız.'));
    }
  }, [t]);

  const createCategory = useCallback(async () => {
    try {
      await adminClient.post('/api/admin/email/categories', categoryForm);
      setCategoryForm({ ad: '', tur: 'all', deger: '', aciklama: '' });
      await loadEmail();
      setStatus(t('E-posta kategorisi eklendi.'));
    } catch (err) {
      setStatus(err.message || t('Kategori oluşturulamadı.'));
    }
  }, [categoryForm, loadEmail, t]);

  const deleteCategory = useCallback(async (id) => {
    try {
      await adminClient.del(`/api/admin/email/categories/${id}`);
      await loadEmail();
      setStatus(t('E-posta kategorisi silindi.'));
    } catch (err) {
      setStatus(err.message || t('Kategori silinemedi.'));
    }
  }, [loadEmail, t]);

  const createTemplate = useCallback(async () => {
    try {
      await adminClient.post('/api/admin/email/templates', templateForm);
      setTemplateForm({ ad: '', konu: '', icerik: '' });
      await loadEmail();
      setStatus(t('E-posta şablonu eklendi.'));
    } catch (err) {
      setStatus(err.message || t('Şablon oluşturulamadı.'));
    }
  }, [loadEmail, t, templateForm]);

  const deleteTemplate = useCallback(async (id) => {
    try {
      await adminClient.del(`/api/admin/email/templates/${id}`);
      await loadEmail();
      setStatus(t('E-posta şablonu silindi.'));
    } catch (err) {
      setStatus(err.message || t('Şablon silinemedi.'));
    }
  }, [loadEmail, t]);

  const togglePageVisibility = useCallback(async (page) => {
    try {
      const nextVisible = page.menugorun ? 0 : 1;
      await adminClient.put(`/api/admin/pages/${page.id}`, {
        sayfaismi: page.sayfaismi,
        sayfaurl: page.sayfaurl,
        babaid: String(page.babaid || '0'),
        menugorun: nextVisible,
        yonlendir: Number(page.yonlendir || 0),
        mozellik: Number(page.mozellik || 0),
        resim: page.resim || 'yok'
      });
      await loadPages();
    } catch (err) {
      setStatus(err.message || t('Sayfa güncellenemedi.'));
    }
  }, [loadPages, t]);

  const savePage = useCallback(async () => {
    try {
      if (editingPage) {
        await adminClient.put(`/api/admin/pages/${editingPage.id}`, pageForm);
        setStatus(t('Sayfa güncellendi.'));
      } else {
        await adminClient.post('/api/admin/pages', pageForm);
        setStatus(t('Sayfa eklendi.'));
      }
      setPageForm(DEFAULT_PAGE_FORM);
      setEditingPage(null);
      await loadPages();
    } catch (err) {
      setStatus(err.message || t('Sayfa kaydedilemedi.'));
    }
  }, [editingPage, loadPages, pageForm, t]);

  const deletePage = useCallback(async (id) => {
    if (!window.confirm(t('Bu sayfayı silmek istediğinize emin misiniz?'))) return;
    try {
      await adminClient.del(`/api/admin/pages/${id}`);
      await loadPages();
      setStatus(t('Sayfa silindi.'));
    } catch (err) {
      setStatus(err.message || t('Sayfa silinemedi.'));
    }
  }, [loadPages, t]);

  const startEdit = useCallback((page) => {
    setEditingPage(page);
    setPageForm({
      sayfaismi: page.sayfaismi || '',
      sayfaurl: page.sayfaurl || '',
      menugorun: Number(page.menugorun ?? 1),
      babaid: String(page.babaid || '0'),
      yonlendir: Number(page.yonlendir || 0),
      mozellik: Number(page.mozellik || 0),
      resim: page.resim || 'yok'
    });
  }, []);

  const cancelEdit = useCallback(() => {
    setEditingPage(null);
    setPageForm(DEFAULT_PAGE_FORM);
  }, []);

  const persistPageOrder = useCallback(async (reordered) => {
    setPages(reordered);
    setDragIndex(null);
    setDragOverIndex(null);
    dragItemRef.current = null;
    try {
      await adminClient.put('/api/admin/pages/reorder', { order: reordered.map((p) => p.id) });
      setStatus(t('Sayfa sırası kaydedildi.'));
    } catch (err) {
      setStatus(err.message || t('Sıralama kaydedilemedi.'));
      await loadPages();
    }
  }, [loadPages, t]);

  const movePage = useCallback(async (fromIndex, toIndex) => {
    if (!Number.isInteger(fromIndex) || !Number.isInteger(toIndex) || fromIndex === toIndex) {
      setDragIndex(null);
      setDragOverIndex(null);
      dragItemRef.current = null;
      return;
    }
    const reordered = [...pages];
    const [moved] = reordered.splice(fromIndex, 1);
    if (!moved) {
      setDragIndex(null);
      setDragOverIndex(null);
      dragItemRef.current = null;
      return;
    }
    reordered.splice(toIndex, 0, moved);
    await persistPageOrder(reordered);
  }, [pages, persistPageOrder]);

  // Drag and drop handlers
  const handleDragStart = useCallback((e, index) => {
    dragItemRef.current = index;
    setDragIndex(index);
    e.dataTransfer.effectAllowed = 'move';
  }, []);

  const handleDragOver = useCallback((e, index) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    setDragOverIndex(index);
  }, []);

  const handleDrop = useCallback(async (e, dropIndex) => {
    e.preventDefault();
    await movePage(dragItemRef.current, dropIndex);
  }, [movePage]);

  const handleDragEnd = useCallback(() => {
    setDragIndex(null);
    setDragOverIndex(null);
    dragItemRef.current = null;
  }, []);

  const handlePointerMove = useCallback((e) => {
    if (!pointerDragRef.current.active) return;
    e.preventDefault();
    const target = document.elementFromPoint(e.clientX, e.clientY);
    const row = target?.closest?.('[data-page-index]');
    const nextIndex = row ? Number(row.getAttribute('data-page-index')) : null;
    if (Number.isInteger(nextIndex)) setDragOverIndex(nextIndex);
  }, []);

  const handlePointerUp = useCallback(async (e) => {
    if (!pointerDragRef.current.active) return;
    const { pointerId } = pointerDragRef.current;
    if (pointerId !== null && e.pointerId !== pointerId) return;
    pointerDragRef.current = { active: false, pointerId: null };
    await movePage(dragItemRef.current, dragOverIndex);
  }, [dragOverIndex, movePage]);

  const handlePointerCancel = useCallback(() => {
    pointerDragRef.current = { active: false, pointerId: null };
    setDragIndex(null);
    setDragOverIndex(null);
    dragItemRef.current = null;
  }, []);

  useEffect(() => {
    if (!pointerDragRef.current.active) return undefined;
    window.addEventListener('pointermove', handlePointerMove, { passive: false });
    window.addEventListener('pointerup', handlePointerUp);
    window.addEventListener('pointercancel', handlePointerCancel);
    return () => {
      window.removeEventListener('pointermove', handlePointerMove);
      window.removeEventListener('pointerup', handlePointerUp);
      window.removeEventListener('pointercancel', handlePointerCancel);
    };
  }, [handlePointerCancel, handlePointerMove, handlePointerUp, dragIndex]);

  const handlePointerDragStart = useCallback((e, index) => {
    if (e.pointerType === 'mouse' && e.button !== 0) return;
    pointerDragRef.current = { active: true, pointerId: e.pointerId };
    dragItemRef.current = index;
    setDragIndex(index);
    setDragOverIndex(index);
    e.preventDefault();
  }, []);

  const moduleSwitches = useMemo(() => {
    if (!siteForm?.modules) return [];
    return moduleKeys.map((key) => ({ key, value: !!siteForm.modules[key] }));
  }, [moduleKeys, siteForm]);

  if (!isAdmin) {
    return (
      <section className="stack">
        <div className="panel"><div className="panel-body muted">{t('Ayarları sadece yöneticiler değiştirebilir.')}</div></div>
      </section>
    );
  }

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>{t('Ayarlar')}</h3>
        <button className="btn ghost" onClick={loadAll} disabled={loading}>{t('Yenile')}</button>
      </div>

      {status ? <div className="muted">{status}</div> : null}

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('Site ve Modüller')}</h3>
          <label className="ops-check-row">
            <input
              type="checkbox"
              checked={!!siteForm?.siteOpen}
              onChange={(e) => setSiteForm((prev) => ({ ...(prev || {}), siteOpen: e.target.checked }))}
            />
            <span>{t('Site kullanıcılara açık')}</span>
          </label>
          <textarea
            className="input"
            rows={3}
            value={siteForm?.maintenanceMessage || ''}
            onChange={(e) => setSiteForm((prev) => ({ ...(prev || {}), maintenanceMessage: e.target.value }))}
            placeholder={t('Bakım mesajı')}
          />
          <label>
            <span>{t('Giriş sonrası açılacak sayfa')}</span>
            <select
              className="input"
              value={siteForm?.defaultLandingPage || ''}
              onChange={(e) => setSiteForm((prev) => ({ ...(prev || {}), defaultLandingPage: e.target.value }))}
            >
              <option value="">{t('Varsayılan (Ana Sayfa)')}</option>
              {pages.filter((p) => !!p.menugorun).map((p) => (
                <option key={p.id} value={p.sayfaurl}>{p.sayfaismi}</option>
              ))}
            </select>
          </label>
          <div className="ops-toggle-grid">
            {moduleSwitches.map((row) => (
              <label key={row.key} className="ops-check-row">
                <input
                  type="checkbox"
                  checked={row.value}
                  onChange={(e) => setSiteForm((prev) => ({
                    ...(prev || {}),
                    modules: {
                      ...(prev?.modules || {}),
                      [row.key]: e.target.checked
                    }
                  }))}
                />
                <span>{row.key}</span>
              </label>
            ))}
          </div>
          <div className="ops-inline-actions">
            <button className="btn" onClick={saveSite}>{t('Site ayarlarını kaydet')}</button>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('Menü Sayfaları')}</h3>
          <p className="muted">{t('Sayfaları sürükleyerek sıralayın. Göz simgesiyle menüde görünürlüğünü açıp kapatın.')}</p>

          <div className="ops-list-grid">
            {pages.map((page, index) => (
              <div
                key={page.id}
                data-page-index={index}
                className={`ops-list-row ops-drag-row${dragIndex === index ? ' ops-drag-active' : ''}${dragOverIndex === index && dragIndex !== index ? ' ops-drag-over' : ''}`}
                draggable
                onDragStart={(e) => handleDragStart(e, index)}
                onDragOver={(e) => handleDragOver(e, index)}
                onDrop={(e) => handleDrop(e, index)}
                onDragEnd={handleDragEnd}
                style={{ cursor: dragIndex === index ? 'grabbing' : 'default', opacity: dragIndex === index ? 0.5 : 1 }}
              >
                <button
                  type="button"
                  className="ops-drag-handle"
                  title={t('Sürükle')}
                  aria-label={t('Sürükle')}
                  onPointerDown={(e) => handlePointerDragStart(e, index)}
                >
                  ⠿
                </button>
                <div style={{ flex: 1 }}>
                  <strong style={{ opacity: page.menugorun ? 1 : 0.45 }}>{page.sayfaismi}</strong>
                  <div className="meta">{page.sayfaurl}</div>
                </div>
                <div className="ops-inline-actions">
                  <button
                    className={`btn ghost${page.menugorun ? '' : ' muted'}`}
                    title={page.menugorun ? t('Menüden gizle') : t('Menüde göster')}
                    onClick={() => togglePageVisibility(page)}
                  >
                    {page.menugorun ? '👁' : '🚫'}
                  </button>
                  <button className="btn ghost" onClick={() => startEdit(page)}>{t('Düzenle')}</button>
                  <button className="btn ghost" onClick={() => deletePage(page.id)}>{t('Sil')}</button>
                </div>
              </div>
            ))}
            {!pages.length ? <div className="muted">{t('Henüz sayfa eklenmemiş.')}</div> : null}
          </div>

          <div className="panel" style={{ marginTop: '1rem' }}>
            <div className="panel-body stack">
              <h4>{editingPage ? t('Sayfa Düzenle') : t('Yeni Sayfa Ekle')}</h4>
              <div className="ops-form-grid">
                <label>
                  <span>{t('Sayfa adı')}</span>
                  <input className="input" placeholder={t('Sayfa adı')} value={pageForm.sayfaismi} onChange={(e) => setPageForm((prev) => ({ ...prev, sayfaismi: e.target.value }))} />
                </label>
                <label>
                  <span>{t('URL (slug)')}</span>
                  <input className="input" placeholder={t('sayfa-url')} value={pageForm.sayfaurl} onChange={(e) => setPageForm((prev) => ({ ...prev, sayfaurl: e.target.value }))} />
                </label>
              </div>
              <label className="ops-check-row">
                <input
                  type="checkbox"
                  checked={!!pageForm.menugorun}
                  onChange={(e) => setPageForm((prev) => ({ ...prev, menugorun: e.target.checked ? 1 : 0 }))}
                />
                <span>{t('Menüde göster')}</span>
              </label>
              <div className="ops-inline-actions">
                <button className="btn" onClick={savePage}>{editingPage ? t('Güncelle') : t('Ekle')}</button>
                {editingPage ? <button className="btn ghost" onClick={cancelEdit}>{t('İptal')}</button> : null}
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('Medya Ayarları')}</h3>
          <div className="ops-form-grid">
            <label>
              <span>{t('Sağlayıcı')}</span>
              <select className="input" value={mediaForm.storage_provider} onChange={(e) => setMediaForm((prev) => ({ ...prev, storage_provider: e.target.value }))}>
                <option value="local">{t('lokal')}</option>
                <option value="spaces">{t('spaces')}</option>
              </select>
            </label>
            <label>
              <span>{t('Küçük görsel genişliği')}</span>
              <input className="input" type="number" value={mediaForm.thumb_width} onChange={(e) => setMediaForm((prev) => ({ ...prev, thumb_width: Number(e.target.value || 0) }))} />
            </label>
            <label>
              <span>{t('Akış genişliği')}</span>
              <input className="input" type="number" value={mediaForm.feed_width} onChange={(e) => setMediaForm((prev) => ({ ...prev, feed_width: Number(e.target.value || 0) }))} />
            </label>
            <label>
              <span>{t('Tam genişlik')}</span>
              <input className="input" type="number" value={mediaForm.full_width} onChange={(e) => setMediaForm((prev) => ({ ...prev, full_width: Number(e.target.value || 0) }))} />
            </label>
            <label>
              <span>{t('WebP kalitesi')}</span>
              <input className="input" type="number" value={mediaForm.webp_quality} onChange={(e) => setMediaForm((prev) => ({ ...prev, webp_quality: Number(e.target.value || 0) }))} />
            </label>
            <label>
              <span>{t('Maksimum yükleme byte')}</span>
              <input className="input" type="number" value={mediaForm.max_upload_bytes} onChange={(e) => setMediaForm((prev) => ({ ...prev, max_upload_bytes: Number(e.target.value || 0) }))} />
            </label>
          </div>
          <label className="ops-check-row">
            <input
              type="checkbox"
              checked={!!mediaForm.avif_enabled}
              onChange={(e) => setMediaForm((prev) => ({ ...prev, avif_enabled: e.target.checked }))}
            />
            <span>{t('AVIF üretimini etkinleştir')}</span>
          </label>
          <label className="ops-check-row">
            <input
              type="checkbox"
              checked={!!mediaForm.album_uploads_require_approval}
              onChange={(e) => setMediaForm((prev) => ({ ...prev, album_uploads_require_approval: e.target.checked }))}
            />
            <span>{t('Albüm fotoğrafı yayınlanmadan önce onay gerektir')}</span>
          </label>
          <div className="meta">
            {t('Spaces yapılandırıldı')}: {mediaConnectionInfo.spacesConfigured ? t('evet') : t('hayır')}
            {mediaConnectionInfo.spacesBucket ? ` | ${t('Bucket')}: ${mediaConnectionInfo.spacesBucket}` : ''}
          </div>
          <div className="ops-inline-actions">
            <button className="btn" onClick={saveMedia}>{t('Medya ayarlarını kaydet')}</button>
            <button className="btn ghost" onClick={testMediaConnection}>{t('Bağlantıyı test et')}</button>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('E-posta Kategorileri')}</h3>
          <div className="ops-form-grid">
            <input className="input" placeholder={t('Ad')} value={categoryForm.ad} onChange={(e) => setCategoryForm((prev) => ({ ...prev, ad: e.target.value }))} />
            <input className="input" placeholder={t('Tür')} value={categoryForm.tur} onChange={(e) => setCategoryForm((prev) => ({ ...prev, tur: e.target.value }))} />
            <input className="input" placeholder={t('Değer')} value={categoryForm.deger} onChange={(e) => setCategoryForm((prev) => ({ ...prev, deger: e.target.value }))} />
            <input className="input" placeholder={t('Açıklama')} value={categoryForm.aciklama} onChange={(e) => setCategoryForm((prev) => ({ ...prev, aciklama: e.target.value }))} />
          </div>
          <div className="ops-inline-actions">
            <button className="btn" onClick={createCategory}>{t('Kategori ekle')}</button>
          </div>

          <div className="ops-list-grid">
            {emailCategories.map((row) => (
              <div key={row.id} className="ops-list-row">
                <div>
                  <strong>{row.ad}</strong>
                  <div className="meta">{row.tur} | {row.deger}</div>
                </div>
                <button className="btn ghost" onClick={() => deleteCategory(row.id).catch(() => {})}>{t('Sil')}</button>
              </div>
            ))}
            {!emailCategories.length ? <div className="muted">{t('E-posta kategorisi yok.')}</div> : null}
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('E-posta Şablonları')}</h3>
          <div className="stack">
            <input className="input" placeholder={t('Şablon adı')} value={templateForm.ad} onChange={(e) => setTemplateForm((prev) => ({ ...prev, ad: e.target.value }))} />
            <input className="input" placeholder={t('Konu')} value={templateForm.konu} onChange={(e) => setTemplateForm((prev) => ({ ...prev, konu: e.target.value }))} />
            <textarea className="input" rows={5} placeholder={t('HTML gövdesi')} value={templateForm.icerik} onChange={(e) => setTemplateForm((prev) => ({ ...prev, icerik: e.target.value }))} />
          </div>
          <div className="ops-inline-actions">
            <button className="btn" onClick={createTemplate}>{t('Şablon ekle')}</button>
          </div>

          <div className="ops-list-grid">
            {emailTemplates.map((row) => (
              <div key={row.id} className="ops-list-row">
                <div>
                  <strong>{row.ad}</strong>
                  <div className="meta">{row.konu}</div>
                </div>
                <button className="btn ghost" onClick={() => deleteTemplate(row.id).catch(() => {})}>{t('Sil')}</button>
              </div>
            ))}
            {!emailTemplates.length ? <div className="muted">{t('E-posta şablonu yok.')}</div> : null}
          </div>
        </div>
      </div>
    </section>
  );
}
