const smileyMap = [
  ':)', ':@', ':))', '8)', ":'(", ':$', ':D', ':*', ':)))', ':#', '*-)', ':(', ':o', ':P', '(:/', ';)'
];
const smileyAlt = [
  ':y1:', ':y2:', ':y3:', ':y4:', ':y5:', ':y6:', ':y7:', ':y8:', ':y9:', ':y10:', ':y11:', ':y12:', ':y13:', ':y14:', ':y15:', ':y16:'
];
const allowedTags = new Set(['a', 'b', 'strong', 'i', 'em', 'u', 's', 'blockquote', 'ul', 'ol', 'li', 'br', 'p', 'div', 'span', 'pre', 'code', 'font']);
const allowedAlign = new Set(['left', 'center', 'right', 'justify']);

function looksLikeHtml(value) {
  return /<\/?[a-z][^>]*>/i.test(String(value || ''));
}

function normalizeColor(value) {
  const color = String(value || '').trim();
  if (!color) return null;
  if (/^#([0-9a-f]{3}|[0-9a-f]{6})$/i.test(color)) return color;
  if (/^rgb(a)?\([0-9,\s.%]+\)$/i.test(color)) return color;
  if (/^[a-z]{3,20}$/i.test(color)) return color.toLowerCase();
  return null;
}

function sanitizeStyle(styleText) {
  const chunks = String(styleText || '').split(';');
  const out = [];
  for (const chunk of chunks) {
    const [propRaw, valRaw] = chunk.split(':');
    if (!propRaw || !valRaw) continue;
    const prop = propRaw.trim().toLowerCase();
    const val = String(valRaw || '').trim();
    if (prop === 'color') {
      const color = normalizeColor(val);
      if (color) out.push(`color:${color}`);
      continue;
    }
    if (prop === 'font-size') {
      const num = Number.parseInt(val.replace(/px$/i, ''), 10);
      if (Number.isFinite(num)) {
        const px = Math.max(10, Math.min(72, num));
        out.push(`font-size:${px}px`);
      }
      continue;
    }
    if (prop === 'text-align') {
      const align = val.toLowerCase();
      if (allowedAlign.has(align)) out.push(`text-align:${align}`);
    }
  }
  return out.join(';');
}

function readAttr(attrText, attrName) {
  const regex = new RegExp(`${attrName}\\s*=\\s*("([^"]*)"|'([^']*)'|([^\\s>]+))`, 'i');
  const match = regex.exec(String(attrText || ''));
  if (!match) return '';
  return String(match[2] || match[3] || match[4] || '');
}

function escapeAttr(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/</g, '')
    .replace(/>/g, '');
}

function sanitizeTag(tag) {
  const raw = String(tag || '');
  const closeMatch = /^<\s*\/\s*([a-z0-9]+)\s*>$/i.exec(raw);
  if (closeMatch) {
    const name = String(closeMatch[1] || '').toLowerCase();
    if (!allowedTags.has(name)) return '';
    if (name === 'font') return '</span>';
    return `</${name}>`;
  }

  const openMatch = /^<\s*([a-z0-9]+)([^>]*)>$/i.exec(raw);
  if (!openMatch) return '';
  const name = String(openMatch[1] || '').toLowerCase();
  const attrs = String(openMatch[2] || '');
  if (!allowedTags.has(name)) return '';

  if (name === 'br') return '<br>';
  if (name === 'font') {
    const color = normalizeColor(readAttr(attrs, 'color'));
    const sizeMap = { 1: 10, 2: 12, 3: 14, 4: 16, 5: 18, 6: 24, 7: 32 };
    const sizeNum = Number.parseInt(readAttr(attrs, 'size'), 10);
    const size = sizeMap[sizeNum] || null;
    const styleChunks = [];
    if (color) styleChunks.push(`color:${color}`);
    if (size) styleChunks.push(`font-size:${size}px`);
    return styleChunks.length ? `<span style="${styleChunks.join(';')}">` : '<span>';
  }
  if (name === 'a') {
    const hrefRaw = readAttr(attrs, 'href').trim();
    const href = /^https?:\/\//i.test(hrefRaw) || /^mailto:/i.test(hrefRaw) ? hrefRaw : '';
    if (!href) return '<a>';
    return `<a href="${escapeAttr(href)}" class="link" target="_blank" rel="noopener noreferrer">`;
  }
  if (name === 'div' || name === 'span' || name === 'p') {
    const style = sanitizeStyle(readAttr(attrs, 'style'));
    if (style) return `<${name} style="${style}">`;
  }
  return `<${name}>`;
}

function sanitizeRichHtml(input) {
  let raw = String(input || '');
  raw = raw.replace(/\u0000/g, '');
  raw = raw.replace(/<!--[\s\S]*?-->/g, '');
  raw = raw.replace(/<(script|style|iframe|object|embed|link|meta)[^>]*>[\s\S]*?<\/\1>/gi, '');
  raw = raw.replace(/<\/?(script|style|iframe|object|embed|link|meta)\b[^>]*>/gi, '');

  const placeholders = [];
  const withTokens = raw.replace(/<[^>]*>/g, (tag) => {
    const safe = sanitizeTag(tag);
    if (!safe) return '';
    const token = `__SDAL_TAG_${placeholders.length}__`;
    placeholders.push(safe);
    return token;
  });

  let escaped = withTokens
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/\r?\n/g, '<br>');

  for (let i = 0; i < placeholders.length; i += 1) {
    escaped = escaped.replace(`__SDAL_TAG_${i}__`, placeholders[i]);
  }
  return escaped;
}

