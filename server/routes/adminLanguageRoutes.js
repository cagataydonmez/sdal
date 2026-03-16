export function registerAdminLanguageRoutes(app, { requireAdmin, sqlGetAsync, sqlAllAsync, sqlRunAsync }) {

  // GET /api/admin/languages — list all languages
  app.get('/api/admin/languages', requireAdmin, async (req, res) => {
    try {
      const rows = await sqlAllAsync(
        'SELECT code, name, native_name, is_default, is_active, created_at FROM languages ORDER BY is_default DESC, code ASC',
        []
      );
      res.json({ languages: rows });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to load languages.' });
    }
  });

  // POST /api/admin/languages — add a new language
  app.post('/api/admin/languages', requireAdmin, async (req, res) => {
    try {
      const code = String(req.body.code || '').trim().toLowerCase().slice(0, 10);
      const name = String(req.body.name || '').trim().slice(0, 100);
      const nativeName = String(req.body.native_name || req.body.nativeName || '').trim().slice(0, 100);
      if (!code || !name || !nativeName) {
        return res.status(400).json({ error: 'code, name, and native_name are required.' });
      }
      const existing = await sqlGetAsync('SELECT code FROM languages WHERE code = $1', [code]);
      if (existing) return res.status(409).json({ error: 'Language code already exists.' });
      await sqlRunAsync(
        'INSERT INTO languages (code, name, native_name, is_default, is_active) VALUES ($1, $2, $3, FALSE, TRUE)',
        [code, name, nativeName]
      );
      res.json({ ok: true, code });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to add language.' });
    }
  });

  // PUT /api/admin/languages/:code — update language metadata or toggle active
  app.put('/api/admin/languages/:code', requireAdmin, async (req, res) => {
    try {
      const code = String(req.params.code || '').trim().toLowerCase();
      const lang = await sqlGetAsync('SELECT code, is_default FROM languages WHERE code = $1', [code]);
      if (!lang) return res.status(404).json({ error: 'Language not found.' });

      const fields = [];
      const values = [];

      if (req.body.name !== undefined) {
        fields.push(`name = $${values.length + 1}`);
        values.push(String(req.body.name).trim().slice(0, 100));
      }
      if (req.body.native_name !== undefined) {
        fields.push(`native_name = $${values.length + 1}`);
        values.push(String(req.body.native_name).trim().slice(0, 100));
      }
      if (req.body.is_active !== undefined) {
        if (lang.is_default && !req.body.is_active) {
          return res.status(400).json({ error: 'Cannot deactivate the default language.' });
        }
        fields.push(`is_active = $${values.length + 1}`);
        values.push(!!req.body.is_active);
      }

      if (!fields.length) return res.status(400).json({ error: 'No fields to update.' });
      values.push(code);
      await sqlRunAsync(`UPDATE languages SET ${fields.join(', ')} WHERE code = $${values.length}`, values);
      res.json({ ok: true });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to update language.' });
    }
  });

  // DELETE /api/admin/languages/:code — remove a language (and all its strings)
  app.delete('/api/admin/languages/:code', requireAdmin, async (req, res) => {
    try {
      const code = String(req.params.code || '').trim().toLowerCase();
      const lang = await sqlGetAsync('SELECT code, is_default FROM languages WHERE code = $1', [code]);
      if (!lang) return res.status(404).json({ error: 'Language not found.' });
      if (lang.is_default) return res.status(400).json({ error: 'Cannot delete the default language.' });
      await sqlRunAsync('DELETE FROM languages WHERE code = $1', [code]);
      res.json({ ok: true });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to delete language.' });
    }
  });

  // GET /api/admin/language-strings — list strings with filtering and pagination
  app.get('/api/admin/language-strings', requireAdmin, async (req, res) => {
    try {
      const lang = String(req.query.lang || '').trim().toLowerCase() || null;
      const q = String(req.query.q || '').trim();
      const limit = Math.min(Math.max(parseInt(req.query.limit || '50', 10), 1), 200);
      const page = Math.max(parseInt(req.query.page || '1', 10), 1);
      const offset = (page - 1) * limit;

      const conditions = [];
      const values = [];

      if (lang) {
        values.push(lang);
        conditions.push(`ls.lang_code = $${values.length}`);
      }
      if (q) {
        values.push(`%${q}%`);
        conditions.push(`(ls.key ILIKE $${values.length} OR ls.value ILIKE $${values.length})`);
      }

      const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

      const countRow = await sqlGetAsync(
        `SELECT COUNT(*) AS total FROM language_strings ls ${where}`,
        values
      );
      const total = Number(countRow?.total || 0);

      values.push(limit);
      values.push(offset);
      const rows = await sqlAllAsync(
        `SELECT ls.id, ls.lang_code, ls.key, ls.value, ls.updated_at
         FROM language_strings ls ${where}
         ORDER BY ls.key ASC, ls.lang_code ASC
         LIMIT $${values.length - 1} OFFSET $${values.length}`,
        values
      );

      res.json({ strings: rows, total, page, limit });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to load language strings.' });
    }
  });

  // GET /api/admin/language-strings/keys — list distinct keys (for key management)
  app.get('/api/admin/language-strings/keys', requireAdmin, async (req, res) => {
    try {
      const q = String(req.query.q || '').trim();
      const limit = Math.min(Math.max(parseInt(req.query.limit || '100', 10), 1), 500);
      const page = Math.max(parseInt(req.query.page || '1', 10), 1);
      const offset = (page - 1) * limit;

      const conditions = [];
      const values = [];
      if (q) {
        values.push(`%${q}%`);
        conditions.push(`key ILIKE $${values.length}`);
      }
      const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

      const countRow = await sqlGetAsync(
        `SELECT COUNT(DISTINCT key) AS total FROM language_strings ${where}`,
        values
      );
      const total = Number(countRow?.total || 0);

      values.push(limit);
      values.push(offset);
      const rows = await sqlAllAsync(
        `SELECT DISTINCT key FROM language_strings ${where} ORDER BY key ASC LIMIT $${values.length - 1} OFFSET $${values.length}`,
        values
      );

      res.json({ keys: rows.map((r) => r.key), total, page, limit });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to load keys.' });
    }
  });

  // PUT /api/admin/language-strings/:lang/:key — upsert a single string
  app.put('/api/admin/language-strings/:lang/:key', requireAdmin, async (req, res) => {
    try {
      const lang = String(req.params.lang || '').trim().toLowerCase();
      const key = String(req.params.key || '').trim();
      const value = String(req.body.value ?? '').trim();

      if (!lang || !key) return res.status(400).json({ error: 'lang and key are required.' });

      const langRow = await sqlGetAsync('SELECT code FROM languages WHERE code = $1', [lang]);
      if (!langRow) return res.status(404).json({ error: 'Language not found.' });

      await sqlRunAsync(
        `INSERT INTO language_strings (lang_code, key, value, updated_at)
         VALUES ($1, $2, $3, NOW())
         ON CONFLICT (lang_code, key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()`,
        [lang, key, value]
      );
      res.json({ ok: true });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to save string.' });
    }
  });

  // POST /api/admin/language-strings/bulk — bulk upsert strings for a language
  app.post('/api/admin/language-strings/bulk', requireAdmin, async (req, res) => {
    try {
      const lang = String(req.body.lang || '').trim().toLowerCase();
      const strings = req.body.strings;

      if (!lang) return res.status(400).json({ error: 'lang is required.' });
      if (!strings || typeof strings !== 'object' || Array.isArray(strings)) {
        return res.status(400).json({ error: 'strings must be a key/value object.' });
      }

      const langRow = await sqlGetAsync('SELECT code FROM languages WHERE code = $1', [lang]);
      if (!langRow) return res.status(404).json({ error: 'Language not found.' });

      const entries = Object.entries(strings);
      if (!entries.length) return res.json({ ok: true, count: 0 });

      // Upsert in batches
      let count = 0;
      for (const [key, value] of entries) {
        const k = String(key).trim();
        const v = String(value ?? '').trim();
        if (!k) continue;
        await sqlRunAsync(
          `INSERT INTO language_strings (lang_code, key, value, updated_at)
           VALUES ($1, $2, $3, NOW())
           ON CONFLICT (lang_code, key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()`,
          [lang, k, v]
        );
        count++;
      }
      res.json({ ok: true, count });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to import strings.' });
    }
  });

  // DELETE /api/admin/language-strings/:lang/:key — delete a single string
  app.delete('/api/admin/language-strings/:lang/:key', requireAdmin, async (req, res) => {
    try {
      const lang = String(req.params.lang || '').trim().toLowerCase();
      const key = String(req.params.key || '').trim();
      await sqlRunAsync('DELETE FROM language_strings WHERE lang_code = $1 AND key = $2', [lang, key]);
      res.json({ ok: true });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to delete string.' });
    }
  });

  // DELETE /api/admin/language-strings/key/:key — delete a key across all languages
  app.delete('/api/admin/language-strings/key/:key', requireAdmin, async (req, res) => {
    try {
      const key = String(req.params.key || '').trim();
      if (!key) return res.status(400).json({ error: 'key is required.' });
      await sqlRunAsync('DELETE FROM language_strings WHERE key = $1', [key]);
      res.json({ ok: true });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to delete key.' });
    }
  });

  // GET /api/admin/language-config — fetch language display/selection config
  app.get('/api/admin/language-config', requireAdmin, async (_req, res) => {
    try {
      const row = await sqlGetAsync('SELECT lang_selection_enabled, default_lang_open, default_lang_closed FROM language_config WHERE id = 1', []);
      if (!row) return res.json({ lang_selection_enabled: true, default_lang_open: 'tr', default_lang_closed: 'tr' });
      res.json({
        lang_selection_enabled: !!row.lang_selection_enabled,
        default_lang_open: row.default_lang_open || 'tr',
        default_lang_closed: row.default_lang_closed || 'tr'
      });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to load language config.' });
    }
  });

  // PUT /api/admin/language-config — save language display/selection config
  app.put('/api/admin/language-config', requireAdmin, async (req, res) => {
    try {
      const selectionEnabled = req.body.lang_selection_enabled !== undefined ? !!req.body.lang_selection_enabled : undefined;
      const defaultOpen = req.body.default_lang_open ? String(req.body.default_lang_open).trim().toLowerCase() : undefined;
      const defaultClosed = req.body.default_lang_closed ? String(req.body.default_lang_closed).trim().toLowerCase() : undefined;

      if (defaultOpen) {
        const langRow = await sqlGetAsync('SELECT code FROM languages WHERE code = $1', [defaultOpen]);
        if (!langRow) return res.status(400).json({ error: `Language "${defaultOpen}" not found.` });
      }
      if (defaultClosed) {
        const langRow = await sqlGetAsync('SELECT code FROM languages WHERE code = $1', [defaultClosed]);
        if (!langRow) return res.status(400).json({ error: `Language "${defaultClosed}" not found.` });
      }

      const current = await sqlGetAsync('SELECT lang_selection_enabled, default_lang_open, default_lang_closed FROM language_config WHERE id = 1', []);
      const nextEnabled = selectionEnabled !== undefined ? selectionEnabled : (current ? !!current.lang_selection_enabled : true);
      const nextOpen = defaultOpen || (current ? current.default_lang_open : 'tr');
      const nextClosed = defaultClosed || (current ? current.default_lang_closed : 'tr');

      await sqlRunAsync(
        `INSERT INTO language_config (id, lang_selection_enabled, default_lang_open, default_lang_closed, updated_at)
         VALUES (1, $1, $2, $3, NOW())
         ON CONFLICT (id) DO UPDATE SET lang_selection_enabled = EXCLUDED.lang_selection_enabled,
           default_lang_open = EXCLUDED.default_lang_open,
           default_lang_closed = EXCLUDED.default_lang_closed,
           updated_at = NOW()`,
        [nextEnabled, nextOpen, nextClosed]
      );
      res.json({ ok: true, lang_selection_enabled: nextEnabled, default_lang_open: nextOpen, default_lang_closed: nextClosed });
    } catch (err) {
      res.status(500).json({ error: err.message || 'Failed to save language config.' });
    }
  });
}
