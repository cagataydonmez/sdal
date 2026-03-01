import React from 'react';

function formatDate(value) {
  return value ? new Date(value).toLocaleString('tr-TR') : '-';
}

export default function AdminPreviewModal({ previewModal, setPreviewModal }) {
  if (!previewModal) return null;

  return (
    <div className="story-modal" onClick={() => setPreviewModal(null)}>
      <div className="story-frame admin-preview" onClick={(e) => e.stopPropagation()}>
        <div className="composer-actions">
          <h3>Önizleme</h3>
          <button className="btn ghost" onClick={() => setPreviewModal(null)}>Kapat</button>
        </div>
        {previewModal.type === 'activity' ? (
          <div className="stack">
            <div className="name">{previewModal.data?.message}</div>
            <div className="meta">{previewModal.data?.type}</div>
            <div className="meta">{formatDate(previewModal.data?.at)}</div>
          </div>
        ) : null}
        {previewModal.type === 'activity-all' ? (
          <div className="list">
            {(previewModal.data || []).map((row) => (
              <div key={`a-all-${row.id}`} className="list-item">
                <div>
                  <div className="name">{row.message}</div>
                  <div className="meta">{row.type} • {formatDate(row.at)}</div>
                </div>
              </div>
            ))}
          </div>
        ) : null}
        {previewModal.type === 'user' ? (
          <div className="stack">
            <div className="name">@{previewModal.data?.kadi}</div>
            <div className="meta">{previewModal.data?.isim} {previewModal.data?.soyisim}</div>
            <div className="meta">Kayıt: {formatDate(previewModal.data?.ilktarih)}</div>
          </div>
        ) : null}
        {previewModal.type === 'post' ? (
          <div className="stack">
            <div className="meta">Paylaşım ID: {previewModal.data?.id}</div>
            <div className="meta">Tarih: {formatDate(previewModal.data?.created_at)}</div>
            <div>{previewModal.data?.content || '(metin yok)'}</div>
            {previewModal.data?.image ? <img className="post-image" src={previewModal.data.image} alt="" /> : null}
          </div>
        ) : null}
        {previewModal.type === 'post-all' ? (
          <div className="list">
            {(previewModal.data || []).map((p) => (
              <button key={`p-all-${p.id}`} className="list-item" onClick={() => setPreviewModal({ type: 'post', data: p })}>
                <div>{(p.content || '').slice(0, 120) || '(metin yok)'}</div>
              </button>
            ))}
          </div>
        ) : null}
        {previewModal.type === 'follow' ? (
          <div className="stack">
            <div className="name">@{previewModal.data?.kadi}</div>
            <div className="meta">Takip tarihi: {formatDate(previewModal.data?.followed_at)}</div>
            <div className="meta">Mesaj sayısı: {previewModal.data?.messageCount || 0}</div>
            <div className="meta">Alıntılama sayısı: {previewModal.data?.quoteCount || 0}</div>
            <div>
              <b>Son Mesajlar</b>
              <div className="list">
                {(previewModal.data?.recentMessages || []).map((m) => (
                  <div key={`fm-${m.id}`} className="list-item">
                    <div>
                      <div className="name">{m.konu || '(konu yok)'}</div>
                      <div className="meta">{formatDate(m.tarih)}</div>
                      <div>{m.mesaj || ''}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
            <div>
              <b>Son Alıntılar</b>
              <div className="list">
                {(previewModal.data?.recentQuotes || []).map((q) => (
                  <div key={`fq-${q.id}`} className="list-item">
                    <div>
                      <div className="meta">{formatDate(q.created_at)}</div>
                      <div>{q.content || ''}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        ) : null}
        {previewModal.type === 'event' ? (
          <div className="stack">
            <div className="name">{previewModal.data?.title}</div>
            <div className="meta">{formatDate(previewModal.data?.starts_at)}</div>
            <div className="meta">{previewModal.data?.location || '-'}</div>
            <div dangerouslySetInnerHTML={{ __html: previewModal.data?.description || previewModal.data?.body || '' }} />
            {previewModal.data?.image ? <img className="post-image" src={previewModal.data.image} alt="" /> : null}
          </div>
        ) : null}
        {previewModal.type === 'announcement' ? (
          <div className="stack">
            <div className="name">{previewModal.data?.title}</div>
            <div className="meta">{formatDate(previewModal.data?.created_at)}</div>
            <div dangerouslySetInnerHTML={{ __html: previewModal.data?.body || previewModal.data?.description || '' }} />
            {previewModal.data?.image ? <img className="post-image" src={previewModal.data.image} alt="" /> : null}
          </div>
        ) : null}
      </div>
    </div>
  );
}
