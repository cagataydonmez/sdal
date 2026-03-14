export const NOTIFICATION_TELEMETRY_EVENTS = Object.freeze({
  impression: 'impression',
  open: 'open',
  action: 'action',
  landed: 'landed',
  bounce: 'bounce',
  noAction: 'no_action'
});

export async function sendNotificationTelemetry(events = []) {
  const normalizedEvents = (Array.isArray(events) ? events : [events]).filter((event) => event && event.event_name);
  if (!normalizedEvents.length) return;
  try {
    await fetch('/api/new/notifications/telemetry', {
      method: 'POST',
      credentials: 'include',
      keepalive: true,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        events: normalizedEvents.map((event) => ({
          notification_id: Number(event.notification_id || 0) || null,
          event_name: event.event_name,
          notification_type: event.notification_type || '',
          surface: event.surface || 'unknown',
          action_kind: event.action_kind || ''
        }))
      })
    });
  } catch {
    // Telemetry should never interrupt notification interactions.
  }
}
