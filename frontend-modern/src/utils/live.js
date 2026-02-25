import { useEffect } from 'react';

const APP_CHANGE_EVENT = 'sdal:app-change';

export function emitAppChange(type, payload = {}) {
  window.dispatchEvent(
    new CustomEvent(APP_CHANGE_EVENT, {
      detail: { type, ...payload, at: Date.now() }
    })
  );
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

    const timer = setInterval(runRefresh, intervalMs);
    window.addEventListener(APP_CHANGE_EVENT, onAppChange);
    return () => {
      clearInterval(timer);
      window.removeEventListener(APP_CHANGE_EVENT, onAppChange);
    };
  }, [callback, intervalMs, enabled, eventKey]);
}
