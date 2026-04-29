import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient } from '../../../admin/api/adminClient.js';
import { useI18n } from '../../../utils/i18n.jsx';
import { invalidateCache } from '../../../utils/swrCache.js';
import { MODULE_CONTROL_ITEMS, MODULE_ROUTE_BY_KEY, normalizeMenuVisibility, normalizeModuleOrder } from '../../../utils/moduleNavigation.js';

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

const DEFAULT_AUTH_SETTINGS = {
  smsVerificationEnabled: false
};

export default function SettingsSection({ isAdmin = false }) {
  const { t } = useI18n();
  const [siteForm, setSiteForm] = useState(null);
  const [moduleKeys, setModuleKeys] = useState([]);
  const [moduleDefinitions, setModuleDefinitions] = useState(MODULE_CONTROL_ITEMS.map((item) => ({ key: item.key, label: item.defaultLabel })));
  const [mediaForm, setMediaForm] = useState(DEFAULT_MEDIA_FORM);
  const [authSettings, setAuthSettings] = useState(DEFAULT_AUTH_SETTINGS);
  const [mediaConnectionInfo, setMediaConnectionInfo] = useState({ spacesConfigured: false, spacesRegion: '', spacesBucket: '', spacesEndpoint: '' });
  const [emailCategories, setEmailCategories] = useState([]);
  const [emailTemplates, setEmailTemplates] = useState([]);
  const [categoryForm, setCategoryForm] = useState({ ad: '', tur: 'all', deger: '', aciklama: '' });
  const [templateForm, setTemplateForm] = useState({ ad: '', konu: '', icerik: '' });
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(false);
  const [draggedModuleKey, setDraggedModuleKey] = useState('');
  const [dragOverModuleKey, setDragOverModuleKey] = useState('');

  const emitSiteAccessRefresh = useCallback(() => {
    invalidateCache();
    if (typeof window !== 'undefined') {
      window.dispatchEvent(new CustomEvent('sdal:site-access-updated'));
    }
  }, []);

  const loadSite = useCallback(async () => {
    const data = await adminClient.get('/api/admin/site-controls');
    const modules = data.modules || {};
    const definitionKeys = Array.isArray(data.moduleDefinitions)
      ? data.moduleDefinitions.map((item) => String(item?.key || '').trim()).filter(Boolean)
      : [];
    const keys = definitionKeys.length ? definitionKeys : Object.keys(modules);
    setModuleKeys(keys);
    setModuleDefinitions(
      Array.isArray(data.moduleDefinitions) && data.moduleDefinitions.length
        ? data.moduleDefinitions
        : MODULE_CONTROL_ITEMS.map((item) => ({ key: item.key, label: item.defaultLabel }))
    );
    setSiteForm({
      siteOpen: !!data.siteOpen,
      maintenanceMessage: data.maintenanceMessage || '',
      defaultLandingPage: data.defaultLandingPage || '',
      modules,
      menuVisibility: normalizeMenuVisibility(data.menuVisibility, keys.filter((key) => Boolean(MODULE_ROUTE_BY_KEY[key]))),
      moduleMenuOrder: normalizeModuleOrder(data.moduleMenuOrder, keys.filter((key) => Boolean(MODULE_ROUTE_BY_KEY[key])))
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

  const loadAuthSettings = useCallback(async () => {
    const data = await adminClient.get('/api/admin/auth-settings');
    const settings = data.settings || {};
    setAuthSettings({
      smsVerificationEnabled: !!settings.smsVerificationEnabled
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

  const loadAll = useCallback(async () => {
    setLoading(true);
    setStatus('');
    try {
      await Promise.all([loadSite(), loadMedia(), loadAuthSettings(), loadEmail()]);
    } catch (err) {
      setStatus(err.message || t('Ayarlar yüklenemedi.'));
    } finally {
      setLoading(false);
    }
  }, [loadAuthSettings, loadEmail, loadMedia, loadSite, t]);

  useEffect(() => {
    if (!isAdmin) return;
    loadAll();
  }, [isAdmin, loadAll]);

  const updateSiteControls = useCallback(async (buildNextState, successMessage) => {
    if (!siteForm) return;
    const previous = siteForm;
    const next = typeof buildNextState === 'function' ? buildNextState(previous) : { ...previous, ...(buildNextState || {}) };
    if (!next) return;
    setSiteForm(next);
    try {
      await adminClient.put('/api/admin/site-controls', next);
      emitSiteAccessRefresh();
      setStatus(successMessage || t('Site ve modül ayarları güncellendi.'));
    } catch (err) {
      setStatus(err.message || t('Site ayarları güncellenemedi.'));
      await loadSite();
    }
  }, [emitSiteAccessRefresh, loadSite, siteForm, t]);

  const saveMedia = useCallback(async () => {
    try {
      await adminClient.put('/api/admin/media-settings', mediaForm);
      setStatus(t('Medya ayarları kaydedildi.'));
      await loadMedia();
    } catch (err) {
      setStatus(err.message || t('Medya ayarları kaydedilemedi.'));
    }
  }, [loadMedia, mediaForm, t]);

  const updateAuthSettings = useCallback(async (nextSettings) => {
    const previous = authSettings;
    const next = { ...previous, ...(nextSettings || {}) };
    setAuthSettings(next);
    try {
      const data = await adminClient.put('/api/admin/auth-settings', next);
      const settings = data.settings || {};
      setAuthSettings({
        smsVerificationEnabled: !!settings.smsVerificationEnabled
      });
      setStatus(t('Doğrulama ayarları güncellendi.'));
    } catch (err) {
      setAuthSettings(previous);
      setStatus(err.message || t('Doğrulama ayarları güncellenemedi.'));
    }
  }, [authSettings, t]);

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

  const moduleLabels = useMemo(() => Object.fromEntries(
    moduleDefinitions.map((item) => [item.key, item.label || item.key])
  ), [moduleDefinitions]);

  const moduleMeta = useMemo(() => {
    const fallback = Object.fromEntries(MODULE_CONTROL_ITEMS.map((item) => [item.key, item]));
    return Object.fromEntries(moduleKeys.map((key) => [key, fallback[key] || { key, path: MODULE_ROUTE_BY_KEY[key] || '', menu: Boolean(MODULE_ROUTE_BY_KEY[key]) }]));
  }, [moduleKeys]);

  const menuModuleKeys = useMemo(() => (
    moduleKeys.filter((key) => moduleMeta[key]?.menu && Boolean(MODULE_ROUTE_BY_KEY[key]))
  ), [moduleKeys, moduleMeta]);

  const reorderMenuModules = useCallback((currentState, draggedKey, targetKey) => {
    const currentOrder = normalizeModuleOrder(currentState.moduleMenuOrder, menuModuleKeys);
    const fromIndex = currentOrder.indexOf(draggedKey);
    const toIndex = currentOrder.indexOf(targetKey);
    if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return currentState;
    const nextOrder = [...currentOrder];
    const [moved] = nextOrder.splice(fromIndex, 1);
    nextOrder.splice(toIndex, 0, moved);
    return {
      ...currentState,
      moduleMenuOrder: nextOrder
    };
  }, [menuModuleKeys]);

  const moduleRows = useMemo(() => {
    if (!siteForm?.modules) return [];
    const order = normalizeModuleOrder(siteForm.moduleMenuOrder, menuModuleKeys);
    const orderIndex = new Map(order.map((key, index) => [key, index]));
    const menuVisibility = normalizeMenuVisibility(siteForm.menuVisibility, menuModuleKeys);
    return [...moduleKeys]
      .sort((a, b) => {
        const aIsMenu = menuModuleKeys.includes(a);
        const bIsMenu = menuModuleKeys.includes(b);
        if (aIsMenu && bIsMenu) return (orderIndex.get(a) ?? Number.MAX_SAFE_INTEGER) - (orderIndex.get(b) ?? Number.MAX_SAFE_INTEGER);
        if (aIsMenu) return -1;
        if (bIsMenu) return 1;
        return (moduleLabels[a] || a).localeCompare(moduleLabels[b] || b, 'tr');
      })
      .map((key) => {
        const path = MODULE_ROUTE_BY_KEY[key] || '';
        const menuEligible = menuModuleKeys.includes(key);
        const active = siteForm.modules[key] !== false;
        const visible = menuEligible ? menuVisibility[key] !== false : false;
        const isDefault = path && siteForm.defaultLandingPage === path;
        return {
          key,
          label: moduleLabels[key] || key,
          path,
          menuEligible,
          active,
          visible,
          isDefault
        };
      });
  }, [menuModuleKeys, moduleKeys, moduleLabels, siteForm]);

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
          <h3>{t('Site ve Modül Ayarları')}</h3>
          <p className="muted">{t('Bu alandaki değişiklikler anında uygulanır. Kaydet butonu gerekmez.')}</p>
          <label className="ops-check-row">
            <input
              type="checkbox"
              checked={!!siteForm?.siteOpen}
              onChange={(e) => updateSiteControls((prev) => ({ ...(prev || {}), siteOpen: e.target.checked }), t('Site erişim durumu güncellendi.'))}
            />
            <span>{t('Site kullanıcılara açık')}</span>
          </label>
          <textarea
            className="input"
            rows={3}
            value={siteForm?.maintenanceMessage || ''}
            onChange={(e) => setSiteForm((prev) => ({ ...(prev || {}), maintenanceMessage: e.target.value }))}
            onBlur={() => updateSiteControls((prev) => ({ ...(prev || {}), maintenanceMessage: siteForm?.maintenanceMessage || '' }), t('Bakım mesajı güncellendi.'))}
            placeholder={t('Bakım mesajı')}
          />
          <div className="ops-settings-list-head">
            <strong>{t('Modüller')}</strong>
            <span className="muted">{t('Sürükle-bırak ile menü sırası değişir. İkonlar aktiflik, görünürlük ve varsayılan açılışı yönetir.')}</span>
          </div>
          <div className="ops-list-grid">
            {moduleRows.map((item) => (
              <div
                key={item.key}
                className={`ops-list-row ops-drag-row ops-module-row${dragOverModuleKey === item.key ? ' ops-drag-over' : ''}${!item.active ? ' is-inactive' : ''}`}
                draggable={item.menuEligible}
                onDragStart={() => {
                  if (!item.menuEligible) return;
                  setDraggedModuleKey(item.key);
                }}
                onDragEnd={() => {
                  setDraggedModuleKey('');
                  setDragOverModuleKey('');
                }}
                onDragOver={(event) => {
                  if (!item.menuEligible || !draggedModuleKey || draggedModuleKey === item.key) return;
                  event.preventDefault();
                  setDragOverModuleKey(item.key);
                }}
                onDrop={(event) => {
                  if (!item.menuEligible || !draggedModuleKey || draggedModuleKey === item.key) return;
                  event.preventDefault();
                  const sourceKey = draggedModuleKey;
                  setDraggedModuleKey('');
                  setDragOverModuleKey('');
                  updateSiteControls(
                    (prev) => reorderMenuModules(prev, sourceKey, item.key),
                    t('Menü sırası güncellendi.')
                  );
                }}
              >
                <button className={`ops-drag-handle${item.menuEligible ? '' : ' disabled'}`} type="button" disabled={!item.menuEligible} title={item.menuEligible ? t('Sürükleyerek menü sırasını değiştir') : t('Bu modül menüde sıralanmaz')}>
                  ☰
                </button>
                <div className="admin-flex-grow">
                  <strong className={item.active ? '' : 'admin-dimmed'}>{item.label}</strong>
                  <div className="meta">
                    {item.path || t('Bu modül için kullanıcı menüsü/rota tanımlı değil.')}
                    {!item.menuEligible ? ` · ${t('Menü dışında çalışır')}` : ''}
                    {!item.active ? ` · ${t('Kullanıcı erişimine kapalı')}` : ''}
                    {item.menuEligible && !item.visible ? ` · ${t('Menüde gizli')}` : ''}
                    {item.isDefault ? ` · ${t('Login sonrası varsayılan')}` : ''}
                  </div>
                </div>
                <div className="ops-inline-actions">
                  <button
                    className={`btn ghost icon-btn${item.isDefault ? ' active' : ''}`}
                    type="button"
                    title={item.menuEligible ? (item.isDefault ? t('Varsayılan açılış sayfası') : t('Bu modülü login sonrası varsayılan açılış yap')) : t('Bu modül varsayılan açılış olamaz')}
                    disabled={!item.menuEligible || !item.active || !item.visible}
                    onClick={() => updateSiteControls((prev) => ({
                      ...(prev || {}),
                      defaultLandingPage: item.path
                    }), t('Varsayılan açılış modülü güncellendi.'))}
                  >
                    {item.isDefault ? '🏠' : '⌂'}
                  </button>
                  <button
                    className={`btn ghost icon-btn${item.visible ? ' active' : ''}`}
                    type="button"
                    title={item.menuEligible ? (item.visible ? t('Menüden gizle') : t('Menüde göster')) : t('Bu modül menüde gösterilmez')}
                    disabled={!item.menuEligible}
                    onClick={() => updateSiteControls((prev) => ({
                      ...(prev || {}),
                      menuVisibility: {
                        ...(prev?.menuVisibility || {}),
                        [item.key]: !(prev?.menuVisibility?.[item.key] !== false)
                      },
                      defaultLandingPage: prev?.defaultLandingPage === item.path && item.visible ? '' : prev?.defaultLandingPage || ''
                    }), t('Menü görünürlüğü güncellendi.'))}
                  >
                    {item.visible ? '👁' : '🙈'}
                  </button>
                  <button
                    className={`btn ghost icon-btn${item.active ? ' active' : ''}`}
                    type="button"
                    title={item.active ? t('Modülü pasife al') : t('Modülü aktifleştir')}
                    onClick={() => updateSiteControls((prev) => {
                      const isCurrentlyActive = prev?.modules?.[item.key] !== false;
                      const nextActive = !isCurrentlyActive;
                      const nextPath = item.path || '';
                      return {
                        ...(prev || {}),
                        modules: {
                          ...(prev?.modules || {}),
                          [item.key]: nextActive
                        },
                        defaultLandingPage: prev?.defaultLandingPage === nextPath && !nextActive ? '' : prev?.defaultLandingPage || ''
                      };
                    }, t('Modül erişimi güncellendi.'))}
                  >
                    {item.active ? '⏻' : '⭘'}
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>{t('Doğrulama Ayarları')}</h3>
          <label className="ops-check-row">
            <input
              type="checkbox"
              checked={!!authSettings.smsVerificationEnabled}
              onChange={(e) => updateAuthSettings({ smsVerificationEnabled: e.target.checked })}
            />
            <span>{t('SMS telefon doğrulamasını etkinleştir')}</span>
          </label>
          <div className="meta">
            {authSettings.smsVerificationEnabled
              ? t('Yeni kayıtlar e-posta aktivasyonundan sonra SMS doğrulamasına yönlendirilir.')
              : t('SMS kapalıyken kayıt ve giriş akışında yalnızca e-posta doğrulaması çalışır.')}
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
