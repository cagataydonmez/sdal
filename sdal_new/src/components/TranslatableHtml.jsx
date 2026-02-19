import React, { useMemo, useState } from 'react';
import { escapeHtml, renderRichTextHtml, richTextToPlainText } from '../utils/richText.js';
import { useI18n } from '../utils/i18n.jsx';

const translationCache = new Map();

function toMultilineHtml(text) {
  const escaped = escapeHtml(text || '');
  return escaped.replace(/\r?\n/g, '<br>');
}

export default function TranslatableHtml({ html, className = '', contentClassName = '' }) {
  const { lang, t } = useI18n();
  const [translated, setTranslated] = useState('');
  const [showTranslated, setShowTranslated] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const safeHtml = useMemo(() => renderRichTextHtml(html || ''), [html]);
  const plainText = useMemo(() => richTextToPlainText(html || ''), [html]);
  const canTranslate = lang !== 'tr' && plainText.length > 0;

  async function toggleTranslate() {
    if (showTranslated) {
      setShowTranslated(false);
      return;
    }
    if (!canTranslate) return;
    const cacheKey = `${lang}:${plainText}`;
    if (translationCache.has(cacheKey)) {
      setTranslated(translationCache.get(cacheKey) || '');
      setShowTranslated(true);
      setError('');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/new/translate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ text: plainText, target: lang })
      });
      if (!res.ok) throw new Error(await res.text());
      const data = await res.json();
      const output = String(data.translatedText || '').trim();
      if (!output) throw new Error(t('translate_failed'));
      translationCache.set(cacheKey, output);
      setTranslated(output);
      setShowTranslated(true);
    } catch {
      setError(t('translate_failed'));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className={`translated-html ${className}`.trim()}>
      {canTranslate ? (
        <div className="translated-actions">
          <button type="button" className="btn ghost btn-xs" onClick={toggleTranslate} disabled={loading}>
            {loading ? t('translate_loading') : (showTranslated ? t('show_original') : t('translate_button'))}
          </button>
          {error ? <span className="meta">{error}</span> : null}
        </div>
      ) : null}
      {showTranslated ? (
        <div className={contentClassName} dangerouslySetInnerHTML={{ __html: toMultilineHtml(translated) }} />
      ) : (
        <div className={contentClassName} dangerouslySetInnerHTML={{ __html: safeHtml }} />
      )}
    </div>
  );
}
