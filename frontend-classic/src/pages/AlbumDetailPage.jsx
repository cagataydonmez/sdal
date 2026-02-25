import React, { useEffect, useState } from 'react';
import { useParams, useSearchParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';

export default function AlbumDetailPage() {
  const { id } = useParams();
  const [params] = useSearchParams();
  const page = Math.max(parseInt(params.get('sf') || '1', 10), 1);
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let alive = true;
    setLoading(true);
    fetch(`/api/albums/${id}?page=${page}&pageSize=20`, { credentials: 'include' })
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
  }, [id, page]);

  if (loading) {
    return (
      <LegacyLayout pageTitle="Fotoğraf Albümü">
        <div style={{ padding: 12 }}>Yükleniyor...</div>
      </LegacyLayout>
    );
  }

  if (!data?.category) {
    return (
      <LegacyLayout pageTitle="Fotoğraf Albümü">
        <div style={{ padding: 12 }}>Kategori bulunamadı.</div>
      </LegacyLayout>
    );
  }

  return (
    <LegacyLayout pageTitle="Fotoğraf Albümü">
      <hr color="#663300" size="1" />
      <a href="/album">Albüm Anasayfa</a>
      <hr color="#663300" size="1" />
      <br /><br />
      <b>Fotoğrafları tam boy olarak görmek için üzerlerine tıklayın.</b>
      <br /><br />

      {data.pages > 1 ? (
        <table border="0" cellPadding="3" cellSpacing="0" width="100%">
          <tbody>
            <tr>
              <td style={{ border: '1px solid #663300', background: 'white' }} align="center">
                <table border="0" cellPadding="2" cellSpacing="1">
                  <tbody>
                    <tr>
                      <td style={{ background: 'white', border: '1px solid #ededed' }} width="15" align="center">
                        <b><a href={`/album/${id}?sf=${page === 1 ? data.pages : page - 1}`}>&lt;</a></b>
                      </td>
                      {Array.from({ length: data.pages }, (_, i) => i + 1).map((p) => (
                        <td key={p} style={{ background: p === page ? 'yellow' : 'white', border: '1px solid #ededed' }} width="15" align="center">
                          {p === page ? <b>{p}</b> : <b><a href={`/album/${id}?sf=${p}`}>{p}</a></b>}
                        </td>
                      ))}
                      <td style={{ background: 'white', border: '1px solid #ededed' }} width="15" align="center">
                        <b><a href={`/album/${id}?sf=${page === data.pages ? 1 : page + 1}`}>&gt;</a></b>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </td>
            </tr>
          </tbody>
        </table>
      ) : null}

      <table border="0" cellPadding="3" cellSpacing="0" width="100%">
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300', background: 'white' }} align="center">
              Toplam <b>{data.total}</b> resimden <b>{(data.page - 1) * data.pageSize + 1}</b> ile <b>{Math.min(data.page * data.pageSize, data.total)}</b> arasında bulunanlara bakıyorsunuz.
            </td>
          </tr>
        </tbody>
      </table>

      <table border="0" cellPadding="8" cellSpacing="0" width="100%">
        <tbody>
          <tr>
            <td colSpan="5" style={{ border: '1px solid #663300', background: '#ffffcc' }}>
              <table border="0" cellPadding="0" cellSpacing="0" width="100%">
                <tbody>
                  <tr>
                    <td>
                      <a href="/album" title="Kategoriler">Kategoriler</a> <font color="blue">&gt;&gt;</font> <b>{data.category.kategori}</b>
                    </td>
                  </tr>
                </tbody>
              </table>
            </td>
          </tr>
          {chunkPhotos(data.photos, 5).map((row, idx) => (
            <tr key={`row-${idx}`}>
              {row.map((photo) => (
                <td key={photo.id} style={{ border: '1px solid #000000', background: '#CCFFE6' }} align="center">
                  <a href={`/api/media/kucukresim?file=${encodeURIComponent(photo.dosyaadi)}`} title={photo.baslik || ''}>
                    <img src={`/api/media/kucukresim?height=100&file=${encodeURIComponent(photo.dosyaadi)}`} border="1" alt="" />
                    <br />
                    <font style={{ fontSize: 9, fontWeight: 'bold', color: 'navy' }}>Büyüt</font>
                  </a>
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </LegacyLayout>
  );
}

function chunkPhotos(items, size) {
  const rows = [];
  for (let i = 0; i < items.length; i += size) {
    rows.push(items.slice(i, i + size));
  }
  return rows;
}
