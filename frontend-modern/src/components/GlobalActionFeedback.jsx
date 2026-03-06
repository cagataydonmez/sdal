import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useI18n } from '../utils/i18n.jsx';

const NET_START = 'sdal:net:start';
const NET_END = 'sdal:net:end';
const VERIFICATION_REQUIRED = 'sdal:verification-required';
const FEEDBACK_DELAY_MS = 3000;

function extractErrorMessage(rawText) {
  const text = String(rawText || '').trim();
  if (!text) return '';
  if (!(text.startsWith('{') || text.startsWith('['))) return text;
  try {
    const payload = JSON.parse(text);
    if (typeof payload === 'string') return payload;
    if (payload && typeof payload === 'object') {
      const candidate = payload.message || payload.error || payload.detail || payload.title;
      if (candidate != null) return String(candidate);
    }
  } catch {
    return text;
  }
  return text;
}

function withSanitizedErrorText(response) {
  if (response.ok) return response;
  return new Proxy(response, {
    get(target, prop, receiver) {
      if (prop === 'text') {
        return async () => {
          const raw = await target.clone().text();
          return extractErrorMessage(raw);
        };
      }
      const value = Reflect.get(target, prop, target);
      if (typeof value === 'function') return value.bind(target);
      return value;
    }
  });
}

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
      const response = await originalFetch(...args);
      if (!response.ok && response.status === 403 && method !== 'GET') {
        try {
          const payload = await response.clone().json();
          if (String(payload?.error || '').toUpperCase() === 'VERIFICATION_REQUIRED') {
            emit(VERIFICATION_REQUIRED, {
              message: payload?.message,
              verificationUrl: payload?.verificationUrl || '/new/profile/verification'
            });
          }
        } catch {
          // ignore non-json responses
        }
      }
      return withSanitizedErrorText(response);
    } finally {
      if (interactive) emit(NET_END, { interactive: true });
    }
  };
}

export default function GlobalActionFeedback() {
  const { t } = useI18n();
  const [pending, setPending] = useState(0);
  const [delayedVisible, setDelayedVisible] = useState(false);
  const [verificationModal, setVerificationModal] = useState({ open: false, message: '', verificationUrl: '/new/profile/verification' });
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
    const onVerificationRequired = (event) => {
      setVerificationModal({
        open: true,
        message: String(event?.detail?.message || t('verification_required_popup_message')),
        verificationUrl: String(event?.detail?.verificationUrl || '/new/profile/verification')
      });
    };
    window.addEventListener(VERIFICATION_REQUIRED, onVerificationRequired);
    return () => {
      window.removeEventListener(NET_START, onStart);
      window.removeEventListener(NET_END, onEnd);
      window.removeEventListener(VERIFICATION_REQUIRED, onVerificationRequired);
      if (delayTimerRef.current) window.clearTimeout(delayTimerRef.current);
    };
  }, [t]);

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
    <>
      <div className={`global-feedback ${active ? 'visible' : ''}`} aria-live="polite" aria-atomic="true">
        <div className="global-feedback-chip">{label}</div>
      </div>
      {verificationModal.open ? (
        <div className="story-modal" onClick={() => setVerificationModal((prev) => ({ ...prev, open: false }))}>
          <div className="verification-popup" onClick={(e) => e.stopPropagation()}>
            <h3>{t('verification_required_popup_title')}</h3>
            <p className="muted">{verificationModal.message}</p>
            <div className="story-actions">
              <button className="btn ghost" onClick={() => setVerificationModal((prev) => ({ ...prev, open: false }))}>{t('close')}</button>
              <a className="btn primary" href={verificationModal.verificationUrl}>{t('verification_required_popup_cta')}</a>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}
