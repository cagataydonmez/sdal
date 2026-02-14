export function detectMentionContext(text, caretPos) {
  const value = String(text || '');
  const caret = Number.isFinite(caretPos) ? Math.max(0, Math.min(caretPos, value.length)) : value.length;
  const before = value.slice(0, caret);
  const match = before.match(/(^|\s)@([a-zA-Z0-9._-]*)$/);
  if (!match) return null;
  const query = match[2] || '';
  const start = before.lastIndexOf('@');
  if (start < 0) return null;
  return { query, start, end: caret };
}

export function applyMention(text, context, kadi) {
  if (!context || !kadi) return String(text || '');
  const value = String(text || '');
  const start = Math.max(0, Math.min(context.start, value.length));
  const end = Math.max(start, Math.min(context.end, value.length));
  return `${value.slice(0, start)}@${kadi} ${value.slice(end)}`;
}
