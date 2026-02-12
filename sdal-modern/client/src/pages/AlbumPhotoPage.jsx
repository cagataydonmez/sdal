import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { tarihduz } from '../utils/date.js';

export default function AlbumPhotoPage() {
  const { id } = useParams();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    fetch(`/api/photos/${id}`, { credentials: 'include' })
      .then((res) => res.json())
      .then((payload) => {
        if (!alive) return;
        setData(payload);
      })
      .catch(() => {
        if (alive) setData(null);
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => { alive = false; };
  }, [id]);

  if (loading) {
    return (
      <LegacyLayout pageTitle="Fotoğraf">
        <div style={{ padding: 12 }}>Yükleniyor...</div>
      </LegacyLayout>
    );
  }

  if (!data?.row) {
    return (
      <LegacyLayout pageTitle="Fotoğraf">
        <div style={{ padding: 12 }}>Fotoğraf bulunamadı.</div>
      </LegacyLayout>
    );
  }

  return (
    <LegacyLayout pageTitle="Fotoğraf">
      <table border="0" cellPadding="3" cellSpacing="1" width="100%">
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300', background: '#ffffcc' }}>
              <b>{data.row.baslik || 'Fotoğraf'}</b>
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300', background: 'white' }} align="center">
              <img src={`/api/media/kucukresim?file=${encodeURIComponent(data.row.dosyaadi)}`} border="1" alt="" />
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300', background: 'white' }}>
              <b>Kategori:</b> {data.category?.kategori || '-'}<br />
              <b>Tarih:</b> {data.row.tarih ? tarihduz(data.row.tarih) : '-'}<br />
              {data.row.aciklama ? (<><b>Açıklama:</b> {data.row.aciklama}</>) : null}
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
