import React, { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function AlbumUploadPage() {
  const [params] = useSearchParams();
  const [categories, setCategories] = useState([]);
  const [form, setForm] = useState({
    kat: params.get('kid') || '',
    baslik: '',
    aciklama: '',
    file: null
  });
  const [error, setError] = useState('');
  const [successFile, setSuccessFile] = useState(params.get('fil') || '');

  useEffect(() => {
    let alive = true;
    fetch('/api/album/categories/active', { credentials: 'include' })
      .then((res) => res.json())
      .then((data) => {
        if (!alive) return;
        setCategories(data.categories || []);
      })
      .catch(() => {
        if (alive) setCategories([]);
      });
    return () => { alive = false; };
  }, []);

  async function submit(e) {
    e.preventDefault();
    setError('');
    setSuccessFile('');
    const body = new FormData();
    body.append('kat', form.kat);
    body.append('baslik', form.baslik);
    body.append('aciklama', form.aciklama);
    if (form.file) body.append('file', form.file);
    const res = await fetch('/api/album/upload', {
      method: 'POST',
      body,
      credentials: 'include'
    });
    if (!res.ok) {
      setError(await res.text());
      return;
    }
    const data = await res.json();
    setSuccessFile(data.file || '');
    setForm((f) => ({ ...f, baslik: '', aciklama: '', file: null }));
  }

  return (
    <LegacyLayout pageTitle="Fotoğraf Albümü - Fotoğraf Ekleme">
      <hr color="#663300" size="1" />
      <a href="/album">Fotoğraf Albümü Anasayfa</a>
      <hr color="#663300" size="1" /><br /><br />

      <table border="0" cellPadding="3" cellSpacing="1">
        {successFile ? (
          <tbody>
            <tr>
              <td style={{ border: '1px solid #663300' }} align="center">
                <b>Fotoğraf başarıyla eklendi!<br />Onaylandıktan sonra Fotoğraf Albümünde yerini alacaktır.</b><br /><br />
                <img src={`/api/media/kucukresim?iwidth=150&r=${encodeURIComponent(successFile)}`} border="1" alt="" />
              </td>
            </tr>
          </tbody>
        ) : null}
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300' }} align="center">
              <b>Fotoğraf Ekleme</b>
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300' }} align="center">
              {categories.length === 0 ? (
                <div>Henüz aktif kategori yok.</div>
              ) : (
                <form method="POST" encType="multipart/form-data" onSubmit={submit} name="ves">
                  <table border="0" cellPadding="0" cellSpacing="0">
                    <tbody>
                      <tr>
                        <td>Kategori : </td>
                        <td>
                          <select name="kat" className="inptxt" value={form.kat} onChange={(e) => setForm({ ...form, kat: e.target.value })}>
                            <option value="">Seçiniz</option>
                            {categories.map((cat) => (
                              <option key={cat.id} value={cat.id}>{cat.kategori}</option>
                            ))}
                          </select>
                        </td>
                      </tr>
                      <tr>
                        <td>Başlık : </td>
                        <td>
                          <input type="text" name="baslik" size="40" className="inptxt" value={form.baslik} onChange={(e) => setForm({ ...form, baslik: e.target.value })} />
                        </td>
                      </tr>
                      <tr>
                        <td>Açıklama : </td>
                        <td>
                          <input type="text" name="aciklama" size="40" className="inptxt" value={form.aciklama} onChange={(e) => setForm({ ...form, aciklama: e.target.value })} />
                        </td>
                      </tr>
                      <tr>
                        <td>Fotoğraf : </td>
                        <td>
                          <input type="file" name="file" size="40" className="inptxt" onChange={(e) => setForm({ ...form, file: e.target.files?.[0] || null })} />
                        </td>
                      </tr>
                      <tr>
                        <td colSpan="2" align="center">
                          <input type="submit" value="Yükle" className="sub" />
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </form>
              )}
              {error ? <div className="hatamsg1">{error}</div> : null}
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
