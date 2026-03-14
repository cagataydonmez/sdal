export function registerGroupRoutes(app, {
  requireAuth,
  sqlGetAsync,
  sqlGet,
  sqlAll,
  sqlRun,
  listOnlineMembersAsync,
  writeAppLog,
  getCurrentUser,
  hasAdminRole,
  hasAdminSession,
  normalizeGroupVisibility,
  sanitizePlainUserText,
  formatUserText,
  isFormattedContentEmpty,
  notifyMentions,
  getGroupMember,
  isGroupManager,
  addNotification,
  sameUserId,
  parseGroupVisibilityInput,
  uploadRateLimit,
  groupUpload,
  postUpload,
  processDiskImageUpload,
  uploadImagePresets
}) {
  app.get('/api/new/messages/unread', requireAuth, async (req, res) => {
    const row = await sqlGetAsync(
      'SELECT COUNT(*) AS cnt FROM gelenkutusu WHERE kime = ? AND aktifgelen = 1 AND yeni = 1',
      [req.session.userId]
    );
    res.json({ count: row?.cnt || 0 });
  });

  app.get('/api/new/online-members', requireAuth, async (req, res) => {
    try {
      const limit = Math.min(Math.max(parseInt(req.query.limit || '12', 10), 1), 80);
      const items = await listOnlineMembersAsync({
        limit,
        excludeUserId: String(req.query.excludeSelf || '1') === '1' ? req.session.userId : null
      });
      res.setHeader('Cache-Control', 'no-store');
      res.json({ items, count: items.length, now: new Date().toISOString() });
    } catch (err) {
      console.error('GET /api/new/online-members failed:', err);
      writeAppLog('error', 'online_members_failed', {
        message: err?.message || 'unknown_error',
        stack: String(err?.stack || '').slice(0, 1000)
      });
      res.setHeader('Cache-Control', 'no-store');
      res.json({ items: [], count: 0, now: new Date().toISOString(), degraded: true });
    }
  });

  app.get('/api/new/groups', requireAuth, (req, res) => {
    const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 100);
    const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
    const cursor = Math.max(parseInt(req.query.cursor || '0', 10), 0);
    const whereParts = [];
    const whereParams = [];
    if (cursor > 0) {
      whereParts.push('id < ?');
      whereParams.push(cursor);
    }
    const whereSql = whereParts.length ? `WHERE ${whereParts.join(' AND ')}` : '';
    const groups = sqlAll(
      `SELECT *
       FROM groups
       ${whereSql}
       ORDER BY id DESC
       LIMIT ? OFFSET ?`,
      [...whereParams, limit + 1, cursor > 0 ? 0 : offset]
    );
    const memberCounts = sqlAll('SELECT group_id, COUNT(*) AS cnt FROM group_members GROUP BY group_id');
    const membership = sqlAll('SELECT group_id, role FROM group_members WHERE user_id = ?', [req.session.userId]);
    const pending = sqlAll(
      `SELECT group_id
       FROM group_join_requests
       WHERE user_id = ? AND status = 'pending'`,
      [req.session.userId]
    );
    const invites = sqlAll(
      `SELECT group_id
       FROM group_invites
       WHERE invited_user_id = ? AND status = 'pending'`,
      [req.session.userId]
    );
    const user = getCurrentUser(req);
    const isAdmin = hasAdminRole(user);
    const countMap = new Map(memberCounts.map((c) => [c.group_id, c.cnt]));
    const memberMap = new Map(membership.map((m) => [m.group_id, m.role]));
    const pendingSet = new Set(pending.map((p) => p.group_id));
    const inviteSet = new Set(invites.map((v) => v.group_id));
    const slice = groups.slice(0, limit);
    res.json({
      items: slice.map((g) => ({
        ...g,
        visibility: normalizeGroupVisibility(g.visibility),
        show_contact_hint: Number(g.show_contact_hint || 0),
        members: countMap.get(g.id) || 0,
        joined: memberMap.has(g.id),
        pending: pendingSet.has(g.id),
        invited: inviteSet.has(g.id),
        myRole: memberMap.get(g.id) || null,
        membershipStatus: memberMap.has(g.id) ? 'member' : (inviteSet.has(g.id) ? 'invited' : (pendingSet.has(g.id) ? 'pending' : 'none'))
      })),
      hasMore: groups.length > limit
    });
  });

  app.post('/api/new/groups', requireAuth, (req, res) => {
    const name = sanitizePlainUserText(String(req.body?.name || '').trim(), 120);
    if (!name) return res.status(400).send('Grup adı gerekli.');
    const description = formatUserText(req.body?.description || '');
    const now = new Date().toISOString();
    const result = sqlRun('INSERT INTO groups (name, description, cover_image, owner_id, created_at, visibility) VALUES (?, ?, ?, ?, ?, ?)', [
      name,
      description,
      req.body?.cover_image || null,
      req.session.userId,
      now,
      'public'
    ]);
    const groupId = result?.lastInsertRowid;
    sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
      groupId,
      req.session.userId,
      'owner',
      now
    ]);
    notifyMentions({
      text: description,
      sourceUserId: req.session.userId,
      entityId: groupId,
      type: 'mention_group',
      message: 'Yeni grup açıklamasında senden bahsetti.'
    });
    res.json({ ok: true, id: groupId });
  });

  app.post('/api/new/groups/:id/join', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const group = sqlGet('SELECT id, name, visibility FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    const pendingInvite = sqlGet(
      `SELECT id
       FROM group_invites
       WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
      [groupId, req.session.userId]
    );

    const existingMember = getGroupMember(groupId, req.session.userId);
    if (existingMember) {
      if (existingMember.role === 'owner') return res.status(400).send('Grup sahibi gruptan ayrılamaz.');
      sqlRun('DELETE FROM group_members WHERE group_id = ? AND user_id = ?', [groupId, req.session.userId]);
      return res.json({ ok: true, joined: false, pending: false, membershipStatus: 'none' });
    }

    if (pendingInvite) {
      sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
        groupId,
        req.session.userId,
        'member',
        new Date().toISOString()
      ]);
      sqlRun('UPDATE group_invites SET status = ?, responded_at = ? WHERE id = ?', ['accepted', new Date().toISOString(), pendingInvite.id]);
      sqlRun('DELETE FROM group_join_requests WHERE group_id = ? AND user_id = ? AND status = ?', [groupId, req.session.userId, 'pending']);
      return res.json({ ok: true, joined: true, pending: false, invited: false, membershipStatus: 'member' });
    }

    const existingRequest = sqlGet(
      `SELECT id
       FROM group_join_requests
       WHERE group_id = ? AND user_id = ? AND status = 'pending'`,
      [groupId, req.session.userId]
    );
    if (existingRequest) {
      sqlRun('DELETE FROM group_join_requests WHERE id = ?', [existingRequest.id]);
      return res.json({ ok: true, joined: false, pending: false, invited: false, membershipStatus: 'none' });
    }

    sqlRun(
      `INSERT INTO group_join_requests (group_id, user_id, status, created_at)
       VALUES (?, ?, 'pending', ?)`,
      [groupId, req.session.userId, new Date().toISOString()]
    );

    const managers = sqlAll(
      `SELECT user_id
       FROM group_members
       WHERE group_id = ? AND role IN ('owner', 'moderator')`,
      [groupId]
    );
    for (const manager of managers) {
      if (Number(manager.user_id) === Number(req.session.userId)) continue;
      addNotification({
        userId: Number(manager.user_id),
        type: 'group_join_request',
        sourceUserId: req.session.userId,
        entityId: Number(groupId),
        message: `${group.name} grubuna katılım isteği gönderdi.`
      });
    }

    return res.json({ ok: true, joined: false, pending: true, invited: false, membershipStatus: 'pending' });
  });

  app.get('/api/new/groups/:id/requests', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
    const rows = sqlAll(
      `SELECT r.id, r.group_id, r.user_id, r.status, r.created_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM group_join_requests r
       LEFT JOIN uyeler u ON u.id = r.user_id
       WHERE r.group_id = ? AND r.status = 'pending'
       ORDER BY r.id DESC`,
      [groupId]
    );
    return res.json({ items: rows });
  });

  app.post('/api/new/groups/:id/requests/:requestId', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const requestId = req.params.requestId;
    const action = String(req.body?.action || '').toLowerCase();
    if (!['approve', 'reject'].includes(action)) return res.status(400).send('Geçersiz işlem.');
    const group = sqlGet('SELECT id, name FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');

    const requestRow = sqlGet(
      `SELECT id, user_id, status
       FROM group_join_requests
       WHERE id = ? AND group_id = ?`,
      [requestId, groupId]
    );
    if (!requestRow) return res.status(404).send('Katılım isteği bulunamadı.');
    if (requestRow.status !== 'pending') return res.status(400).send('İstek zaten sonuçlandırılmış.');

    if (action === 'approve') {
      const alreadyMember = getGroupMember(groupId, requestRow.user_id);
      if (!alreadyMember) {
        sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
          groupId,
          requestRow.user_id,
          'member',
          new Date().toISOString()
        ]);
      }
    }

    sqlRun(
      `UPDATE group_join_requests
       SET status = ?, reviewed_at = ?, reviewed_by = ?
       WHERE id = ?`,
      [action === 'approve' ? 'approved' : 'rejected', new Date().toISOString(), req.session.userId, requestId]
    );

    addNotification({
      userId: Number(requestRow.user_id),
      type: action === 'approve' ? 'group_join_approved' : 'group_join_rejected',
      sourceUserId: req.session.userId,
      entityId: Number(groupId),
      message: action === 'approve'
        ? `${group.name} grubuna katılım isteğin onaylandı.`
        : `${group.name} grubuna katılım isteğin reddedildi.`
    });

    return res.json({ ok: true, status: action === 'approve' ? 'approved' : 'rejected' });
  });

  app.get('/api/new/groups/:id/invitations', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
    const rows = sqlAll(
      `SELECT i.id, i.group_id, i.invited_user_id, i.invited_by, i.status, i.created_at, i.responded_at,
              u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM group_invites i
       LEFT JOIN uyeler u ON u.id = i.invited_user_id
       WHERE i.group_id = ? AND i.status = 'pending'
       ORDER BY i.id DESC`,
      [groupId]
    );
    return res.json({ items: rows });
  });

  app.post('/api/new/groups/:id/invitations', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const group = sqlGet('SELECT id, name FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
    const idsRaw = Array.isArray(req.body?.userIds) ? req.body.userIds : [];
    const userIds = Array.from(new Set(idsRaw.map((v) => Number(v)).filter((v) => Number.isFinite(v) && v > 0)));
    if (!userIds.length) return res.status(400).send('En az bir üye seçmelisin.');
    let sent = 0;
    for (const userId of userIds) {
      if (sameUserId(userId, req.session.userId)) continue;
      const alreadyMember = getGroupMember(groupId, userId);
      if (alreadyMember) continue;
      const existingPending = sqlGet(
        `SELECT id
         FROM group_invites
         WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
        [groupId, userId]
      );
      if (existingPending) continue;
      sqlRun(
        `INSERT INTO group_invites (group_id, invited_user_id, invited_by, status, created_at)
         VALUES (?, ?, ?, 'pending', ?)`,
        [groupId, userId, req.session.userId, new Date().toISOString()]
      );
      addNotification({
        userId,
        type: 'group_invite',
        sourceUserId: req.session.userId,
        entityId: Number(groupId),
        message: `${group.name} grubuna davet edildin.`
      });
      sent += 1;
    }
    return res.json({ ok: true, sent });
  });

  app.post('/api/new/groups/:id/invitations/respond', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const action = String(req.body?.action || '').toLowerCase();
    if (!['accept', 'reject'].includes(action)) return res.status(400).send('Geçersiz işlem.');
    const invite = sqlGet(
      `SELECT id, invited_user_id, invited_by, status
       FROM group_invites
       WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
      [groupId, req.session.userId]
    );
    if (!invite) return res.status(404).send('Bekleyen davet bulunamadı.');
    const group = sqlGet('SELECT id, name FROM groups WHERE id = ?', [groupId]);

    if (action === 'accept') {
      const alreadyMember = getGroupMember(groupId, req.session.userId);
      if (!alreadyMember) {
        sqlRun('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
          groupId,
          req.session.userId,
          'member',
          new Date().toISOString()
        ]);
      }
    }

    sqlRun('UPDATE group_invites SET status = ?, responded_at = ? WHERE id = ?', [
      action === 'accept' ? 'accepted' : 'rejected',
      new Date().toISOString(),
      invite.id
    ]);

    if (Number(invite.invited_by || 0) > 0 && !sameUserId(invite.invited_by, req.session.userId)) {
      addNotification({
        userId: invite.invited_by,
        type: action === 'accept' ? 'group_invite_accepted' : 'group_invite_rejected',
        sourceUserId: req.session.userId,
        entityId: Number(groupId || 0),
        message: action === 'accept'
          ? `${group?.name || 'Grup'} davetini kabul etti.`
          : `${group?.name || 'Grup'} davetini reddetti.`
      });
    }

    return res.json({ ok: true, status: action === 'accept' ? 'accepted' : 'rejected' });
  });

  app.post('/api/new/groups/:id/settings', requireAuth, (req, res) => {
    const groupId = req.params.id;
    if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
    const hasVisibility = typeof req.body?.visibility !== 'undefined';
    const hasShowHint = typeof req.body?.showContactHint !== 'undefined';
    if (!hasVisibility && !hasShowHint) return res.status(400).send('Ayar verisi bulunamadı.');

    let visibility = null;
    if (hasVisibility) {
      visibility = parseGroupVisibilityInput(req.body?.visibility);
      if (!visibility) return res.status(400).send('Geçersiz görünürlük.');
    }
    const showContactHint = hasShowHint && req.body?.showContactHint ? 1 : 0;

    if (hasVisibility && hasShowHint) {
      sqlRun('UPDATE groups SET visibility = ?, show_contact_hint = ? WHERE id = ?', [visibility, showContactHint, groupId]);
    } else if (hasVisibility) {
      sqlRun('UPDATE groups SET visibility = ? WHERE id = ?', [visibility, groupId]);
    } else {
      sqlRun('UPDATE groups SET show_contact_hint = ? WHERE id = ?', [showContactHint, groupId]);
    }

    const row = sqlGet('SELECT visibility, show_contact_hint FROM groups WHERE id = ?', [groupId]);
    return res.json({
      ok: true,
      visibility: normalizeGroupVisibility(row?.visibility),
      showContactHint: Number(row?.show_contact_hint || 0) === 1
    });
  });

  app.post('/api/new/groups/:id/cover', requireAuth, uploadRateLimit, groupUpload.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).send('Görsel seçilmedi.');
    const group = sqlGet('SELECT * FROM groups WHERE id = ?', [req.params.id]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    if (!isGroupManager(req, req.params.id)) {
      return res.status(403).send('Yetki yok.');
    }
    const processed = await processDiskImageUpload({
      req,
      res,
      file: req.file,
      bucket: 'group_cover',
      preset: uploadImagePresets.groupCover
    });
    if (!processed.ok) return res.status(processed.statusCode).send(processed.message);
    const image = processed.url || `/uploads/groups/${req.file.filename}`;
    sqlRun('UPDATE groups SET cover_image = ? WHERE id = ?', [image, req.params.id]);
    res.json({ ok: true, image });
  });

  app.post('/api/new/groups/:id/role', requireAuth, (req, res) => {
    const group = sqlGet('SELECT * FROM groups WHERE id = ?', [req.params.id]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    const member = sqlGet('SELECT role FROM group_members WHERE group_id = ? AND user_id = ?', [req.params.id, req.session.userId]);
    const user = getCurrentUser(req);
    const isAdmin = hasAdminSession(req, user);
    if (!isAdmin && (!member || member.role !== 'owner')) {
      return res.status(403).send('Yetki yok.');
    }
    const targetId = req.body?.userId;
    const role = req.body?.role;
    if (!targetId || !['member', 'moderator', 'owner'].includes(role)) {
      return res.status(400).send('Geçersiz rol.');
    }
    const targetMember = sqlGet('SELECT id FROM group_members WHERE group_id = ? AND user_id = ?', [req.params.id, targetId]);
    if (!targetMember) return res.status(404).send('Üye bulunamadı.');
    sqlRun('UPDATE group_members SET role = ? WHERE group_id = ? AND user_id = ?', [role, req.params.id, targetId]);
    if (!sameUserId(targetId, req.session.userId)) {
      addNotification({
        userId: targetId,
        type: 'group_role_changed',
        sourceUserId: req.session.userId,
        entityId: Number(req.params.id || 0),
        message: `${group.name || 'Grup'} grubundaki rolün ${role} olarak güncellendi.`
      });
    }
    res.json({ ok: true });
  });

  app.get('/api/new/groups/:id', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const group = sqlGet('SELECT * FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    const user = getCurrentUser(req);
    const isAdmin = hasAdminRole(user);
    const member = getGroupMember(groupId, req.session.userId);
    const invite = sqlGet(
      `SELECT id, status
       FROM group_invites
       WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
      [groupId, req.session.userId]
    );
    const pending = sqlGet(
      `SELECT id
       FROM group_join_requests
       WHERE group_id = ? AND user_id = ? AND status = 'pending'`,
      [groupId, req.session.userId]
    );
    const membersOnly = normalizeGroupVisibility(group.visibility) === 'members_only';
    const groupManagers = sqlAll(
      `SELECT m.user_id AS id, m.role, u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM group_members m
       LEFT JOIN uyeler u ON u.id = m.user_id
       WHERE m.group_id = ? AND m.role IN ('owner', 'moderator')
       ORDER BY CASE WHEN m.role = 'owner' THEN 0 ELSE 1 END, m.id ASC`,
      [groupId]
    );
    const showContactHint = Number(group.show_contact_hint || 0) === 1;

    if (membersOnly && !isAdmin && !member) {
      const memberCount = sqlGet('SELECT COUNT(*) AS cnt FROM group_members WHERE group_id = ?', [groupId])?.cnt || 0;
      return res.status(403).json({
        message: 'Bu grup özel. İçerikleri görmek için owner/moderatör onayı ile üye olmalısın.',
        membershipStatus: invite ? 'invited' : (pending ? 'pending' : 'none'),
        group: {
          id: group.id,
          name: group.name,
          description: group.description,
          cover_image: group.cover_image,
          members: memberCount,
          visibility: normalizeGroupVisibility(group.visibility),
          show_contact_hint: showContactHint ? 1 : 0
        },
        managers: showContactHint ? groupManagers : []
      });
    }

    const members = sqlAll(
      `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.verified, m.role
       FROM group_members m
       LEFT JOIN uyeler u ON u.id = m.user_id
       WHERE m.group_id = ?`,
      [groupId]
    );
    const rawPosts = sqlAll(
      `SELECT p.id, p.content, p.image, p.created_at,
              u.id as user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
       FROM posts p
       LEFT JOIN uyeler u ON u.id = p.user_id
       WHERE p.group_id = ?
       ORDER BY p.id DESC`,
      [groupId]
    );
    const postIds = rawPosts.map((p) => p.id);
    const likes = postIds.length
      ? sqlAll(`SELECT post_id, COUNT(*) AS cnt FROM post_likes WHERE post_id IN (${postIds.map(() => '?').join(',')}) GROUP BY post_id`, postIds)
      : [];
    const comments = postIds.length
      ? sqlAll(`SELECT post_id, COUNT(*) AS cnt FROM post_comments WHERE post_id IN (${postIds.map(() => '?').join(',')}) GROUP BY post_id`, postIds)
      : [];
    const liked = postIds.length
      ? sqlAll(`SELECT post_id FROM post_likes WHERE user_id = ? AND post_id IN (${postIds.map(() => '?').join(',')})`, [req.session.userId, ...postIds])
      : [];
    const likeMap = new Map(likes.map((l) => [l.post_id, l.cnt]));
    const commentMap = new Map(comments.map((c) => [c.post_id, c.cnt]));
    const likedSet = new Set(liked.map((l) => l.post_id));
    const canReviewRequests = isGroupManager(req, groupId);
    const joinRequests = canReviewRequests
      ? sqlAll(
        `SELECT r.id, r.group_id, r.user_id, r.status, r.created_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM group_join_requests r
         LEFT JOIN uyeler u ON u.id = r.user_id
         WHERE r.group_id = ? AND r.status = 'pending'
         ORDER BY r.id DESC`,
        [groupId]
      )
      : [];
    const groupEvents = sqlAll(
      `SELECT e.id, e.group_id, e.title, e.description, e.location, e.starts_at, e.ends_at, e.created_at, e.created_by, u.kadi AS creator_kadi
       FROM group_events e
       LEFT JOIN uyeler u ON u.id = e.created_by
       WHERE e.group_id = ?
       ORDER BY COALESCE(e.starts_at, e.created_at) ASC, e.id DESC
       LIMIT 50`,
      [groupId]
    );
    const groupAnnouncements = sqlAll(
      `SELECT a.id, a.group_id, a.title, a.body, a.created_at, a.created_by, u.kadi AS creator_kadi
       FROM group_announcements a
       LEFT JOIN uyeler u ON u.id = a.created_by
       WHERE a.group_id = ?
       ORDER BY a.id DESC
       LIMIT 50`,
      [groupId]
    );
    const pendingInvites = canReviewRequests
      ? sqlAll(
        `SELECT i.id, i.group_id, i.invited_user_id, i.invited_by, i.status, i.created_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM group_invites i
         LEFT JOIN uyeler u ON u.id = i.invited_user_id
         WHERE i.group_id = ? AND i.status = 'pending'
         ORDER BY i.id DESC`,
        [groupId]
      )
      : [];
    return res.json({
      group: {
        ...group,
        visibility: normalizeGroupVisibility(group.visibility),
        show_contact_hint: showContactHint ? 1 : 0
      },
      members,
      managers: groupManagers,
      membershipStatus: member ? 'member' : (invite ? 'invited' : (pending ? 'pending' : 'none')),
      myRole: member?.role || (isAdmin ? 'admin' : null),
      canReviewRequests,
      joinRequests,
      pendingInvites,
      groupEvents,
      groupAnnouncements,
      posts: rawPosts.map((p) => ({
        ...p,
        likeCount: likeMap.get(p.id) || 0,
        commentCount: commentMap.get(p.id) || 0,
        liked: likedSet.has(p.id)
      }))
    });
  });

  app.post('/api/new/groups/:id/posts', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    const user = getCurrentUser(req);
    if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
      return res.status(403).send('Bu grup özel. Paylaşım için onaylı üyelik gerekli.');
    }
    const content = formatUserText(req.body?.content || '');
    const contentRaw = String(req.body?.content || '');
    if (isFormattedContentEmpty(content)) return res.status(400).send('İçerik boş olamaz.');
    const now = new Date().toISOString();
    sqlRun('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
      req.session.userId,
      content,
      null,
      now,
      groupId
    ]);
    notifyMentions({
      text: contentRaw,
      sourceUserId: req.session.userId,
      entityId: groupId,
      type: 'mention_group',
      message: 'Grup paylaşımında senden bahsetti.'
    });
    res.json({ ok: true });
  });

  app.post('/api/new/groups/:id/posts/upload', requireAuth, uploadRateLimit, postUpload.single('image'), async (req, res) => {
    const groupId = req.params.id;
    const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    const user = getCurrentUser(req);
    if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
      return res.status(403).send('Bu grup özel. Paylaşım için onaylı üyelik gerekli.');
    }
    const content = formatUserText(req.body?.content || '');
    const contentRaw = String(req.body?.content || '');
    const filter = req.body?.filter || '';
    let processedUpload = null;
    if (req.file?.path) {
      processedUpload = await processDiskImageUpload({
        req,
        res,
        file: req.file,
        bucket: 'group_post_image',
        preset: uploadImagePresets.postImage,
        filter
      });
      if (!processedUpload.ok) return res.status(processedUpload.statusCode).send(processedUpload.message);
    }
    const image = processedUpload?.url || null;
    if (isFormattedContentEmpty(content) && !image) return res.status(400).send('İçerik boş olamaz.');
    const now = new Date().toISOString();
    sqlRun('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
      req.session.userId,
      content,
      image,
      now,
      groupId
    ]);
    notifyMentions({
      text: contentRaw,
      sourceUserId: req.session.userId,
      entityId: groupId,
      type: 'mention_group',
      message: 'Grup paylaşımında senden bahsetti.'
    });
    res.json({ ok: true });
  });

  app.get('/api/new/groups/:id/events', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    const user = getCurrentUser(req);
    if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
      return res.status(403).send('Bu grup özel. Etkinlikler yalnızca üyelere açık.');
    }
    const rows = sqlAll(
      `SELECT e.id, e.group_id, e.title, e.description, e.location, e.starts_at, e.ends_at, e.created_at, e.created_by, u.kadi AS creator_kadi
       FROM group_events e
       LEFT JOIN uyeler u ON u.id = e.created_by
       WHERE e.group_id = ?
       ORDER BY COALESCE(e.starts_at, e.created_at) ASC, e.id DESC
       LIMIT 100`,
      [groupId]
    );
    res.json({ items: rows });
  });

  app.post('/api/new/groups/:id/events', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok. Sadece owner/moderator etkinlik ekleyebilir.');
    const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
    if (!title) return res.status(400).send('Başlık gerekli.');
    const now = new Date().toISOString();
    const result = sqlRun(
      `INSERT INTO group_events (group_id, title, description, location, starts_at, ends_at, created_at, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        groupId,
        title,
        formatUserText(req.body?.description || ''),
        sanitizePlainUserText(String(req.body?.location || '').trim(), 180),
        String(req.body?.starts_at || ''),
        String(req.body?.ends_at || ''),
        now,
        req.session.userId
      ]
    );
    res.json({ ok: true, id: result?.lastInsertRowid });
  });

  app.delete('/api/new/groups/:id/events/:eventId', requireAuth, (req, res) => {
    const groupId = req.params.id;
    if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
    sqlRun('DELETE FROM group_events WHERE id = ? AND group_id = ?', [req.params.eventId, groupId]);
    res.json({ ok: true });
  });

  app.get('/api/new/groups/:id/announcements', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    const user = getCurrentUser(req);
    if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
      return res.status(403).send('Bu grup özel. Duyurular yalnızca üyelere açık.');
    }
    const rows = sqlAll(
      `SELECT a.id, a.group_id, a.title, a.body, a.created_at, a.created_by, u.kadi AS creator_kadi
       FROM group_announcements a
       LEFT JOIN uyeler u ON u.id = a.created_by
       WHERE a.group_id = ?
       ORDER BY a.id DESC
       LIMIT 100`,
      [groupId]
    );
    res.json({ items: rows });
  });

  app.post('/api/new/groups/:id/announcements', requireAuth, (req, res) => {
    const groupId = req.params.id;
    const group = sqlGet('SELECT id FROM groups WHERE id = ?', [groupId]);
    if (!group) return res.status(404).send('Grup bulunamadı.');
    if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok. Sadece owner/moderator duyuru ekleyebilir.');
    const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
    const body = formatUserText(req.body?.body || '');
    if (!title || isFormattedContentEmpty(body)) return res.status(400).send('Başlık ve içerik gerekli.');
    const now = new Date().toISOString();
    const result = sqlRun(
      `INSERT INTO group_announcements (group_id, title, body, created_at, created_by)
       VALUES (?, ?, ?, ?, ?)`,
      [groupId, title, body, now, req.session.userId]
    );
    res.json({ ok: true, id: result?.lastInsertRowid });
  });

  app.delete('/api/new/groups/:id/announcements/:announcementId', requireAuth, (req, res) => {
    const groupId = req.params.id;
    if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
    sqlRun('DELETE FROM group_announcements WHERE id = ? AND group_id = ?', [req.params.announcementId, groupId]);
    res.json({ ok: true });
  });
}
