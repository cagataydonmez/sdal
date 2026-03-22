import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useI18n } from '../utils/i18n.jsx';
import { CLOSE_DIALOG_EVENT, OPEN_DIALOG_EVENT, resolveDialog } from '../utils/dialogs.js';

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
  const [dialogQueue, setDialogQueue] = useState([]);
  const [promptValue, setPromptValue] = useState('');
  const delayTimerRef = useRef(null);
  const dialogRef = useRef(null);
  const dialogInputRef = useRef(null);
  const dialogTriggerRef = useRef(null);
  const currentDialog = dialogQueue[0] || null;

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
    const onDialogOpen = (event) => {
      const detail = event?.detail;
      if (!detail?.id) return;
      dialogTriggerRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
      setDialogQueue((prev) => [...prev, detail]);
    };
    const onDialogClose = (event) => {
      const closedId = Number(event?.detail?.id || 0);
      setDialogQueue((prev) => prev.filter((item) => Number(item.id) !== closedId));
    };
    const onVerificationRequired = (event) => {
      setVerificationModal({
        open: true,
        message: String(event?.detail?.message || t('verification_required_popup_message')),
        verificationUrl: String(event?.detail?.verificationUrl || '/new/profile/verification')
      });
    };
    window.addEventListener(VERIFICATION_REQUIRED, onVerificationRequired);
    window.addEventListener(OPEN_DIALOG_EVENT, onDialogOpen);
    window.addEventListener(CLOSE_DIALOG_EVENT, onDialogClose);
    return () => {
      window.removeEventListener(NET_START, onStart);
      window.removeEventListener(NET_END, onEnd);
      window.removeEventListener(VERIFICATION_REQUIRED, onVerificationRequired);
      window.removeEventListener(OPEN_DIALOG_EVENT, onDialogOpen);
      window.removeEventListener(CLOSE_DIALOG_EVENT, onDialogClose);
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

  useEffect(() => {
    if (!currentDialog) return;
    setPromptValue(currentDialog.defaultValue || '');
  }, [currentDialog]);

  useEffect(() => {
    if (!currentDialog) return undefined;
    const target = currentDialog.type === 'prompt'
      ? dialogInputRef.current
      : dialogRef.current?.querySelector('button, a, input, textarea, select');
    if (target instanceof HTMLElement) target.focus();

    const onKeyDown = (event) => {
      if (!dialogRef.current) return;
      if (event.key === 'Escape') {
        event.preventDefault();
        resolveDialog(currentDialog.id, currentDialog.type === 'alert' ? true : null);
        return;
      }
      if (event.key !== 'Tab') return;
      const focusable = Array.from(dialogRef.current.querySelectorAll('button, [href], input, textarea, select, [tabindex]:not([tabindex="-1"])'))
        .filter((element) => !element.hasAttribute('disabled'));
      if (!focusable.length) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('keydown', onKeyDown);
      if (dialogQueue.length <= 1 && dialogTriggerRef.current instanceof HTMLElement) {
        dialogTriggerRef.current.focus();
      }
    };
  }, [currentDialog, dialogQueue.length]);

  const dialogTitle = currentDialog?.title || (
    currentDialog?.type === 'confirm'
      ? t('Onay gerekli')
      : currentDialog?.type === 'prompt'
        ? t('Bilgi girin')
        : t('Bilgilendirme')
  );
  const dialogConfirmLabel = currentDialog?.confirmLabel || (currentDialog?.type === 'prompt' ? t('save') : t('close'));
  const dialogCancelLabel = currentDialog?.cancelLabel || t('close');

  return (
    <>
      <div className={`global-feedback ${active ? 'visible' : ''}`} aria-live="polite" aria-atomic="true">
        <div className="global-feedback-chip">{label}</div>
      </div>
      {currentDialog ? (
        <div className="story-modal dialog-backdrop" onClick={() => resolveDialog(currentDialog.id, currentDialog.type === 'alert' ? true : null)}>
          <div
            ref={dialogRef}
            className={`verification-popup app-dialog app-dialog-${currentDialog.type}${currentDialog.tone ? ` is-${currentDialog.tone}` : ''}`}
            role="dialog"
            aria-modal="true"
            aria-labelledby={`app-dialog-title-${currentDialog.id}`}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 id={`app-dialog-title-${currentDialog.id}`}>{dialogTitle}</h3>
            {currentDialog.message ? <p className="muted">{currentDialog.message}</p> : null}
            {currentDialog.type === 'prompt' ? (
              <input
                ref={dialogInputRef}
                className="input"
                value={promptValue}
                placeholder={currentDialog.placeholder || ''}
                onChange={(e) => setPromptValue(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') resolveDialog(currentDialog.id, promptValue);
                }}
              />
            ) : null}
            <div className="story-actions">
              {currentDialog.type !== 'alert' ? (
                <button className="btn ghost" onClick={() => resolveDialog(currentDialog.id, currentDialog.type === 'confirm' ? false : null)}>
                  {dialogCancelLabel}
                </button>
              ) : null}
              <button
                className="btn primary"
                onClick={() => resolveDialog(
                  currentDialog.id,
                  currentDialog.type === 'confirm' ? true : currentDialog.type === 'prompt' ? promptValue : true
                )}
              >
                {dialogConfirmLabel}
              </button>
            </div>
          </div>
        </div>
      ) : null}
      {verificationModal.open ? (
        <div className="story-modal" onClick={() => setVerificationModal((prev) => ({ ...prev, open: false }))}>
          <div className="verification-popup" role="dialog" aria-modal="true" aria-labelledby="verification-required-title" onClick={(e) => e.stopPropagation()}>
            <h3 id="verification-required-title">{t('verification_required_popup_title')}</h3>
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
