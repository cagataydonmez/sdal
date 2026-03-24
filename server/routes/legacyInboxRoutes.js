export function registerLegacyInboxRoutes(app, {
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  toNumericUserIdOrNull,
  sameUserId,
  normalizeUserId,
  toDbFlagForColumn,
  sanitizePlainUserText,
  formatUserText,
  notifyMentions,
  writeAppLog
}) {
  app.get('/api/new/messages/unread', async (req, res) => {
    const row = await sqlGetAsync(
      'SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE kime = ? AND aktifgelen = 1 AND yeni = 1',
      [req.session.userId]
    );
    res.json({ count: row?.cnt || 0 });
  });

  app.get('/api/messages', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const box = req.query.box === 'outbox' ? 'outbox' : 'inbox';
      const page = Math.max(parseInt(req.query.page || '1', 10), 1);
      const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '5', 10), 1), 50);
      const where = box === 'inbox'
        ? 'CAST(kime AS INTEGER) = CAST(? AS INTEGER) AND aktifgelen = 1'
        : 'CAST(kimden AS INTEGER) = CAST(? AS INTEGER) AND aktifgiden = 1';
      const totalRow = await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE ${where}`, [req.session.userId]);
      const total = totalRow ? totalRow.cnt : 0;
      const pages = Math.max(Math.ceil(total / pageSize), 1);
      const safePage = Math.min(page, pages);
      const offset = (safePage - 1) * pageSize;

      const rows = await sqlAllAsync(
        `SELECT g.*, u1.kadi AS kimden_kadi, u1.resim AS kimden_resim, u2.kadi AS kime_kadi, u2.resim AS kime_resim
         FROM gelenkutusu g
         LEFT JOIN uyeler u1 ON u1.id = g.kimden
         LEFT JOIN uyeler u2 ON u2.id = g.kime
         WHERE ${where}
         ORDER BY g.tarih DESC
         LIMIT ? OFFSET ?`,
        [req.session.userId, pageSize, offset]
      );

      return res.json({ rows, page: safePage, pages, total, box, pageSize });
    } catch (err) {
      console.error('messages.list failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/messages/recipients', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const q = String(req.query.q || '').trim().replace(/^@+/, '').replace(/'/g, '');
      const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 50);
      if (!q) return res.json({ items: [] });
      const term = `%${q}%`;
      const rows = await sqlAllAsync(
        `SELECT id, kadi, isim, soyisim, resim, verified
         FROM uyeler
         WHERE COALESCE(CAST(yasak AS INTEGER), 0) = 0
           AND (
             aktiv IS NULL
             OR CAST(aktiv AS INTEGER) = 1
             OR LOWER(CAST(aktiv AS TEXT)) IN ('true', 'evet')
           )
           AND (
             LOWER(kadi) LIKE LOWER(?)
             OR LOWER(isim) LIKE LOWER(?)
             OR LOWER(soyisim) LIKE LOWER(?)
             OR LOWER(email) LIKE LOWER(?)
           )
         ORDER BY kadi ASC
         LIMIT ?`,
        [term, term, term, term, limit]
      );
      return res.json({ items: rows });
    } catch (err) {
      console.error('messages.recipients failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/messages/:id', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const row = await sqlGetAsync('SELECT * FROM gelenkutusu WHERE id = ?', [req.params.id]);
      if (!row) return res.status(404).send('Mesaj bulunamadı');
      if (!sameUserId(row.kime, req.session.userId) && !sameUserId(row.kimden, req.session.userId)) {
        return res.status(403).send('Yetkisiz');
      }
      const [sender, receiver] = await Promise.all([
        sqlGetAsync('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [normalizeUserId(row.kimden)]),
        sqlGetAsync('SELECT id, kadi, resim FROM uyeler WHERE id = ?', [normalizeUserId(row.kime)])
      ]);

      if (sameUserId(row.kime, req.session.userId) && Number(row.yeni || 0) === 1) {
        await sqlRunAsync('UPDATE gelenkutusu SET yeni = 0 WHERE id = ?', [row.id]);
      }

      return res.json({ row, sender, receiver });
    } catch (err) {
      console.error('messages.detail failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/messages', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const { kime, konu, mesaj } = req.body || {};
      const recipientId = toNumericUserIdOrNull(kime);
      if (!recipientId) return res.status(400).send('Alıcı seçilmedi');
      const subject = (konu && String(konu).trim())
        ? sanitizePlainUserText(String(konu).trim(), 50)
        : 'Konusuz';
      const body = (mesaj && String(mesaj).trim()) ? formatUserText(String(mesaj)) : 'Sistem Bilgisi : [b]Boş Mesaj Gönderildi![/b]';
      const now = new Date().toISOString();

      const result = await sqlRunAsync(
        `INSERT INTO gelenkutusu (kime, kimden, aktifgelen, konu, mesaj, yeni, tarih, aktifgiden)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          recipientId,
          req.session.userId,
          toDbFlagForColumn('gelenkutusu', 'aktifgelen', true),
          subject,
          body,
          toDbFlagForColumn('gelenkutusu', 'yeni', true),
          now,
          toDbFlagForColumn('gelenkutusu', 'aktifgiden', true)
        ]
      );
      notifyMentions({
        text: req.body?.mesaj || '',
        sourceUserId: req.session.userId,
        entityId: result?.lastInsertRowid,
        type: 'mention_message',
        message: 'Mesajda senden bahsetti.',
        allowedUserIds: [recipientId]
      });

      return res.status(201).json({ ok: true });
    } catch (err) {
      writeAppLog('error', 'messages_create_failed', {
        userId: req.session?.userId || null,
        message: err?.message || 'unknown_error',
        stack: String(err?.stack || '').slice(0, 1000)
      });
      return res.status(500).send('Mesaj gönderilirken bir hata oluştu.');
    }
  });

  app.delete('/api/messages/:id', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const row = await sqlGetAsync('SELECT * FROM gelenkutusu WHERE id = ?', [req.params.id]);
      if (!row) return res.status(404).send('Mesaj bulunamadı');
      if (!sameUserId(row.kime, req.session.userId) && !sameUserId(row.kimden, req.session.userId)) {
        return res.status(403).send('Yetkisiz');
      }
      if (sameUserId(row.kime, req.session.userId)) {
        await sqlRunAsync('UPDATE gelenkutusu SET aktifgelen = ? WHERE id = ?', [toDbFlagForColumn('gelenkutusu', 'aktifgelen', false), row.id]);
      }
      if (sameUserId(row.kimden, req.session.userId)) {
        await sqlRunAsync('UPDATE gelenkutusu SET aktifgiden = ? WHERE id = ?', [toDbFlagForColumn('gelenkutusu', 'aktifgiden', false), row.id]);
      }
      return res.status(204).send();
    } catch (err) {
      writeAppLog('error', 'messages_delete_failed', {
        userId: req.session?.userId || null,
        messageId: req.params?.id || null,
        message: err?.message || 'unknown_error',
        stack: String(err?.stack || '').slice(0, 1000)
      });
      return res.status(500).send('Mesaj silinirken bir hata oluştu.');
    }
  });
}
