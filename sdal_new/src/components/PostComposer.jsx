import React, { useEffect, useMemo, useRef, useState } from 'react';
import { emitAppChange } from '../utils/live.js';
import { applyMention, detectMentionContext, fetchMentionCandidates } from '../utils/mentions.js';
import { useI18n } from '../utils/i18n.jsx';

const FILTERS = [
  { key: '', label: 'Filtre Yok' },
  { key: 'grayscale', label: 'Siyah Beyaz' },
  { key: 'sepia', label: 'Sepya' },
  { key: 'vivid', label: 'Canlı' },
  { key: 'cool', label: 'Soğuk' },
  { key: 'warm', label: 'Sıcak' },
  { key: 'blur', label: 'Blur' },
  { key: 'sharp', label: 'Sharp' }
];

export default function PostComposer({ onPost }) {
  const { t } = useI18n();
  const [content, setContent] = useState('');
  const [image, setImage] = useState(null);
  const [filter, setFilter] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [mentionUsers, setMentionUsers] = useState([]);
  const [mentionCtx, setMentionCtx] = useState(null);
  const [showAdvanced, setShowAdvanced] = useState(false);
  const textareaRef = useRef(null);

  function withSelection(openTag, closeTag) {
    const el = textareaRef.current;
    if (!el) return;
    const start = Number(el.selectionStart || 0);
    const end = Number(el.selectionEnd || 0);
    const selected = content.slice(start, end);
    const next = `${content.slice(0, start)}${openTag}${selected}${closeTag}${content.slice(end)}`;
    setContent(next);
    requestAnimationFrame(() => {
      const cursor = start + openTag.length + selected.length + closeTag.length;
      el.focus();
      el.selectionStart = cursor;
      el.selectionEnd = cursor;
    });
  }

  const previewHtml = useMemo(() => {
    let text = String(content || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
    text = text.replace(/\r?\n/g, '<br>');
    text = text
      .replace(/\[b\]([\s\S]*?)\[\/b\]/gi, '<b>$1</b>')
      .replace(/\[i\]([\s\S]*?)\[\/i\]/gi, '<i>$1</i>')
      .replace(/\[u\]([\s\S]*?)\[\/u\]/gi, '<u>$1</u>')
      .replace(/\[s\]([\s\S]*?)\[\/s\]/gi, '<s>$1</s>')
      .replace(/\[left\]([\s\S]*?)\[\/left\]/gi, '<div style="text-align:left;">$1</div>')
      .replace(/\[center\]([\s\S]*?)\[\/center\]/gi, '<div style="text-align:center;">$1</div>')
      .replace(/\[right\]([\s\S]*?)\[\/right\]/gi, '<div style="text-align:right;">$1</div>')
      .replace(/\[justify\]([\s\S]*?)\[\/justify\]/gi, '<div style="text-align:justify;">$1</div>')
      .replace(/\[quote\]([\s\S]*?)\[\/quote\]/gi, '<blockquote>$1</blockquote>')
      .replace(/\[size=(\d{1,3})\]([\s\S]*?)\[\/size\]/gi, (_m, size, val) => `<span style="font-size:${Math.max(10, Math.min(72, Number(size || 14)))}px;">${val}</span>`)
      .replace(/\[color=([#a-zA-Z0-9(),.\s%-]{1,30})\]([\s\S]*?)\[\/color\]/gi, (_m, c, val) => `<span style="color:${String(c).replace(/"/g, '').trim()};">${val}</span>`);
    return text;
  }, [content]);

  function handleContentChange(value, caretPos) {
    setContent(value);
    const nextCtx = detectMentionContext(value, caretPos);
    setMentionCtx(nextCtx);
    if (!nextCtx) setMentionUsers([]);
  }

  function insertMention(kadi) {
    setContent((prev) => applyMention(prev, mentionCtx, kadi));
    setMentionCtx(null);
  }

  useEffect(() => {
    if (!mentionCtx?.query) {
      setMentionUsers([]);
      return;
    }
    fetchMentionCandidates(mentionCtx.query).then(setMentionUsers).catch(() => setMentionUsers([]));
  }, [mentionCtx?.query]);

  async function submit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      if (image) {
        const form = new FormData();
        form.append('content', content);
        form.append('image', image);
        form.append('filter', filter);
        const res = await fetch('/api/new/posts/upload', {
          method: 'POST',
          credentials: 'include',
          body: form
        });
        if (!res.ok) throw new Error(await res.text());
      } else {
        const res = await fetch('/api/new/posts', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          credentials: 'include',
          body: JSON.stringify({ content })
        });
        if (!res.ok) throw new Error(await res.text());
      }
      setContent('');
      setImage(null);
      setFilter('');
      emitAppChange('post:created');
      onPost?.();
    } catch (err) {
      setError(err.message || 'Paylaşım başarısız.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <form className="composer" onSubmit={submit}>
      <textarea
        ref={textareaRef}
        placeholder="Bugün neler oluyor?"
        value={content}
        onChange={(e) => handleContentChange(e.target.value, e.target.selectionStart)}
      />
      {mentionCtx ? (
        <div className="mention-box">
          {mentionUsers
            .slice(0, 8)
            .map((u) => (
              <button key={u.id || u.following_id || u.kadi} type="button" className="mention-item" onClick={() => insertMention(u.kadi)}>
                @{u.kadi}
              </button>
            ))}
        </div>
      ) : null}
      <div className="composer-actions">
        <button type="button" className="btn ghost formatting-toggle" onClick={() => setShowAdvanced((v) => !v)} title={t('advanced_format')}>
          A+
        </button>
        <input type="file" accept="image/*" onChange={(e) => setImage(e.target.files?.[0] || null)} />
        <button className="btn primary" disabled={loading}>Paylaş</button>
      </div>
      {showAdvanced ? (
        <div className="advanced-editor">
          <div className="advanced-toolbar">
            <button type="button" className="chip" onClick={() => withSelection('[b]', '[/b]')}>B</button>
            <button type="button" className="chip" onClick={() => withSelection('[i]', '[/i]')}>I</button>
            <button type="button" className="chip" onClick={() => withSelection('[u]', '[/u]')}>U</button>
            <button type="button" className="chip" onClick={() => withSelection('[s]', '[/s]')}>S</button>
            <button type="button" className="chip" onClick={() => withSelection('[left]', '[/left]')}>Sol</button>
            <button type="button" className="chip" onClick={() => withSelection('[center]', '[/center]')}>Orta</button>
            <button type="button" className="chip" onClick={() => withSelection('[right]', '[/right]')}>Sağ</button>
            <button type="button" className="chip" onClick={() => withSelection('[justify]', '[/justify]')}>Yasla</button>
            <button type="button" className="chip" onClick={() => withSelection('[size=18]', '[/size]')}>Boyut</button>
            <button type="button" className="chip" onClick={() => withSelection('[color=#1b7f6b]', '[/color]')}>Renk</button>
            <button type="button" className="chip" onClick={() => withSelection('[quote]', '[/quote]')}>Alıntı</button>
          </div>
          <div className="advanced-preview" dangerouslySetInnerHTML={{ __html: previewHtml || '<span class="muted">Önizleme</span>' }} />
        </div>
      ) : null}
      {image ? (
        <div className="filter-grid">
          {FILTERS.map((f) => (
            <button
              key={f.key || 'none'}
              type="button"
              className={`chip ${filter === f.key ? 'chip-active' : ''}`}
              onClick={() => setFilter(f.key)}
            >
              {f.label}
            </button>
          ))}
        </div>
      ) : null}
      {error ? <div className="error">{error}</div> : null}
    </form>
  );
}
