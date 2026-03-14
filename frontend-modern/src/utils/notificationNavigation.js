import { useEffect, useRef } from 'react';
import { sendNotificationTelemetry } from './notificationTelemetry.js';

const NAV_SESSION_PREFIX = 'sdal:notification-nav:';

function sessionKey(notificationId) {
  return `${NAV_SESSION_PREFIX}${Number(notificationId || 0)}`;
}

function readSession(notificationId) {
  if (typeof window === 'undefined' || !window.sessionStorage || !notificationId) return {};
  try {
    const raw = window.sessionStorage.getItem(sessionKey(notificationId));
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

function writeSession(notificationId, patch) {
  if (typeof window === 'undefined' || !window.sessionStorage || !notificationId) return;
  try {
    const current = readSession(notificationId);
    window.sessionStorage.setItem(sessionKey(notificationId), JSON.stringify({ ...current, ...patch }));
  } catch {
    // ignore storage failures
  }
}

export function useNotificationNavigationTracking(notificationId, {
  surface,
  resolved = true,
  noActionMs = 8000,
  bounceMs = 4000
} = {}) {
  const engagedRef = useRef(false);

  useEffect(() => {
    const safeNotificationId = Number(notificationId || 0);
    if (!safeNotificationId || !surface) return undefined;

    const session = readSession(safeNotificationId);
    if (!session.landingSent) {
      void sendNotificationTelemetry({
        notification_id: safeNotificationId,
        event_name: 'landed',
        surface,
        action_kind: resolved ? 'resolved' : 'missing_context'
      });
      writeSession(safeNotificationId, {
        landingSent: true,
        landingStatus: resolved ? 'resolved' : 'missing_context',
        landedAt: Date.now()
      });
    }

    const markEngaged = () => {
      if (engagedRef.current) return;
      engagedRef.current = true;
      writeSession(safeNotificationId, {
        engaged: true,
        engagedAt: Date.now()
      });
    };

    const noActionTimer = window.setTimeout(() => {
      const current = readSession(safeNotificationId);
      if (engagedRef.current || current.noActionSent) return;
      void sendNotificationTelemetry({
        notification_id: safeNotificationId,
        event_name: 'no_action',
        surface,
        action_kind: resolved ? 'resolved' : 'missing_context'
      });
      writeSession(safeNotificationId, {
        noActionSent: true,
        noActionAt: Date.now()
      });
    }, Math.max(1500, Number(noActionMs || 8000)));

    const handleExit = () => {
      const current = readSession(safeNotificationId);
      const landedAt = Number(current.landedAt || Date.now());
      if (engagedRef.current || current.bounceSent || Date.now() - landedAt > Math.max(1000, Number(bounceMs || 4000))) return;
      void sendNotificationTelemetry({
        notification_id: safeNotificationId,
        event_name: 'bounce',
        surface,
        action_kind: resolved ? 'resolved' : 'missing_context'
      });
      writeSession(safeNotificationId, {
        bounceSent: true,
        bounceAt: Date.now()
      });
    };

    window.addEventListener('click', markEngaged, true);
    window.addEventListener('keydown', markEngaged, true);
    window.addEventListener('submit', markEngaged, true);
    window.addEventListener('touchstart', markEngaged, true);
    window.addEventListener('pagehide', handleExit);
    return () => {
      window.clearTimeout(noActionTimer);
      window.removeEventListener('click', markEngaged, true);
      window.removeEventListener('keydown', markEngaged, true);
      window.removeEventListener('submit', markEngaged, true);
      window.removeEventListener('touchstart', markEngaged, true);
      window.removeEventListener('pagehide', handleExit);
    };
  }, [bounceMs, noActionMs, notificationId, resolved, surface]);
}
