import React, { useCallback, useEffect, useRef, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';
import { useI18n } from '../../../utils/i18n.jsx';
import { openConfirm } from '../../../utils/dialogs.js';

const TABS = [
  { key: 'languages', label: 'Diller' },
  { key: 'strings', label: 'Çeviri Dizeleri' }
];

export default function LanguagesSection({ isAdmin = false }) {
  const { t } = useI18n();
  const [tab, setTab] = useState('languages');
  const [languages, setLanguages] = useState([]);

  const loadLangsGlobal = useCallback(async () => {
    try {
      const data = await adminClient.get('/api/admin/languages');
      setLanguages(data.languages || []);
    } catch {}
  }, []);

  useEffect(() => { if (isAdmin) loadLangsGlobal(); }, [isAdmin, loadLangsGlobal]);

  return (
    <div className="stack">
      <div className="panel">
        <div className="panel-body">
          <div className="tabs-row admin-inline-wrap">
            {TABS.map((tabItem) => (
              <button
                key={tabItem.key}
                className={`btn btn-sm ${tab === tabItem.key ? 'btn-primary' : 'btn-secondary'}`}
                onClick={() => setTab(tabItem.key)}
              >
                {t(tabItem.label)}
              </button>
            ))}
          </div>
        </div>
      </div>

      <LangConfigPanel languages={languages} />
      {tab === 'languages' && <LanguagesTab isAdmin={isAdmin} onChanged={loadLangsGlobal} />}
      {tab === 'strings' && <StringsTab isAdmin={isAdmin} languages={languages} />}
    </div>
  );
}

// ─── Language Config Panel ─────────────────────────────────────────────────────

function LangConfigPanel({ languages }) {
  const { t, reloadI18nConfig } = useI18n();
  const [config, setConfig] = useState(null);
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState('');

  const load = useCallback(async () => {
    try {
      const data = await adminClient.get('/api/admin/language-config');
      setConfig(data);
    } catch (err) {
      setStatus(err.message || t('Dil yapılandırması yüklenemedi.'));
    }
  }, [t]);

  useEffect(() => { load(); }, [load]);

  const save = async (e) => {
    e.preventDefault();
    setSaving(true);
    setStatus('');
    try {
      await adminClient.put('/api/admin/language-config', config);
      await reloadI18nConfig();
      setStatus(t('Dil ayarları kaydedildi.'));
    } catch (err) {
      setStatus(err.message || t('Kaydetme başarısız.'));
    } finally {
      setSaving(false);
    }
  };

  if (!config) return null;

  return (
    <div className="panel">
      <div className="panel-header"><strong>{t('Dil Seçimi Ayarları')}</strong></div>
      <div className="panel-body">
        <form onSubmit={save} className="stack">
          <label className="ops-check-row">
            <input
              type="checkbox"
              checked={!!config.lang_selection_enabled}
              onChange={(e) => setConfig((c) => ({ ...c, lang_selection_enabled: e.target.checked }))}
            />
            <span>{t('Kullanıcıların dilini değiştirmesine izin ver')}</span>
          </label>
          <div className="admin-inline-wrap">
            <label className="admin-field-stack admin-field-grow">
              <span className="label-text">{t('Varsayılan dil — site açık (giriş yapanlar)')}</span>
              <select
                className="input"
                value={config.default_lang_open || 'tr'}
                onChange={(e) => setConfig((c) => ({ ...c, default_lang_open: e.target.value }))}
              >
                {languages.map((l) => (
                  <option key={l.code} value={l.code}>{l.name} ({l.code})</option>
                ))}
              </select>
            </label>
            <label className="admin-field-stack admin-field-grow">
              <span className="label-text">{t('Varsayılan dil — site kapalı (ziyaretçiler)')}</span>
              <select
                className="input"
                value={config.default_lang_closed || 'tr'}
                onChange={(e) => setConfig((c) => ({ ...c, default_lang_closed: e.target.value }))}
              >
                {languages.map((l) => (
                  <option key={l.code} value={l.code}>{l.name} ({l.code})</option>
                ))}
              </select>
            </label>
          </div>
          <div>
            <button type="submit" className="btn btn-primary" disabled={saving}>
              {saving ? t('saving') : t('Dil Ayarlarını Kaydet')}
            </button>
          </div>
          {status ? (
            <div className={`muted admin-status-message ${status.includes(t('kaydedildi')) || status.includes('saved') ? 'is-success' : 'is-error'}`}>
              {status}
            </div>
          ) : null}
        </form>
      </div>
    </div>
  );
}

// ─── Languages Tab ────────────────────────────────────────────────────────────

function LanguagesTab({ isAdmin, onChanged }) {
  const { t, reloadI18nConfig } = useI18n();
  const [languages, setLanguages] = useState([]);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState('');
  const [addForm, setAddForm] = useState({ code: '', name: '', native_name: '' });
  const [adding, setAdding] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setStatus('');
    try {
      const data = await adminClient.get('/api/admin/languages');
      setLanguages(data.languages || []);
    } catch (err) {
      setStatus(err.message || t('Diller yüklenemedi.'));
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => { load(); }, [load]);

  const handleAdd = async (e) => {
    e.preventDefault();
    setStatus('');
    setAdding(true);
    try {
      await adminClient.post('/api/admin/languages', addForm);
      setAddForm({ code: '', name: '', native_name: '' });
      await load();
      await reloadI18nConfig();
      if (onChanged) onChanged();
    } catch (err) {
      setStatus(err.message || t('Dil eklenemedi.'));
    } finally {
      setAdding(false);
    }
  };

  const handleToggle = async (code, currentActive) => {
    setStatus('');
    try {
      await adminClient.put(`/api/admin/languages/${code}`, { is_active: !currentActive });
      await load();
      await reloadI18nConfig();
      if (onChanged) onChanged();
    } catch (err) {
      setStatus(err.message || t('Dil güncellenemedi.'));
    }
  };

  const handleDelete = async (code) => {
    if (!(await openConfirm({
      title: t('delete'),
      message: t('"{code}" dili ve tüm çevirileri silinsin mi?', { code }),
      confirmLabel: t('delete'),
      cancelLabel: t('close'),
      tone: 'error'
    }))) return;
    setStatus('');
    try {
      await adminClient.del(`/api/admin/languages/${code}`);
      await load();
      await reloadI18nConfig();
      if (onChanged) onChanged();
    } catch (err) {
      setStatus(err.message || t('Dil silinemedi.'));
    }
  };

  return (
    <div className="stack">
      <div className="panel">
        <div className="panel-header"><strong>{t('Dil Ekle')}</strong></div>
        <div className="panel-body">
          <form onSubmit={handleAdd} className="admin-inline-wrap admin-inline-wrap-end">
            <label className="admin-field-stack admin-field-compact">
              <span className="label-text">{t('Kod (ör. es)')}</span>
              <input
                className="input admin-input-code"
                value={addForm.code}
                onChange={(e) => setAddForm((f) => ({ ...f, code: e.target.value.toLowerCase().trim() }))}
                placeholder="es"
                maxLength={10}
                required
              />
            </label>
            <label className="admin-field-stack admin-field-grow">
              <span className="label-text">{t('Ad (İngilizce)')}</span>
              <input
                className="input"
                value={addForm.name}
                onChange={(e) => setAddForm((f) => ({ ...f, name: e.target.value }))}
                placeholder="Spanish"
                maxLength={100}
                required
              />
            </label>
            <label className="admin-field-stack admin-field-grow">
              <span className="label-text">{t('Yerel Ad')}</span>
              <input
                className="input"
                value={addForm.native_name}
                onChange={(e) => setAddForm((f) => ({ ...f, native_name: e.target.value }))}
                placeholder="Español"
                maxLength={100}
                required
              />
            </label>
            <button type="submit" className="btn btn-primary" disabled={adding}>
              {adding ? t('Ekleniyor...') : t('Dil Ekle')}
            </button>
          </form>
          {status ? <div className="muted admin-status-message is-error admin-preview-note">{status}</div> : null}
        </div>
      </div>

      <div className="panel">
        <div className="panel-header">
          <strong>{t('Diller')}</strong>
          <button className="btn btn-sm btn-secondary admin-inline-spacer" onClick={load} disabled={loading}>
            {loading ? t('loading') : t('Yenile')}
          </button>
        </div>
        <div className="panel-body">
          {languages.length === 0 && !loading && <div className="muted">{t('Dil bulunamadı.')}</div>}
          {languages.length > 0 && (
            <table className="data-table admin-table-full">
              <thead>
                <tr>
                  <th>{t('Kod')}</th>
                  <th>{t('Ad')}</th>
                  <th>{t('Yerel Ad')}</th>
                  <th>{t('Varsayılan')}</th>
                  <th>{t('Aktif')}</th>
                  <th>{t('İşlemler')}</th>
                </tr>
              </thead>
              <tbody>
                {languages.map((lang) => (
                  <tr key={lang.code}>
                    <td data-label={t('Kod')}><code>{lang.code}</code></td>
                    <td data-label={t('Ad')}>{lang.name}</td>
                    <td data-label={t('Yerel Ad')}>{lang.native_name}</td>
                    <td data-label={t('Varsayılan')}>{lang.is_default ? <span className="chip">{t('Varsayılan')}</span> : '—'}</td>
                    <td data-label={t('Aktif')}>
                      <button
                        className={`btn btn-sm ${lang.is_active ? 'btn-success' : 'btn-secondary'}`}
                        onClick={() => handleToggle(lang.code, lang.is_active)}
                        disabled={!!lang.is_default}
                        title={lang.is_default ? t('Varsayılan dil devre dışı bırakılamaz') : ''}
                      >
                        {lang.is_active ? t('Aktif') : t('Pasif')}
                      </button>
                    </td>
                    <td data-label={t('İşlemler')}>
                      {!lang.is_default && (
                        <button
                          className="btn btn-sm btn-danger"
                          onClick={() => handleDelete(lang.code)}
                        >
                          {t('delete')}
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── Strings Tab ──────────────────────────────────────────────────────────────

function StringsTab({ isAdmin, languages }) {
  const { t, reloadI18nConfig } = useI18n();
  const [filterLang, setFilterLang] = useState('');
  const [filterQ, setFilterQ] = useState('');
  const [strings, setStrings] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [status, setStatus] = useState('');
  const [editingId, setEditingId] = useState(null);
  const [editValue, setEditValue] = useState('');
  const [newKey, setNewKey] = useState({ key: '', lang: '', value: '' });
  const [addingKey, setAddingKey] = useState(false);
  const [importLang, setImportLang] = useState('');
  const [importText, setImportText] = useState('');
  const [importing, setImporting] = useState(false);
  const [fillingMissing, setFillingMissing] = useState(false);
  const LIMIT = 50;

  const loadStrings = useCallback(async (pg = 1) => {
    setLoading(true);
    setStatus('');
    try {
      const data = await adminClient.get(withQuery('/api/admin/language-strings', { lang: filterLang, q: filterQ, page: pg, limit: LIMIT }));
      setStrings(data.strings || []);
      setTotal(data.total || 0);
      setPage(pg);
    } catch (err) {
      setStatus(err.message || t('Çeviri dizeleri yüklenemedi.'));
    } finally {
      setLoading(false);
    }
  }, [filterLang, filterQ, t]);

  useEffect(() => { loadStrings(1); }, [loadStrings]);

  const handleSave = async (lang, key) => {
    setStatus('');
    try {
      await adminClient.put(`/api/admin/language-strings/${lang}/${encodeURIComponent(key)}`, { value: editValue });
      setEditingId(null);
      await loadStrings(page);
    } catch (err) {
      setStatus(err.message || t('Kaydetme başarısız.'));
    }
  };

  const handleDelete = async (lang, key) => {
    if (!(await openConfirm({
      title: t('delete'),
      message: t('"{lang}" dili için "{key}" dizesi silinsin mi?', { lang, key }),
      confirmLabel: t('delete'),
      cancelLabel: t('close'),
      tone: 'error'
    }))) return;
    setStatus('');
    try {
      await adminClient.del(`/api/admin/language-strings/${lang}/${encodeURIComponent(key)}`);
      await loadStrings(page);
    } catch (err) {
      setStatus(err.message || t('Silme başarısız.'));
    }
  };

  const handleAddKey = async (e) => {
    e.preventDefault();
    setStatus('');
    setAddingKey(true);
    try {
      await adminClient.put(`/api/admin/language-strings/${newKey.lang}/${encodeURIComponent(newKey.key)}`, { value: newKey.value });
      setNewKey({ key: '', lang: newKey.lang, value: '' });
      await loadStrings(1);
    } catch (err) {
      setStatus(err.message || t('Dize eklenemedi.'));
    } finally {
      setAddingKey(false);
    }
  };

  const handleImport = async (e) => {
    e.preventDefault();
    setStatus('');
    setImporting(true);
    try {
      let parsed;
      try {
        parsed = JSON.parse(importText);
      } catch {
        setStatus(t('Geçersiz JSON. Lütfen geçerli bir JSON nesnesi gir.'));
        return;
      }
      if (typeof parsed !== 'object' || Array.isArray(parsed)) {
        setStatus(t('JSON düz bir anahtar/değer nesnesi olmalı.'));
        return;
      }
      const result = await adminClient.post('/api/admin/language-strings/bulk', { lang: importLang, strings: parsed });
      setStatus(t('"{lang}" dili için {count} dize içe aktarıldı.', { lang: importLang, count: result.count }));
      setImportText('');
      await loadStrings(1);
    } catch (err) {
      setStatus(err.message || t('İçe aktarma başarısız.'));
    } finally {
      setImporting(false);
    }
  };

  const handleExport = async () => {
    if (!filterLang) {
      setStatus(t('Dışa aktarmak için bir dil seç.'));
      return;
    }
    setStatus('');
    try {
      const data = await adminClient.get(withQuery('/api/admin/language-strings', { lang: filterLang, limit: 2000 }));
      const obj = {};
      for (const s of (data.strings || [])) obj[s.key] = s.value;
      const blob = new Blob([JSON.stringify(obj, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `lang-${filterLang}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      setStatus(err.message || t('Dışa aktarma başarısız.'));
    }
  };

  const handleFillMissing = async () => {
    if (!filterLang || filterLang === 'tr') {
      setStatus(t('Boş dizeleri doldurmak için Türkçe dışı bir dil seç.'));
      return;
    }
    setStatus('');
    setFillingMissing(true);
    try {
      const result = await adminClient.post('/api/admin/language-strings/fill-missing', { lang: filterLang });
      await reloadI18nConfig();
      setStatus(t('"{lang}" dili için {filled}/{missing} boş dize dolduruldu.', {
        lang: filterLang,
        filled: result.filled || 0,
        missing: result.missing || 0
      }));
      await loadStrings(page);
    } catch (err) {
      setStatus(err.message || t('Boş dizeler doldurulamadı.'));
    } finally {
      setFillingMissing(false);
    }
  };

  const totalPages = Math.max(1, Math.ceil(total / LIMIT));

  return (
    <div className="stack">
      {/* Add new string */}
      <div className="panel">
        <div className="panel-header"><strong>{t('Çeviri Dizesi Ekle')}</strong></div>
        <div className="panel-body">
          <form onSubmit={handleAddKey} className="admin-inline-wrap admin-inline-wrap-end">
            <label className="admin-field-stack admin-field-compact">
              <span className="label-text">{t('Dil')}</span>
              <select
                className="input"
                value={newKey.lang}
                onChange={(e) => setNewKey((f) => ({ ...f, lang: e.target.value }))}
                required
              >
                <option value="">{t('Seç...')}</option>
                {languages.map((l) => (
                  <option key={l.code} value={l.code}>{l.name} ({l.code})</option>
                ))}
              </select>
            </label>
            <label className="admin-field-stack admin-field-grow">
              <span className="label-text">{t('Anahtar (ör. nav_home)')}</span>
              <input
                className="input"
                value={newKey.key}
                onChange={(e) => setNewKey((f) => ({ ...f, key: e.target.value.trim() }))}
                placeholder="nav_home"
                required
              />
            </label>
            <label className="admin-field-stack admin-field-grow-wide">
              <span className="label-text">{t('Değer')}</span>
              <input
                className="input"
                value={newKey.value}
                onChange={(e) => setNewKey((f) => ({ ...f, value: e.target.value }))}
                placeholder="Home"
                required
              />
            </label>
            <button type="submit" className="btn btn-primary" disabled={addingKey}>
              {addingKey ? t('Ekleniyor...') : t('Dize Ekle')}
            </button>
          </form>
        </div>
      </div>

      {/* Import / Export */}
      <div className="panel">
        <div className="panel-header"><strong>{t('JSON İçe / Dışa Aktar')}</strong></div>
        <div className="panel-body stack">
          <div className="admin-inline-wrap admin-inline-wrap-center">
            <select
              className="input admin-input-select"
              value={filterLang}
              onChange={(e) => setFilterLang(e.target.value)}
            >
              <option value="">{t('Tüm diller')}</option>
              {languages.map((l) => (
                <option key={l.code} value={l.code}>{l.name} ({l.code})</option>
              ))}
            </select>
            <button className="btn btn-secondary" onClick={handleExport} disabled={!filterLang}>
              {t('JSON olarak dışa aktar')} {filterLang ? `"${filterLang}"` : ''}
            </button>
            <button className="btn btn-secondary" onClick={handleFillMissing} disabled={fillingMissing || !filterLang || filterLang === 'tr'}>
              {fillingMissing ? t('Boş dizeler dolduruluyor...') : t('Boş dizeleri doldur')}
            </button>
          </div>
          <form onSubmit={handleImport} className="stack">
            <div className="admin-inline-wrap admin-inline-wrap-center">
              <label className="label-text">{t('Şu dile içe aktar:')}</label>
              <select
                className="input admin-input-select"
                value={importLang}
                onChange={(e) => setImportLang(e.target.value)}
                required
              >
                <option value="">{t('Seç...')}</option>
                {languages.map((l) => (
                  <option key={l.code} value={l.code}>{l.name} ({l.code})</option>
                ))}
              </select>
            </div>
            <textarea
              className="input admin-textarea-mono"
              rows={6}
              value={importText}
              onChange={(e) => setImportText(e.target.value)}
              placeholder={'{\n  "nav_home": "Home",\n  "nav_feed": "Feed"\n}'}
            />
            <div>
              <button type="submit" className="btn btn-primary" disabled={importing || !importLang}>
                {importing ? t('İçe aktarılıyor...') : t('JSON İçe Aktar')}
              </button>
            </div>
          </form>
          {status ? (
            <div className={`muted admin-status-message ${status.includes(t('içe aktarıldı')) || status.startsWith('Imported') ? 'is-success' : 'is-error'}`}>
              {status}
            </div>
          ) : null}
        </div>
      </div>

      {/* String list */}
      <div className="panel">
        <div className="panel-header">
          <strong>{t('Dizeler')}</strong>
          <span className="muted admin-preview-note">({total} {t('toplam')})</span>
          <button className="btn btn-sm btn-secondary admin-inline-spacer" onClick={() => loadStrings(page)} disabled={loading}>
            {loading ? t('loading') : t('Yenile')}
          </button>
        </div>
        <div className="panel-body stack">
          {/* Filters */}
          <div className="admin-inline-wrap">
            <select
              className="input admin-input-select"
              value={filterLang}
              onChange={(e) => { setFilterLang(e.target.value); setPage(1); }}
            >
              <option value="">{t('Tüm diller')}</option>
              {languages.map((l) => (
                <option key={l.code} value={l.code}>{l.name} ({l.code})</option>
              ))}
            </select>
            <input
              className="input admin-input-search"
              placeholder={t('Anahtar veya değer ara...')}
              value={filterQ}
              onChange={(e) => { setFilterQ(e.target.value); setPage(1); }}
            />
          </div>

          {strings.length === 0 && !loading && <div className="muted">{t('Dize bulunamadı.')}</div>}

          {strings.length > 0 && (
            <table className="data-table admin-table-full">
              <thead>
                <tr>
                  <th className="admin-table-col-xs">{t('Dil')}</th>
                  <th className="admin-table-col-lg">{t('Anahtar')}</th>
                  <th>{t('Değer')}</th>
                  <th className="admin-table-col-sm">{t('İşlemler')}</th>
                </tr>
              </thead>
              <tbody>
                {strings.map((s) => {
                  const rowId = `${s.lang_code}:${s.key}`;
                  const isEditing = editingId === rowId;
                  return (
                    <tr key={rowId}>
                      <td data-label={t('Dil')}><code>{s.lang_code}</code></td>
                      <td data-label={t('Anahtar')}><code className="admin-code-wrap">{s.key}</code></td>
                      <td data-label={t('Değer')}>
                        {isEditing ? (
                          <textarea
                            className="input admin-textarea-resizable"
                            rows={2}
                            value={editValue}
                            onChange={(e) => setEditValue(e.target.value)}
                            autoFocus
                          />
                        ) : (
                          <span className="admin-text-wrap">{s.value}</span>
                        )}
                      </td>
                      <td data-label={t('İşlemler')}>
                        {isEditing ? (
                          <div className="admin-actions-compact">
                            <button className="btn btn-sm btn-primary" onClick={() => handleSave(s.lang_code, s.key)}>{t('save')}</button>
                            <button className="btn btn-sm btn-secondary" onClick={() => setEditingId(null)}>{t('İptal')}</button>
                          </div>
                        ) : (
                          <div className="admin-actions-compact">
                            <button
                              className="btn btn-sm btn-secondary"
                              onClick={() => { setEditingId(rowId); setEditValue(s.value); }}
                            >
                              {t('edit')}
                            </button>
                            <button
                              className="btn btn-sm btn-danger"
                              onClick={() => handleDelete(s.lang_code, s.key)}
                            >
                              {t('delete')}
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="admin-inline-wrap admin-inline-wrap-center">
              <button className="btn btn-sm btn-secondary" disabled={page <= 1} onClick={() => loadStrings(page - 1)}>{t('Önceki')}</button>
              <span className="muted">{t('Sayfa')} {page} / {totalPages}</span>
              <button className="btn btn-sm btn-secondary" disabled={page >= totalPages} onClick={() => loadStrings(page + 1)}>{t('Sonraki')}</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
