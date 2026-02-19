const BB_TAG_REGEX = /\[(\/)?(b|i|u|s|strike|left|center|right|justify|quote|size|color)\b[^\]]*\]/i;
const ALLOWED_STYLE_PROPS = new Set(['color', 'font-size', 'text-align']);
const ALLOWED_ALIGN = new Set(['left', 'center', 'right', 'justify']);

export function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function hasHtmlTag(value) {
  return /<\/?[a-z][^>]*>/i.test(String(value || ''));
}

function hasBbcode(value) {
  return BB_TAG_REGEX.test(String(value || ''));
}

function clampFontSize(value) {
  const num = Number.parseInt(String(value || ''), 10);
  if (!Number.isFinite(num)) return null;
  return Math.max(10, Math.min(72, num));
}

function normalizeColor(value) {
  const color = String(value || '').trim();
  if (!color) return null;
  if (/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(color)) return color;
  if (/^rgb(a)?\([0-9,\s.%]+\)$/i.test(color)) return color;
  if (/^[a-z]{3,20}$/i.test(color)) return color.toLowerCase();
  return null;
}

function filterStyle(styleText) {
  const raw = String(styleText || '');
  if (!raw.trim()) return '';
  const safe = [];
  for (const chunk of raw.split(';')) {
    const [propRaw, valRaw] = chunk.split(':');
    if (!propRaw || !valRaw) continue;
    const prop = propRaw.trim().toLowerCase();
    const value = valRaw.trim();
    if (!ALLOWED_STYLE_PROPS.has(prop)) continue;
    if (prop === 'color') {
      const color = normalizeColor(value);
      if (color) safe.push(`color:${color}`);
      continue;
    }
    if (prop === 'font-size') {
      const size = clampFontSize(value.replace(/px$/i, ''));
      if (size) safe.push(`font-size:${size}px`);
      continue;
    }
    if (prop === 'text-align') {
      const align = value.toLowerCase();
      if (ALLOWED_ALIGN.has(align)) safe.push(`text-align:${align}`);
    }
  }
  return safe.join(';');
}

function cleanElement(node, doc) {
  if (!node || node.nodeType !== 1) return;
  const tag = String(node.tagName || '').toLowerCase();

  if (tag === 'font') {
    const span = doc.createElement('span');
    const color = normalizeColor(node.getAttribute('color') || '');
    const sizeMap = { 1: 10, 2: 12, 3: 14, 4: 16, 5: 18, 6: 24, 7: 32 };
    const sizeKey = Number.parseInt(String(node.getAttribute('size') || ''), 10);
    const size = sizeMap[sizeKey] || null;
    if (color) span.style.color = color;
    if (size) span.style.fontSize = `${size}px`;
    span.innerHTML = node.innerHTML;
    node.replaceWith(span);
    cleanElement(span, doc);
    return;
  }

  const allowed = new Set(['b', 'strong', 'i', 'em', 'u', 's', 'br', 'p', 'div', 'span', 'blockquote', 'ul', 'ol', 'li', 'a']);
  if (!allowed.has(tag)) {
    const frag = doc.createDocumentFragment();
    while (node.firstChild) frag.appendChild(node.firstChild);
    node.replaceWith(frag);
    return;
  }

  for (const attr of Array.from(node.attributes || [])) {
    const name = String(attr.name || '').toLowerCase();
    if (name.startsWith('on')) {
      node.removeAttribute(attr.name);
      continue;
    }
    if (tag === 'a' && name === 'href') continue;
    if (tag === 'a' && (name === 'target' || name === 'rel')) continue;
    if ((tag === 'span' || tag === 'div' || tag === 'p') && name === 'style') continue;
    node.removeAttribute(attr.name);
  }

  if (tag === 'a') {
    const href = String(node.getAttribute('href') || '').trim();
    if (/^https?:\/\//i.test(href) || /^mailto:/i.test(href)) {
      node.setAttribute('target', '_blank');
      node.setAttribute('rel', 'noopener noreferrer');
    } else {
      node.removeAttribute('href');
      node.removeAttribute('target');
      node.removeAttribute('rel');
    }
  }

  if (tag === 'span' || tag === 'div' || tag === 'p') {
    const safeStyle = filterStyle(node.getAttribute('style') || '');
    if (safeStyle) {
      node.setAttribute('style', safeStyle);
    } else {
      node.removeAttribute('style');
    }
  }

  const children = Array.from(node.childNodes || []);
  for (const child of children) {
    if (child.nodeType === 1) cleanElement(child, doc);
  }
}

