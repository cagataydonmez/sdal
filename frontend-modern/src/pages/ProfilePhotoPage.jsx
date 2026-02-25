import React, { useState } from 'react';
import Layout from '../components/Layout.jsx';
import NativeImageButtons from '../components/NativeImageButtons.jsx';
import { useAuth } from '../utils/auth.jsx';
import { emitAppChange } from '../utils/live.js';
import { useI18n } from '../utils/i18n.jsx';

export default function ProfilePhotoPage() {
  const { t } = useI18n();
  const { refresh } = useAuth();
  const [file, setFile] = useState(null);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  async function upload() {
    setStatus('');
    setError('');
    if (!file) return setError(t('profile_photo_error_no_file'));
    const form = new FormData();
    form.append('file', file);
    const res = await fetch('/api/profile/photo', { method: 'POST', credentials: 'include', body: form });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    await refresh();
    emitAppChange('profile:updated');
    setStatus(t('profile_photo_status_updated'));
  }

  return (
    <Layout title={t('profile_photo_title')}>
      <div className="panel">
        <div className="panel-body">
          <NativeImageButtons onPick={setFile} onError={setError} />
          <input type="file" accept="image/*" onChange={(e) => setFile(e.target.files?.[0] || null)} />
          <button className="btn primary" onClick={upload}>{t('upload')}</button>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
