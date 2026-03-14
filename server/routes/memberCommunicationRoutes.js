import path from 'path';

export function registerMemberCommunicationRoutes(app, {
  requireAuth,
  sqlGet,
  sqlAll,
  sqlRun,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  ensureTeacherAlumniLinksTable,
  getCachedActiveMemberNameRows,
  buildMemberTrustBadges,
  toNumericUserIdOrNull,
  sameUserId,
  normalizeUserId,
  toDbFlagForColumn,
  sanitizePlainUserText,
  formatUserText,
  notifyMentions,
  writeAppLog,
  ensureMessengerThread,
  getMessengerThreadForUser,
  markMessengerMessagesDelivered,
  broadcastMessengerEvent,
  messengerSendIdempotency,
  albumUpload,
  processDiskImageUpload,
  loadMediaSettings,
  uploadImagePresets,
  getCurrentUser,
  addNotification
}) {
  const albumActiveExpr = "(COALESCE(CAST(aktif AS INTEGER), 0) = 1 OR LOWER(CAST(aktif AS TEXT)) IN ('true','evet','yes'))";
  const albumActiveValue = toDbFlagForColumn('album_foto', 'aktif', true);
  const isTruthyAlbumFlag = (value) => {
    if (value === true) return true;
    if (Number(value) === 1) return true;
    const raw = String(value || '').trim().toLowerCase();
    return raw === '1' || raw === 'true' || raw === 'evet' || raw === 'yes';
  };

  app.get('/api/members', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      ensureTeacherAlumniLinksTable();
      const page = Math.max(parseInt(req.query.page || '1', 10), 1);
      const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '10', 10), 1), 50);
      const term = req.query.term ? String(req.query.term).replace(/'/g, '') : '';
      const gradYear = parseInt(String(req.query.gradYear || '0'), 10) || 0;
      const location = req.query.location ? String(req.query.location).trim().toLowerCase() : '';
      const profession = req.query.profession ? String(req.query.profession).trim().toLowerCase() : '';
      const expertise = req.query.expertise ? String(req.query.expertise).trim().toLowerCase() : '';
      const title = req.query.title ? String(req.query.title).trim().toLowerCase() : '';
      const mentorsOnly = String(req.query.mentors || '').trim() === '1';
      const verifiedOnly = String(req.query.verified || '').trim() === '1';
      const withPhoto = String(req.query.withPhoto || '').trim() === '1';
      const onlineOnly = String(req.query.online || '').trim() === '1';
      const relation = String(req.query.relation || '').trim();
      const excludeSelf = String(req.query.excludeSelf || '').trim() === '1';
      const sort = String(req.query.sort || 'recommended').trim();
      const whereParts = [
        'COALESCE(CAST(aktiv AS INTEGER), 1) = 1',
        'COALESCE(CAST(yasak AS INTEGER), 0) = 0'
      ];
      const params = [];
      if (excludeSelf) {
        whereParts.push('id != ?');
        params.push(req.session.userId);
      }
      if (term) {
        whereParts.push('(LOWER(kadi) LIKE LOWER(?) OR LOWER(isim) LIKE LOWER(?) OR LOWER(soyisim) LIKE LOWER(?) OR LOWER(meslek) LIKE LOWER(?) OR LOWER(email) LIKE LOWER(?))');
        params.push(...Array(5).fill(`%${term}%`));
      }
      if (gradYear > 0) {
        whereParts.push('CAST(COALESCE(mezuniyetyili, 0) AS INTEGER) = ?');
        params.push(gradYear);
      }
      if (location) {
        whereParts.push('LOWER(sehir) LIKE ?');
        params.push(`%${location}%`);
      }
      if (profession) {
        whereParts.push('LOWER(meslek) LIKE ?');
        params.push(`%${profession}%`);
      }
      if (expertise) {
        whereParts.push('LOWER(uzmanlik) LIKE ?');
        params.push(`%${expertise}%`);
      }
      if (title) {
        whereParts.push('LOWER(unvan) LIKE ?');
        params.push(`%${title}%`);
      }
      if (mentorsOnly) {
        whereParts.push('COALESCE(CAST(mentor_opt_in AS INTEGER), 0) = 1');
      }
      if (verifiedOnly) {
        whereParts.push('COALESCE(CAST(verified AS INTEGER), 0) = 1');
      }
      if (withPhoto) {
        whereParts.push("resim IS NOT NULL AND TRIM(CAST(resim AS TEXT)) != '' AND LOWER(TRIM(CAST(resim AS TEXT))) != 'yok'");
      }
      if (onlineOnly) {
        whereParts.push('COALESCE(CAST(online AS INTEGER), 0) = 1');
      }
      if (relation === 'following') {
        whereParts.push('id IN (SELECT following_id FROM follows WHERE follower_id = ?)');
        params.push(req.session.userId);
      }
      if (relation === 'not_following') {
        whereParts.push('id NOT IN (SELECT following_id FROM follows WHERE follower_id = ?)');
        params.push(req.session.userId);
      }
      const where = whereParts.join(' AND ');
      const orderByMap = {
        name: 'u.isim ASC, u.soyisim ASC',
        recent: 'u.id DESC',
        online: 'COALESCE(CAST(u.online AS INTEGER), 0) DESC, u.isim ASC',
        year: 'CAST(COALESCE(u.mezuniyetyili, 0) AS INTEGER) DESC, u.isim ASC',
        engagement: 'COALESCE(es.score, 0) DESC, u.id DESC',
        recommended: 'COALESCE(es.score, 0) DESC, COALESCE(CAST(u.online AS INTEGER), 0) DESC, COALESCE(CAST(u.verified AS INTEGER), 0) DESC, u.id DESC'
      };
      const orderBy = orderByMap[sort] || orderByMap.name;

      const totalRow = await sqlGetAsync(`SELECT COUNT(*) AS cnt FROM uyeler WHERE ${where}`, params);
      const total = totalRow ? totalRow.cnt : 0;
      const pages = Math.max(Math.ceil(total / pageSize), 1);
      const safePage = Math.min(page, pages);
      const offset = (safePage - 1) * pageSize;
      const [rows, rangeRows] = await Promise.all([
        sqlAllAsync(
          `SELECT u.id, u.kadi, u.isim, u.soyisim, u.email, u.mailkapali, u.mezuniyetyili, u.dogumgun, u.dogumay, u.dogumyil,
                  u.sehir, u.universite, u.meslek, u.websitesi, u.imza, u.resim, u.online, u.sontarih, u.verified,
                  u.sirket, u.unvan, u.uzmanlik, u.linkedin_url, u.universite_bolum, u.mentor_opt_in, u.mentor_konulari,
                  u.role,
                  CASE WHEN EXISTS (
                    SELECT 1
                    FROM teacher_alumni_links tal
                    WHERE tal.teacher_user_id = u.id OR tal.alumni_user_id = u.id
                  ) THEN 1 ELSE 0 END AS teacher_network_member
           FROM uyeler u
           LEFT JOIN member_engagement_scores es ON es.user_id = u.id
           WHERE ${where}
           ORDER BY ${orderBy}
           LIMIT ? OFFSET ?`,
          [...params, pageSize, offset]
        ),
        term ? Promise.resolve([]) : getCachedActiveMemberNameRows()
      ]);

      const ranges = [];
      for (let i = 0; i < rangeRows.length; i += pageSize) {
        const start = rangeRows[i]?.isim ? rangeRows[i].isim.slice(0, 2) : '--';
        const end = rangeRows[Math.min(i + pageSize - 1, rangeRows.length - 1)]?.isim?.slice(0, 2) || '--';
        ranges.push({ start, end });
      }

      const rowsWithTrustBadges = rows.map((row) => ({
        ...row,
        trust_badges: buildMemberTrustBadges(row)
      }));

      return res.json({
        rows: rowsWithTrustBadges,
        page: safePage,
        pages,
        total,
        ranges,
        pageSize,
        term,
        filters: { gradYear, verifiedOnly, withPhoto, onlineOnly, relation, sort, mentorsOnly }
      });
    } catch (err) {
      console.error('members.list failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/members/:id', async (req, res) => {
    try {
      if (!req.session.userId) return res.status(401).send('Login required');
      const row = await sqlGetAsync(
        `SELECT id, kadi, isim, soyisim, email, mailkapali, mezuniyetyili, dogumgun, dogumay, dogumyil,
                sehir, universite, meslek, websitesi, imza, resim, online, sontarih,
                sirket, unvan, uzmanlik, linkedin_url, universite_bolum, mentor_opt_in, mentor_konulari
         FROM uyeler
         WHERE id = ?`,
        [req.params.id]
      );
      if (!row) return res.status(404).send('Üye bulunamadı');
      return res.json({ row });
    } catch (err) {
      console.error('members.detail failed:', err);
      return res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
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

  app.get('/api/sdal-messenger/contacts', requireAuth, (req, res) => {
    const q = String(req.query.q || '').trim().replace(/^@+/, '').replace(/'/g, '');
    const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 80);
    if (!q) return res.json({ items: [] });
    const term = `%${q}%`;
    const rows = sqlAll(
      `SELECT id, kadi, isim, soyisim, resim, verified
       FROM uyeler
       WHERE CAST(id AS INTEGER) <> CAST(? AS INTEGER)
         AND COALESCE(CAST(yasak AS INTEGER), 0) = 0
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
      [req.session.userId, term, term, term, term, limit]
    );
    res.json({ items: rows });
  });

  app.post('/api/sdal-messenger/threads', requireAuth, (req, res) => {
    const peerId = normalizeUserId(req.body?.userId);
    if (!peerId) return res.status(400).send('Kullanıcı seçilmedi.');
    if (sameUserId(peerId, req.session.userId)) return res.status(400).send('Kendinle mesajlaşamazsın.');
    const peer = sqlGet('SELECT id, kadi, isim, soyisim, resim, verified FROM uyeler WHERE id = ?', [peerId]);
    if (!peer) return res.status(404).send('Kullanıcı bulunamadı.');
    const thread = ensureMessengerThread(req.session.userId, peerId);
    if (!thread) return res.status(500).send('Sohbet oluşturulamadı.');
    res.status(201).json({ ok: true, threadId: thread.id });
  });

  app.get('/api/sdal-messenger/threads', requireAuth, (req, res) => {
    const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 100);
    const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
    const q = String(req.query.q || '').trim();
    const term = q ? `%${q.toLowerCase()}%` : null;
    const userId = req.session.userId;
    const deliveredNow = new Date().toISOString();
    sqlRun(
      `UPDATE sdal_messenger_messages
       SET delivered_at = COALESCE(delivered_at, ?)
       WHERE CAST(receiver_id AS INTEGER) = CAST(? AS INTEGER)
         AND delivered_at IS NULL
         AND COALESCE(CAST(deleted_by_receiver AS INTEGER), 0) = 0`,
      [deliveredNow, userId]
    );

    const filterParams = [];
    let filterSql = '';
    if (term) {
      filterSql = `
        AND (
          LOWER(COALESCE(u.kadi, '')) LIKE ?
          OR LOWER(COALESCE(u.isim, '')) LIKE ?
          OR LOWER(COALESCE(u.soyisim, '')) LIKE ?
        )
      `;
      filterParams.push(term, term, term);
    }
    const queryParams = [userId, userId, userId, userId, userId, userId, ...filterParams, limit, offset];

    const rows = sqlAll(
      `SELECT
         t.id,
         t.user_a_id,
         t.user_b_id,
         t.last_message_at,
         t.updated_at,
         u.id AS peer_id,
         u.kadi AS peer_kadi,
         u.isim AS peer_isim,
         u.soyisim AS peer_soyisim,
         u.resim AS peer_resim,
         u.verified AS peer_verified,
         lm.id AS last_message_id,
         lm.body AS last_message_body,
         lm.created_at AS last_message_created_at,
         lm.sender_id AS last_message_sender_id,
         lm.client_written_at AS last_message_client_written_at,
         lm.server_received_at AS last_message_server_received_at,
         lm.delivered_at AS last_message_delivered_at,
         lm.read_at AS last_message_read_at,
         (
           SELECT COUNT(*)
           FROM sdal_messenger_messages um
           WHERE um.thread_id = t.id
             AND CAST(um.receiver_id AS INTEGER) = CAST(? AS INTEGER)
             AND um.read_at IS NULL
             AND COALESCE(CAST(um.deleted_by_receiver AS INTEGER), 0) = 0
         ) AS unread_count
       FROM sdal_messenger_threads t
       LEFT JOIN uyeler u
         ON CAST(u.id AS INTEGER) = CASE
           WHEN CAST(t.user_a_id AS INTEGER) = CAST(? AS INTEGER) THEN CAST(t.user_b_id AS INTEGER)
           ELSE CAST(t.user_a_id AS INTEGER)
         END
       LEFT JOIN sdal_messenger_messages lm
         ON CAST(lm.id AS INTEGER) = (
           SELECT CAST(mm.id AS INTEGER)
           FROM sdal_messenger_messages mm
           WHERE CAST(mm.thread_id AS INTEGER) = CAST(t.id AS INTEGER)
             AND (
               (CAST(mm.sender_id AS INTEGER) = CAST(? AS INTEGER) AND COALESCE(CAST(mm.deleted_by_sender AS INTEGER), 0) = 0)
               OR
               (CAST(mm.receiver_id AS INTEGER) = CAST(? AS INTEGER) AND COALESCE(CAST(mm.deleted_by_receiver AS INTEGER), 0) = 0)
             )
           ORDER BY mm.created_at DESC, CAST(mm.id AS INTEGER) DESC
           LIMIT 1
         )
       WHERE (
         CAST(t.user_a_id AS INTEGER) = CAST(? AS INTEGER)
         OR CAST(t.user_b_id AS INTEGER) = CAST(? AS INTEGER)
       )
       ${filterSql}
       ORDER BY COALESCE(lm.created_at, t.last_message_at, t.updated_at, t.created_at) DESC
       LIMIT ? OFFSET ?`,
      queryParams
    );

    const items = rows.map((row) => ({
      id: row.id,
      peer: {
        id: row.peer_id,
        kadi: row.peer_kadi,
        isim: row.peer_isim,
        soyisim: row.peer_soyisim,
        resim: row.peer_resim,
        verified: Number(row.peer_verified || 0) === 1
      },
      lastMessage: row.last_message_id ? {
        id: row.last_message_id,
        body: row.last_message_body,
        createdAt: row.last_message_created_at,
        senderId: row.last_message_sender_id,
        clientWrittenAt: row.last_message_client_written_at,
        serverReceivedAt: row.last_message_server_received_at,
        deliveredAt: row.last_message_delivered_at,
        readAt: row.last_message_read_at
      } : null,
      unreadCount: Number(row.unread_count || 0)
    }));

    res.json({ items, limit, offset, hasMore: items.length === limit });
  });

  app.get('/api/sdal-messenger/threads/:id/messages', requireAuth, (req, res) => {
    const thread = getMessengerThreadForUser(req.params.id, req.session.userId);
    if (!thread) return res.status(404).send('Sohbet bulunamadı.');
    const delivered = markMessengerMessagesDelivered(thread.id, req.session.userId);
    if (delivered.changed > 0) {
      broadcastMessengerEvent([thread.user_a_id, thread.user_b_id], {
        type: 'messenger:delivered',
        threadId: Number(thread.id),
        byUserId: Number(req.session.userId),
        deliveredAt: delivered.deliveredAt
      });
    }
    const limit = Math.min(Math.max(parseInt(req.query.limit || '60', 10), 1), 120);
    const beforeId = parseInt(req.query.beforeId || '0', 10) || 0;
    const params = [thread.id, req.session.userId, req.session.userId];
    let beforeSql = '';
    if (beforeId > 0) {
      beforeSql = 'AND CAST(m.id AS INTEGER) < CAST(? AS INTEGER)';
      params.push(beforeId);
    }
    params.push(limit);

    const items = sqlAll(
      `SELECT
         m.id,
         m.thread_id AS threadId,
         m.sender_id AS senderId,
         m.receiver_id AS receiverId,
         CASE WHEN CAST(m.sender_id AS INTEGER) = CAST(? AS INTEGER) THEN 1 ELSE 0 END AS isMine,
         m.body,
         COALESCE(m.client_written_at, m.created_at) AS clientWrittenAt,
         COALESCE(m.server_received_at, m.created_at) AS serverReceivedAt,
         m.delivered_at AS deliveredAt,
         m.created_at AS createdAt,
         m.read_at AS readAt,
         u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM sdal_messenger_messages m
       LEFT JOIN uyeler u ON CAST(u.id AS INTEGER) = CAST(m.sender_id AS INTEGER)
       WHERE CAST(m.thread_id AS INTEGER) = CAST(? AS INTEGER)
         AND (
           (CAST(m.sender_id AS INTEGER) = CAST(? AS INTEGER) AND COALESCE(CAST(m.deleted_by_sender AS INTEGER), 0) = 0)
           OR
           (CAST(m.receiver_id AS INTEGER) = CAST(? AS INTEGER) AND COALESCE(CAST(m.deleted_by_receiver AS INTEGER), 0) = 0)
         )
         ${beforeSql}
       ORDER BY m.created_at DESC, CAST(m.id AS INTEGER) DESC
       LIMIT ?`,
      [req.session.userId, ...params]
    ).reverse();

    res.json({ items });
  });

  app.post('/api/sdal-messenger/threads/:id/messages', requireAuth, messengerSendIdempotency, (req, res) => {
    const thread = getMessengerThreadForUser(req.params.id, req.session.userId);
    if (!thread) return res.status(404).send('Sohbet bulunamadı.');
    const text = sanitizePlainUserText(String(req.body?.text || '').trim(), 4000);
    if (!text) return res.status(400).send('Mesaj boş olamaz.');
    const clientWrittenAtRaw = String(req.body?.clientWrittenAt || '').trim();
    const clientWrittenAt = clientWrittenAtRaw || null;
    const receiverId = sameUserId(thread.user_a_id, req.session.userId) ? thread.user_b_id : thread.user_a_id;
    const now = new Date().toISOString();
    const result = sqlRun(
      `INSERT INTO sdal_messenger_messages
        (thread_id, sender_id, receiver_id, body, client_written_at, server_received_at, delivered_at, created_at, read_at, deleted_by_sender, deleted_by_receiver)
       VALUES (?, ?, ?, ?, ?, ?, NULL, ?, NULL, ?, ?)`,
      [
        thread.id,
        req.session.userId,
        receiverId,
        text,
        clientWrittenAt,
        now,
        now,
        toDbFlagForColumn('sdal_messenger_messages', 'deleted_by_sender', false),
        toDbFlagForColumn('sdal_messenger_messages', 'deleted_by_receiver', false)
      ]
    );
    sqlRun(
      'UPDATE sdal_messenger_threads SET updated_at = ?, last_message_at = ? WHERE id = ?',
      [now, now, thread.id]
    );
    const id = result?.lastInsertRowid;
    const item = sqlGet(
      `SELECT
         m.id,
         m.thread_id AS threadId,
         m.sender_id AS senderId,
         m.receiver_id AS receiverId,
         CASE WHEN CAST(m.sender_id AS INTEGER) = CAST(? AS INTEGER) THEN 1 ELSE 0 END AS isMine,
         m.body,
         COALESCE(m.client_written_at, m.created_at) AS clientWrittenAt,
         COALESCE(m.server_received_at, m.created_at) AS serverReceivedAt,
         m.delivered_at AS deliveredAt,
         m.created_at AS createdAt,
         m.read_at AS readAt,
         u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM sdal_messenger_messages m
       LEFT JOIN uyeler u ON CAST(u.id AS INTEGER) = CAST(m.sender_id AS INTEGER)
       WHERE m.id = ?`,
      [req.session.userId, id]
    );
    if (item) {
      broadcastMessengerEvent([thread.user_a_id, thread.user_b_id], {
        type: 'messenger:new',
        threadId: Number(thread.id),
        item
      });
    }
    res.status(201).json({ ok: true, item });
  });

  app.post('/api/sdal-messenger/threads/:id/read', requireAuth, (req, res) => {
    const thread = getMessengerThreadForUser(req.params.id, req.session.userId);
    if (!thread) return res.status(404).send('Sohbet bulunamadı.');
    const now = new Date().toISOString();
    const result = sqlRun(
      `UPDATE sdal_messenger_messages
       SET read_at = ?,
           delivered_at = COALESCE(delivered_at, ?)
       WHERE CAST(thread_id AS INTEGER) = CAST(? AS INTEGER)
         AND CAST(receiver_id AS INTEGER) = CAST(? AS INTEGER)
         AND read_at IS NULL
         AND COALESCE(CAST(deleted_by_receiver AS INTEGER), 0) = 0`,
      [now, now, thread.id, req.session.userId]
    );
    if (Number(result?.changes || 0) > 0) {
      broadcastMessengerEvent([thread.user_a_id, thread.user_b_id], {
        type: 'messenger:read',
        threadId: Number(thread.id),
        byUserId: Number(req.session.userId),
        readAt: now
      });
    }
    res.json({ ok: true });
  });

  app.get('/api/albums', (req, res) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    const categories = sqlAll(`SELECT id, kategori, aciklama FROM album_kat WHERE ${albumActiveExpr} ORDER BY id`);
    const items = categories.map((cat) => {
      const countRow = sqlGet(`SELECT COUNT(*) AS cnt FROM album_foto WHERE ${albumActiveExpr} AND katid = ?`, [cat.id]);
      const previews = sqlAll(`SELECT dosyaadi FROM album_foto WHERE ${albumActiveExpr} AND katid = ? ORDER BY id DESC LIMIT 5`, [cat.id]);
      return { ...cat, count: countRow?.cnt || 0, previews: previews.map((p) => p.dosyaadi) };
    });
    res.json({ items });
  });

  app.get('/api/album/categories/active', (req, res) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    const categories = sqlAll(`SELECT id, kategori FROM album_kat WHERE ${albumActiveExpr} ORDER BY kategori`);
    res.json({ categories });
  });

  app.post('/api/album/upload', (req, res, next) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    return albumUpload.single('file')(req, res, (err) => {
      if (err) return next(err);
      next();
    });
  }, async (req, res) => {
    const kat = String(req.body?.kat || '').trim();
    const baslik = sanitizePlainUserText(String(req.body?.baslik || '').trim(), 255);
    const aciklama = formatUserText(req.body?.aciklama || '');

    if (!baslik) return res.status(400).send('Yüklemek üzere olduğun fotoğraf için bir başlık girmen gerekiyor.');
    if (!kat) return res.status(400).send('Kategori seçmelisin.');
    const category = sqlGet(`SELECT * FROM album_kat WHERE id = ? AND ${albumActiveExpr}`, [kat]);
    if (!category) return res.status(400).send('Seçtiğin kategori bulunamadı.');
    if (!req.file?.filename) return res.status(400).send('Geçerli bir resim dosyası girmedin.');

    const processed = await processDiskImageUpload({
      req,
      res,
      file: req.file,
      bucket: 'album_photo',
      preset: uploadImagePresets.albumPhoto
    });
    if (!processed.ok) return res.status(processed.statusCode).send(processed.message);

    const storedFilename = path.basename(processed.path || req.file.path);
    const mediaSettings = loadMediaSettings(sqlGet);
    const requireApproval = mediaSettings.albumUploadsRequireApproval === true;
    const initialActiveValue = requireApproval ? toDbFlagForColumn('album_foto', 'aktif', false) : albumActiveValue;

    sqlRun('UPDATE album_kat SET sonekleme = ?, sonekleyen = ? WHERE id = ?', [new Date().toISOString(), req.session.userId, category.id]);
    sqlRun(
      `INSERT INTO album_foto (dosyaadi, katid, baslik, aciklama, aktif, ekleyenid, tarih, hit)
       VALUES (?, ?, ?, ?, ?, ?, ?, 0)`,
      [storedFilename, String(category.id), baslik, aciklama, initialActiveValue, req.session.userId, new Date().toISOString()]
    );

    res.json({
      ok: true,
      file: storedFilename,
      categoryId: category.id,
      active: !requireApproval,
      requiresApproval: requireApproval
    });
  });

  app.get('/api/albums/:id', (req, res) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    const page = Math.max(parseInt(req.query.page || '1', 10), 1);
    const pageSize = Math.min(Math.max(parseInt(req.query.pageSize || '20', 10), 1), 50);
    const category = sqlGet(`SELECT id, kategori, aciklama FROM album_kat WHERE id = ? AND ${albumActiveExpr}`, [req.params.id]);
    if (!category) return res.status(404).send('Kategori bulunamadı');
    const totalRow = sqlGet(`SELECT COUNT(*) AS cnt FROM album_foto WHERE ${albumActiveExpr} AND katid = ?`, [req.params.id]);
    const total = totalRow?.cnt || 0;
    const pages = Math.max(Math.ceil(total / pageSize), 1);
    const safePage = Math.min(page, pages);
    const offset = (safePage - 1) * pageSize;
    const photos = sqlAll(`SELECT id, dosyaadi, baslik, tarih FROM album_foto WHERE ${albumActiveExpr} AND katid = ? ORDER BY tarih LIMIT ? OFFSET ?`, [req.params.id, pageSize, offset]);
    res.json({ category, photos, page: safePage, pages, total, pageSize });
  });

  app.get('/api/photos/:id', (req, res) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    const row = sqlGet(`SELECT id, katid, dosyaadi, baslik, aciklama, tarih FROM album_foto WHERE id = ? AND ${albumActiveExpr}`, [req.params.id]);
    if (!row) return res.status(404).send('Fotoğraf bulunamadı');
    const category = sqlGet('SELECT id, kategori FROM album_kat WHERE id = ?', [row.katid]);
    const comments = sqlAll(
      `SELECT c.id, c.uyeadi, c.yorum, c.tarih,
              u.id AS user_id, u.kadi, u.verified, u.resim, u.isim, u.soyisim
       FROM album_fotoyorum c
       LEFT JOIN uyeler u ON LOWER(u.kadi) = LOWER(c.uyeadi)
       WHERE c.fotoid = ?
       ORDER BY c.id DESC`,
      [row.id]
    );
    res.json({ row, category, comments });
  });

  app.get('/api/photos/:id/comments', (req, res) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    const comments = sqlAll(
      `SELECT c.id, c.uyeadi, c.yorum, c.tarih,
              u.id AS user_id, u.kadi, u.verified, u.resim, u.isim, u.soyisim
       FROM album_fotoyorum c
       LEFT JOIN uyeler u ON LOWER(u.kadi) = LOWER(c.uyeadi)
       WHERE c.fotoid = ?
       ORDER BY c.id DESC`,
      [req.params.id]
    );
    res.json({ comments });
  });

  app.post('/api/photos/:id/comments', (req, res) => {
    if (!req.session.userId) return res.status(401).send('Login required');
    const photo = sqlGet('SELECT id, ekleyenid, aktif FROM album_foto WHERE id = ?', [req.params.id]);
    if (!photo) return res.status(404).send('Fotoğraf bulunamadı');
    if (!isTruthyAlbumFlag(photo.aktif)) return res.status(400).send('Fotoğraf yoruma açık değil');
    const yorumRaw = String(req.body?.yorum || '');
    const yorum = formatUserText(yorumRaw);
    if (!yorum) return res.status(400).send('Yorum girmedin');
    const user = getCurrentUser(req);
    sqlRun('INSERT INTO album_fotoyorum (fotoid, uyeadi, yorum, tarih) VALUES (?, ?, ?, ?)', [
      photo.id,
      user?.kadi || 'Misafir',
      yorum,
      new Date().toISOString()
    ]);
    const ownerId = normalizeUserId(photo.ekleyenid);
    if (ownerId && !sameUserId(ownerId, req.session.userId)) {
      addNotification({
        userId: ownerId,
        type: 'photo_comment',
        sourceUserId: req.session.userId,
        entityId: photo.id,
        message: 'Fotoğrafına yorum yaptı.'
      });
    }
    notifyMentions({
      text: yorumRaw,
      sourceUserId: req.session.userId,
      entityId: photo.id,
      type: 'mention_photo',
      message: 'Fotoğraf yorumunda senden bahsetti.'
    });
    res.json({ ok: true });
  });
}
