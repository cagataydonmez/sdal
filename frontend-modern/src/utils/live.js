import { useEffect, useRef } from 'react';

const APP_CHANGE_EVENT = 'sdal:app-change';
const APP_CHANGE_STORAGE_KEY = 'sdal:app-change:broadcast';
const APP_CHANGE_CHANNEL_NAME = 'sdal-app-change';
const APP_CHANGE_SOURCE_ID = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;

function dispatchLocalAppChange(detail) {
  window.dispatchEvent(
    new CustomEvent(APP_CHANGE_EVENT, {
      detail
    })
  );
}

function getBroadcastChannel() {
  if (typeof window === 'undefined' || typeof window.BroadcastChannel !== 'function') return null;
  if (!window.__sdalAppChangeChannel) {
    window.__sdalAppChangeChannel = new window.BroadcastChannel(APP_CHANGE_CHANNEL_NAME);
  }
  return window.__sdalAppChangeChannel;
}

export function emitAppChange(type, payload = {}) {
  const detail = { ...payload, eventType: type, type, at: Date.now(), sourceId: APP_CHANGE_SOURCE_ID };
  dispatchLocalAppChange(detail);
  try {
    getBroadcastChannel()?.postMessage(detail);
  } catch {
    // ignore broadcast channel failures
  }
  try {
    if (typeof window !== 'undefined' && window.localStorage) {
      window.localStorage.setItem(APP_CHANGE_STORAGE_KEY, JSON.stringify(detail));
    }
  } catch {
    // ignore storage failures
  }
}

function getNetworkRefreshMultiplier() {
  if (typeof navigator === 'undefined') return 1;
  const connection = navigator.connection || navigator.mozConnection || navigator.webkitConnection;
  if (!connection) return 1;
  if (connection.saveData) return 3;
  const effectiveType = String(connection.effectiveType || '').toLowerCase();
  if (effectiveType === 'slow-2g' || effectiveType === '2g') return 4;
  if (effectiveType === '3g') return 2;
  return 1;
}

export function useLiveRefresh(callback, options = {}) {
  const {
    intervalMs = 10000,
    hiddenIntervalMs = null,
    eventTypes = ['*'],
    enabled = true,
    onlineOnly = true,
    eventDebounceMs = 250,
    resumeRefresh = true
  } = options;
  const eventKey = eventTypes.join('|');
  const callbackRef = useRef(callback);

  useEffect(() => {
    callbackRef.current = callback;
  }, [callback]);

  useEffect(() => {
    if (!enabled) return undefined;
    let timerId = 0;
    let eventTimerId = 0;

    function clearTimers() {
      if (timerId) {
        window.clearTimeout(timerId);
        timerId = 0;
      }
      if (eventTimerId) {
        window.clearTimeout(eventTimerId);
        eventTimerId = 0;
      }
    }

    function isRefreshBlocked() {
      if (typeof document !== 'undefined' && document.hidden) return true;
      if (!onlineOnly || typeof navigator === 'undefined') return false;
      return navigator.onLine === false;
    }

    function getDelay() {
      const baseInterval = typeof document !== 'undefined' && document.hidden
        ? (hiddenIntervalMs ?? Math.max(intervalMs * 3, intervalMs))
        : intervalMs;
      if (!Number.isFinite(baseInterval) || baseInterval <= 0) return 0;
      return Math.round(baseInterval * getNetworkRefreshMultiplier());
    }

    function runRefresh({ force = false } = {}) {
      if (!force && isRefreshBlocked()) return;
      callbackRef.current?.();
    }

    function scheduleNextRefresh() {
      if (!Number.isFinite(intervalMs) || intervalMs <= 0) return;
      const delay = getDelay();
      if (delay <= 0) return;
      timerId = window.setTimeout(() => {
        runRefresh();
        scheduleNextRefresh();
      }, delay);
    }

    function scheduleEventRefresh() {
      if (eventDebounceMs <= 0) {
        runRefresh();
        return;
      }
      if (eventTimerId) return;
      eventTimerId = window.setTimeout(() => {
        eventTimerId = 0;
        runRefresh();
      }, eventDebounceMs);
    }

    function onAppChange(event) {
      const eventType = event?.detail?.type || '*';
      if (eventTypes.includes('*') || eventTypes.includes(eventType)) {
        scheduleEventRefresh();
      }
    }

    function onStorage(event) {
      if (event?.key !== APP_CHANGE_STORAGE_KEY || !event.newValue) return;
      try {
        const detail = JSON.parse(event.newValue);
        if (!detail || detail.sourceId === APP_CHANGE_SOURCE_ID) return;
        onAppChange({ detail });
      } catch {
        // ignore malformed payloads
      }
    }

    const channel = getBroadcastChannel();
    const visibilityTarget = typeof document !== 'undefined' ? document : null;
    const onChannelMessage = (event) => {
      const detail = event?.data;
      if (!detail || detail.sourceId === APP_CHANGE_SOURCE_ID) return;
      onAppChange({ detail });
    };

    const onVisibilityChange = () => {
      if (!resumeRefresh) return;
      if (typeof document !== 'undefined' && !document.hidden) {
        clearTimers();
        runRefresh();
        scheduleNextRefresh();
        return;
      }
      if (timerId) {
        window.clearTimeout(timerId);
        timerId = 0;
      }
      scheduleNextRefresh();
    };

    const onOnline = () => {
      if (!resumeRefresh) return;
      clearTimers();
      if (typeof document !== 'undefined' && document.hidden) {
        scheduleNextRefresh();
        return;
      }
      runRefresh({ force: true });
      scheduleNextRefresh();
    };

    const connection = typeof navigator !== 'undefined'
      ? (navigator.connection || navigator.mozConnection || navigator.webkitConnection)
      : null;
    const onConnectionChange = () => {
      if (timerId) {
        window.clearTimeout(timerId);
        timerId = 0;
      }
      scheduleNextRefresh();
    };

    window.addEventListener(APP_CHANGE_EVENT, onAppChange);
    window.addEventListener('storage', onStorage);
    visibilityTarget?.addEventListener('visibilitychange', onVisibilityChange);
    if (onlineOnly) window.addEventListener('online', onOnline);
    channel?.addEventListener?.('message', onChannelMessage);
    connection?.addEventListener?.('change', onConnectionChange);
    scheduleNextRefresh();

    return () => {
      clearTimers();
      window.removeEventListener(APP_CHANGE_EVENT, onAppChange);
      window.removeEventListener('storage', onStorage);
      visibilityTarget?.removeEventListener('visibilitychange', onVisibilityChange);
      if (onlineOnly) window.removeEventListener('online', onOnline);
      channel?.removeEventListener?.('message', onChannelMessage);
      connection?.removeEventListener?.('change', onConnectionChange);
    };
  }, [enabled, eventDebounceMs, eventKey, hiddenIntervalMs, intervalMs, onlineOnly, resumeRefresh]);
}
