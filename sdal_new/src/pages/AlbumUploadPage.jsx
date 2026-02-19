import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import RichTextEditor from '../components/RichTextEditor.jsx';
import { useI18n } from '../utils/i18n.jsx';

export default function AlbumUploadPage() {
  const { t } = useI18n();
  const [categories, setCategories] = useState([]);
  const [form, setForm] = useState({ kat: '', baslik: '', aciklama: '' });
  const [file, setFile] = useState(null);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    fetch('/api/album/categories/active', { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => setCategories(p.categories || []))
      .catch(() => {});
  }, []);

  async function submit(e) {
    e.preventDefault();
    setStatus('');
    setError('');
    const formData = new FormData();
    formData.append('kat', form.kat);
    formData.append('baslik', form.baslik);
    formData.append('aciklama', form.aciklama);
    if (file) formData.append('file', file);
    const res = await fetch('/api/album/upload', { method: 'POST', credentials: 'include', body: formData });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    const data = await res.json();
    setStatus(t('album_upload_status_success', { categoryId: data.categoryId }));
    setForm({ kat: '', baslik: '', aciklama: '' });
    setFile(null);
  }

  return (
    <Layout title={t('albums_upload')}>
      <div className="panel">
        <div className="panel-body">
          <form className="stack" onSubmit={submit}>
            <select className="input" value={form.kat} onChange={(e) => setForm({ ...form, kat: e.target.value })}>
              <option value="">{t('album_upload_select_category')}</option>
              {categories.map((c) => <option key={c.id} value={c.id}>{c.kategori}</option>)}
            </select>
            <input className="input" placeholder={t('title')} value={form.baslik} onChange={(e) => setForm({ ...form, baslik: e.target.value })} />
            <RichTextEditor
              value={form.aciklama}
              onChange={(next) => setForm((prev) => ({ ...prev, aciklama: next }))}
              placeholder={t('description')}
              minHeight={110}
            />
            <input type="file" accept="image/*" onChange={(e) => setFile(e.target.files?.[0] || null)} />
            <button className="btn primary" type="submit">{t('upload')}</button>
          </form>
          {status ? <div className="ok">{status}</div> : null}
          {error ? <div className="error">{error}</div> : null}
        </div>
      </div>
    </Layout>
  );
}
