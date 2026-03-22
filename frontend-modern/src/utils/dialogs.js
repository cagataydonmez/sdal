const OPEN_DIALOG_EVENT = 'sdal:dialog:open';
const CLOSE_DIALOG_EVENT = 'sdal:dialog:close';

let nextDialogId = 1;
const resolvers = new Map();

function dispatchDialog(type, options = {}) {
  if (typeof window === 'undefined') {
    if (type === 'confirm') return Promise.resolve(false);
    if (type === 'prompt') return Promise.resolve(null);
    return Promise.resolve(undefined);
  }

  const id = nextDialogId++;
  return new Promise((resolve) => {
    resolvers.set(id, resolve);
    window.dispatchEvent(new CustomEvent(OPEN_DIALOG_EVENT, {
      detail: {
        id,
        type,
        title: String(options.title || '').trim(),
        message: String(options.message || '').trim(),
        confirmLabel: String(options.confirmLabel || '').trim(),
        cancelLabel: String(options.cancelLabel || '').trim(),
        placeholder: String(options.placeholder || '').trim(),
        defaultValue: options.defaultValue == null ? '' : String(options.defaultValue),
        tone: String(options.tone || '').trim()
      }
    }));
  });
}

export function resolveDialog(id, value) {
  const resolve = resolvers.get(id);
  if (!resolve) return;
  resolvers.delete(id);
  resolve(value);
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent(CLOSE_DIALOG_EVENT, { detail: { id } }));
  }
}

export function openAlert(options = {}) {
  return dispatchDialog('alert', options).then(() => undefined);
}

export function openConfirm(options = {}) {
  return dispatchDialog('confirm', options).then((value) => Boolean(value));
}

export function openPrompt(options = {}) {
  return dispatchDialog('prompt', options).then((value) => (value == null ? null : String(value)));
}

export { OPEN_DIALOG_EVENT, CLOSE_DIALOG_EVENT };
