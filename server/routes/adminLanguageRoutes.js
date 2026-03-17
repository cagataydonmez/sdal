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
