import React, { useEffect, useState } from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function AlbumsPage() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    fetch('/api/albums', { credentials: 'include' })
      .then((res) => res.json())
      .then((payload) => {
        if (!alive) return;
        setItems(payload.items || []);
      })
      .catch(() => {
        if (alive) setItems([]);
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => { alive = false; };
  }, []);

  return (
    <LegacyLayout pageTitle="Fotoğraf Albümü">
      <table border="0" cellPadding="3" cellSpacing="1" width="100%">
        <tbody>
          <tr>
            <td>
              <font style={{ color: '#663300', fontSize: 15 }}><b>Kategoriler</b></font>
            </td>
          </tr>
          {loading ? (
            <tr><td>Yükleniyor...</td></tr>
          ) : items.length === 0 ? (
            <tr><td>Henüz bir kategori açılmamış...</td></tr>
          ) : items.map((cat) => (
            <React.Fragment key={cat.id}>
              <tr>
                <td style={{ border: '1px solid #663300', background: '#ffffcc' }}>
                  <a href={`/album/${cat.id}`} title={cat.aciklama || ''}>{cat.kategori} ( Toplam <b>{cat.count}</b> fotoğraf )</a>
                </td>
              </tr>
              <tr>
                <td style={{ border: '1px solid #663300' }}>
                  <a href={`/album/${cat.id}`} title={cat.aciklama || ''} style={{ textDecoration: 'none' }}>
                    {cat.previews.length === 0 ? (
                      'Henüz bir fotoğraf eklenmemiş...'
                    ) : (
                      <>
                        {cat.previews.map((file, idx) => (
                          <img key={`${file}-${idx}`} src={`/api/media/kucukresim?height=40&file=${encodeURIComponent(file)}`} border="1" alt="" />
                        ))}
                        Devamı için tıklayın...
                      </>
                    )}
                  </a>
                </td>
              </tr>
            </React.Fragment>
          ))}
        </tbody>
      </table>
      <br /><br />
      <table border="0" cellPadding="3" cellSpacing="1" width="100%">
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300', background: '#ffffcc' }}>
              <a href="/album/yeni" title="Fotoğraf eklemek için tıklayın." style={{ color: '#663300' }}><b>Fotoğraf Eklemek için tıklayın!</b></a>
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
