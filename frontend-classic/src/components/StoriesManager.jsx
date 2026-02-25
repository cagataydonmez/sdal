import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { tarihduz } from '../utils/date.js';

async function apiRequest(url, options = {}) {
  const res = await fetch(url, { credentials: 'include', ...options });
  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Request failed: ${res.status}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

export default function StoriesManager() {
  const [stories, setStories] = useState([]);
  const [myStories, setMyStories] = useState([]);
  const [caption, setCaption] = useState('');
  const [file, setFile] = useState(null);
  const [loadingStories, setLoadingStories] = useState(false);
  const [busyStoryId, setBusyStoryId] = useState(null);
  const [busyUpload, setBusyUpload] = useState(false);
  const [statusMsg, setStatusMsg] = useState('');
  const [errorMsg, setErrorMsg] = useState('');
  const [editingStoryId, setEditingStoryId] = useState(null);
  const [editCaption, setEditCaption] = useState('');

  const loadStories = useCallback(async () => {
    setLoadingStories(true);
    setErrorMsg('');
    try {
      const [activeData, mineData] = await Promise.all([
        apiRequest('/api/new/stories'),
        apiRequest('/api/new/stories/mine')
      ]);
      setStories(Array.isArray(activeData?.items) ? activeData.items : []);
      setMyStories(Array.isArray(mineData?.items) ? mineData.items : []);
    } catch (err) {
      setErrorMsg(err.message || 'Hikayeler yüklenemedi.');
    } finally {
      setLoadingStories(false);
    }
  }, []);

  useEffect(() => {
    loadStories();
  }, [loadStories]);

  const activeCount = useMemo(() => myStories.filter((story) => !story.isExpired).length, [myStories]);
  const expiredCount = useMemo(() => myStories.filter((story) => story.isExpired).length, [myStories]);

  const clearMessages = () => {
    setStatusMsg('');
    setErrorMsg('');
  };

  const handleUpload = async (event) => {
    event.preventDefault();
    if (!file) {
      setErrorMsg('Lütfen bir görsel seçin.');
      return;
    }
    clearMessages();
    setBusyUpload(true);
    try {
      const formData = new FormData();
      formData.append('image', file);
      formData.append('caption', caption);
      await apiRequest('/api/new/stories/upload', {
        method: 'POST',
        body: formData
      });
      setCaption('');
      setFile(null);
      if (event.currentTarget) event.currentTarget.reset();
      setStatusMsg('Hikaye paylaşıldı.');
      await loadStories();
    } catch (err) {
      setErrorMsg(err.message || 'Hikaye paylaşılırken hata oluştu.');
    } finally {
      setBusyUpload(false);
    }
  };

  const handleMarkViewed = async (storyId) => {
    clearMessages();
    setBusyStoryId(storyId);
    try {
      await apiRequest(`/api/new/stories/${storyId}/view`, { method: 'POST' });
      setStories((prev) => prev.map((story) => (story.id === storyId ? { ...story, viewed: true } : story)));
    } catch (err) {
      setErrorMsg(err.message || 'Hikaye görüntüleme kaydedilemedi.');
    } finally {
      setBusyStoryId(null);
    }
  };

  const startEditing = (story) => {
    setEditingStoryId(story.id);
    setEditCaption(story.caption || '');
    clearMessages();
  };

  const handleEditSave = async (storyId) => {
    clearMessages();
    setBusyStoryId(storyId);
    try {
      await apiRequest(`/api/new/stories/${storyId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ caption: editCaption })
      });
      setEditingStoryId(null);
      setEditCaption('');
      setStatusMsg('Hikaye açıklaması güncellendi.');
      await loadStories();
    } catch (err) {
      setErrorMsg(err.message || 'Hikaye güncellenemedi.');
    } finally {
      setBusyStoryId(null);
    }
  };

  const handleDelete = async (storyId) => {
    if (!window.confirm('Bu hikayeyi silmek istediğine emin misin?')) return;
    clearMessages();
    setBusyStoryId(storyId);
    try {
      await apiRequest(`/api/new/stories/${storyId}`, { method: 'DELETE' });
      setStatusMsg('Hikaye silindi.');
      await loadStories();
    } catch (err) {
      setErrorMsg(err.message || 'Hikaye silinemedi.');
    } finally {
      setBusyStoryId(null);
    }
  };

  const handleRepost = async (storyId) => {
    clearMessages();
    setBusyStoryId(storyId);
    try {
      await apiRequest(`/api/new/stories/${storyId}/repost`, { method: 'POST' });
      setStatusMsg('Hikaye yeniden paylaşıldı.');
      await loadStories();
    } catch (err) {
      setErrorMsg(err.message || 'Hikaye yeniden paylaşılamadı.');
    } finally {
      setBusyStoryId(null);
    }
  };

  return (
    <div style={{ padding: 12 }}>
      <h3>Hikayeler</h3>
      <p>Hikayeler 24 saat görünür kalır. Süresi dolan hikayelerini aşağıdan yönetebilirsin.</p>

      <table border="0" cellPadding="4" cellSpacing="0" width="100%" style={{ marginBottom: 12 }}>
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300', background: '#ffffdd' }}>
              <b>Yeni Hikaye Paylaş</b>
              <form onSubmit={handleUpload} style={{ marginTop: 8 }}>
                <div style={{ marginBottom: 6 }}>
                  <input
                    type="file"
                    name="storyImage"
                    accept="image/*"
                    className="inptxt"
                    onChange={(event) => setFile(event.target.files?.[0] || null)}
                    disabled={busyUpload}
                  />
                </div>
                <div style={{ marginBottom: 6 }}>
                  <input
                    type="text"
                    className="inptxt"
                    value={caption}
                    onChange={(event) => setCaption(event.target.value)}
                    placeholder="Açıklama (isteğe bağlı)"
                    maxLength={500}
                    style={{ width: '98%' }}
                    disabled={busyUpload}
                  />
                </div>
                <input type="submit" value={busyUpload ? 'Yükleniyor...' : 'Paylaş'} className="sub" disabled={busyUpload} />
              </form>
            </td>
          </tr>
        </tbody>
      </table>

      {statusMsg ? <div className="sdal-alert" style={{ marginBottom: 10 }}>{statusMsg}</div> : null}
      {errorMsg ? <div className="hatamsg1" style={{ marginBottom: 10 }}>{errorMsg}</div> : null}

      <table border="0" cellPadding="4" cellSpacing="0" width="100%" style={{ marginBottom: 12 }}>
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300', background: '#ffffdd' }}>
              <b>Aktif Hikayeler</b>
              <div style={{ marginTop: 8 }}>
                {loadingStories ? 'Yükleniyor...' : null}
                {!loadingStories && stories.length === 0 ? 'Aktif hikaye yok.' : null}
                {!loadingStories && stories.map((story) => (
                  <div key={story.id} style={{ borderBottom: '1px solid #e5d5c1', padding: '8px 0' }}>
                    <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                      <img
                        src={story.image}
                        alt="Hikaye"
                        width="90"
                        height="120"
                        style={{ objectFit: 'cover', border: '1px solid #663300' }}
                      />
                      <div>
                        <div>
                          <b>{story.author?.kadi || 'Üye'}</b> - {story.viewed ? 'Görüldü' : 'Görülmedi'}
                        </div>
                        <div>{story.caption || <i>(Açıklama yok)</i>}</div>
                        <div style={{ fontSize: 10 }}>Süre sonu: {tarihduz(story.expiresAt)}</div>
                        {!story.viewed ? (
                          <input
                            type="button"
                            className="sub"
                            value={busyStoryId === story.id ? 'Kaydediliyor...' : 'Görüldü Olarak İşaretle'}
                            onClick={() => handleMarkViewed(story.id)}
                            disabled={busyStoryId === story.id}
                            style={{ marginTop: 4 }}
                          />
                        ) : null}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <table border="0" cellPadding="4" cellSpacing="0" width="100%">
        <tbody>
          <tr>
            <td style={{ border: '1px solid #663300', background: '#ffffdd' }}>
              <b>Hikayelerim</b> <small>(Aktif: {activeCount}, Süresi dolan: {expiredCount})</small>
              <div style={{ marginTop: 8 }}>
                {loadingStories ? 'Yükleniyor...' : null}
                {!loadingStories && myStories.length === 0 ? 'Henüz hikaye paylaşmadın.' : null}
                {!loadingStories && myStories.map((story) => (
                  <div key={story.id} style={{ borderBottom: '1px solid #e5d5c1', padding: '8px 0' }}>
                    <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
                      <img
                        src={story.image}
                        alt="Hikayem"
                        width="90"
                        height="120"
                        style={{ objectFit: 'cover', border: '1px solid #663300' }}
                      />
                      <div style={{ flex: 1 }}>
                        <div>
                          <b>Durum:</b> {story.isExpired ? 'Süresi doldu' : 'Aktif'}
                        </div>
                        <div><b>Paylaşım:</b> {tarihduz(story.createdAt)}</div>
                        <div><b>Süre sonu:</b> {tarihduz(story.expiresAt)}</div>
                        <div><b>Görüntülenme:</b> {story.viewCount}</div>

                        {editingStoryId === story.id ? (
                          <div style={{ marginTop: 6 }}>
                            <input
                              type="text"
                              className="inptxt"
                              value={editCaption}
                              onChange={(event) => setEditCaption(event.target.value)}
                              maxLength={500}
                              style={{ width: '96%' }}
                              disabled={busyStoryId === story.id}
                            />
                            <div style={{ marginTop: 4 }}>
                              <input
                                type="button"
                                className="sub"
                                value={busyStoryId === story.id ? 'Kaydediliyor...' : 'Kaydet'}
                                onClick={() => handleEditSave(story.id)}
                                disabled={busyStoryId === story.id}
                              />
                              <input
                                type="button"
                                className="sub"
                                value="Vazgeç"
                                onClick={() => setEditingStoryId(null)}
                                style={{ marginLeft: 6 }}
                                disabled={busyStoryId === story.id}
                              />
                            </div>
                          </div>
                        ) : (
                          <div style={{ marginTop: 6 }}>
                            <div>{story.caption || <i>(Açıklama yok)</i>}</div>
                            <div style={{ marginTop: 4 }}>
                              <input
                                type="button"
                                className="sub"
                                value="Düzenle"
                                onClick={() => startEditing(story)}
                                disabled={busyStoryId === story.id}
                              />
                              <input
                                type="button"
                                className="sub"
                                value={busyStoryId === story.id ? 'Siliniyor...' : 'Sil'}
                                onClick={() => handleDelete(story.id)}
                                style={{ marginLeft: 6 }}
                                disabled={busyStoryId === story.id}
                              />
                              {story.isExpired ? (
                                <input
                                  type="button"
                                  className="sub"
                                  value={busyStoryId === story.id ? 'Paylaşılıyor...' : 'Yeniden Paylaş'}
                                  onClick={() => handleRepost(story.id)}
                                  style={{ marginLeft: 6 }}
                                  disabled={busyStoryId === story.id}
                                />
                              ) : null}
                            </div>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  );
}
