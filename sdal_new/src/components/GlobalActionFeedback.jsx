import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useI18n } from '../utils/i18n.jsx';

const NET_START = 'sdal:net:start';
const NET_END = 'sdal:net:end';
const PULSE = 'sdal:action:pulse';

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
  const [pulseVisible, setPulseVisible] = useState(false);
  const pulseTimerRef = useRef(null);

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
    const onPulse = () => {
      if (pulseTimerRef.current) window.clearTimeout(pulseTimerRef.current);
      setPulseVisible(true);
      pulseTimerRef.current = window.setTimeout(() => setPulseVisible(false), 650);
    };

    const onClick = (e) => {
      const target = e.target;
      if (!(target instanceof Element)) return;
      const clickable = target.closest('button, [role="button"], .btn, a.btn');
      if (!clickable) return;
      window.__sdalLastActionAt = Date.now();
      emit(PULSE);
    };

    window.addEventListener(NET_START, onStart);
    window.addEventListener(NET_END, onEnd);
    window.addEventListener(PULSE, onPulse);
    document.addEventListener('click', onClick, true);
    return () => {
      window.removeEventListener(NET_START, onStart);
      window.removeEventListener(NET_END, onEnd);
      window.removeEventListener(PULSE, onPulse);
      document.removeEventListener('click', onClick, true);
      if (pulseTimerRef.current) window.clearTimeout(pulseTimerRef.current);
    };
  }, []);

  const active = pending > 0 || pulseVisible;
  const label = useMemo(() => {
    if (pending > 0) return t('loading');
    if (pulseVisible) return t('processing');
    return '';
  }, [pending, pulseVisible, t]);

  return (
    <div className={`global-feedback ${active ? 'visible' : ''}`} aria-live="polite" aria-atomic="true">
      <div className="global-feedback-bar" />
      <div className="global-feedback-chip">{label}</div>
    </div>
  );
}
