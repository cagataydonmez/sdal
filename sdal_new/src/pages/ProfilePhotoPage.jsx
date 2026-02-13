import React, { useState } from 'react';
import Layout from '../components/Layout.jsx';

export default function ProfilePhotoPage() {
  const [file, setFile] = useState(null);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  async function upload() {
    setStatus('');
    setError('');
    if (!file) return setError('Fotoğraf seçilmedi.');
    const form = new FormData();
    form.append('file', file);
    const res = await fetch('/api/profile/photo', { method: 'POST', credentials: 'include', body: form });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    setStatus('Fotoğraf güncellendi.');
  }

  return (
    <Layout title="Fotoğraf Düzenle">
      <div className="panel">
        <div className="panel-body">
          <input type="file" accept="image/*" onChange={(e) => setFile(e.target.files?.[0] || null)} />
          <button className="btn primary" onClick={upload}>Yükle</button>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
