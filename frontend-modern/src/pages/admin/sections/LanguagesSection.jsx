import React, { useCallback, useEffect, useRef, useState } from 'react';
import { adminClient, withQuery } from '../../../admin/api/adminClient.js';

const TABS = [
  { key: 'languages', label: 'Languages' },
  { key: 'strings', label: 'Translation Strings' }
];

export default function LanguagesSection({ isAdmin = false }) {
  const [tab, setTab] = useState('languages');

  return (
    <div className="stack">
      <div className="panel">
        <div className="panel-body">
          <div className="tabs-row" style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
            {TABS.map((t) => (
              <button
                key={t.key}
                className={`btn btn-sm ${tab === t.key ? 'btn-primary' : 'btn-secondary'}`}
                onClick={() => setTab(t.key)}
              >
                {t.label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {tab === 'languages' && <LanguagesTab isAdmin={isAdmin} />}
      {tab === 'strings' && <StringsTab isAdmin={isAdmin} />}
    </div>
  );
}

// ─── Languages Tab ────────────────────────────────────────────────────────────

function LanguagesTab({ isAdmin }) {
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
      setStatus(err.message || 'Failed to load languages.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleAdd = async (e) => {
    e.preventDefault();
    setStatus('');
    setAdding(true);
    try {
      await adminClient.post('/api/admin/languages', addForm);
      setAddForm({ code: '', name: '', native_name: '' });
      await load();
    } catch (err) {
      setStatus(err.message || 'Failed to add language.');
    } finally {
      setAdding(false);
    }
  };

  const handleToggle = async (code, currentActive) => {
    setStatus('');
    try {
      await adminClient.put(`/api/admin/languages/${code}`, { is_active: !currentActive });
      await load();
    } catch (err) {
      setStatus(err.message || 'Failed to update language.');
    }
  };

  const handleDelete = async (code) => {
    if (!window.confirm(`Delete language "${code}" and all its translations?`)) return;
    setStatus('');
    try {
      await adminClient.del(`/api/admin/languages/${code}`);
      await load();
    } catch (err) {
      setStatus(err.message || 'Failed to delete language.');
    }
  };

  return (
    <div className="stack">
      <div className="panel">
        <div className="panel-header"><strong>Add Language</strong></div>
        <div className="panel-body">
          <form onSubmit={handleAdd} style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', alignItems: 'flex-end' }}>
            <label style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '0 0 auto' }}>
              <span className="label-text">Code (e.g. es)</span>
              <input
                className="input"
                style={{ width: '80px' }}
                value={addForm.code}
                onChange={(e) => setAddForm((f) => ({ ...f, code: e.target.value.toLowerCase().trim() }))}
                placeholder="es"
                maxLength={10}
                required
              />
            </label>
            <label style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '1 1 160px' }}>
              <span className="label-text">Name (English)</span>
              <input
                className="input"
                value={addForm.name}
                onChange={(e) => setAddForm((f) => ({ ...f, name: e.target.value }))}
                placeholder="Spanish"
                maxLength={100}
                required
              />
            </label>
            <label style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '1 1 160px' }}>
              <span className="label-text">Native Name</span>
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
              {adding ? 'Adding...' : 'Add Language'}
            </button>
          </form>
          {status && <div className="muted" style={{ marginTop: '8px', color: 'var(--color-danger, red)' }}>{status}</div>}
        </div>
      </div>

      <div className="panel">
        <div className="panel-header">
          <strong>Languages</strong>
          <button className="btn btn-sm btn-secondary" onClick={load} disabled={loading} style={{ marginLeft: 'auto' }}>
            {loading ? 'Loading...' : 'Refresh'}
          </button>
        </div>
        <div className="panel-body">
          {languages.length === 0 && !loading && <div className="muted">No languages found.</div>}
          {languages.length > 0 && (
            <table className="data-table" style={{ width: '100%' }}>
              <thead>
                <tr>
                  <th>Code</th>
                  <th>Name</th>
                  <th>Native Name</th>
                  <th>Default</th>
                  <th>Active</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {languages.map((lang) => (
                  <tr key={lang.code}>
                    <td><code>{lang.code}</code></td>
                    <td>{lang.name}</td>
                    <td>{lang.native_name}</td>
                    <td>{lang.is_default ? <span className="chip">Default</span> : '—'}</td>
                    <td>
                      <button
                        className={`btn btn-sm ${lang.is_active ? 'btn-success' : 'btn-secondary'}`}
                        onClick={() => handleToggle(lang.code, lang.is_active)}
                        disabled={!!lang.is_default}
                        title={lang.is_default ? 'Cannot deactivate default language' : ''}
                      >
                        {lang.is_active ? 'Active' : 'Inactive'}
                      </button>
                    </td>
                    <td>
                      {!lang.is_default && (
                        <button
                          className="btn btn-sm btn-danger"
                          onClick={() => handleDelete(lang.code)}
                        >
                          Delete
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

function StringsTab({ isAdmin }) {
  const [languages, setLanguages] = useState([]);
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
  const LIMIT = 50;

  const loadLangs = useCallback(async () => {
    try {
      const data = await adminClient.get('/api/admin/languages');
      setLanguages(data.languages || []);
    } catch {}
  }, []);

  useEffect(() => { loadLangs(); }, [loadLangs]);

  const loadStrings = useCallback(async (pg = 1) => {
    setLoading(true);
    setStatus('');
    try {
      const data = await adminClient.get(withQuery('/api/admin/language-strings', { lang: filterLang, q: filterQ, page: pg, limit: LIMIT }));
      setStrings(data.strings || []);
      setTotal(data.total || 0);
      setPage(pg);
    } catch (err) {
      setStatus(err.message || 'Failed to load strings.');
    } finally {
      setLoading(false);
    }
  }, [filterLang, filterQ]);

  useEffect(() => { loadStrings(1); }, [loadStrings]);

  const handleSave = async (lang, key) => {
    setStatus('');
    try {
      await adminClient.put(`/api/admin/language-strings/${lang}/${encodeURIComponent(key)}`, { value: editValue });
      setEditingId(null);
      await loadStrings(page);
    } catch (err) {
      setStatus(err.message || 'Failed to save.');
    }
  };

  const handleDelete = async (lang, key) => {
    if (!window.confirm(`Delete string "${key}" for language "${lang}"?`)) return;
    setStatus('');
    try {
      await adminClient.del(`/api/admin/language-strings/${lang}/${encodeURIComponent(key)}`);
      await loadStrings(page);
    } catch (err) {
      setStatus(err.message || 'Failed to delete.');
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
      setStatus(err.message || 'Failed to add string.');
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
        setStatus('Invalid JSON. Please provide a valid JSON object.');
        return;
      }
      if (typeof parsed !== 'object' || Array.isArray(parsed)) {
        setStatus('JSON must be a flat key/value object.');
        return;
      }
      const result = await adminClient.post('/api/admin/language-strings/bulk', { lang: importLang, strings: parsed });
      setStatus(`Imported ${result.count} strings for "${importLang}".`);
      setImportText('');
      await loadStrings(1);
    } catch (err) {
      setStatus(err.message || 'Import failed.');
    } finally {
      setImporting(false);
    }
  };

  const handleExport = async () => {
    if (!filterLang) {
      setStatus('Select a language to export.');
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
      setStatus(err.message || 'Export failed.');
    }
  };

  const totalPages = Math.max(1, Math.ceil(total / LIMIT));

  return (
    <div className="stack">
      {/* Add new string */}
      <div className="panel">
        <div className="panel-header"><strong>Add Translation String</strong></div>
        <div className="panel-body">
          <form onSubmit={handleAddKey} style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', alignItems: 'flex-end' }}>
            <label style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '0 0 auto' }}>
              <span className="label-text">Language</span>
              <select
                className="input"
                value={newKey.lang}
                onChange={(e) => setNewKey((f) => ({ ...f, lang: e.target.value }))}
                required
              >
                <option value="">Select...</option>
                {languages.map((l) => (
                  <option key={l.code} value={l.code}>{l.name} ({l.code})</option>
                ))}
              </select>
            </label>
            <label style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '1 1 180px' }}>
              <span className="label-text">Key (e.g. nav_home)</span>
              <input
                className="input"
                value={newKey.key}
                onChange={(e) => setNewKey((f) => ({ ...f, key: e.target.value.trim() }))}
                placeholder="nav_home"
                required
              />
            </label>
            <label style={{ display: 'flex', flexDirection: 'column', gap: '4px', flex: '2 1 220px' }}>
              <span className="label-text">Value</span>
              <input
                className="input"
                value={newKey.value}
                onChange={(e) => setNewKey((f) => ({ ...f, value: e.target.value }))}
                placeholder="Home"
                required
              />
            </label>
            <button type="submit" className="btn btn-primary" disabled={addingKey}>
              {addingKey ? 'Adding...' : 'Add String'}
            </button>
          </form>
        </div>
      </div>

      {/* Import / Export */}
      <div className="panel">
        <div className="panel-header"><strong>Import / Export JSON</strong></div>
        <div className="panel-body stack">
          <div style={{ display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'wrap' }}>
            <select
              className="input"
              style={{ flex: '0 0 auto', width: '180px' }}
              value={filterLang}
              onChange={(e) => setFilterLang(e.target.value)}
            >
              <option value="">All languages</option>
              {languages.map((l) => (
                <option key={l.code} value={l.code}>{l.name} ({l.code})</option>
              ))}
            </select>
            <button className="btn btn-secondary" onClick={handleExport} disabled={!filterLang}>
              Export {filterLang ? `"${filterLang}"` : ''} as JSON
            </button>
          </div>
          <form onSubmit={handleImport} className="stack">
            <div style={{ display: 'flex', gap: '8px', alignItems: 'center', flexWrap: 'wrap' }}>
              <label className="label-text">Import into language:</label>
              <select
                className="input"
                style={{ flex: '0 0 auto', width: '180px' }}
                value={importLang}
                onChange={(e) => setImportLang(e.target.value)}
                required
              >
                <option value="">Select...</option>
                {languages.map((l) => (
                  <option key={l.code} value={l.code}>{l.name} ({l.code})</option>
                ))}
              </select>
            </div>
            <textarea
              className="input"
              rows={6}
              style={{ fontFamily: 'monospace', fontSize: '12px', width: '100%', boxSizing: 'border-box' }}
              value={importText}
              onChange={(e) => setImportText(e.target.value)}
              placeholder={'{\n  "nav_home": "Home",\n  "nav_feed": "Feed"\n}'}
            />
            <div>
              <button type="submit" className="btn btn-primary" disabled={importing || !importLang}>
                {importing ? 'Importing...' : 'Import JSON'}
              </button>
            </div>
          </form>
          {status && <div className="muted" style={{ color: status.startsWith('Imported') ? 'var(--color-success, green)' : 'var(--color-danger, red)' }}>{status}</div>}
        </div>
      </div>

      {/* String list */}
      <div className="panel">
        <div className="panel-header">
          <strong>Strings</strong>
          <span className="muted" style={{ marginLeft: '8px' }}>({total} total)</span>
          <button className="btn btn-sm btn-secondary" onClick={() => loadStrings(page)} disabled={loading} style={{ marginLeft: 'auto' }}>
            {loading ? 'Loading...' : 'Refresh'}
          </button>
        </div>
        <div className="panel-body stack">
          {/* Filters */}
          <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
            <select
              className="input"
              style={{ flex: '0 0 auto', width: '180px' }}
              value={filterLang}
              onChange={(e) => { setFilterLang(e.target.value); setPage(1); }}
            >
              <option value="">All languages</option>
              {languages.map((l) => (
                <option key={l.code} value={l.code}>{l.name} ({l.code})</option>
              ))}
            </select>
            <input
              className="input"
              style={{ flex: '1 1 200px' }}
              placeholder="Search key or value..."
              value={filterQ}
              onChange={(e) => { setFilterQ(e.target.value); setPage(1); }}
            />
          </div>

          {strings.length === 0 && !loading && <div className="muted">No strings found.</div>}

          {strings.length > 0 && (
            <table className="data-table" style={{ width: '100%' }}>
              <thead>
                <tr>
                  <th style={{ width: '80px' }}>Lang</th>
                  <th style={{ width: '220px' }}>Key</th>
                  <th>Value</th>
                  <th style={{ width: '120px' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {strings.map((s) => {
                  const rowId = `${s.lang_code}:${s.key}`;
                  const isEditing = editingId === rowId;
                  return (
                    <tr key={rowId}>
                      <td><code>{s.lang_code}</code></td>
                      <td><code style={{ fontSize: '12px', wordBreak: 'break-all' }}>{s.key}</code></td>
                      <td>
                        {isEditing ? (
                          <textarea
                            className="input"
                            rows={2}
                            style={{ width: '100%', boxSizing: 'border-box', resize: 'vertical' }}
                            value={editValue}
                            onChange={(e) => setEditValue(e.target.value)}
                            autoFocus
                          />
                        ) : (
                          <span style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>{s.value}</span>
                        )}
                      </td>
                      <td>
                        {isEditing ? (
                          <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap' }}>
                            <button className="btn btn-sm btn-primary" onClick={() => handleSave(s.lang_code, s.key)}>Save</button>
                            <button className="btn btn-sm btn-secondary" onClick={() => setEditingId(null)}>Cancel</button>
                          </div>
                        ) : (
                          <div style={{ display: 'flex', gap: '4px', flexWrap: 'wrap' }}>
                            <button
                              className="btn btn-sm btn-secondary"
                              onClick={() => { setEditingId(rowId); setEditValue(s.value); }}
                            >
                              Edit
                            </button>
                            <button
                              className="btn btn-sm btn-danger"
                              onClick={() => handleDelete(s.lang_code, s.key)}
                            >
                              Del
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
            <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
              <button className="btn btn-sm btn-secondary" disabled={page <= 1} onClick={() => loadStrings(page - 1)}>Previous</button>
              <span className="muted">Page {page} / {totalPages}</span>
              <button className="btn btn-sm btn-secondary" disabled={page >= totalPages} onClick={() => loadStrings(page + 1)}>Next</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
