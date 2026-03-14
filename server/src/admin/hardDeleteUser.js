import fs from 'fs';
import path from 'path';

export async function hardDeleteUser(userId, {
  sqlRun,
  sqlGet,
  sqlAll,
  uploadsDir,
  writeAppLog,
  getTableColumnSetAsync,
  deleteImageRecord
}) {
  const runGet = async (query, params = []) => Promise.resolve(sqlGet(query, params));
  const runAll = async (query, params = []) => Promise.resolve(sqlAll(query, params));
  const runExec = async (query, params = []) => Promise.resolve(sqlRun(query, params));

  const userIdStr = String(userId);
  const user = await runGet('SELECT kadi, resim FROM uyeler WHERE id = ?', [userId]);
  if (!user) return;

  const metadataTables = [
    'posts', 'post_comments', 'post_likes', 'stories', 'story_views',
    'events', 'event_responses', 'event_comments', 'groups', 'group_members',
    'group_join_requests', 'group_invites', 'group_events', 'group_announcements',
    'album_fotoyorum', 'album_foto', 'gelenkutusu', 'sdal_messenger_messages',
    'sdal_messenger_threads', 'follows', 'notifications', 'oyun_yilan',
    'oyun_tetris', 'game_scores', 'verification_requests', 'member_engagement_scores',
    'engagement_ab_assignments', 'network_suggestion_ab_assignments', 'oauth_accounts', 'chat_messages'
  ];
  const tableColumns = new Map();
  await Promise.all(metadataTables.map(async (table) => {
    const cols = await getTableColumnSetAsync(table);
    tableColumns.set(table, cols);
  }));
  const hasTableLocal = (table) => (tableColumns.get(table)?.size || 0) > 0;
  const hasColumnLocal = (table, column) => tableColumns.get(table)?.has(String(column || '').toLowerCase()) || false;
  const getUserColumn = (table) => {
    if (hasColumnLocal(table, 'user_id')) return 'user_id';
    if (hasColumnLocal(table, 'uye_id')) return 'uye_id';
    return '';
  };

  const userColumn = {
    posts: getUserColumn('posts'),
    postComments: getUserColumn('post_comments'),
    postLikes: getUserColumn('post_likes'),
    stories: getUserColumn('stories'),
    storyViews: getUserColumn('story_views'),
    eventResponses: getUserColumn('event_responses'),
    eventComments: getUserColumn('event_comments'),
    groupMembers: getUserColumn('group_members'),
    groupJoinRequests: getUserColumn('group_join_requests'),
    notifications: getUserColumn('notifications'),
    gameScores: getUserColumn('game_scores'),
    verificationRequests: getUserColumn('verification_requests'),
    memberEngagementScores: getUserColumn('member_engagement_scores'),
    engagementAbAssignments: getUserColumn('engagement_ab_assignments'),
    networkSuggestionAbAssignments: getUserColumn('network_suggestion_ab_assignments'),
    oauthAccounts: getUserColumn('oauth_accounts'),
    chatMessages: getUserColumn('chat_messages')
  };

  if (user.resim && user.resim !== 'yok' && user.resim.trim() !== '') {
    const avatarPath = path.join(uploadsDir, 'vesikalik', user.resim);
    try {
      if (fs.existsSync(avatarPath)) fs.unlinkSync(avatarPath);
    } catch (e) {
      writeAppLog('error', 'avatar_delete_failed', { userId, path: avatarPath, error: e.message });
    }
  }

  if (hasTableLocal('posts') && userColumn.posts) {
    const userPosts = await runAll(`SELECT id, image_record_id FROM posts WHERE ${userColumn.posts} = ?`, [userId]);
    for (const p of userPosts) {
      if (p.image_record_id) {
        await deleteImageRecord(p.image_record_id, runGet, runExec, uploadsDir, writeAppLog).catch(() => {});
      }
    }
    await runExec(`DELETE FROM posts WHERE ${userColumn.posts} = ?`, [userId]);
  }
  if (hasTableLocal('post_comments') && userColumn.postComments) await runExec(`DELETE FROM post_comments WHERE ${userColumn.postComments} = ?`, [userId]);
  if (hasTableLocal('post_likes') && userColumn.postLikes) await runExec(`DELETE FROM post_likes WHERE ${userColumn.postLikes} = ?`, [userId]);

  if (hasTableLocal('stories') && userColumn.stories) {
    const userStories = await runAll(`SELECT id, image_record_id FROM stories WHERE ${userColumn.stories} = ?`, [userId]);
    for (const s of userStories) {
      if (s.image_record_id) {
        await deleteImageRecord(s.image_record_id, runGet, runExec, uploadsDir, writeAppLog).catch(() => {});
      }
    }
    await runExec(`DELETE FROM stories WHERE ${userColumn.stories} = ?`, [userId]);
  }
  if (hasTableLocal('story_views') && userColumn.storyViews) await runExec(`DELETE FROM story_views WHERE ${userColumn.storyViews} = ?`, [userId]);

  if (hasTableLocal('events')) await runExec('DELETE FROM events WHERE created_by = ?', [userId]);
  if (hasTableLocal('event_responses') && userColumn.eventResponses) await runExec(`DELETE FROM event_responses WHERE ${userColumn.eventResponses} = ?`, [userId]);
  if (hasTableLocal('event_comments') && userColumn.eventComments) await runExec(`DELETE FROM event_comments WHERE ${userColumn.eventComments} = ?`, [userId]);

  if (hasTableLocal('groups')) {
    const ownedGroups = await runAll('SELECT id FROM groups WHERE owner_id = ?', [userId]);
    for (const g of ownedGroups) {
      if (hasTableLocal('group_members')) await runExec('DELETE FROM group_members WHERE group_id = ?', [g.id]);
      if (hasTableLocal('group_join_requests')) await runExec('DELETE FROM group_join_requests WHERE group_id = ?', [g.id]);
      if (hasTableLocal('group_invites')) await runExec('DELETE FROM group_invites WHERE group_id = ?', [g.id]);
      if (hasTableLocal('group_events')) await runExec('DELETE FROM group_events WHERE group_id = ?', [g.id]);
      if (hasTableLocal('group_announcements')) await runExec('DELETE FROM group_announcements WHERE group_id = ?', [g.id]);
      await runExec('DELETE FROM groups WHERE id = ?', [g.id]);
    }
  }
  if (hasTableLocal('group_members') && userColumn.groupMembers) await runExec(`DELETE FROM group_members WHERE ${userColumn.groupMembers} = ?`, [userId]);
  if (hasTableLocal('group_join_requests') && userColumn.groupJoinRequests) await runExec(`DELETE FROM group_join_requests WHERE ${userColumn.groupJoinRequests} = ? OR reviewed_by = ?`, [userId, userId]);
  if (hasTableLocal('group_invites')) await runExec('DELETE FROM group_invites WHERE invited_user_id = ? OR invited_by = ?', [userId, userId]);

  if (hasTableLocal('album_fotoyorum') && hasTableLocal('album_foto')) {
    await runExec('DELETE FROM album_fotoyorum WHERE fotoid IN (SELECT id FROM album_foto WHERE ekleyenid = ?)', [userId]);
  }
  if (hasTableLocal('album_fotoyorum')) {
    await runExec('DELETE FROM album_fotoyorum WHERE uyeadi = ?', [user.kadi]);
  }
  if (hasTableLocal('album_foto')) await runExec('DELETE FROM album_foto WHERE ekleyenid = ?', [userId]);

  if (hasTableLocal('gelenkutusu')) await runExec('DELETE FROM gelenkutusu WHERE kime = ? OR kimden = ?', [userIdStr, userIdStr]);
  if (hasTableLocal('sdal_messenger_messages')) await runExec('DELETE FROM sdal_messenger_messages WHERE sender_id = ? OR receiver_id = ?', [userId, userId]);
  if (hasTableLocal('sdal_messenger_threads')) await runExec('DELETE FROM sdal_messenger_threads WHERE user_a_id = ? OR user_b_id = ?', [userId, userId]);

  if (hasTableLocal('follows')) await runExec('DELETE FROM follows WHERE follower_id = ? OR following_id = ?', [userId, userId]);
  if (hasTableLocal('notifications') && userColumn.notifications) await runExec(`DELETE FROM notifications WHERE ${userColumn.notifications} = ? OR source_user_id = ?`, [userId, userId]);

  if (hasTableLocal('oyun_yilan')) await runExec('DELETE FROM oyun_yilan WHERE isim = ?', [user.kadi]);
  if (hasTableLocal('oyun_tetris')) await runExec('DELETE FROM oyun_tetris WHERE isim = ?', [user.kadi]);
  if (hasTableLocal('game_scores') && userColumn.gameScores) await runExec(`DELETE FROM game_scores WHERE ${userColumn.gameScores} = ?`, [userId]);

  if (hasTableLocal('verification_requests') && userColumn.verificationRequests) {
    const proofRows = await runAll(`SELECT proof_path, proof_image_record_id FROM verification_requests WHERE ${userColumn.verificationRequests} = ?`, [userId]);
    for (const row of proofRows) {
      if (row?.proof_image_record_id) {
        await deleteImageRecord(row.proof_image_record_id, runGet, runExec, uploadsDir, writeAppLog).catch(() => {});
        continue;
      }
      const proofPath = String(row?.proof_path || '').trim();
      if (!proofPath.startsWith('/uploads/verification-proofs/')) continue;
      const relativeProof = proofPath.replace(/^\/+/, '').replace(/^uploads\//, '');
      const absoluteProof = path.join(uploadsDir, relativeProof);
      try {
        if (fs.existsSync(absoluteProof)) fs.unlinkSync(absoluteProof);
      } catch (e) {
        writeAppLog('error', 'verification_proof_delete_failed', { userId, path: absoluteProof, error: e.message });
      }
    }
    await runExec(`DELETE FROM verification_requests WHERE ${userColumn.verificationRequests} = ? OR reviewer_id = ?`, [userId, userId]);
  }
  if (hasTableLocal('member_engagement_scores') && userColumn.memberEngagementScores) await runExec(`DELETE FROM member_engagement_scores WHERE ${userColumn.memberEngagementScores} = ?`, [userId]);
  if (hasTableLocal('engagement_ab_assignments') && userColumn.engagementAbAssignments) await runExec(`DELETE FROM engagement_ab_assignments WHERE ${userColumn.engagementAbAssignments} = ?`, [userId]);
  if (hasTableLocal('network_suggestion_ab_assignments') && userColumn.networkSuggestionAbAssignments) {
    await runExec(`DELETE FROM network_suggestion_ab_assignments WHERE ${userColumn.networkSuggestionAbAssignments} = ?`, [userId]);
  }
  if (hasTableLocal('oauth_accounts') && userColumn.oauthAccounts) await runExec(`DELETE FROM oauth_accounts WHERE ${userColumn.oauthAccounts} = ?`, [userId]);
  if (hasTableLocal('chat_messages') && userColumn.chatMessages) await runExec(`DELETE FROM chat_messages WHERE ${userColumn.chatMessages} = ?`, [userId]);

  await runExec('DELETE FROM uyeler WHERE id = ?', [userId]);
  writeAppLog('info', 'member_hard_deleted', { userId, kadi: user.kadi });
}
