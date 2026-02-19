import React, { useEffect, useMemo, useRef, useState } from 'react';
import { isRichTextEmpty, sanitizeRichTextHtml, toEditorHtml } from '../utils/richText.js';
import { useI18n } from '../utils/i18n.jsx';

export default function RichTextEditor({
  value,
  onChange,
  placeholder = '',
  minHeight = 120,
  compact = false,
  className = ''
}) {
  const { t } = useI18n();
  const editorRef = useRef(null);
  const [fontSize, setFontSize] = useState('14');
  const [color, setColor] = useState('#1b7f6b');
  const [focused, setFocused] = useState(false);
  const [toolbarOpen, setToolbarOpen] = useState(false);
  const [active, setActive] = useState({
    bold: false,
    italic: false,
    underline: false,
    strikeThrough: false,
    justifyLeft: false,
    justifyCenter: false,
    justifyRight: false,
    justifyFull: false,
    insertUnorderedList: false,
    insertOrderedList: false
  });

  const normalizedValue = useMemo(() => toEditorHtml(value || ''), [value]);

  function emitChange() {
    const editor = editorRef.current;
    if (!editor) return;
    const cleaned = sanitizeRichTextHtml(editor.innerHTML || '');
    if (cleaned !== editor.innerHTML) {
      editor.innerHTML = cleaned;
    }
    onChange?.(isRichTextEmpty(cleaned) ? '' : cleaned);
  }

  useEffect(() => {
    const editor = editorRef.current;
    if (!editor || focused) return;
    if ((editor.innerHTML || '') !== normalizedValue) {
      editor.innerHTML = normalizedValue || '';
    }
  }, [normalizedValue, focused]);

  function run(cmd, arg = null) {
    const editor = editorRef.current;
    if (!editor) return;
    editor.focus();
    try {
      document.execCommand(cmd, false, arg);
    } catch {
      // ignore unsupported command
    }
    emitChange();
    refreshActiveState();
  }

  function refreshActiveState() {
    const next = {
      bold: false,
      italic: false,
      underline: false,
      strikeThrough: false,
      justifyLeft: false,
      justifyCenter: false,
      justifyRight: false,
      justifyFull: false,
      insertUnorderedList: false,
      insertOrderedList: false
    };
    try {
      next.bold = document.queryCommandState('bold');
      next.italic = document.queryCommandState('italic');
      next.underline = document.queryCommandState('underline');
      next.strikeThrough = document.queryCommandState('strikeThrough');
      next.insertUnorderedList = document.queryCommandState('insertUnorderedList');
      next.insertOrderedList = document.queryCommandState('insertOrderedList');
      const align = String(document.queryCommandValue('justify') || '').toLowerCase();
      next.justifyCenter = align.includes('center');
      next.justifyRight = align.includes('right');
      next.justifyFull = align.includes('justify');
      next.justifyLeft = !next.justifyCenter && !next.justifyRight && !next.justifyFull;
    } catch {
      // ignore unsupported queryCommandState on some browsers
    }
    setActive(next);
  }

  function applyFontSize(nextSize) {
    setFontSize(String(nextSize));
    const editor = editorRef.current;
    if (!editor) return;
    editor.focus();
    try {
      document.execCommand('fontSize', false, '7');
      const nodes = Array.from(editor.querySelectorAll('font[size="7"]'));
      for (const node of nodes) {
        const span = document.createElement('span');
        span.style.fontSize = `${Number(nextSize)}px`;
        span.innerHTML = node.innerHTML;
        node.replaceWith(span);
      }
    } catch {
      // no-op
    }
    emitChange();
    refreshActiveState();
  }

  function applyColor(nextColor) {
    const safe = String(nextColor || '#1b7f6b');
    setColor(safe);
    run('foreColor', safe);
  }

  function onPaste(event) {
    const html = event.clipboardData?.getData('text/html');
    if (html) {
      event.preventDefault();
      run('insertHTML', sanitizeRichTextHtml(html));
    }
  }

  const sizeOptions = [12, 14, 16, 18, 20, 24, 28];

  useEffect(() => {
    function handleSelection() {
      const editor = editorRef.current;
      if (!editor) return;
      const sel = window.getSelection?.();
      const anchorNode = sel?.anchorNode;
      if (!anchorNode) return;
      if (!editor.contains(anchorNode)) return;
      refreshActiveState();
    }
    document.addEventListener('selectionchange', handleSelection);
    return () => document.removeEventListener('selectionchange', handleSelection);
  }, []);

  return (
    <div className={`rich-editor ${compact ? 'rich-editor-compact' : ''} ${className}`.trim()}>
      <div className="rich-toolbar-toggle">
        <button
          type="button"
          className={`chip rich-toolbar-toggle-btn ${toolbarOpen ? 'chip-active' : ''}`}
          onClick={() => setToolbarOpen((v) => !v)}
          title={t('advanced_format')}
          aria-label={t('advanced_format')}
        >
          A+
        </button>
      </div>
      {toolbarOpen ? (
        <div className="rich-toolbar">
          <button type="button" className="chip" onClick={() => run('undo')} title={t('rt_undo')}>↶</button>
          <button type="button" className="chip" onClick={() => run('redo')} title={t('rt_redo')}>↷</button>
          <button type="button" className={`chip ${active.bold ? 'chip-active' : ''}`} onClick={() => run('bold')}><b>B</b></button>
          <button type="button" className={`chip ${active.italic ? 'chip-active' : ''}`} onClick={() => run('italic')}><i>I</i></button>
          <button type="button" className={`chip ${active.underline ? 'chip-active' : ''}`} onClick={() => run('underline')}><u>U</u></button>
          <button type="button" className={`chip ${active.strikeThrough ? 'chip-active' : ''}`} onClick={() => run('strikeThrough')}><s>S</s></button>
          <select className="input rich-select" value={fontSize} onChange={(e) => applyFontSize(e.target.value)} title={t('rt_font_size')}>
            {sizeOptions.map((size) => (
              <option key={size} value={String(size)}>{size}px</option>
            ))}
          </select>
          <label className="chip rich-color-label" title={t('rt_color')}>
            <input type="color" value={color} onChange={(e) => applyColor(e.target.value)} />
          </label>
          {!compact ? (
            <>
              <button type="button" className={`chip ${active.justifyLeft ? 'chip-active' : ''}`} onClick={() => run('justifyLeft')} title={t('rt_align_left')}>L</button>
              <button type="button" className={`chip ${active.justifyCenter ? 'chip-active' : ''}`} onClick={() => run('justifyCenter')} title={t('rt_align_center')}>C</button>
              <button type="button" className={`chip ${active.justifyRight ? 'chip-active' : ''}`} onClick={() => run('justifyRight')} title={t('rt_align_right')}>R</button>
              <button type="button" className={`chip ${active.justifyFull ? 'chip-active' : ''}`} onClick={() => run('justifyFull')} title={t('rt_align_justify')}>J</button>
              <button type="button" className={`chip ${active.insertUnorderedList ? 'chip-active' : ''}`} onClick={() => run('insertUnorderedList')} title={t('rt_bullet_list')}>•</button>
              <button type="button" className={`chip ${active.insertOrderedList ? 'chip-active' : ''}`} onClick={() => run('insertOrderedList')} title={t('rt_numbered_list')}>1.</button>
              <button type="button" className="chip" onClick={() => run('formatBlock', '<blockquote>')}>{t('rt_quote')}</button>
              <button type="button" className="chip" onClick={() => run('removeFormat')} title={t('rt_clear_format')}>{t('rt_clear')}</button>
            </>
          ) : null}
        </div>
      ) : null}
      <div
        ref={editorRef}
        className="rich-editor-input input"
        contentEditable
        suppressContentEditableWarning
        data-placeholder={placeholder}
        style={{ minHeight: `${minHeight}px` }}
        onFocus={() => setFocused(true)}
        onBlur={() => {
          setFocused(false);
          emitChange();
          refreshActiveState();
        }}
        onInput={() => {
          emitChange();
          refreshActiveState();
        }}
        onKeyUp={refreshActiveState}
        onMouseUp={refreshActiveState}
        onPaste={onPaste}
      />
    </div>
  );
}
