export function registerMessengerRoutes(app, {
  requireAuth,
  sqlGetAsync,
  sqlAllAsync,
  sqlRunAsync,
  sameUserId,
  normalizeUserId,
  toDbFlagForColumn,
  sanitizePlainUserText,
  ensureMessengerThread,
  getMessengerThreadForUser,
  markMessengerMessagesDelivered,
  broadcastMessengerEvent,
  messengerSendIdempotency,
  addNotification
}) {
  app.get('/api/sdal-messenger/contacts', requireAuth, async (req, res) => {
    try {
      const q = String(req.query.q || '').trim().replace(/^@+/, '').replace(/'/g, '');
      const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 80);
      if (!q) return res.json({ items: [] });
      const term = `%${q}%`;
      const rows = await sqlAllAsync(
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/sdal-messenger/threads', requireAuth, async (req, res) => {
    try {
      const rawRecipientIds = Array.isArray(req.body?.recipientIds)
        ? req.body.recipientIds
        : [];
      const recipientIds = Array.from(new Set(rawRecipientIds
        .map((value) => normalizeUserId(value))
        .filter(Boolean)));
      const peerId = recipientIds.length > 0
        ? recipientIds[0]
        : normalizeUserId(req.body?.userId);
      if (recipientIds.length > 1) {
        return res.status(400).json({
          ok: false,
          code: 'group_threads_not_supported',
          message: 'Grup sohbetleri henüz desteklenmiyor.'
        });
      }
      if (!peerId) return res.status(400).send('Kullanıcı seçilmedi.');
      if (sameUserId(peerId, req.session.userId)) return res.status(400).send('Kendinle mesajlaşamazsın.');
      const peer = await sqlGetAsync('SELECT id, kadi, isim, soyisim, resim, verified FROM uyeler WHERE id = ?', [peerId]);
      if (!peer) return res.status(404).send('Kullanıcı bulunamadı.');
      const thread = ensureMessengerThread(req.session.userId, peerId);
      if (!thread) return res.status(500).send('Sohbet oluşturulamadı.');
      res.status(201).json({ ok: true, threadId: thread.id });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/sdal-messenger/threads', requireAuth, async (req, res) => {
    try {
      const limit = Math.min(Math.max(parseInt(req.query.limit || '40', 10), 1), 100);
      const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
      const q = String(req.query.q || '').trim();
      const term = q ? `%${q.toLowerCase()}%` : null;
      const userId = req.session.userId;
      const deliveredNow = new Date().toISOString();
      await sqlRunAsync(
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

      const rows = await sqlAllAsync(
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/sdal-messenger/threads/:id/messages', requireAuth, async (req, res) => {
    try {
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

      const items = (await sqlAllAsync(
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
      )).reverse();

      res.json({ items });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/sdal-messenger/threads/:id/messages', requireAuth, messengerSendIdempotency, async (req, res) => {
    try {
      const thread = getMessengerThreadForUser(req.params.id, req.session.userId);
      if (!thread) return res.status(404).send('Sohbet bulunamadı.');
      const text = sanitizePlainUserText(String(req.body?.text || '').trim(), 4000);
      if (!text) return res.status(400).send('Mesaj boş olamaz.');
      const clientWrittenAtRaw = String(req.body?.clientWrittenAt || '').trim();
      const clientWrittenAt = clientWrittenAtRaw || null;
      const receiverId = sameUserId(thread.user_a_id, req.session.userId) ? thread.user_b_id : thread.user_a_id;
      const now = new Date().toISOString();
      const result = await sqlRunAsync(
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
      await sqlRunAsync(
        'UPDATE sdal_messenger_threads SET updated_at = ?, last_message_at = ? WHERE id = ?',
        [now, now, thread.id]
      );
      const id = result?.lastInsertRowid;
      const item = await sqlGetAsync(
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
      if (receiverId && Number(receiverId) !== Number(req.session.userId)) {
        await Promise.resolve(addNotification?.({
          userId: receiverId,
          type: 'message',
          sourceUserId: req.session.userId,
          entityId: thread.id,
          message: text
        })).catch(() => null);
      }
      res.status(201).json({ ok: true, item });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/sdal-messenger/threads/:id/read', requireAuth, async (req, res) => {
    try {
      const thread = getMessengerThreadForUser(req.params.id, req.session.userId);
      if (!thread) return res.status(404).send('Sohbet bulunamadı.');
      const now = new Date().toISOString();
      const result = await sqlRunAsync(
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
