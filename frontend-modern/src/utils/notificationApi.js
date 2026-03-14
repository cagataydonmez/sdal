import { readApiPayload } from './api.js';
import { emitAppChange } from './live.js';

async function postNotificationAction(pathname, body = null, { keepalive = false } = {}) {
  const res = await fetch(pathname, {
    method: 'POST',
    credentials: 'include',
    keepalive,
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined
  });
  const { data, message, code } = await readApiPayload(res, '');
  return { ok: res.ok, data, message, code };
}

export async function openNotification(notificationId) {
  const result = await postNotificationAction(`/api/new/notifications/${notificationId}/open`, null, { keepalive: true });
  if (result.ok) {
    emitAppChange('notification:opened', { id: Number(notificationId || 0) });
    emitAppChange('notification:read', { id: Number(notificationId || 0) });
  }
  return result;
}

export async function readNotification(notificationId) {
  const result = await postNotificationAction(`/api/new/notifications/${notificationId}/read`);
  if (result.ok) {
    emitAppChange('notification:read', { id: Number(notificationId || 0) });
  }
  return result;
}

export async function bulkReadNotifications(ids = []) {
  const result = await postNotificationAction('/api/new/notifications/bulk-read', { ids });
  if (result.ok) {
    emitAppChange('notification:read', { ids: Array.isArray(ids) ? ids : [] });
  }
  return result;
}

export async function runNotificationAction(action) {
  if (!action?.endpoint || !action?.method) {
    return { ok: false, data: null, message: 'Geçersiz bildirim aksiyonu.', code: 'INVALID_NOTIFICATION_ACTION' };
  }
  const result = await postNotificationAction(action.endpoint, action.body || null);
  if (result.ok) {
    emitAppChange('notification:action', { kind: action.kind || '', endpoint: action.endpoint });
    emitAppChange('notification:read', {});
  }
  return result;
}
