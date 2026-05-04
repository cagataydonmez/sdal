export function registerCommunityGroupRoutes(app, {
  requireAuth,
  sqlGetAsync,
  sqlGet,
  sqlAll,
  sqlAllAsync,
  sqlRun,
  sqlRunAsync,
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
  app.get('/api/new/groups', requireAuth, async (req, res) => {
    try {
      const limit = Math.min(Math.max(parseInt(req.query.limit || '20', 10), 1), 500);
      const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);
      const cursor = Math.max(parseInt(req.query.cursor || '0', 10), 0);
      const user = getCurrentUser(req);
      const isAdmin = hasAdminRole(user);
      const viewerRow = await sqlGetAsync('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [req.session.userId]);
      const viewerCohort = String(viewerRow?.mezuniyetyili || '').trim();
      const whereParts = [];
      const whereParams = [];
      if (cursor > 0) {
        whereParts.push('id < ?');
        whereParams.push(cursor);
      }
      // Non-admins can only see their own cohort group among cohort groups
      if (!isAdmin) {
        if (viewerCohort && viewerCohort !== '0') {
          whereParts.push("(COALESCE(is_cohort_group, 0) = 0 OR cohort_year = ?)");
          whereParams.push(viewerCohort);
        } else {
          whereParts.push("COALESCE(is_cohort_group, 0) = 0");
        }
      }
      const whereSql = whereParts.length ? `WHERE ${whereParts.join(' AND ')}` : '';
      // Ordering: 1) user's own cohort group first, 2) Öğretmenler + non-cohort groups alphabetically, 3) other cohort years ascending
      const orderParams = [viewerCohort || '', viewerCohort || ''];
      const groups = await sqlAllAsync(
        `SELECT *
         FROM groups
         ${whereSql}
         ORDER BY
           CASE
             WHEN COALESCE(is_cohort_group, 0) = 1 AND cohort_year = ? THEN 0
             WHEN COALESCE(is_cohort_group, 0) = 0 OR (COALESCE(is_cohort_group, 0) = 1 AND cohort_year = '9999') THEN 1
             ELSE 2
           END ASC,
           CASE
             WHEN COALESCE(is_cohort_group, 0) = 1 AND cohort_year != '9999' AND cohort_year != ? THEN CAST(cohort_year AS INTEGER)
             ELSE 0
           END ASC,
           name ASC
         LIMIT ? OFFSET ?`,
        [...whereParams, ...orderParams, limit + 1, cursor > 0 ? 0 : offset]
      );
      const memberCounts = await sqlAllAsync('SELECT group_id, COUNT(*) AS cnt FROM group_members GROUP BY group_id');
      const membership = await sqlAllAsync('SELECT group_id, role FROM group_members WHERE user_id = ?', [req.session.userId]);
      const pending = await sqlAllAsync(
        `SELECT group_id
         FROM group_join_requests
         WHERE user_id = ? AND status = 'pending'`,
        [req.session.userId]
      );
      const invites = await sqlAllAsync(
        `SELECT group_id
         FROM group_invites
         WHERE invited_user_id = ? AND status = 'pending'`,
        [req.session.userId]
      );
      const countMap = new Map(memberCounts.map((c) => [c.group_id, c.cnt]));
      const memberMap = new Map(membership.map((m) => [m.group_id, m.role]));
      const pendingSet = new Set(pending.map((p) => p.group_id));
      const inviteSet = new Set(invites.map((v) => v.group_id));
      const slice = groups.slice(0, limit);
      res.json({
        items: slice.map((g) => ({
          ...g,
          visibility: Number(g.is_cohort_group || 0) === 1 ? 'members_only' : normalizeGroupVisibility(g.visibility),
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/groups', requireAuth, async (req, res) => {
    try {
      const name = sanitizePlainUserText(String(req.body?.name || '').trim(), 120);
      if (!name) return res.status(400).send('Grup adı gerekli.');
      const description = formatUserText(req.body?.description || '');
      const now = new Date().toISOString();
      const result = await sqlRunAsync('INSERT INTO groups (name, description, cover_image, owner_id, created_at, visibility) VALUES (?, ?, ?, ?, ?, ?)', [
        name,
        description,
        req.body?.cover_image || null,
        req.session.userId,
        now,
        'public'
      ]);
      const groupId = result?.lastInsertRowid;
      await sqlRunAsync('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/groups/:id/join', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT id, name, visibility FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      const pendingInvite = await sqlGetAsync(
        `SELECT id
         FROM group_invites
         WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
        [groupId, req.session.userId]
      );

      const existingMember = getGroupMember(groupId, req.session.userId);
      if (existingMember) {
        if (existingMember.role === 'owner') return res.status(400).send('Grup sahibi gruptan ayrılamaz.');
        await sqlRunAsync('DELETE FROM group_members WHERE group_id = ? AND user_id = ?', [groupId, req.session.userId]);
        return res.json({ ok: true, joined: false, pending: false, membershipStatus: 'none' });
      }

      if (pendingInvite) {
        await sqlRunAsync('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
          groupId,
          req.session.userId,
          'member',
          new Date().toISOString()
        ]);
        await sqlRunAsync('UPDATE group_invites SET status = ?, responded_at = ? WHERE id = ?', ['accepted', new Date().toISOString(), pendingInvite.id]);
        await sqlRunAsync('DELETE FROM group_join_requests WHERE group_id = ? AND user_id = ? AND status = ?', [groupId, req.session.userId, 'pending']);
        return res.json({ ok: true, joined: true, pending: false, invited: false, membershipStatus: 'member' });
      }

      const existingRequest = await sqlGetAsync(
        `SELECT id
         FROM group_join_requests
         WHERE group_id = ? AND user_id = ? AND status = 'pending'`,
        [groupId, req.session.userId]
      );
      if (existingRequest) {
        await sqlRunAsync('DELETE FROM group_join_requests WHERE id = ?', [existingRequest.id]);
        return res.json({ ok: true, joined: false, pending: false, invited: false, membershipStatus: 'none' });
      }

      await sqlRunAsync(
        `INSERT INTO group_join_requests (group_id, user_id, status, created_at)
         VALUES (?, ?, 'pending', ?)`,
        [groupId, req.session.userId, new Date().toISOString()]
      );

      const managers = await sqlAllAsync(
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/groups/:id/requests', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT id FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
      const rows = await sqlAllAsync(
        `SELECT r.id, r.group_id, r.user_id, r.status, r.created_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM group_join_requests r
         LEFT JOIN uyeler u ON u.id = r.user_id
         WHERE r.group_id = ? AND r.status = 'pending'
         ORDER BY r.id DESC`,
        [groupId]
      );
      return res.json({ items: rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/groups/:id/requests/:requestId', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const requestId = req.params.requestId;
      const action = String(req.body?.action || '').toLowerCase();
      if (!['approve', 'reject'].includes(action)) return res.status(400).send('Geçersiz işlem.');
      const group = await sqlGetAsync('SELECT id, name FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');

      const requestRow = await sqlGetAsync(
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
          await sqlRunAsync('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
            groupId,
            requestRow.user_id,
            'member',
            new Date().toISOString()
          ]);
        }
      }

      await sqlRunAsync(
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/groups/:id/invitations', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT id FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
      const rows = await sqlAllAsync(
        `SELECT i.id, i.group_id, i.invited_user_id, i.invited_by, i.status, i.created_at, i.responded_at,
                u.kadi, u.isim, u.soyisim, u.resim, u.verified
         FROM group_invites i
         LEFT JOIN uyeler u ON u.id = i.invited_user_id
         WHERE i.group_id = ? AND i.status = 'pending'
         ORDER BY i.id DESC`,
        [groupId]
      );
      return res.json({ items: rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/groups/:id/invitations', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT id, name FROM groups WHERE id = ?', [groupId]);
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
        const existingPending = await sqlGetAsync(
          `SELECT id
           FROM group_invites
           WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
          [groupId, userId]
        );
        if (existingPending) continue;
        await sqlRunAsync(
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  async function _handleGroupInviteResponse(req, res, action) {
    try {
      const groupId = req.params.id;
      const invite = await sqlGetAsync(
        `SELECT id, invited_user_id, invited_by, status
         FROM group_invites
         WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
        [groupId, req.session.userId]
      );
      if (!invite) return res.status(404).send('Bekleyen davet bulunamadı.');
      const group = await sqlGetAsync('SELECT id, name FROM groups WHERE id = ?', [groupId]);

      if (action === 'accept') {
        const alreadyMember = getGroupMember(groupId, req.session.userId);
        if (!alreadyMember) {
          await sqlRunAsync('INSERT INTO group_members (group_id, user_id, role, created_at) VALUES (?, ?, ?, ?)', [
            groupId,
            req.session.userId,
            'member',
            new Date().toISOString()
          ]);
        }
      }

      await sqlRunAsync('UPDATE group_invites SET status = ?, responded_at = ? WHERE id = ?', [
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  }

  app.post('/api/new/groups/:id/invitations/respond', requireAuth, async (req, res) => {
    const action = String(req.body?.action || '').toLowerCase();
    if (!['accept', 'reject'].includes(action)) return res.status(400).send('Geçersiz işlem.');
    return _handleGroupInviteResponse(req, res, action);
  });

  // Flutter-compatible aliases: no request body required
  app.post('/api/new/groups/:id/invitations/accept', requireAuth, (req, res) =>
    _handleGroupInviteResponse(req, res, 'accept')
  );
  app.post('/api/new/groups/:id/invitations/reject', requireAuth, (req, res) =>
    _handleGroupInviteResponse(req, res, 'reject')
  );

  app.post('/api/new/groups/:id/settings', requireAuth, async (req, res) => {
    try {
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
        await sqlRunAsync('UPDATE groups SET visibility = ?, show_contact_hint = ? WHERE id = ?', [visibility, showContactHint, groupId]);
      } else if (hasVisibility) {
        await sqlRunAsync('UPDATE groups SET visibility = ? WHERE id = ?', [visibility, groupId]);
      } else {
        await sqlRunAsync('UPDATE groups SET show_contact_hint = ? WHERE id = ?', [showContactHint, groupId]);
      }

      const row = await sqlGetAsync('SELECT visibility, show_contact_hint FROM groups WHERE id = ?', [groupId]);
      return res.json({
        ok: true,
        visibility: normalizeGroupVisibility(row?.visibility),
        showContactHint: Number(row?.show_contact_hint || 0) === 1
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/groups/:id/cover', requireAuth, uploadRateLimit, groupUpload.single('image'), async (req, res) => {
    try {
      if (!req.file) return res.status(400).send('Görsel seçilmedi.');
      const group = await sqlGetAsync('SELECT * FROM groups WHERE id = ?', [req.params.id]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      const coverUser = getCurrentUser(req);
      const isCohortGroupCover = Number(group.is_cohort_group || 0) === 1;
      if (isCohortGroupCover && !hasAdminRole(coverUser) && !isGroupManager(req, req.params.id)) {
        return res.status(403).send('Yetki yok. Topluluk grubu kapağını yalnızca yöneticiler değiştirebilir.');
      }
      if (!isCohortGroupCover && !isGroupManager(req, req.params.id)) {
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
      await sqlRunAsync('UPDATE groups SET cover_image = ? WHERE id = ?', [image, req.params.id]);
      res.json({ ok: true, image });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/groups/:id/role', requireAuth, async (req, res) => {
    try {
      const group = await sqlGetAsync('SELECT * FROM groups WHERE id = ?', [req.params.id]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      const member = await sqlGetAsync('SELECT role FROM group_members WHERE group_id = ? AND user_id = ?', [req.params.id, req.session.userId]);
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
      const targetMember = await sqlGetAsync('SELECT id FROM group_members WHERE group_id = ? AND user_id = ?', [req.params.id, targetId]);
      if (!targetMember) return res.status(404).send('Üye bulunamadı.');
      await sqlRunAsync('UPDATE group_members SET role = ? WHERE group_id = ? AND user_id = ?', [role, req.params.id, targetId]);
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/groups/:id', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT * FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      const user = getCurrentUser(req);
      const isAdmin = hasAdminRole(user);
      // Non-admins cannot access other cohorts' groups
      if (!isAdmin && Number(group.is_cohort_group || 0) === 1) {
        const viewerRow = await sqlGetAsync('SELECT mezuniyetyili FROM uyeler WHERE id = ?', [req.session.userId]);
        const viewerCohort = String(viewerRow?.mezuniyetyili || '').trim();
        if (!viewerCohort || viewerCohort === '0' || viewerCohort !== String(group.cohort_year || '').trim()) {
          return res.status(403).send('Bu cohort grubuna erişim izniniz yok.');
        }
      }
      const member = getGroupMember(groupId, req.session.userId);
      const invite = await sqlGetAsync(
        `SELECT id, status
         FROM group_invites
         WHERE group_id = ? AND invited_user_id = ? AND status = 'pending'`,
        [groupId, req.session.userId]
      );
      const pending = await sqlGetAsync(
        `SELECT id
         FROM group_join_requests
         WHERE group_id = ? AND user_id = ? AND status = 'pending'`,
        [groupId, req.session.userId]
      );
      const membersOnly = normalizeGroupVisibility(group.visibility) === 'members_only';
      const rawGroupManagers = await sqlAllAsync(
        `SELECT m.user_id AS id, m.role, u.kadi, u.isim, u.soyisim, u.resim, u.verified,
                u.admin, LOWER(COALESCE(u.role,'')) AS urole
         FROM group_members m
         LEFT JOIN uyeler u ON u.id = m.user_id
         WHERE m.group_id = ? AND m.role IN ('owner', 'moderator')
         ORDER BY CASE WHEN m.role = 'owner' THEN 0 ELSE 1 END, m.id ASC`,
        [groupId]
      );
      const isCohortGroupEarly = Number(group.is_cohort_group || 0) === 1;
      const _isAdminUser = (m) => Number(m.admin || 0) === 1 || m.urole === 'admin' || m.urole === 'root';
      const groupManagers = isCohortGroupEarly && !isAdmin
        ? rawGroupManagers.filter((m) => !_isAdminUser(m))
        : rawGroupManagers;
      const showContactHint = Number(group.show_contact_hint || 0) === 1;

      if (membersOnly && !isAdmin && !member) {
        const memberCount = (await sqlGetAsync('SELECT COUNT(*) AS cnt FROM group_members WHERE group_id = ?', [groupId]))?.cnt || 0;
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

      // For cohort groups: hide admin/owner members (unless the viewer is admin)
      const isCohortGroup = isCohortGroupEarly;
      const memberRows = await sqlAllAsync(
        `SELECT u.id, u.kadi, u.isim, u.soyisim, u.resim, u.verified, m.role,
                u.admin, LOWER(COALESCE(u.role,'')) AS urole
         FROM group_members m
         LEFT JOIN uyeler u ON u.id = m.user_id
         WHERE m.group_id = ?`,
        [groupId]
      );
      const members = isCohortGroup && !isAdmin
        ? memberRows.filter((m) => !_isAdminUser(m))
        : memberRows;
      const rawPosts = await sqlAllAsync(
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
        ? await sqlAllAsync(`SELECT post_id, COUNT(*) AS cnt FROM post_likes WHERE post_id IN (${postIds.map(() => '?').join(',')}) GROUP BY post_id`, postIds)
        : [];
      const comments = postIds.length
        ? await sqlAllAsync(`SELECT post_id, COUNT(*) AS cnt FROM post_comments WHERE post_id IN (${postIds.map(() => '?').join(',')}) GROUP BY post_id`, postIds)
        : [];
      const liked = postIds.length
        ? await sqlAllAsync(`SELECT post_id FROM post_likes WHERE user_id = ? AND post_id IN (${postIds.map(() => '?').join(',')})`, [req.session.userId, ...postIds])
        : [];
      const likeMap = new Map(likes.map((l) => [l.post_id, l.cnt]));
      const commentMap = new Map(comments.map((c) => [c.post_id, c.cnt]));
      const likedSet = new Set(liked.map((l) => l.post_id));
      const canReviewRequests = isGroupManager(req, groupId);
      const joinRequests = canReviewRequests
        ? await sqlAllAsync(
          `SELECT r.id, r.group_id, r.user_id, r.status, r.created_at,
                  u.kadi, u.isim, u.soyisim, u.resim, u.verified
           FROM group_join_requests r
           LEFT JOIN uyeler u ON u.id = r.user_id
           WHERE r.group_id = ? AND r.status = 'pending'
           ORDER BY r.id DESC`,
          [groupId]
        )
        : [];
      const groupEvents = await sqlAllAsync(
        `SELECT e.id, e.group_id, e.title, e.description, e.location, e.starts_at, e.ends_at, e.created_at, e.created_by, u.kadi AS creator_kadi
         FROM group_events e
         LEFT JOIN uyeler u ON u.id = e.created_by
         WHERE e.group_id = ?
         ORDER BY COALESCE(e.starts_at, e.created_at) ASC, e.id DESC
         LIMIT 50`,
        [groupId]
      );
      const groupAnnouncements = await sqlAllAsync(
        `SELECT a.id, a.group_id, a.title, a.body, a.created_at, a.created_by, u.kadi AS creator_kadi
         FROM group_announcements a
         LEFT JOIN uyeler u ON u.id = a.created_by
         WHERE a.group_id = ?
         ORDER BY a.id DESC
         LIMIT 50`,
        [groupId]
      );
      const pendingInvites = canReviewRequests
        ? await sqlAllAsync(
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
          visibility: isCohortGroup ? 'members_only' : normalizeGroupVisibility(group.visibility),
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/groups/:id/posts', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT id FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      const user = getCurrentUser(req);
      if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
        return res.status(403).send('Grup üyesi değilsiniz.');
      }
      const limit = Math.min(Math.max(parseInt(req.query.limit || '30', 10), 1), 100);
      const offset = Math.max(parseInt(req.query.offset || '0', 10), 0);

      const stripHtml = (s) => (s || '').replace(/<[^>]+>/g, '').trim();

      const [regularPosts, events, announcements] = await Promise.all([
        sqlAllAsync(
          `SELECT p.id, p.content, p.image, p.created_at, 'post' AS post_type, NULL AS entity_id,
                  u.id as user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
           FROM posts p LEFT JOIN uyeler u ON u.id = p.user_id
           WHERE p.group_id = ? ORDER BY p.id DESC`,
          [groupId]
        ),
        sqlAllAsync(
          `SELECT e.id, e.title, e.description, e.location, e.starts_at, e.created_at,
                  u.id as user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
           FROM group_events e LEFT JOIN uyeler u ON u.id = e.created_by
           WHERE e.group_id = ? ORDER BY e.id DESC`,
          [groupId]
        ),
        sqlAllAsync(
          `SELECT a.id, a.title, a.body, a.created_at,
                  u.id as user_id, u.kadi, u.isim, u.soyisim, u.resim, u.verified
           FROM group_announcements a LEFT JOIN uyeler u ON u.id = a.created_by
           WHERE a.group_id = ? ORDER BY a.id DESC`,
          [groupId]
        )
      ]);

      const eventItems = events.map((e) => ({
        id: e.id,
        content: [e.title, stripHtml(e.description), e.location ? `📍 ${e.location}` : '', e.starts_at ? `🗓 ${e.starts_at}` : ''].filter(Boolean).join('\n'),
        image: null, created_at: e.created_at,
        post_type: 'group_event', entity_id: e.id,
        user_id: e.user_id, kadi: e.kadi, isim: e.isim, soyisim: e.soyisim, resim: e.resim, verified: e.verified,
        likeCount: 0, commentCount: 0, liked: false
      }));

      const announcementItems = announcements.map((a) => ({
        id: a.id,
        content: [a.title, stripHtml(a.body)].filter(Boolean).join('\n'),
        image: null, created_at: a.created_at,
        post_type: 'group_announcement', entity_id: a.id,
        user_id: a.user_id, kadi: a.kadi, isim: a.isim, soyisim: a.soyisim, resim: a.resim, verified: a.verified,
        likeCount: 0, commentCount: 0, liked: false
      }));

      const merged = [...regularPosts, ...eventItems, ...announcementItems]
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));

      const regularIds = regularPosts.map((p) => p.id);
      const likes = regularIds.length
        ? await sqlAllAsync(`SELECT post_id, COUNT(*) AS cnt FROM post_likes WHERE post_id IN (${regularIds.map(() => '?').join(',')}) GROUP BY post_id`, regularIds)
        : [];
      const comments = regularIds.length
        ? await sqlAllAsync(`SELECT post_id, COUNT(*) AS cnt FROM post_comments WHERE post_id IN (${regularIds.map(() => '?').join(',')}) GROUP BY post_id`, regularIds)
        : [];
      const likedRows = regularIds.length
        ? await sqlAllAsync(`SELECT post_id FROM post_likes WHERE user_id = ? AND post_id IN (${regularIds.map(() => '?').join(',')})`, [req.session.userId, ...regularIds])
        : [];
      const likeMap = new Map(likes.map((l) => [l.post_id, l.cnt]));
      const commentMap = new Map(comments.map((c) => [c.post_id, c.cnt]));
      const likedSet = new Set(likedRows.map((l) => l.post_id));

      const slice = merged.slice(offset, offset + limit);
      res.json({
        items: slice.map((p) => p.post_type === 'post'
          ? { ...p, likeCount: likeMap.get(p.id) || 0, commentCount: commentMap.get(p.id) || 0, liked: likedSet.has(p.id) }
          : p
        ),
        hasMore: merged.length > offset + limit
      });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/groups/:id/posts', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT id FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      const user = getCurrentUser(req);
      if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
        return res.status(403).send('Bu grup özel. Paylaşım için onaylı üyelik gerekli.');
      }
      const content = formatUserText(req.body?.content || '');
      const contentRaw = String(req.body?.content || '');
      if (isFormattedContentEmpty(content)) return res.status(400).send('İçerik boş olamaz.');
      const now = new Date().toISOString();
      await sqlRunAsync('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/groups/:id/posts/upload', requireAuth, uploadRateLimit, postUpload.single('image'), async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT id FROM groups WHERE id = ?', [groupId]);
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
      await sqlRunAsync('INSERT INTO posts (user_id, content, image, created_at, group_id) VALUES (?, ?, ?, ?, ?)', [
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
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/groups/:id/events', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT id FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      const user = getCurrentUser(req);
      if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
        return res.status(403).send('Bu grup özel. Etkinlikler yalnızca üyelere açık.');
      }
      const rows = await sqlAllAsync(
        `SELECT e.id, e.group_id, e.title, e.description, e.location, e.starts_at, e.ends_at, e.created_at, e.created_by, u.kadi AS creator_kadi
         FROM group_events e
         LEFT JOIN uyeler u ON u.id = e.created_by
         WHERE e.group_id = ?
         ORDER BY COALESCE(e.starts_at, e.created_at) ASC, e.id DESC
         LIMIT 100`,
        [groupId]
      );
      res.json({ items: rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/groups/:id/events', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT id FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok. Sadece owner/moderator etkinlik ekleyebilir.');
      const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
      if (!title) return res.status(400).send('Başlık gerekli.');
      const now = new Date().toISOString();
      const desc = formatUserText(req.body?.description || '');
      const location = sanitizePlainUserText(String(req.body?.location || '').trim(), 180);
      const startsAt = String(req.body?.starts_at || '');
      const endsAt = String(req.body?.ends_at || '');
      const result = await sqlRunAsync(
        `INSERT INTO group_events (group_id, title, description, location, starts_at, ends_at, created_at, created_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [groupId, title, desc, location, startsAt, endsAt, now, req.session.userId]
      );
      const eventId = result?.lastInsertRowid;
      const groupForNotif = await sqlGetAsync('SELECT name FROM groups WHERE id = ?', [groupId]);
      const membersForNotif = await sqlAllAsync('SELECT user_id FROM group_members WHERE group_id = ?', [groupId]);
      for (const m of membersForNotif) {
        if (Number(m.user_id) === Number(req.session.userId)) continue;
        addNotification({
          userId: Number(m.user_id),
          type: 'group_event',
          sourceUserId: req.session.userId,
          entityId: Number(groupId),
          message: `${groupForNotif?.name || 'Grupta'} yeni etkinlik: ${title}`
        });
      }
      res.json({ ok: true, id: eventId });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/new/groups/:id/events/:eventId', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
      await sqlRunAsync('DELETE FROM group_events WHERE id = ? AND group_id = ?', [req.params.eventId, groupId]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.get('/api/new/groups/:id/announcements', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT id FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      const user = getCurrentUser(req);
      if (!hasAdminRole(user) && !getGroupMember(groupId, req.session.userId)) {
        return res.status(403).send('Bu grup özel. Duyurular yalnızca üyelere açık.');
      }
      const rows = await sqlAllAsync(
        `SELECT a.id, a.group_id, a.title, a.body, a.created_at, a.created_by, u.kadi AS creator_kadi
         FROM group_announcements a
         LEFT JOIN uyeler u ON u.id = a.created_by
         WHERE a.group_id = ?
         ORDER BY a.id DESC
         LIMIT 100`,
        [groupId]
      );
      res.json({ items: rows });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.post('/api/new/groups/:id/announcements', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      const group = await sqlGetAsync('SELECT id FROM groups WHERE id = ?', [groupId]);
      if (!group) return res.status(404).send('Grup bulunamadı.');
      if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok. Sadece owner/moderator duyuru ekleyebilir.');
      const title = sanitizePlainUserText(String(req.body?.title || '').trim(), 180);
      const body = formatUserText(req.body?.body || '');
      if (!title || isFormattedContentEmpty(body)) return res.status(400).send('Başlık ve içerik gerekli.');
      const now = new Date().toISOString();
      const result = await sqlRunAsync(
        `INSERT INTO group_announcements (group_id, title, body, created_at, created_by)
         VALUES (?, ?, ?, ?, ?)`,
        [groupId, title, body, now, req.session.userId]
      );
      const announcementId = result?.lastInsertRowid;
      const groupForNotif = await sqlGetAsync('SELECT name FROM groups WHERE id = ?', [groupId]);
      const membersForNotif = await sqlAllAsync('SELECT user_id FROM group_members WHERE group_id = ?', [groupId]);
      for (const m of membersForNotif) {
        if (Number(m.user_id) === Number(req.session.userId)) continue;
        addNotification({
          userId: Number(m.user_id),
          type: 'group_announcement',
          sourceUserId: req.session.userId,
          entityId: Number(groupId),
          message: `${groupForNotif?.name || 'Grupta'} yeni duyuru: ${title}`
        });
      }
      res.json({ ok: true, id: announcementId });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });

  app.delete('/api/new/groups/:id/announcements/:announcementId', requireAuth, async (req, res) => {
    try {
      const groupId = req.params.id;
      if (!isGroupManager(req, groupId)) return res.status(403).send('Yetki yok.');
      await sqlRunAsync('DELETE FROM group_announcements WHERE id = ? AND group_id = ?', [req.params.announcementId, groupId]);
      res.json({ ok: true });
    } catch (err) {
      console.error(err);
      if (!res.headersSent) res.status(500).send('Beklenmeyen bir hata oluştu.');
    }
  });
}
