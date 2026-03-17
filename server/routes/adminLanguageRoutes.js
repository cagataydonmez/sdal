import {
  addLanguage,
  bulkUpsertLanguageStrings,
  deleteLanguage,
  deleteLanguageKey,
  deleteLanguageString,
  getLanguageConfig,
  listLanguageStringKeys,
  listLanguageStrings,
  listLanguages,
  updateLanguage,
  updateLanguageConfig,
  upsertLanguageString
} from '../src/shared/languageCatalogStore.js';

async function translateText(text, target, source = 'tr') {
  const payload = String(text || '').trim();
  const targetLang = String(target || '').trim().toLowerCase();
  const sourceLang = String(source || 'auto').trim().toLowerCase();
  if (!payload) return '';
  const params = new URLSearchParams({
    client: 'gtx',
    sl: sourceLang || 'auto',
    tl: targetLang,
    dt: 't',
    q: payload.slice(0, 5000)
  });
  const response = await fetch(`https://translate.googleapis.com/translate_a/single?${params.toString()}`, {
    method: 'GET',
    headers: { 'User-Agent': 'SDAL-New/1.0' }
  });
  if (!response.ok) throw new Error('Translation service could not be reached.');
  const data = await response.json();
  const segments = Array.isArray(data?.[0]) ? data[0] : [];
  return segments.map((segment) => (Array.isArray(segment) ? String(segment[0] || '') : '')).join('').trim();
}

async function fillMissingStringsForLanguage(lang) {
  const targetLang = String(lang || '').trim().toLowerCase();
  if (!targetLang) throw new Error('lang is required.');
  if (targetLang === 'tr') return { ok: true, lang: 'tr', missing: 0, filled: 0, skipped: 0 };

  const [sourcePayload, targetPayload] = await Promise.all([
    listLanguageStrings({ lang: 'tr', page: 1, limit: 5000 }),
    listLanguageStrings({ lang: targetLang, page: 1, limit: 5000 })
  ]);
  const sourceStrings = Object.fromEntries((sourcePayload?.strings || []).map((row) => [row.key, row.value]));
  const targetStrings = Object.fromEntries((targetPayload?.strings || []).map((row) => [row.key, row.value]));
  const missingEntries = Object.entries(sourceStrings).filter(([key, value]) => (
    String(value || '').trim()
    && !String(targetStrings[key] || '').trim()
  ));

  if (!missingEntries.length) {
    return { ok: true, lang: targetLang, missing: 0, filled: 0, skipped: 0 };
  }

  const translations = {};
  let cursor = 0;
  const concurrency = 4;

  async function worker() {
    while (cursor < missingEntries.length) {
      const index = cursor++;
      const [key, value] = missingEntries[index];
      try {
        const translated = await translateText(value, targetLang, 'tr');
        if (translated) translations[key] = translated;
      } catch {
        // leave missing entries blank so the admin can retry later
      }
    }
  }

  await Promise.all(Array.from({ length: Math.min(concurrency, missingEntries.length) }, () => worker()));
  const filled = Object.keys(translations).length;
  if (filled > 0) {
    await bulkUpsertLanguageStrings(targetLang, translations);
  }
  return {
    ok: true,
    lang: targetLang,
    missing: missingEntries.length,
    filled,
    skipped: Math.max(missingEntries.length - filled, 0)
  };
}

