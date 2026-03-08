import React, { useMemo, useRef, useState } from 'react';
import { emitAppChange } from '../utils/live.js';
import { useI18n } from '../utils/i18n.jsx';
import RichTextEditor from './RichTextEditor.jsx';
import NativeImageButtons from './NativeImageButtons.jsx';

const FILTERS = [
  { key: '', label: '' },
  { key: 'grayscale', label: '' },
  { key: 'sepia', label: '' },
  { key: 'vivid', label: '' },
  { key: 'cool', label: '' },
  { key: 'warm', label: '' },
  { key: 'blur', label: 'Blur' },
  { key: 'sharp', label: 'Sharp' }
];

export default function PostComposer({ onPost }) {
  const { t, lang } = useI18n();
  const [content, setContent] = useState('');
  const [image, setImage] = useState(null);
  const [filter, setFilter] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const fileInputRef = useRef(null);
  const localizedFilters = useMemo(
    () => FILTERS.map((item) => ({
      ...item,
      label: t(`filter_${item.key || 'none'}`)
    })),
    [lang, t]
  );

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
      if (fileInputRef.current) fileInputRef.current.value = '';
      emitAppChange('post:created');
      onPost?.();
    } catch (err) {
      setError(err.message || t('post_share_failed'));
    } finally {
      setLoading(false);
    }
  }

  return (
    <form className="composer" onSubmit={submit}>
      <RichTextEditor
        value={content}
        onChange={setContent}
        placeholder={t('post_placeholder')}
        minHeight={130}
      />
      <div className="composer-actions">
        <NativeImageButtons onPick={setImage} onError={setError} />

        <button
          type="button"
          className="btn ghost composer-media-trigger"
          onClick={() => fileInputRef.current?.click()}
        >
          {t('image_pick_gallery')}
        </button>
        <input
          ref={fileInputRef}
          className="composer-file-input"
          type="file"
          accept="image/*"
          hidden
          style={{ display: 'none' }}
          onChange={(e) => setImage(e.target.files?.[0] || null)}
        />

        {image ? (
          <div className="composer-media-chip" title={image.name}>
            <span className="composer-media-chip-name">{image.name || 'image'}</span>
            <button
              type="button"
              className="btn ghost composer-media-remove"
              onClick={() => {
                setImage(null);
                setFilter('');
                if (fileInputRef.current) fileInputRef.current.value = '';
              }}
            >
              {t('delete')}
            </button>
          </div>
        ) : null}

        <button className="btn primary" disabled={loading}>{t('post_share')}</button>
      </div>
      {image ? (
        <div className="filter-grid">
          {localizedFilters.map((f) => (
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
