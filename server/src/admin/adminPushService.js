/**
 * Admin push notification service.
 *
 * Sends permission-aware push notifications to root/admin/moderator users
 * for high-priority operational events without exposing private content.
 *
 * Channels:
 *   root_critical  — factory reset, DB restore/switch, permission group changes, privilege escalation
 *   admin_ops      — site controls changed, broadcast completed/failed, queue spike
 *   moderator_queue — new request spike in scoped queue, content report spike
 *   security_watch — auth security anomaly, trusted device revoked
 *
 * Payload contract: { type, title, body (safe), data: { route, eventId, channel } }
 * No raw user content, no secrets, no phone numbers in payloads.
 */

const CHANNEL = Object.freeze({
  ROOT_CRITICAL: 'root_critical',
  ADMIN_OPS: 'admin_ops',
  MODERATOR_QUEUE: 'moderator_queue',
  SECURITY_WATCH: 'security_watch'
});

const DEEP_LINK = Object.freeze({
  ADMIN: '/admin',
  MODERATION: '/moderation',
  REQUESTS: '/admin/requests',
  CONTENT: '/admin/content',
  AUTH_SECURITY: '/admin/auth-security',
  NOTIFICATIONS: '/admin/notifications',
  OPERATIONS: '/admin/operations',
  DATABASE: '/admin/database',
  PERMISSIONS: '/admin/permission-groups'
});

function normalizeRole(value) {
  return String(value || '').trim().toLowerCase();
}

function isDbBooleanTrue(value) {
  return value === true || Number(value || 0) === 1 || ['1', 'true', 'yes'].includes(String(value || '').trim().toLowerCase());
}

