import React, { useState } from 'react';
import { pickImageFromNative, supportsNativeImagePicker } from '../utils/imagePicker.js';
import { useI18n } from '../utils/i18n.jsx';

export default function NativeImageButtons({ onPick, onError, className = '' }) {
  const { t } = useI18n();
  const [busy, setBusy] = useState('');

  if (!supportsNativeImagePicker()) return null;

  async function handlePick(source) {
    setBusy(source);
    try {
      const file = await pickImageFromNative(source);
      if (file) onPick?.(file);
    } catch (err) {
      const message = err?.message || '';
      const cancelled = /cancel/i.test(message);
      if (!cancelled) onError?.(message || t('image_pick_failed'));
    } finally {
      setBusy('');
    }
  }

  return (
    <div className={`native-image-buttons ${className}`.trim()}>
      <button type="button" className="btn ghost" disabled={!!busy} onClick={() => handlePick('camera')}>
        {busy === 'camera' ? t('processing') : t('image_pick_camera')}
      </button>
      <button type="button" className="btn ghost" disabled={!!busy} onClick={() => handlePick('gallery')}>
        {busy === 'gallery' ? t('processing') : t('image_pick_gallery')}
      </button>
    </div>
  );
}
