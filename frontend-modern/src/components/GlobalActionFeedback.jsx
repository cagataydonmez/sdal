import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useI18n } from '../utils/i18n.jsx';

const NET_START = 'sdal:net:start';
const NET_END = 'sdal:net:end';
const FEEDBACK_DELAY_MS = 3000;

function emit(name, detail) {
  window.dispatchEvent(new CustomEvent(name, { detail }));
}

function patchFetchOnce() {
  if (typeof window === 'undefined') return;
  if (window.__sdalFetchPatched) return;
  const originalFetch = window.fetch?.bind(window);
  if (!originalFetch) return;
  window.__sdalFetchPatched = true;
  window.__sdalOriginalFetch = originalFetch;
  window.fetch = async (...args) => {
    const options = args?.[1] || {};
    const method = String(options.method || 'GET').toUpperCase();
    const lastActionAt = Number(window.__sdalLastActionAt || 0);
    const interactive = method !== 'GET' || (Date.now() - lastActionAt) < 1800;
    if (interactive) emit(NET_START, { interactive: true });
    try {
      return await originalFetch(...args);
    } finally {
      if (interactive) emit(NET_END, { interactive: true });
    }
  };
}

export default function GlobalActionFeedback() {
  const { t } = useI18n();
  const [pending, setPending] = useState(0);
  const [delayedVisible, setDelayedVisible] = useState(false);
  const delayTimerRef = useRef(null);

  useEffect(() => {
    patchFetchOnce();
    const onStart = (e) => {
      if (e?.detail?.interactive !== true) return;
      setPending((v) => v + 1);
    };
    const onEnd = (e) => {
      if (e?.detail?.interactive !== true) return;
      setPending((v) => Math.max(0, v - 1));
    };

    window.addEventListener(NET_START, onStart);
    window.addEventListener(NET_END, onEnd);
    return () => {
      window.removeEventListener(NET_START, onStart);
      window.removeEventListener(NET_END, onEnd);
      if (delayTimerRef.current) window.clearTimeout(delayTimerRef.current);
    };
  }, []);

  useEffect(() => {
    if (pending > 0) {
      if (delayTimerRef.current) return;
      delayTimerRef.current = window.setTimeout(() => {
        setDelayedVisible(true);
        delayTimerRef.current = null;
      }, FEEDBACK_DELAY_MS);
      return;
    }
    if (delayTimerRef.current) {
      window.clearTimeout(delayTimerRef.current);
      delayTimerRef.current = null;
    }
    setDelayedVisible(false);
  }, [pending]);

  const active = delayedVisible && pending > 0;
  const label = useMemo(() => {
    if (active) return t('loading');
    return '';
  }, [active, t]);

  return (
    <div className={`global-feedback ${active ? 'visible' : ''}`} aria-live="polite" aria-atomic="true">
      <div className="global-feedback-chip">{label}</div>
    </div>
  );
}