export function createAdminPushService({
  dbDriver,
  sqlAllAsync,
  dispatchPushNotification,
  writeAppLog,
  writeAuditLog,
  ROOT_ADMIN_USERNAME = 'cagatay'
}) {
  async function resolveRecipients(channel, graduationYear = null) {
    try {
      const isPg = dbDriver === 'postgres';
      const usernameCol = isPg ? 'username' : 'kadi';
      const tableName = isPg ? 'users' : 'uyeler';
      const activeCol = isPg ? 'is_active' : 'aktiv';
      const activeTrue = isPg ? 'TRUE' : '1';

      // For MODERATOR_QUEUE with a graduation year, filter mods by scope:
      // root/admin always included; mods only if unscoped OR scoped to the matching year.
      if (channel === CHANNEL.MODERATOR_QUEUE && graduationYear) {
        const gy = String(graduationYear).trim();
        const rows = await sqlAllAsync(
          `SELECT DISTINCT u.id, u.${usernameCol} AS handle, u.role
           FROM ${tableName} u
           WHERE u.role IN ('root', 'admin', 'mod')
             AND u.${activeCol} = ${activeTrue}
             AND (
               u.role IN ('root', 'admin')
               OR NOT EXISTS (SELECT 1 FROM moderation_scopes ms WHERE ms.user_id = u.id)
               OR EXISTS (SELECT 1 FROM moderation_scopes ms WHERE ms.user_id = u.id AND ms.graduation_year = ?)
             )`,
          [gy]
        );
        return Array.isArray(rows) ? rows : [];
      }

      const rows = await sqlAllAsync(
        `SELECT id, ${usernameCol} AS handle, role
         FROM ${tableName}
         WHERE role IN ('root', 'admin', 'mod')
           AND ${activeCol} = ${activeTrue}`,
        []
      );
      if (!Array.isArray(rows)) return [];

      return rows.filter((u) => {
        const role = normalizeRole(u.role);
        switch (channel) {
          case CHANNEL.ROOT_CRITICAL:
            return role === 'root';
          case CHANNEL.ADMIN_OPS:
            return role === 'root' || role === 'admin';
          case CHANNEL.MODERATOR_QUEUE:
            return role === 'root' || role === 'admin' || role === 'mod';
          case CHANNEL.SECURITY_WATCH:
            return role === 'root' || role === 'admin';
          default:
            return false;
        }
      });
    } catch (err) {
      writeAppLog('error', 'admin_push_resolve_recipients_failed', { channel, message: err?.message || 'unknown' });
      return [];
    }
  }

  async function send({ channel, type, title, body, route, eventId, actorId = null, graduationYear = null }) {
    const recipients = await resolveRecipients(channel, graduationYear);
    if (!recipients.length) return { ok: true, sent: 0, skipped: 0 };

    let sent = 0;
    let skipped = 0;

    for (const recipient of recipients) {
      try {
        const result = await dispatchPushNotification({
          notificationId: null,
          userId: recipient.id,
          notificationType: type,
          message: body,
          sourceUserId: actorId,
          entityId: null
        });
        if (result?.ok) {
          sent++;
        } else {
          skipped++;
        }
      } catch (err) {
        skipped++;
        writeAppLog('warn', 'admin_push_dispatch_failed', {
          channel, type, recipientId: recipient.id, message: err?.message || 'unknown'
        });
      }
    }

    writeAppLog('info', 'admin_push_sent', { channel, type, eventId, sent, skipped, route });
    return { ok: true, sent, skipped };
  }

  return {
    CHANNEL,
    DEEP_LINK,

    async notifyFactoryReset({ actorId, actorHandle }) {
      return send({
        channel: CHANNEL.ROOT_CRITICAL,
        type: 'admin_factory_reset',
        title: 'Factory reset başlatıldı',
        body: `@${actorHandle || 'bilinmeyen'} factory reset işlemini başlattı.`,
        route: DEEP_LINK.ADMIN,
        eventId: `factory_reset_${Date.now()}`,
        actorId
      });
    },

    async notifyDbRestore({ actorId, actorHandle, operation }) {
      return send({
        channel: CHANNEL.ROOT_CRITICAL,
        type: 'admin_db_restore',
        title: 'Veritabanı geri yüklendi',
        body: `@${actorHandle || 'bilinmeyen'} ${operation || 'DB'} işlemi gerçekleştirdi.`,
        route: DEEP_LINK.DATABASE,
        eventId: `db_restore_${Date.now()}`,
        actorId
      });
    },

    async notifyDbDriverSwitch({ actorId, actorHandle, from, to }) {
      return send({
        channel: CHANNEL.ROOT_CRITICAL,
        type: 'admin_db_driver_switch',
        title: 'DB driver geçişi başlatıldı',
        body: `@${actorHandle || 'bilinmeyen'} driver geçişi başlattı: ${from} → ${to}.`,
        route: DEEP_LINK.DATABASE,
        eventId: `db_switch_${Date.now()}`,
        actorId
      });
    },

    async notifyPermissionGroupChange({ actorId, actorHandle, groupName, action }) {
      return send({
        channel: CHANNEL.ROOT_CRITICAL,
        type: 'admin_permission_group_changed',
        title: 'İzin grubu değiştirildi',
        body: `@${actorHandle || 'bilinmeyen'} "${groupName}" grubunu ${action || 'güncelledi'}.`,
        route: DEEP_LINK.PERMISSIONS,
        eventId: `perm_group_${Date.now()}`,
        actorId
      });
    },

    async notifyUserPermissionChange({ actorId, actorHandle, targetHandle, groupName }) {
      return send({
        channel: CHANNEL.ROOT_CRITICAL,
        type: 'admin_user_permission_changed',
        title: 'Kullanıcı izin grubu değiştirildi',
        body: `@${actorHandle || 'bilinmeyen'}, @${targetHandle || 'bilinmeyen'} kullanıcısını "${groupName}" grubuna atadı.`,
        route: DEEP_LINK.PERMISSIONS,
        eventId: `user_perm_${Date.now()}`,
        actorId
      });
    },

    async notifyLargeQueueSpike({ channel = CHANNEL.ADMIN_OPS, queueType, count, graduationYear = null }) {
      return send({
        channel,
        type: 'admin_queue_spike',
        title: 'Kuyruk uyarısı',
        body: `${queueType} kuyruğunda ${count} bekleyen kayıt var.`,
        route: DEEP_LINK.REQUESTS,
        eventId: `queue_spike_${Date.now()}`,
        graduationYear
      });
    },

    async notifySecurityAnomaly({ actorId, detail, route = DEEP_LINK.AUTH_SECURITY }) {
      return send({
        channel: CHANNEL.SECURITY_WATCH,
        type: 'admin_security_anomaly',
        title: 'Güvenlik uyarısı',
        body: detail || 'Anormal auth aktivitesi tespit edildi.',
        route,
        eventId: `security_${Date.now()}`,
        actorId
      });
    },

    async notifyBroadcastResult({ actorId, actorHandle, inserted, sentCount, failedCount }) {
      return send({
        channel: CHANNEL.ADMIN_OPS,
        type: 'admin_broadcast_result',
        title: 'Yayın tamamlandı',
        body: `@${actorHandle || 'bilinmeyen'}: ${sentCount} push iletildi, ${failedCount} başarısız.`,
        route: DEEP_LINK.NOTIFICATIONS,
        eventId: `broadcast_${Date.now()}`,
        actorId
      });
    }
  };
}