export function sanitizeRichTextHtml(input) {
  const raw = String(input || '');
  if (!raw.trim()) return '';
  if (typeof window === 'undefined' || typeof DOMParser === 'undefined') {
    return raw;
  }
  const doc = new DOMParser().parseFromString(`<div>${raw}</div>`, 'text/html');
  const root = doc.body.firstElementChild;
  if (!root) return '';
  const dangerTags = root.querySelectorAll('script,style,iframe,object,embed,link,meta');
  dangerTags.forEach((el) => el.remove());
  const nodes = Array.from(root.querySelectorAll('*'));
  for (const node of nodes) cleanElement(node, doc);
  return String(root.innerHTML || '').trim();
}

function bbcodeToHtml(input) {
  let text = escapeHtml(input);
  text = text.replace(/\r?\n/g, '<br>');
  text = text
    .replace(/\[b\]([\s\S]*?)\[\/b\]/gi, '<b>$1</b>')
    .replace(/\[i\]([\s\S]*?)\[\/i\]/gi, '<i>$1</i>')
    .replace(/\[u\]([\s\S]*?)\[\/u\]/gi, '<u>$1</u>')
    .replace(/\[(s|strike)\]([\s\S]*?)\[\/(s|strike)\]/gi, '<s>$2</s>')
    .replace(/\[left\]([\s\S]*?)\[\/left\]/gi, '<div style="text-align:left;">$1</div>')
    .replace(/\[center\]([\s\S]*?)\[\/center\]/gi, '<div style="text-align:center;">$1</div>')
    .replace(/\[right\]([\s\S]*?)\[\/right\]/gi, '<div style="text-align:right;">$1</div>')
    .replace(/\[justify\]([\s\S]*?)\[\/justify\]/gi, '<div style="text-align:justify;">$1</div>')
    .replace(/\[quote\]([\s\S]*?)\[\/quote\]/gi, '<blockquote>$1</blockquote>')
    .replace(/\[size=(\d{1,3})\]([\s\S]*?)\[\/size\]/gi, (_m, size, body) => {
      const px = clampFontSize(size) || 14;
      return `<span style="font-size:${px}px;">${body}</span>`;
    })
    .replace(/\[color=([#a-zA-Z0-9(),.\s%-]{1,30})\]([\s\S]*?)\[\/color\]/gi, (_m, color, body) => {
      const safe = normalizeColor(color) || '#1b7f6b';
      return `<span style="color:${safe};">${body}</span>`;
    });

  const linked = text.replace(
    /(^|[\s>])((https?:\/\/|www\.)[^\s<]+)/gi,
    (full, lead, url) => {
      const href = /^https?:\/\//i.test(url) ? url : `http://${url}`;
      return `${lead}<a href="${href}" target="_blank" rel="noopener noreferrer">${url}</a>`;
    }
  );
  return linked;
}

export function renderRichTextHtml(value) {
  const raw = String(value || '');
  if (!raw.trim()) return '';
  if (hasHtmlTag(raw)) return sanitizeRichTextHtml(raw);
  if (hasBbcode(raw)) return sanitizeRichTextHtml(bbcodeToHtml(raw));
  return sanitizeRichTextHtml(escapeHtml(raw).replace(/\r?\n/g, '<br>'));
}

export function toEditorHtml(value) {
  return renderRichTextHtml(value);
}

export function richTextToPlainText(value) {
  const html = renderRichTextHtml(value);
  if (!html) return '';
  if (typeof window === 'undefined' || typeof DOMParser === 'undefined') {
    return String(html).replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  }
  const doc = new DOMParser().parseFromString(`<div>${html}</div>`, 'text/html');
  return String(doc.body.textContent || '').replace(/\u00a0/g, ' ').replace(/\s+/g, ' ').trim();
}

export function isRichTextEmpty(value) {
  return !richTextToPlainText(value);
}
