export function registerNetworkRequestRoutes(app, {
  requireAuth,
  connectionRequestRateLimit,
  mentorshipRequestRateLimit,
  ensureVerifiedSocialHubMember,
  ensureConnectionRequestsTable,
  ensureMentorshipRequestsTable,
  sqlGet,
  sqlRun,
  sqlGetAsync,
  sqlRunAsync,
  sqlAllAsync,
  sendApiError,
  calculateCooldownRemainingSeconds,
  connectionRequestCooldownSeconds,
  mentorshipRequestCooldownSeconds,
  addNotification,
  recordNetworkingTelemetryEvent,
  apiSuccessEnvelope,
  normalizeConnectionStatus,
  normalizeMentorshipStatus,
  clearExploreSuggestionsCache,
  scheduleEngagementRecalculation,
  invalidateFeedCache,
  buildNetworkInboxPayload
}) {
  app.post('/api/new/connections/request/:id', requireAuth, connectionRequestRateLimit, async (req, res) => {
    try {
      if (!ensureVerifiedSocialHubMember(req, res)) return;
      ensureConnectionRequestsTable();
      const senderId = Number(req.session?.userId || 0);
      const receiverId = Number(req.params.id || 0);
      if (!senderId || !receiverId) return sendApiError(res, 400, 'INVALID_USER_ID', 'Geçersiz kullanıcı kimliği.');
      if (senderId === receiverId) return sendApiError(res, 400, 'SELF_CONNECTION_NOT_ALLOWED', 'Kendine bağlantı isteği gönderemezsin.');

      const receiver = await sqlGetAsync('SELECT id FROM uyeler WHERE id = ?', [receiverId]);
      if (!receiver) return sendApiError(res, 404, 'MEMBER_NOT_FOUND', 'Üye bulunamadı.');

      const existingFollow = await sqlGetAsync('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [senderId, receiverId]);
      const reverseFollow = await sqlGetAsync('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [receiverId, senderId]);
      if (existingFollow && reverseFollow) {
        return sendApiError(res, 409, 'ALREADY_CONNECTED', 'Bu üye ile zaten bağlantısınız.');
      }

      const outgoingPending = await sqlGetAsync(
        `SELECT id
         FROM connection_requests
         WHERE sender_id = ?
           AND receiver_id = ?
           AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'
         ORDER BY COALESCE(CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) DESC, id DESC
         LIMIT 1`,
        [senderId, receiverId]
      );
      if (outgoingPending) {
        return sendApiError(res, 409, 'REQUEST_ALREADY_PENDING', 'Bu üyeye zaten bekleyen bir bağlantı isteği gönderdiniz.');
      }

      const incomingPending = await sqlGetAsync(
        `SELECT id
         FROM connection_requests
         WHERE sender_id = ?
           AND receiver_id = ?
           AND LOWER(TRIM(COALESCE(status, ''))) = 'pending'
         ORDER BY COALESCE(CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) DESC, id DESC
         LIMIT 1`,
        [receiverId, senderId]
      );
      if (incomingPending) {
        return sendApiError(res, 409, 'REQUEST_PENDING_FROM_TARGET', 'Bu üyeden bekleyen bir bağlantı isteğiniz var. Kabul edebilirsiniz.');
      }

      const latestOutgoing = await sqlGetAsync(
        `SELECT id, status, updated_at, responded_at
         FROM connection_requests
         WHERE sender_id = ? AND receiver_id = ?
         ORDER BY COALESCE(CASE WHEN CAST(updated_at AS TEXT) = '' THEN NULL ELSE updated_at END, created_at) DESC, id DESC
         LIMIT 1`,
        [senderId, receiverId]
      );
      const latestOutgoingStatus = String(latestOutgoing?.status || '').toLowerCase();
      if (latestOutgoing && latestOutgoingStatus === 'ignored') {
        const remainingSeconds = calculateCooldownRemainingSeconds(
          latestOutgoing.responded_at || latestOutgoing.updated_at,
          connectionRequestCooldownSeconds
        );
        if (remainingSeconds > 0) {
          res.setHeader('Retry-After', String(remainingSeconds));
          return sendApiError(
            res,
            429,
            'REQUEST_COOLDOWN_ACTIVE',
            'Bu üyeye tekrar bağlantı isteği göndermek için biraz beklemelisin.',
            { retry_after_seconds: remainingSeconds },
            { retry_after_seconds: remainingSeconds }
          );
        }
      }

      const now = new Date().toISOString();
      let requestId = 0;
      if (latestOutgoing) {
        await sqlRunAsync('UPDATE connection_requests SET status = ?, updated_at = ?, responded_at = NULL WHERE id = ?', ['pending', now, latestOutgoing.id]);
        requestId = Number(latestOutgoing.id || 0);
      } else {
        const result = await sqlRunAsync(
          'INSERT INTO connection_requests (sender_id, receiver_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
          [senderId, receiverId, 'pending', now, now]
        );
        requestId = Number(result?.lastInsertRowid || 0);
      }

      addNotification({
        userId: receiverId,
        type: 'connection_request',
        sourceUserId: senderId,
        entityId: requestId,
        message: 'Sana bir bağlantı isteği gönderdi.'
      });
      recordNetworkingTelemetryEvent({
        userId: senderId,
        eventName: 'connection_requested',
        sourceSurface: req.body?.source_surface,
        targetUserId: receiverId,
        entityType: 'connection_request',
        entityId: requestId
      });

      return res.json(apiSuccessEnvelope(
        'CONNECTION_REQUEST_CREATED',
        'Yeni bağlantı isteği gönderildi.',
        { status: 'pending', request_id: requestId },
        { status: 'pending', request_id: requestId }
      ));
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/connections/requests', requireAuth, async (req, res) => {
    ensureConnectionRequestsTable();
    const userId = Number(req.session?.userId || 0);
    const status = normalizeConnectionStatus(req.query.status) || 'pending';
    const direction = String(req.query.direction || 'incoming').trim().toLowerCase() === 'outgoing' ? 'outgoing' : 'incoming';
    const limit = Math.min(Math.max(parseInt(req.query.limit || '30', 10), 1), 100);
    const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

    const whereClause = direction === 'incoming' ? 'cr.receiver_id = ?' : 'cr.sender_id = ?';
    const joinClause = direction === 'incoming'
      ? 'LEFT JOIN uyeler u ON u.id = cr.sender_id'
      : 'LEFT JOIN uyeler u ON u.id = cr.receiver_id';

    try {
      const rows = await sqlAllAsync(
        `SELECT cr.id, cr.sender_id, cr.receiver_id, cr.status, cr.created_at, cr.updated_at, cr.responded_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM connection_requests cr
         ${joinClause}
         WHERE ${whereClause} AND cr.status = ?
         ORDER BY COALESCE(CASE WHEN CAST(cr.updated_at AS TEXT) = '' THEN NULL ELSE cr.updated_at END, cr.created_at) DESC, cr.id DESC
         LIMIT ? OFFSET ?`,
        [userId, status, limit, offset]
      );
      const payload = { items: rows, hasMore: rows.length === limit, direction, status };
      return res.json(apiSuccessEnvelope('CONNECTION_REQUESTS_LIST_OK', 'Bağlantı istekleri listelendi.', payload, payload));
    } catch (err) {
      console.error('connections.requests failed:', err);
      return sendApiError(res, 500, 'CONNECTION_REQUESTS_LIST_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/connections/accept/:id', requireAuth, async (req, res) => {
    try {
      ensureConnectionRequestsTable();
      const requestId = Number(req.params.id || 0);
      const currentUserId = Number(req.session?.userId || 0);
      if (!requestId || !currentUserId) return sendApiError(res, 400, 'INVALID_CONNECTION_REQUEST_ID', 'Geçersiz istek kimliği.');

      const row = await sqlGetAsync('SELECT id, sender_id, receiver_id, status FROM connection_requests WHERE id = ?', [requestId]);
      if (!row) return sendApiError(res, 404, 'CONNECTION_REQUEST_NOT_FOUND', 'Bağlantı isteği bulunamadı.');
      if (Number(row.receiver_id) !== currentUserId) return sendApiError(res, 403, 'CONNECTION_REQUEST_FORBIDDEN', 'Bu bağlantı isteğini yönetemezsiniz.');
      if (String(row.status || '').toLowerCase() !== 'pending') return sendApiError(res, 409, 'CONNECTION_REQUEST_NOT_PENDING', 'Bağlantı isteği artık beklemede değil.');

      const now = new Date().toISOString();
      await sqlRunAsync('UPDATE connection_requests SET status = ?, updated_at = ?, responded_at = ? WHERE id = ?', ['accepted', now, now, requestId]);

      const senderId = Number(row.sender_id);
      const receiverId = Number(row.receiver_id);

      const senderToReceiver = await sqlGetAsync('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [senderId, receiverId]);
      if (!senderToReceiver) {
        await sqlRunAsync('INSERT INTO follows (follower_id, following_id, created_at) VALUES (?, ?, ?)', [senderId, receiverId, now]);
      }
      const receiverToSender = await sqlGetAsync('SELECT id FROM follows WHERE follower_id = ? AND following_id = ?', [receiverId, senderId]);
      if (!receiverToSender) {
        await sqlRunAsync('INSERT INTO follows (follower_id, following_id, created_at) VALUES (?, ?, ?)', [receiverId, senderId, now]);
      }

      addNotification({
        userId: senderId,
        type: 'connection_accepted',
        sourceUserId: receiverId,
        entityId: requestId,
        message: 'Bağlantı isteğini kabul etti.'
      });
      recordNetworkingTelemetryEvent({
        userId: receiverId,
        eventName: 'connection_accepted',
        sourceSurface: req.body?.source_surface,
        targetUserId: senderId,
        entityType: 'connection_request',
        entityId: requestId
      });

      clearExploreSuggestionsCache();
      scheduleEngagementRecalculation('follow_changed');
      invalidateFeedCache();

      return res.json(apiSuccessEnvelope(
        'CONNECTION_REQUEST_ACCEPTED',
        'Bağlantı isteği kabul edildi.',
        { status: 'accepted', request_id: requestId },
        { status: 'accepted', request_id: requestId }
      ));
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/connections/ignore/:id', requireAuth, async (req, res) => {
    try {
      ensureConnectionRequestsTable();
      const requestId = Number(req.params.id || 0);
      const currentUserId = Number(req.session?.userId || 0);
      if (!requestId || !currentUserId) return sendApiError(res, 400, 'INVALID_CONNECTION_REQUEST_ID', 'Geçersiz istek kimliği.');

      const row = await sqlGetAsync('SELECT id, sender_id, receiver_id, status FROM connection_requests WHERE id = ?', [requestId]);
      if (!row) return sendApiError(res, 404, 'CONNECTION_REQUEST_NOT_FOUND', 'Bağlantı isteği bulunamadı.');
      if (Number(row.receiver_id) !== currentUserId) return sendApiError(res, 403, 'CONNECTION_REQUEST_FORBIDDEN', 'Bu bağlantı isteğini yönetemezsiniz.');
      if (String(row.status || '').toLowerCase() !== 'pending') return sendApiError(res, 409, 'CONNECTION_REQUEST_NOT_PENDING', 'Bağlantı isteği artık beklemede değil.');

      const now = new Date().toISOString();
      await sqlRunAsync('UPDATE connection_requests SET status = ?, updated_at = ?, responded_at = ? WHERE id = ?', ['ignored', now, now, requestId]);
      recordNetworkingTelemetryEvent({
        userId: currentUserId,
        eventName: 'connection_ignored',
        sourceSurface: req.body?.source_surface,
        targetUserId: Number(row.sender_id || 0),
        entityType: 'connection_request',
        entityId: requestId
      });
      return res.json(apiSuccessEnvelope(
        'CONNECTION_REQUEST_IGNORED',
        'Bağlantı isteği yok sayıldı.',
        { status: 'ignored', request_id: requestId },
        { status: 'ignored', request_id: requestId }
      ));
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/connections/cancel/:id', requireAuth, async (req, res) => {
    try {
      ensureConnectionRequestsTable();
      const requestId = Number(req.params.id || 0);
      const currentUserId = Number(req.session?.userId || 0);
      if (!requestId || !currentUserId) return sendApiError(res, 400, 'INVALID_CONNECTION_REQUEST_ID', 'Geçersiz istek kimliği.');

      const row = await sqlGetAsync('SELECT id, sender_id, receiver_id, status FROM connection_requests WHERE id = ?', [requestId]);
      if (!row) return sendApiError(res, 404, 'CONNECTION_REQUEST_NOT_FOUND', 'Bağlantı isteği bulunamadı.');
      if (Number(row.sender_id) !== currentUserId) return sendApiError(res, 403, 'CONNECTION_REQUEST_CANCEL_FORBIDDEN', 'Bu bağlantı isteğini geri çekemezsiniz.');
      if (String(row.status || '').toLowerCase() !== 'pending') return sendApiError(res, 409, 'CONNECTION_REQUEST_NOT_PENDING', 'Bağlantı isteği artık beklemede değil.');

      const now = new Date().toISOString();
      await sqlRunAsync('UPDATE connection_requests SET status = ?, updated_at = ?, responded_at = ? WHERE id = ?', ['cancelled', now, now, requestId]);
      recordNetworkingTelemetryEvent({
        userId: currentUserId,
        eventName: 'connection_cancelled',
        sourceSurface: req.body?.source_surface,
        targetUserId: Number(row.receiver_id || 0),
        entityType: 'connection_request',
        entityId: requestId
      });
      return res.json(apiSuccessEnvelope(
        'CONNECTION_REQUEST_CANCELLED',
        'Bağlantı isteği geri çekildi.',
        { status: 'cancelled', request_id: requestId },
        { status: 'cancelled', request_id: requestId }
      ));
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/mentorship/request/:id', requireAuth, mentorshipRequestRateLimit, async (req, res) => {
    try {
      if (!ensureVerifiedSocialHubMember(req, res)) return;
      ensureMentorshipRequestsTable();
      const requesterId = Number(req.session?.userId || 0);
      const mentorId = Number(req.params.id || 0);
      if (!requesterId || !mentorId) return sendApiError(res, 400, 'INVALID_USER_ID', 'Geçersiz kullanıcı kimliği.');
      if (requesterId === mentorId) return sendApiError(res, 400, 'SELF_MENTORSHIP_NOT_ALLOWED', 'Kendine mentorluk isteği gönderemezsin.');

      const mentor = await sqlGetAsync('SELECT id, mentor_opt_in FROM uyeler WHERE id = ?', [mentorId]);
      if (!mentor) return sendApiError(res, 404, 'MENTOR_NOT_FOUND', 'Mentor bulunamadı.');
      if (Number(mentor.mentor_opt_in || 0) !== 1) {
        return sendApiError(res, 409, 'MENTOR_NOT_AVAILABLE', 'Seçilen üye mentorluk taleplerini kabul etmiyor.');
      }

      const focusArea = String(req.body?.focus_area || '').trim().slice(0, 120);
      const message = String(req.body?.message || '').trim().slice(0, 2000);
      const now = new Date().toISOString();

      const existing = await sqlGetAsync(
        'SELECT id, status, updated_at, responded_at FROM mentorship_requests WHERE requester_id = ? AND mentor_id = ?',
        [requesterId, mentorId]
      );
      const existingStatus = String(existing?.status || '').toLowerCase();
      if (existing && existingStatus === 'requested') {
        return sendApiError(res, 409, 'REQUEST_ALREADY_PENDING', 'Bu mentor için zaten bekleyen bir talebin var.');
      }
      if (existing && existingStatus === 'accepted') {
        return sendApiError(res, 409, 'REQUEST_ALREADY_ACCEPTED', 'Bu mentor ile aktif bir mentorluk bağlantın var.');
      }
      if (existing && existingStatus === 'declined') {
        const remainingSeconds = calculateCooldownRemainingSeconds(
          existing.responded_at || existing.updated_at,
          mentorshipRequestCooldownSeconds
        );
        if (remainingSeconds > 0) {
          res.setHeader('Retry-After', String(remainingSeconds));
          return sendApiError(
            res,
            429,
            'MENTORSHIP_COOLDOWN_ACTIVE',
            'Aynı mentora tekrar istek göndermeden önce biraz beklemelisin.',
            { retry_after_seconds: remainingSeconds },
            { retry_after_seconds: remainingSeconds }
          );
        }
      }

      if (existing) {
        await sqlRunAsync(
          'UPDATE mentorship_requests SET status = ?, focus_area = ?, message = ?, updated_at = ?, responded_at = NULL WHERE id = ?',
          ['requested', focusArea, message, now, existing.id]
        );
      } else {
        await sqlRunAsync(
          `INSERT INTO mentorship_requests (requester_id, mentor_id, status, focus_area, message, created_at, updated_at)
           VALUES (?, ?, 'requested', ?, ?, ?, ?)`,
          [requesterId, mentorId, focusArea, message, now, now]
        );
      }

      const mentorshipRequestId = Number(existing?.id || (await sqlGetAsync(
        'SELECT id FROM mentorship_requests WHERE requester_id = ? AND mentor_id = ?',
        [requesterId, mentorId]
      ))?.id || 0);
      addNotification({
        userId: mentorId,
        type: 'mentorship_request',
        sourceUserId: requesterId,
        entityId: mentorshipRequestId,
        message: 'Sana bir mentorluk isteği gönderdi.'
      });
      recordNetworkingTelemetryEvent({
        userId: requesterId,
        eventName: 'mentorship_requested',
        sourceSurface: req.body?.source_surface,
        targetUserId: mentorId,
        entityType: 'mentorship_request',
        entityId: mentorshipRequestId,
        metadata: {
          focus_area: focusArea || '',
          has_message: message.length > 0
        }
      });

      return res.json(apiSuccessEnvelope(
        'MENTORSHIP_REQUEST_CREATED',
        'Mentorluk talebi gönderildi.',
        { status: 'requested' },
        { status: 'requested' }
      ));
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/mentorship/requests', requireAuth, async (req, res) => {
    ensureMentorshipRequestsTable();
    const userId = Number(req.session?.userId || 0);
    const status = normalizeMentorshipStatus(req.query.status) || 'requested';
    const direction = String(req.query.direction || 'incoming').trim().toLowerCase() === 'outgoing' ? 'outgoing' : 'incoming';
    const limit = Math.min(Math.max(parseInt(req.query.limit || '30', 10), 1), 100);
    const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

    const whereClause = direction === 'incoming' ? 'mr.mentor_id = ?' : 'mr.requester_id = ?';
    const joinClause = direction === 'incoming'
      ? 'LEFT JOIN uyeler u ON u.id = mr.requester_id'
      : 'LEFT JOIN uyeler u ON u.id = mr.mentor_id';

    try {
      const rows = await sqlAllAsync(
        `SELECT mr.id, mr.requester_id, mr.mentor_id, mr.status, mr.focus_area, mr.message, mr.created_at, mr.updated_at, mr.responded_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM mentorship_requests mr
         ${joinClause}
         WHERE ${whereClause} AND mr.status = ?
         ORDER BY COALESCE(CASE WHEN CAST(mr.updated_at AS TEXT) = '' THEN NULL ELSE mr.updated_at END, mr.created_at) DESC, mr.id DESC
         LIMIT ? OFFSET ?`,
        [userId, status, limit, offset]
      );
      const payload = { items: rows, hasMore: rows.length === limit, direction, status };
      return res.json(apiSuccessEnvelope('MENTORSHIP_REQUESTS_LIST_OK', 'Mentorluk talepleri listelendi.', payload, payload));
    } catch (err) {
      console.error('mentorship.requests failed:', err);
      return sendApiError(res, 500, 'MENTORSHIP_REQUESTS_LIST_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/mentorship/accept/:id', requireAuth, async (req, res) => {
    try {
      ensureMentorshipRequestsTable();
      const requestId = Number(req.params.id || 0);
      const currentUserId = Number(req.session?.userId || 0);
      if (!requestId || !currentUserId) return sendApiError(res, 400, 'INVALID_MENTORSHIP_REQUEST_ID', 'Geçersiz istek kimliği.');

      const row = await sqlGetAsync('SELECT id, requester_id, mentor_id, status FROM mentorship_requests WHERE id = ?', [requestId]);
      if (!row) return sendApiError(res, 404, 'MENTORSHIP_REQUEST_NOT_FOUND', 'Mentorluk isteği bulunamadı.');
      if (Number(row.mentor_id) !== currentUserId) return sendApiError(res, 403, 'MENTORSHIP_REQUEST_FORBIDDEN', 'Bu mentorluk isteğini yönetemezsiniz.');
      if (String(row.status || '').toLowerCase() !== 'requested') return sendApiError(res, 409, 'MENTORSHIP_REQUEST_NOT_PENDING', 'Mentorluk isteği artık beklemede değil.');

      const now = new Date().toISOString();
      await sqlRunAsync('UPDATE mentorship_requests SET status = ?, updated_at = ?, responded_at = ? WHERE id = ?', ['accepted', now, now, requestId]);

      addNotification({
        userId: Number(row.requester_id),
        type: 'mentorship_accepted',
        sourceUserId: currentUserId,
        entityId: requestId,
        message: 'Mentorluk isteğini kabul etti.'
      });
      recordNetworkingTelemetryEvent({
        userId: currentUserId,
        eventName: 'mentorship_accepted',
        sourceSurface: req.body?.source_surface,
        targetUserId: Number(row.requester_id || 0),
        entityType: 'mentorship_request',
        entityId: requestId
      });

      return res.json(apiSuccessEnvelope(
        'MENTORSHIP_REQUEST_ACCEPTED',
        'Mentorluk talebi kabul edildi.',
        { status: 'accepted', request_id: requestId },
        { status: 'accepted', request_id: requestId }
      ));
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/mentorship/decline/:id', requireAuth, async (req, res) => {
    try {
      ensureMentorshipRequestsTable();
      const requestId = Number(req.params.id || 0);
      const currentUserId = Number(req.session?.userId || 0);
      if (!requestId || !currentUserId) return sendApiError(res, 400, 'INVALID_MENTORSHIP_REQUEST_ID', 'Geçersiz istek kimliği.');

      const row = await sqlGetAsync('SELECT id, requester_id, mentor_id, status FROM mentorship_requests WHERE id = ?', [requestId]);
      if (!row) return sendApiError(res, 404, 'MENTORSHIP_REQUEST_NOT_FOUND', 'Mentorluk isteği bulunamadı.');
      if (Number(row.mentor_id) !== currentUserId) return sendApiError(res, 403, 'MENTORSHIP_REQUEST_FORBIDDEN', 'Bu mentorluk isteğini yönetemezsiniz.');
      if (String(row.status || '').toLowerCase() !== 'requested') return sendApiError(res, 409, 'MENTORSHIP_REQUEST_NOT_PENDING', 'Mentorluk isteği artık beklemede değil.');

      const now = new Date().toISOString();
      await sqlRunAsync('UPDATE mentorship_requests SET status = ?, updated_at = ?, responded_at = ? WHERE id = ?', ['declined', now, now, requestId]);
      recordNetworkingTelemetryEvent({
        userId: currentUserId,
        eventName: 'mentorship_declined',
        sourceSurface: req.body?.source_surface,
        targetUserId: Number(row.requester_id || 0),
        entityType: 'mentorship_request',
        entityId: requestId
      });
      return res.json(apiSuccessEnvelope(
        'MENTORSHIP_REQUEST_DECLINED',
        'Mentorluk talebi reddedildi.',
        { status: 'declined', request_id: requestId },
        { status: 'declined', request_id: requestId }
      ));
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/network/inbox', requireAuth, async (req, res) => {
    try {
      const userId = Number(req.session?.userId || 0);
      const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 50);
      const teacherLinkLimit = Math.min(Math.max(parseInt(req.query.teacher_limit || String(limit), 10), 1), 50);
      const inbox = await buildNetworkInboxPayload(userId, { limit, teacherLinkLimit });
      return res.json(apiSuccessEnvelope('NETWORK_INBOX_OK', 'Networking inbox hazır.', { inbox }, { inbox }));
    } catch (err) {
      console.error('network.inbox failed:', err);
      return sendApiError(res, 500, 'NETWORK_INBOX_FAILED', 'Beklenmeyen bir hata oluştu.');
    }
  });
}
