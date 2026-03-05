import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { adminClient } from '../../../admin/api/adminClient.js';

const DEFAULT_MEDIA_FORM = {
  storage_provider: 'local',
  thumb_width: 320,
  feed_width: 1280,
  full_width: 1920,
  webp_quality: 82,
  max_upload_bytes: 10485760,
  avif_enabled: false
};

export default function SettingsSection({ isAdmin = false }) {
  const [siteForm, setSiteForm] = useState(null);
  const [moduleKeys, setModuleKeys] = useState([]);
  const [mediaForm, setMediaForm] = useState(DEFAULT_MEDIA_FORM);
  const [mediaConnectionInfo, setMediaConnectionInfo] = useState({ spacesConfigured: false, spacesRegion: '', spacesBucket: '', spacesEndpoint: '' });
  const [emailCategories, setEmailCategories] = useState([]);
  const [emailTemplates, setEmailTemplates] = useState([]);
  const [categoryForm, setCategoryForm] = useState({ ad: '', tur: 'all', deger: '', aciklama: '' });
  const [templateForm, setTemplateForm] = useState({ ad: '', konu: '', icerik: '' });
  const [status, setStatus] = useState('');
  const [loading, setLoading] = useState(false);

  const loadSite = useCallback(async () => {
    const data = await adminClient.get('/api/admin/site-controls');
    const modules = data.modules || {};
    setModuleKeys(Object.keys(modules));
    setSiteForm({
      siteOpen: !!data.siteOpen,
      maintenanceMessage: data.maintenanceMessage || '',
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
      avif_enabled: Number(settings.avif_enabled || 0) === 1 || settings.avif_enabled === true
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

  const loadAll = useCallback(async () => {
    setLoading(true);
    setStatus('');
    try {
      await Promise.all([loadSite(), loadMedia(), loadEmail()]);
    } catch (err) {
      setStatus(err.message || 'Settings could not be loaded.');
    } finally {
      setLoading(false);
    }
  }, [loadEmail, loadMedia, loadSite]);

  useEffect(() => {
    if (!isAdmin) return;
    loadAll();
  }, [isAdmin, loadAll]);

  const saveSite = useCallback(async () => {
    if (!siteForm) return;
    try {
      await adminClient.put('/api/admin/site-controls', siteForm);
      setStatus('Site and module settings saved.');
      await loadSite();
    } catch (err) {
      setStatus(err.message || 'Site settings save failed.');
    }
  }, [loadSite, siteForm]);

  const saveMedia = useCallback(async () => {
    try {
      await adminClient.put('/api/admin/media-settings', mediaForm);
      setStatus('Media settings saved.');
      await loadMedia();
    } catch (err) {
      setStatus(err.message || 'Media settings save failed.');
    }
  }, [loadMedia, mediaForm]);

  const testMediaConnection = useCallback(async () => {
    try {
      const data = await adminClient.post('/api/admin/media-settings/test', {});
      if (data?.ok) setStatus(data.message || 'Media storage connection test passed.');
      else setStatus(data?.error || 'Media storage connection test failed.');
    } catch (err) {
      setStatus(err.message || 'Media storage connection test failed.');
    }
  }, []);

  const createCategory = useCallback(async () => {
    try {
      await adminClient.post('/api/admin/email/categories', categoryForm);
      setCategoryForm({ ad: '', tur: 'all', deger: '', aciklama: '' });
      await loadEmail();
      setStatus('Email category added.');
    } catch (err) {
      setStatus(err.message || 'Category create failed.');
    }
  }, [categoryForm, loadEmail]);

  const deleteCategory = useCallback(async (id) => {
    try {
      await adminClient.del(`/api/admin/email/categories/${id}`);
      await loadEmail();
      setStatus('Email category deleted.');
    } catch (err) {
      setStatus(err.message || 'Category delete failed.');
    }
  }, [loadEmail]);

  const createTemplate = useCallback(async () => {
    try {
      await adminClient.post('/api/admin/email/templates', templateForm);
      setTemplateForm({ ad: '', konu: '', icerik: '' });
      await loadEmail();
      setStatus('Email template added.');
    } catch (err) {
      setStatus(err.message || 'Template create failed.');
    }
  }, [loadEmail, templateForm]);

  const deleteTemplate = useCallback(async (id) => {
    try {
      await adminClient.del(`/api/admin/email/templates/${id}`);
      await loadEmail();
      setStatus('Email template deleted.');
    } catch (err) {
      setStatus(err.message || 'Template delete failed.');
    }
  }, [loadEmail]);

  const moduleSwitches = useMemo(() => {
    if (!siteForm?.modules) return [];
    return moduleKeys.map((key) => ({ key, value: !!siteForm.modules[key] }));
  }, [moduleKeys, siteForm]);

  if (!isAdmin) {
    return (
      <section className="stack">
        <div className="panel"><div className="panel-body muted">Only admins can change settings.</div></div>
      </section>
    );
  }

  return (
    <section className="stack">
      <div className="ops-head-row">
        <h3>Settings</h3>
        <button className="btn ghost" onClick={loadAll} disabled={loading}>Refresh</button>
      </div>

      {status ? <div className="muted">{status}</div> : null}

      <div className="panel">
        <div className="panel-body stack">
          <h3>Site & Modules</h3>
          <label className="ops-check-row">
            <input
              type="checkbox"
              checked={!!siteForm?.siteOpen}
              onChange={(e) => setSiteForm((prev) => ({ ...(prev || {}), siteOpen: e.target.checked }))}
            />
            <span>Site open for users</span>
          </label>
          <textarea
            className="input"
            rows={3}
            value={siteForm?.maintenanceMessage || ''}
            onChange={(e) => setSiteForm((prev) => ({ ...(prev || {}), maintenanceMessage: e.target.value }))}
            placeholder="Maintenance message"
          />
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
            <button className="btn" onClick={saveSite}>Save site settings</button>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>Media Settings</h3>
          <div className="ops-form-grid">
            <label>
              <span>Provider</span>
              <select className="input" value={mediaForm.storage_provider} onChange={(e) => setMediaForm((prev) => ({ ...prev, storage_provider: e.target.value }))}>
                <option value="local">local</option>
                <option value="spaces">spaces</option>
              </select>
            </label>
            <label>
              <span>Thumb width</span>
              <input className="input" type="number" value={mediaForm.thumb_width} onChange={(e) => setMediaForm((prev) => ({ ...prev, thumb_width: Number(e.target.value || 0) }))} />
            </label>
            <label>
              <span>Feed width</span>
              <input className="input" type="number" value={mediaForm.feed_width} onChange={(e) => setMediaForm((prev) => ({ ...prev, feed_width: Number(e.target.value || 0) }))} />
            </label>
            <label>
              <span>Full width</span>
              <input className="input" type="number" value={mediaForm.full_width} onChange={(e) => setMediaForm((prev) => ({ ...prev, full_width: Number(e.target.value || 0) }))} />
            </label>
            <label>
              <span>WebP quality</span>
              <input className="input" type="number" value={mediaForm.webp_quality} onChange={(e) => setMediaForm((prev) => ({ ...prev, webp_quality: Number(e.target.value || 0) }))} />
            </label>
            <label>
              <span>Max upload bytes</span>
              <input className="input" type="number" value={mediaForm.max_upload_bytes} onChange={(e) => setMediaForm((prev) => ({ ...prev, max_upload_bytes: Number(e.target.value || 0) }))} />
            </label>
          </div>
          <label className="ops-check-row">
            <input
              type="checkbox"
              checked={!!mediaForm.avif_enabled}
              onChange={(e) => setMediaForm((prev) => ({ ...prev, avif_enabled: e.target.checked }))}
            />
            <span>Enable AVIF generation</span>
          </label>
          <div className="meta">
            Spaces configured: {mediaConnectionInfo.spacesConfigured ? 'yes' : 'no'}
            {mediaConnectionInfo.spacesBucket ? ` | Bucket: ${mediaConnectionInfo.spacesBucket}` : ''}
          </div>
          <div className="ops-inline-actions">
            <button className="btn" onClick={saveMedia}>Save media settings</button>
            <button className="btn ghost" onClick={testMediaConnection}>Test connection</button>
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>Email Categories</h3>
          <div className="ops-form-grid">
            <input className="input" placeholder="Name" value={categoryForm.ad} onChange={(e) => setCategoryForm((prev) => ({ ...prev, ad: e.target.value }))} />
            <input className="input" placeholder="Type" value={categoryForm.tur} onChange={(e) => setCategoryForm((prev) => ({ ...prev, tur: e.target.value }))} />
            <input className="input" placeholder="Value" value={categoryForm.deger} onChange={(e) => setCategoryForm((prev) => ({ ...prev, deger: e.target.value }))} />
            <input className="input" placeholder="Description" value={categoryForm.aciklama} onChange={(e) => setCategoryForm((prev) => ({ ...prev, aciklama: e.target.value }))} />
          </div>
          <div className="ops-inline-actions">
            <button className="btn" onClick={createCategory}>Add category</button>
          </div>

          <div className="ops-list-grid">
            {emailCategories.map((row) => (
              <div key={row.id} className="ops-list-row">
                <div>
                  <strong>{row.ad}</strong>
                  <div className="meta">{row.tur} | {row.deger}</div>
                </div>
                <button className="btn ghost" onClick={() => deleteCategory(row.id).catch(() => {})}>Delete</button>
              </div>
            ))}
            {!emailCategories.length ? <div className="muted">No email categories.</div> : null}
          </div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-body stack">
          <h3>Email Templates</h3>
          <div className="stack">
            <input className="input" placeholder="Template name" value={templateForm.ad} onChange={(e) => setTemplateForm((prev) => ({ ...prev, ad: e.target.value }))} />
            <input className="input" placeholder="Subject" value={templateForm.konu} onChange={(e) => setTemplateForm((prev) => ({ ...prev, konu: e.target.value }))} />
            <textarea className="input" rows={5} placeholder="HTML body" value={templateForm.icerik} onChange={(e) => setTemplateForm((prev) => ({ ...prev, icerik: e.target.value }))} />
          </div>
          <div className="ops-inline-actions">
            <button className="btn" onClick={createTemplate}>Add template</button>
          </div>

          <div className="ops-list-grid">
            {emailTemplates.map((row) => (
              <div key={row.id} className="ops-list-row">
                <div>
                  <strong>{row.ad}</strong>
                  <div className="meta">{row.konu}</div>
                </div>
                <button className="btn ghost" onClick={() => deleteTemplate(row.id).catch(() => {})}>Delete</button>
              </div>
            ))}
            {!emailTemplates.length ? <div className="muted">No email templates.</div> : null}
          </div>
        </div>
      </div>
    </section>
  );
}
