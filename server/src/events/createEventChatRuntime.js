export function createEventChatRuntime({
  sqlAll,
  sqlRunAsync,
  sanitizePlainUserText,
  sameUserId,
  getCurrentUser,
  hasAdminSession,
  getTableColumnSetAsync,
  formatUserText,
  toDbFlagForColumn,
  notifyMentions,
  getChatWss,
  getRealtimeBus
}) {
  function normalizeEventResponse(value) {
    const raw = String(value || '').trim().toLowerCase();
    if (['attend', 'joined', 'join', 'going', 'yes'].includes(raw)) return 'attend';
    if (['decline', 'declined', 'no', 'reject', 'not_going'].includes(raw)) return 'decline';
    return null;
  }

  function getEventResponseBundle(eventRow, viewerUserId, canSeePrivate = false) {
    const eventId = Number(eventRow?.id || 0);
    if (!eventId) {
      return {
        counts: { attend: 0, decline: 0 },
        myResponse: null,
        attendees: [],
        decliners: []
      };
    }
    const rows = sqlAll(
      `SELECT er.response, er.updated_at, er.user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM event_responses er
       LEFT JOIN uyeler u ON u.id = er.user_id
       WHERE er.event_id = ?`,
      [eventId]
    );
    const counts = { attend: 0, decline: 0 };
    const attendees = [];
    const decliners = [];
    let myResponse = null;

    for (const row of rows) {
      const response = normalizeEventResponse(row.response);
      if (!response) continue;
      counts[response] += 1;
      if (sameUserId(row.user_id, viewerUserId)) {
        myResponse = response;
      }
      const member = {
        user_id: row.user_id,
        kadi: row.kadi,
        isim: row.isim,
        soyisim: row.soyisim,
        resim: row.resim,
        verified: row.verified,
        updated_at: row.updated_at
      };
      if (response === 'attend') attendees.push(member);
      if (response === 'decline') decliners.push(member);
    }

    const showCounts = canSeePrivate || Number(eventRow?.show_response_counts ?? 1) === 1;
    const showAttendeeNames = canSeePrivate || Number(eventRow?.show_attendee_names ?? 0) === 1;
    const showDeclinerNames = canSeePrivate || Number(eventRow?.show_decliner_names ?? 0) === 1;

    return {
      counts: showCounts ? counts : null,
      myResponse,
      attendees: showAttendeeNames ? attendees : [],
      decliners: showDeclinerNames ? decliners : [],
      visibility: {
        showCounts: Number(eventRow?.show_response_counts ?? 1) === 1,
        showAttendeeNames: Number(eventRow?.show_attendee_names ?? 0) === 1,
        showDeclinerNames: Number(eventRow?.show_decliner_names ?? 0) === 1
      }
    };
  }

  async function createEventRecord(req, { image = null } = {}) {
    const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
    const descriptionRaw = String(req.body?.description ?? req.body?.body ?? '');
    const location = sanitizePlainUserText(String(req.body?.location || '').trim(), 180);
    const startsAt = String(req.body?.starts_at ?? req.body?.date ?? '');
    const endsAt = String(req.body?.ends_at || '');
    if (!title) return { error: 'Baslik gerekli.' };
    const user = getCurrentUser(req);
    const isAdmin = hasAdminSession(req, user);
    const now = new Date().toISOString();
    const eventCols = await getTableColumnSetAsync('events');
    const columns = [];
    const values = [];
    const addColumn = (column, value) => {
      if (!eventCols.has(String(column || '').toLowerCase())) return;
      columns.push(column);
      values.push(value);
    };

    addColumn('title', title);
    addColumn('description', formatUserText(descriptionRaw));
    addColumn('location', location);
    addColumn('starts_at', startsAt ? startsAt : null);
    addColumn('ends_at', endsAt ? endsAt : null);
    addColumn('image', image || null);
    addColumn('created_at', now);
    addColumn('created_by', req.session.userId);
    addColumn('approved', toDbFlagForColumn('events', 'approved', isAdmin));
    addColumn('approved_by', isAdmin ? req.session.userId : null);
    addColumn('approved_at', isAdmin ? now : null);
    addColumn('show_response_counts', toDbFlagForColumn('events', 'show_response_counts', true));
    addColumn('show_attendee_names', toDbFlagForColumn('events', 'show_attendee_names', false));
    addColumn('show_decliner_names', toDbFlagForColumn('events', 'show_decliner_names', false));

    if (!columns.length || !columns.includes('title')) {
      throw new Error('events_table_missing_required_columns');
    }
    const placeholders = columns.map(() => '?').join(', ');
    const result = await sqlRunAsync(
      `INSERT INTO events (${columns.join(', ')}) VALUES (${placeholders})`,
      values
    );
    notifyMentions({
      text: descriptionRaw,
      sourceUserId: req.session.userId,
      entityId: result?.lastInsertRowid,
      type: 'mention_event',
      message: 'Etkinlik aciklamasinda senden bahsetti.'
    });
    return { ok: true, pending: !isAdmin, id: result?.lastInsertRowid };
  }

  function broadcastChatEventLocal(payload) {
    try {
      const chatWss = getChatWss?.();
      if (!payload || !chatWss || !chatWss.clients) return;
      const outgoing = JSON.stringify(payload);
      chatWss.clients.forEach((client) => {
        if (client.readyState !== 1) return;
        if (!Number(client.sdalUserId || 0)) return;
        client.send(outgoing);
      });
    } catch {
      // ignore local broadcast errors
    }
  }

  function publishChatPayload(payload) {
    try {
      broadcastChatEventLocal(payload);
      Promise.resolve(getRealtimeBus?.()?.publishChat?.(payload)).catch(() => {});
    } catch {
      // ignore broadcast errors
    }
  }

  function broadcastChatMessage(item) {
    if (!item) return;
    publishChatPayload({
      type: 'chat:new',
      id: item.id,
      user_id: item.user_id,
      message: item.message,
      created_at: item.created_at,
      user: {
        id: item.user_id,
        kadi: item.kadi,
        isim: item.isim,
        soyisim: item.soyisim,
        resim: item.resim,
        verified: item.verified
      }
    });
  }

  function broadcastChatUpdate(item) {
    if (!item) return;
    publishChatPayload({
      type: 'chat:updated',
      id: item.id,
      user_id: item.user_id,
      message: item.message,
      created_at: item.created_at,
      user: {
        id: item.user_id,
        kadi: item.kadi,
        isim: item.isim,
        soyisim: item.soyisim,
        resim: item.resim,
        verified: item.verified
      }
    });
  }

  function broadcastChatDelete(messageId) {
    if (!messageId) return;
    publishChatPayload({
      type: 'chat:deleted',
      id: Number(messageId)
    });
  }

  function canManageChatMessage(req, messageRow) {
    if (!messageRow) return false;
    if (sameUserId(messageRow.user_id, req.session.userId)) return true;
    const currentUser = getCurrentUser(req);
    return hasAdminSession(req, currentUser);
  }

  return {
    normalizeEventResponse,
    getEventResponseBundle,
    createEventRecord,
    broadcastChatMessage,
    broadcastChatUpdate,
    broadcastChatDelete,
    broadcastChatEventLocal,
    canManageChatMessage
  };
}
