import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { tarihduz } from '../utils/date.js';

export default function AlbumPhotoPage() {
  const { id } = useParams();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [commentText, setCommentText] = useState('');
  const [commentError, setCommentError] = useState('');

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

  async function submitComment(e) {
    e.preventDefault();
    setCommentError('');
    try {
      const res = await fetch(`/api/photos/${id}/comments`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ yorum: commentText })
      });
      if (!res.ok) {
        const msg = await res.text();
        throw new Error(msg || 'Yorum eklenemedi');
      }
      setCommentText('');
      const updated = await fetch(`/api/photos/${id}`, { credentials: 'include' }).then((r) => r.json());
      setData(updated);
    } catch (err) {
      setCommentError(err.message);
    }
  }

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
          <tr>
            <td style={{ border: '1px solid #663300', background: '#ffffcc' }}>
              <b>Yorumlar</b>
            </td>
          </tr>
          <tr>
            <td style={{ border: '1px solid #663300', background: 'white' }}>
              {(data.comments || []).length === 0 ? (
                <div>Henüz yorum yok.</div>
              ) : (
                (data.comments || []).map((c) => (
                  <div key={c.id}>
                    <b>{c.uyeadi}</b> - {c.yorum} <small>({c.tarih ? tarihduz(c.tarih) : ''})</small>
                  </div>
                ))
              )}
              <hr className="sdal-hr" />
              <form onSubmit={submitComment}>
                <textarea className="inptxt" rows="3" cols="60" value={commentText} onChange={(e) => setCommentText(e.target.value)} />
                <br />
                <button className="sub" type="submit">Yorum Ekle</button>
              </form>
              {commentError ? <div className="hatamsg1">{commentError}</div> : null}
            </td>
          </tr>
        </tbody>
      </table>
    </LegacyLayout>
  );
}
