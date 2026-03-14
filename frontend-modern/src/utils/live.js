import { useEffect } from 'react';

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
  const detail = { type, ...payload, at: Date.now(), sourceId: APP_CHANGE_SOURCE_ID };
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

export function useLiveRefresh(callback, options = {}) {
  const { intervalMs = 10000, eventTypes = ['*'], enabled = true } = options;
  const eventKey = eventTypes.join('|');

  useEffect(() => {
    if (!enabled) return undefined;

    function runRefresh() {
      if (document.hidden) return;
      callback();
    }

    function onAppChange(event) {
      const eventType = event?.detail?.type || '*';
      if (eventTypes.includes('*') || eventTypes.includes(eventType)) {
        callback();
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
    const onChannelMessage = (event) => {
      const detail = event?.data;
      if (!detail || detail.sourceId === APP_CHANGE_SOURCE_ID) return;
      onAppChange({ detail });
    };

    const timer = setInterval(runRefresh, intervalMs);
    window.addEventListener(APP_CHANGE_EVENT, onAppChange);
    window.addEventListener('storage', onStorage);
    channel?.addEventListener?.('message', onChannelMessage);
    return () => {
      clearInterval(timer);
      window.removeEventListener(APP_CHANGE_EVENT, onAppChange);
      window.removeEventListener('storage', onStorage);
      channel?.removeEventListener?.('message', onChannelMessage);
    };
  }, [callback, intervalMs, enabled, eventKey]);
}
