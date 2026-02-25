import React, { useEffect, useState } from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function NewPhotosPage() {
  const [items, setItems] = useState([]);
  const [error, setError] = useState('');

  useEffect(() => {
    let alive = true;
    fetch('/api/album/latest?limit=100', { credentials: 'include' })
      .then((res) => res.json())
      .then((data) => {
        if (!alive) return;
        setItems(data.items || []);
      })
      .catch(() => {
        if (alive) setError('Veri alınamadı.');
      });
    return () => { alive = false; };
  }, []);

  return (
    <LegacyLayout pageTitle="En Yeni Fotoğraflar">
      <hr color="#662233" size="1" />
      <table border="0" cellPadding="2" cellSpacing="0" width="100%">
        <tbody>
          <tr>
            <td style={{ background: '#660000', color: 'white' }}>
              <b>En Yeni Fotoğraflar</b>
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300' }} align="center">
              {error ? <div className="hatamsg1">{error}</div> : null}
              {items.map((p) => (
                <div key={p.id} style={{ marginBottom: 8 }}>
                  <a href={`/album/foto/${p.id}`} title={p.kategori || ''}>
                    <img src={`/api/media/kucukresim?iwidth=100&r=${encodeURIComponent(p.dosyaadi)}`} border="1" alt="" />
                  </a>
                  {' '}
                  <b>{p.tarih} - {p.hit}</b>
                  <hr color="#ededed" size="1" />
                </div>
              ))}
              <hr color="#662233" size="1" />
              <a href="/album/yeni" title="Fotoğraf Albümüne yeni fotoğraf/fotoğraflar yüklemek için tıklayınız.">Yeni Fotoğraf Ekle</a>
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