export function registerAdminLanguageRoutes(app, { requireAdmin }) {

  // GET /api/admin/languages — list all languages
  app.get('/api/admin/languages', requireAdmin, async (req, res) => {
    try {
      res.json({ languages: await listLanguages() });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to load languages.' });
    }
  });

  // POST /api/admin/languages — add a new language
  app.post('/api/admin/languages', requireAdmin, async (req, res) => {
    try {
      res.json(await addLanguage(req.body || {}));
    } catch (err) {
      const status = err.message === 'Language code already exists.' || err.message === 'code, name, and native_name are required.' ? 400 : 500;
      res.status(status).json({ error: err.message || 'Failed to add language.' });
    }
  });

  // PUT /api/admin/languages/:code — update language metadata or toggle active
  app.put('/api/admin/languages/:code', requireAdmin, async (req, res) => {
    try {
      const updated = await updateLanguage(req.params.code, req.body || {});
      res.json({ ok: true, language: updated });
    } catch (err) {
      const status = err.message === 'Language not found.' ? 404 : err.message === 'Cannot deactivate the default language.' ? 400 : 500;
      res.status(status).json({ error: err.message || 'Failed to update language.' });
    }
  });

  // DELETE /api/admin/languages/:code — remove a language (and all its strings)
  app.delete('/api/admin/languages/:code', requireAdmin, async (req, res) => {
    try {
      res.json(await deleteLanguage(req.params.code));
    } catch (err) {
      const status = err.message === 'Language not found.' ? 404 : err.message === 'Cannot delete the default language.' ? 400 : 500;
      res.status(status).json({ error: err.message || 'Failed to delete language.' });
    }
  });

  // GET /api/admin/language-strings — list strings with filtering and pagination
  app.get('/api/admin/language-strings', requireAdmin, async (req, res) => {
    try {
      res.json(await listLanguageStrings(req.query || {}));
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to load language strings.' });
    }
  });

  // GET /api/admin/language-strings/keys — list distinct keys (for key management)
  app.get('/api/admin/language-strings/keys', requireAdmin, async (req, res) => {
    try {
      res.json(await listLanguageStringKeys(req.query || {}));
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to load keys.' });
    }
  });

  // PUT /api/admin/language-strings/:lang/:key — upsert a single string
  app.put('/api/admin/language-strings/:lang/:key', requireAdmin, async (req, res) => {
    try {
      res.json(await upsertLanguageString(req.params.lang, req.params.key, req.body?.value));
    } catch (err) {
      const status = err.message === 'lang and key are required.' ? 400 : err.message === 'Language not found.' ? 404 : 500;
      res.status(status).json({ error: err.message || 'Failed to save string.' });
    }
  });

  // POST /api/admin/language-strings/bulk — bulk upsert strings for a language
  app.post('/api/admin/language-strings/bulk', requireAdmin, async (req, res) => {
    try {
      res.json(await bulkUpsertLanguageStrings(req.body?.lang, req.body?.strings));
    } catch (err) {
      const status = err.message === 'lang is required.' || err.message === 'strings must be a key/value object.' ? 400 : err.message === 'Language not found.' ? 404 : 500;
      res.status(status).json({ error: err.message || 'Failed to import strings.' });
    }
  });

  app.post('/api/admin/language-strings/fill-missing', requireAdmin, async (req, res) => {
    try {
      res.json(await fillMissingStringsForLanguage(req.body?.lang));
    } catch (err) {
      const status = err.message === 'lang is required.' ? 400 : 500;
      res.status(status).json({ error: err.message || 'Failed to fill missing strings.' });
    }
  });

  // DELETE /api/admin/language-strings/:lang/:key — delete a single string
  app.delete('/api/admin/language-strings/:lang/:key', requireAdmin, async (req, res) => {
    try {
      res.json(await deleteLanguageString(req.params.lang, req.params.key));
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to delete string.' });
    }
  });

  // DELETE /api/admin/language-strings/key/:key — delete a key across all languages
  app.delete('/api/admin/language-strings/key/:key', requireAdmin, async (req, res) => {
    try {
      res.json(await deleteLanguageKey(req.params.key));
    } catch (err) {
      const status = err.message === 'key is required.' ? 400 : 500;
      res.status(status).json({ error: err.message || 'Failed to delete key.' });
    }
  });

  // GET /api/admin/language-config — fetch language display/selection config
  app.get('/api/admin/language-config', requireAdmin, async (_req, res) => {
    try {
      res.json(await getLanguageConfig());
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to load language config.' });
    }
  });

  // PUT /api/admin/language-config — save language display/selection config
  app.put('/api/admin/language-config', requireAdmin, async (req, res) => {
    try {
      res.json(await updateLanguageConfig(req.body || {}));
    } catch (err) {
      const status = /^Language ".+" not found\.$/.test(err.message || '') ? 400 : 500;
      res.status(status).json({ error: err.message || 'Failed to save language config.' });
    }
  });
}