function applySmileys(html) {
  let mesaj = String(html || '');
  for (let i = 0; i < smileyMap.length; i += 1) {
    const img = `<img src=/smiley/${i + 1}.gif border=0 width=19 height=19>`;
    if (i !== 0 && i !== 2) {
      mesaj = mesaj.split(smileyMap[i]).join(img);
    }
    mesaj = mesaj.split(smileyAlt[i]).join(img);
  }
  mesaj = mesaj.split(smileyMap[2]).join('<img src=/smiley/3.gif border=0 width=19 height=19>');
  mesaj = mesaj.split(smileyMap[0]).join('<img src=/smiley/1.gif border=0 width=19 height=19>');
  return mesaj;
}

function formatLegacyText(input) {
  let metin = String(input || '');
  metin = metin.replace(/</g, '&lt;').replace(/>/g, '&gt;');
  metin = metin.replace(/\r?\n/g, '<br>');

  const parts = metin.split(' ');
  for (let i = 0; i < parts.length; i += 1) {
    let token = parts[i];
    const lines = token.split('<br>');
    for (let j = 0; j < lines.length; j += 1) {
      const word = lines[j];
      if (word.includes('http://') || word.includes('https://')) {
        lines[j] = `<a href="${word}" class=link target="_blank">${word}</a>`;
      } else if (word.includes('www.')) {
        lines[j] = `<a href="http://${word}" class=link target="_blank">${word}</a>`;
      } else if (/\.(com|net|org|edu|tr)/i.test(word)) {
        lines[j] = `<a href="http://www.${word}" class=link target="_blank">${word}</a>`;
      }
    }
    parts[i] = lines.join('<br>');
  }
  metin = parts.join(' ');

  metin = metin.replace(/\t/g, '   ').replace(/  /g, '&nbsp;&nbsp;');

  let mesaj = metin
    .replace(/\[b\]/g, '<b>').replace(/\[\/b\]/g, '</b>')
    .replace(/\[i\]/g, '<i>').replace(/\[\/i\]/g, '</i>')
    .replace(/\[u\]/g, '<u>').replace(/\[\/u\]/g, '</u>')
    .replace(/\[s\]/g, '<s>').replace(/\[\/s\]/g, '</s>')
    .replace(/\[strike\]/g, '<s>').replace(/\[\/strike\]/g, '</s>')
    .replace(/\[ul\]/g, '<ul>').replace(/\[\/ul\]/g, '</ul>')
    .replace(/\[ol\]/g, '<ol>').replace(/\[\/ol\]/g, '</ol>')
    .replace(/\[li\]/g, '<li>').replace(/\[\/li\]/g, '</li>')
    .replace(/\[sagayasla\]/g, '<div align=right>').replace(/\[\/sagayasla\]/g, '</div>')
    .replace(/\[solayasla\]/g, '<div align=left>').replace(/\[\/solayasla\]/g, '</div>')
    .replace(/\[ortala\]/g, '<center>').replace(/\[\/ortala\]/g, '</center>')
    .replace(/\[left\]/g, '<div style="text-align:left;">').replace(/\[\/left\]/g, '</div>')
    .replace(/\[center\]/g, '<div style="text-align:center;">').replace(/\[\/center\]/g, '</div>')
    .replace(/\[right\]/g, '<div style="text-align:right;">').replace(/\[\/right\]/g, '</div>')
    .replace(/\[justify\]/g, '<div style="text-align:justify;">').replace(/\[\/justify\]/g, '</div>')
    .replace(/\[listele\]/g, '<li>')
    .replace(/\[quote\]/g, '<blockquote>').replace(/\[\/quote\]/g, '</blockquote>')
    .replace(/\[code\]/g, '<pre><code>').replace(/\[\/code\]/g, '</code></pre>')
    .replace(/\[mavi\]/g, '<font style=color:blue;>').replace(/\[\/mavi\]/g, '</font>')
    .replace(/\[sari\]/g, '<font style=color:yellow;>').replace(/\[\/sari\]/g, '</font>')
    .replace(/\[yesil\]/g, '<font style=color:green;>').replace(/\[\/yesil\]/g, '</font>')
    .replace(/\[lacivert\]/g, '<font style=color:darkblue;>').replace(/\[\/lacivert\]/g, '</font>')
    .replace(/\[kayfe\]/g, '<font style=color:brown;>').replace(/\[\/kayfe\]/g, '</font>')
    .replace(/\[pembe\]/g, '<font style=color:pink;>').replace(/\[\/pembe\]/g, '</font>')
    .replace(/\[kirmizi\]/g, '<font style=color:red;>').replace(/\[\/kirmizi\]/g, '</font>')
    .replace(/\[portakal\]/g, '<font style=color:orange;>').replace(/\[\/portakal\]/g, '</font>');

  mesaj = mesaj.replace(/\[size=(\d{1,3})\]([\s\S]*?)\[\/size\]/gi, (_m, size, text) => {
    const px = Math.max(10, Math.min(72, Number(size || 14)));
    return `<span style="font-size:${px}px;line-height:1.45;">${text}</span>`;
  });
  mesaj = mesaj.replace(/\[color=([#a-zA-Z0-9(),.\s%-]{1,30})\]([\s\S]*?)\[\/color\]/gi, (_m, color, text) => {
    const safe = String(color || '').replace(/"/g, '').trim();
    return `<span style="color:${safe};">${text}</span>`;
  });
  return mesaj;
}

export function metinDuzenle(input) {
  if (input == null) return '';
  const raw = String(input);
  if (!raw.trim()) return '';
  const html = looksLikeHtml(raw) ? sanitizeRichHtml(raw) : formatLegacyText(raw);
  return applySmileys(html);
}
