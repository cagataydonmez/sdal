import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import Layout from '../components/Layout.jsx';
import { formatDateTime } from '../utils/date.js';
import { applyMention, detectMentionContext, fetchMentionCandidates } from '../utils/mentions.js';

export default function AlbumPhotoPage() {
  const { id } = useParams();
  const [photo, setPhoto] = useState(null);
  const [comments, setComments] = useState([]);
  const [comment, setComment] = useState('');
  const [mentionUsers, setMentionUsers] = useState([]);
  const [mentionCtx, setMentionCtx] = useState(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function load() {
    const res = await fetch(`/api/photos/${id}`, { credentials: 'include' });
    if (!res.ok) return;
    const data = await res.json();
    setPhoto(data.row || null);
    setComments(data.comments || []);
  }

  useEffect(() => {
    load();
  }, [id]);

  async function submit(e) {
    e.preventDefault();
    setError('');
    if (!comment.trim()) {
      setError('Yorum yazmalısın.');
      return;
    }
    setLoading(true);
    const res = await fetch(`/api/photos/${id}/comments`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ yorum: comment })
    });
    if (!res.ok) {
      setError(await res.text());
      setLoading(false);
      return;
    }
    setComment('');
    setMentionCtx(null);
    await load();
    setLoading(false);
  }

  function handleCommentChange(value, caretPos) {
    setComment(value);
    const ctx = detectMentionContext(value, caretPos);
    setMentionCtx(ctx);
    if (!ctx) setMentionUsers([]);
  }

  function insertMention(kadi) {
    setComment((prev) => applyMention(prev, mentionCtx, kadi));
    setMentionCtx(null);
  }

  useEffect(() => {
    if (!mentionCtx?.query) {
      setMentionUsers([]);
      return;
    }
    fetchMentionCandidates(mentionCtx.query).then(setMentionUsers).catch(() => setMentionUsers([]));
  }, [mentionCtx?.query]);

  if (!photo) return <Layout title="Fotoğraf">Yükleniyor...</Layout>;

  return (
    <Layout title={photo.baslik || 'Fotoğraf'}>
      <div className="panel">
        <img className="photo-view-image" src={`/api/media/kucukresim?width=1200&file=${encodeURIComponent(photo.dosyaadi)}`} alt="" />
          <div className="panel-body">
          <div className="meta">{formatDateTime(photo.tarih)}</div>
          <div>{photo.aciklama}</div>
        </div>
      </div>
      <div className="panel">
        <div className="panel-body">
          <form className="stack" onSubmit={submit}>
            <textarea className="input" placeholder="Yorum yaz... (@kullanici mention)" value={comment} onChange={(e) => handleCommentChange(e.target.value, e.target.selectionStart)} />
            {mentionCtx ? (
              <div className="mention-box">
                {mentionUsers
                  .slice(0, 8)
                  .map((u) => (
                    <button key={u.id || u.following_id || u.kadi} type="button" className="mention-item" onClick={() => insertMention(u.kadi)}>
                      @{u.kadi}
                    </button>
                  ))}
              </div>
            ) : null}
            <button className="btn" disabled={loading}>{loading ? 'Gönderiliyor...' : 'Yorum Ekle'}</button>
            {error ? <div className="error">{error}</div> : null}
          </form>
        </div>
      </div>
      <div className="panel">
        <h3>Yorumlar</h3>
        <div className="panel-body">
          {comments.map((c) => (
            <div key={c.id} className="list-item">
              <div>
                <div className="name">
                  {c.user_id ? (
                    <a className="verify-user" href={`/new/members/${c.user_id}`}>
                      @{c.kadi || c.uyeadi}
                      {c.verified ? <span className="badge">✓</span> : null}
                    </a>
                  ) : (
                    <span>@{c.kadi || c.uyeadi}</span>
                  )}
                </div>
                <div className="meta">{formatDateTime(c.tarih)}</div>
              </div>
              <div dangerouslySetInnerHTML={{ __html: c.yorum || '' }} />
            </div>
          ))}
        </div>
      </div>
    </Layout>
  );
}
