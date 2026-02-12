import React, { useEffect, useMemo, useState } from 'react';
import LegacyLayout from '../components/LegacyLayout.jsx';
import { useAuth } from '../utils/auth.jsx';

async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    credentials: 'include',
    ...options
  });
  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Request failed: ${res.status}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

export default function AdminPage() {
  const { user, loading } = useAuth();
  const [adminOk, setAdminOk] = useState(false);
  const [adminPass, setAdminPass] = useState('');
  const [error, setError] = useState('');
  const [tab, setTab] = useState('members');

  const [memberFilter, setMemberFilter] = useState('all');
  const [members, setMembers] = useState([]);
  const [selectedMemberId, setSelectedMemberId] = useState('');
  const [memberDetail, setMemberDetail] = useState(null);

  const [searchQuery, setSearchQuery] = useState('');
  const [searchPhotoOnly, setSearchPhotoOnly] = useState(false);
  const [searchResults, setSearchResults] = useState([]);

  const [pages, setPages] = useState([]);
  const [pageForm, setPageForm] = useState({ sayfaismi: '', sayfaurl: '', babaid: '0', menugorun: 1, yonlendir: 0, mozellik: 0, resim: 'yok' });
  const [editPageId, setEditPageId] = useState('');

  const [emailForm, setEmailForm] = useState({ to: '', from: '', subject: '', html: '' });
  const [emailStatus, setEmailStatus] = useState('');
  const [emailCategories, setEmailCategories] = useState([]);
  const [emailTemplates, setEmailTemplates] = useState([]);
  const [emailCategoryForm, setEmailCategoryForm] = useState({ ad: '', tur: 'active', deger: '', aciklama: '' });
  const [editEmailCategoryId, setEditEmailCategoryId] = useState('');
  const [emailTemplateForm, setEmailTemplateForm] = useState({ ad: '', konu: '', icerik: '' });
  const [editEmailTemplateId, setEditEmailTemplateId] = useState('');
  const [bulkForm, setBulkForm] = useState({ categoryId: '', subject: '', html: '', from: '' });

  const [logType, setLogType] = useState('error');
  const [logFiles, setLogFiles] = useState([]);
  const [logContent, setLogContent] = useState('');
  const [selectedLog, setSelectedLog] = useState('');

  const [categories, setCategories] = useState([]);
  const [categoryCounts, setCategoryCounts] = useState({});
  const [categoryForm, setCategoryForm] = useState({ kategori: '', aciklama: '', aktif: 1 });
  const [editCategoryId, setEditCategoryId] = useState('');

  const [photoFilter, setPhotoFilter] = useState({ krt: 'onaybekleyen', kid: '', diz: '' });
  const [photos, setPhotos] = useState([]);
  const [photoSelected, setPhotoSelected] = useState({});
  const [photoEdit, setPhotoEdit] = useState(null);
  const [photoComments, setPhotoComments] = useState([]);

  const [teams, setTeams] = useState([]);

  useEffect(() => {
    apiJson('/api/admin/session')
      .then((data) => setAdminOk(!!data.adminOk))
      .catch(() => setAdminOk(false));
  }, []);

  const isAdmin = user?.admin === 1;

  async function adminLogin(e) {
    e.preventDefault();
    setError('');
    try {
      await apiJson('/api/admin/login', { method: 'POST', body: JSON.stringify({ password: adminPass }) });
      setAdminOk(true);
      setAdminPass('');
    } catch (err) {
      setError(err.message);
    }
  }

  async function adminLogout() {
    await apiJson('/api/admin/logout', { method: 'POST' });
    setAdminOk(false);
  }

  async function loadMembers() {
    setError('');
    try {
      const data = await apiJson(`/api/admin/users/lists?filter=${memberFilter}`);
      setMembers(data.users || []);
    } catch (err) {
      setError(err.message);
    }
  }

  async function loadMemberDetail(id) {
    setError('');
    try {
      const data = await apiJson(`/api/admin/users/${id}`);
      setMemberDetail(data.user);
    } catch (err) {
      setError(err.message);
    }
  }

  async function saveMemberDetail() {
    if (!memberDetail) return;
    setError('');
    try {
      await apiJson(`/api/admin/users/${memberDetail.id}`, {
        method: 'PUT',
        body: JSON.stringify(memberDetail)
      });
      await loadMembers();
    } catch (err) {
      setError(err.message);
    }
  }

  async function doSearch() {
    setError('');
    try {
      const qs = searchPhotoOnly ? 'res=1' : `q=${encodeURIComponent(searchQuery)}`;
      const data = await apiJson(`/api/admin/users/search?${qs}`);
      setSearchResults(data.users || []);
    } catch (err) {
      setError(err.message);
    }
  }

  async function loadPages() {
    setError('');
    try {
      const data = await apiJson('/api/admin/pages');
      setPages(data.pages || []);
    } catch (err) {
      setError(err.message);
    }
  }

  async function savePage() {
    setError('');
    try {
      if (editPageId) {
        await apiJson(`/api/admin/pages/${editPageId}`, { method: 'PUT', body: JSON.stringify(pageForm) });
      } else {
        await apiJson('/api/admin/pages', { method: 'POST', body: JSON.stringify(pageForm) });
      }
      setPageForm({ sayfaismi: '', sayfaurl: '', babaid: '0', menugorun: 1, yonlendir: 0, mozellik: 0, resim: 'yok' });
      setEditPageId('');
      await loadPages();
    } catch (err) {
      setError(err.message);
    }
  }

  async function deletePage(id) {
    setError('');
    try {
      await apiJson(`/api/admin/pages/${id}`, { method: 'DELETE' });
      await loadPages();
    } catch (err) {
      setError(err.message);
    }
  }

  async function sendEmail() {
    setError('');
    setEmailStatus('');
    try {
      await apiJson('/api/admin/email/send', { method: 'POST', body: JSON.stringify(emailForm) });
      setEmailStatus('E-mail gönderildi.');
    } catch (err) {
      setError(err.message);
    }
  }

  async function loadEmailCategories() {
    setError('');
    try {
      const data = await apiJson('/api/admin/email/categories');
      setEmailCategories(data.categories || []);
    } catch (err) {
      setError(err.message);
    }
  }

  async function saveEmailCategory() {
    setError('');
    try {
      if (editEmailCategoryId) {
        await apiJson(`/api/admin/email/categories/${editEmailCategoryId}`, { method: 'PUT', body: JSON.stringify(emailCategoryForm) });
      } else {
        await apiJson('/api/admin/email/categories', { method: 'POST', body: JSON.stringify(emailCategoryForm) });
      }
      setEmailCategoryForm({ ad: '', tur: 'active', deger: '', aciklama: '' });
      setEditEmailCategoryId('');
      await loadEmailCategories();
    } catch (err) {
      setError(err.message);
    }
  }

  async function deleteEmailCategory(id) {
    setError('');
    try {
      await apiJson(`/api/admin/email/categories/${id}`, { method: 'DELETE' });
      await loadEmailCategories();
    } catch (err) {
      setError(err.message);
    }
  }

  async function loadEmailTemplates() {
    setError('');
    try {
      const data = await apiJson('/api/admin/email/templates');
      setEmailTemplates(data.templates || []);
    } catch (err) {
      setError(err.message);
    }
  }

  async function saveEmailTemplate() {
    setError('');
    try {
      if (editEmailTemplateId) {
        await apiJson(`/api/admin/email/templates/${editEmailTemplateId}`, { method: 'PUT', body: JSON.stringify(emailTemplateForm) });
      } else {
        await apiJson('/api/admin/email/templates', { method: 'POST', body: JSON.stringify(emailTemplateForm) });
      }
      setEmailTemplateForm({ ad: '', konu: '', icerik: '' });
      setEditEmailTemplateId('');
      await loadEmailTemplates();
    } catch (err) {
      setError(err.message);
    }
  }

  async function deleteEmailTemplate(id) {
    setError('');
    try {
      await apiJson(`/api/admin/email/templates/${id}`, { method: 'DELETE' });
      await loadEmailTemplates();
    } catch (err) {
      setError(err.message);
    }
  }

  async function sendBulkEmail() {
    setError('');
    setEmailStatus('');
    try {
      const payload = { ...bulkForm, categoryId: bulkForm.categoryId || undefined };
      const data = await apiJson('/api/admin/email/bulk', { method: 'POST', body: JSON.stringify(payload) });
      setEmailStatus(`Toplam ${data.count || 0} e-mail gönderildi.`);
    } catch (err) {
      setError(err.message);
    }
  }

  async function loadLogs() {
    setError('');
    try {
      const data = await apiJson(`/api/admin/logs?type=${logType}`);
      setLogFiles(data.files || []);
    } catch (err) {
      setError(err.message);
    }
  }

  async function openLogFile(name) {
    setError('');
    setSelectedLog(name);
    try {
      const data = await apiJson(`/api/admin/logs?type=${logType}&file=${encodeURIComponent(name)}`);
      setLogContent(data.content || '');
    } catch (err) {
      setError(err.message);
    }
  }

  async function loadCategories() {
    setError('');
    try {
      const data = await apiJson('/api/admin/album/categories');
      setCategories(data.categories || []);
      setCategoryCounts(data.counts || {});
    } catch (err) {
      setError(err.message);
    }
  }

  async function saveCategory() {
    setError('');
    try {
      if (editCategoryId) {
        await apiJson(`/api/admin/album/categories/${editCategoryId}`, { method: 'PUT', body: JSON.stringify(categoryForm) });
      } else {
        await apiJson('/api/admin/album/categories', { method: 'POST', body: JSON.stringify(categoryForm) });
      }
      setCategoryForm({ kategori: '', aciklama: '', aktif: 1 });
      setEditCategoryId('');
      await loadCategories();
    } catch (err) {
      setError(err.message);
    }
  }

  async function deleteCategory(id) {
    setError('');
    try {
      await apiJson(`/api/admin/album/categories/${id}`, { method: 'DELETE' });
      await loadCategories();
    } catch (err) {
      setError(err.message);
    }
  }

  async function loadPhotos() {
    setError('');
    const qs = new URLSearchParams(photoFilter).toString();
    try {
      const data = await apiJson(`/api/admin/album/photos?${qs}`);
      setPhotos(data.photos || []);
    } catch (err) {
      setError(err.message);
    }
  }

  async function bulkPhoto(action) {
    const ids = Object.keys(photoSelected).filter((id) => photoSelected[id]);
    if (!ids.length) return;
    setError('');
    try {
      await apiJson('/api/admin/album/photos/bulk', { method: 'POST', body: JSON.stringify({ ids, action }) });
      await loadPhotos();
    } catch (err) {
      setError(err.message);
    }
  }

  async function updatePhoto() {
    if (!photoEdit) return;
    setError('');
    try {
      await apiJson(`/api/admin/album/photos/${photoEdit.id}`, { method: 'PUT', body: JSON.stringify(photoEdit) });
      setPhotoEdit(null);
      await loadPhotos();
    } catch (err) {
      setError(err.message);
    }
  }

  async function deletePhoto(id) {
    setError('');
    try {
      await apiJson(`/api/admin/album/photos/${id}`, { method: 'DELETE' });
      await loadPhotos();
    } catch (err) {
      setError(err.message);
    }
  }

  async function loadPhotoComments(id) {
    setError('');
    try {
      const data = await apiJson(`/api/admin/album/photos/${id}/comments`);
      setPhotoComments(data.comments || []);
    } catch (err) {
      setError(err.message);
    }
  }

  async function deleteComment(photoId, commentId) {
    setError('');
    try {
      await apiJson(`/api/admin/album/photos/${photoId}/comments/${commentId}`, { method: 'DELETE' });
      await loadPhotoComments(photoId);
    } catch (err) {
      setError(err.message);
    }
  }

  async function loadTeams() {
    setError('');
    try {
      const data = await apiJson('/api/admin/tournament');
      setTeams(data.teams || []);
    } catch (err) {
      setError(err.message);
    }
  }

  async function deleteTeam(id) {
    setError('');
    try {
      await apiJson(`/api/admin/tournament/${id}`, { method: 'DELETE' });
      await loadTeams();
    } catch (err) {
      setError(err.message);
    }
  }

  const tabs = useMemo(() => ([
    { id: 'members', label: 'Üyeler' },
    { id: 'search', label: 'Üye Ara' },
    { id: 'pages', label: 'Sayfalar' },
    { id: 'email', label: 'E-Mail' },
    { id: 'logs', label: 'Kayıtlar' },
    { id: 'album', label: 'Albüm' },
    { id: 'tournament', label: 'Turnuva' }
  ]), []);

  if (loading) {
    return (
      <LegacyLayout pageTitle="Yönetim Paneli" showLeftColumn={false}>
        Yükleniyor...
      </LegacyLayout>
    );
  }

  if (!user) {
    return (
      <LegacyLayout pageTitle="Yönetim Paneli" showLeftColumn={false}>
        Yönetim paneline girmek için giriş yapmalısınız.
      </LegacyLayout>
    );
  }

  if (!isAdmin) {
    return (
      <LegacyLayout pageTitle="Yönetim Paneli" showLeftColumn={false}>
        Bu sayfaya erişiminiz yok.
      </LegacyLayout>
    );
  }

  if (!adminOk) {
    return (
      <LegacyLayout pageTitle="Yönetim Paneli" showLeftColumn={false}>
        <form onSubmit={adminLogin}>
          <b>Yönetim Şifresi:</b><br />
          <input type="password" className="inptxt" value={adminPass} onChange={(e) => setAdminPass(e.target.value)} />
          <input type="submit" className="sub" value="Gir" />
        </form>
        {error ? <div className="hatamsg1">{error}</div> : null}
      </LegacyLayout>
    );
  }

  return (
    <LegacyLayout pageTitle="Yönetim Paneli" showLeftColumn={false}>
      <div style={{ padding: 10 }}>
        <div style={{ marginBottom: 10 }}>
          {tabs.map((t) => (
            <button key={t.id} className="sub" onClick={() => setTab(t.id)} style={{ marginRight: 6 }}>
              {t.label}
            </button>
          ))}
          <button className="sub" onClick={adminLogout}>Çıkış</button>
        </div>
        {error ? <div className="hatamsg1">{error}</div> : null}

        {tab === 'members' && (
          <div>
            <b>Üye Listeleri</b><br />
            <select className="inptxt" value={memberFilter} onChange={(e) => setMemberFilter(e.target.value)}>
              <option value="all">Genel Sıralama</option>
              <option value="active">Aktif Üyeler</option>
              <option value="pending">Aktivite Bekleyen Üyeler</option>
              <option value="banned">Yasaklı Üyeler</option>
              <option value="recent">Son Giriş Tarihi</option>
              <option value="online">Online Üyeler</option>
            </select>
            <button className="sub" onClick={loadMembers}>Yükle</button>
            <div style={{ marginTop: 10 }}>
              <select className="inptxt" value={selectedMemberId} onChange={(e) => setSelectedMemberId(e.target.value)}>
                <option value="">Üye seç</option>
                {members.map((m, idx) => (
                  <option key={m.id} value={m.id}>{idx + 1} - {m.kadi} ({m.isim} {m.soyisim})</option>
                ))}
              </select>
              <button className="sub" onClick={() => selectedMemberId && loadMemberDetail(selectedMemberId)}>Göster</button>
            </div>
            {memberDetail && (
              <div style={{ marginTop: 10 }}>
                <table border="0" cellPadding="3" cellSpacing="1">
                  <tbody>
                    <tr><td>Şifre</td><td><input type="text" className="inptxt" value={memberDetail.sifre || ''} onChange={(e) => setMemberDetail({ ...memberDetail, sifre: e.target.value })} /></td></tr>
                    <tr><td>İsim</td><td><input type="text" className="inptxt" value={memberDetail.isim || ''} onChange={(e) => setMemberDetail({ ...memberDetail, isim: e.target.value })} /></td></tr>
                    <tr><td>Soyisim</td><td><input type="text" className="inptxt" value={memberDetail.soyisim || ''} onChange={(e) => setMemberDetail({ ...memberDetail, soyisim: e.target.value })} /></td></tr>
                    <tr><td>Aktivasyon</td><td><input type="text" className="inptxt" value={memberDetail.aktivasyon || ''} onChange={(e) => setMemberDetail({ ...memberDetail, aktivasyon: e.target.value })} /></td></tr>
                    <tr><td>Email</td><td><input type="text" className="inptxt" value={memberDetail.email || ''} onChange={(e) => setMemberDetail({ ...memberDetail, email: e.target.value })} /></td></tr>
                    <tr><td>Aktiv</td><td><input type="text" className="inptxt" value={memberDetail.aktiv ?? ''} onChange={(e) => setMemberDetail({ ...memberDetail, aktiv: e.target.value })} /></td></tr>
                    <tr><td>Yasak</td><td><input type="text" className="inptxt" value={memberDetail.yasak ?? ''} onChange={(e) => setMemberDetail({ ...memberDetail, yasak: e.target.value })} /></td></tr>
                    <tr><td>İlk BD</td><td><input type="text" className="inptxt" value={memberDetail.ilkbd ?? ''} onChange={(e) => setMemberDetail({ ...memberDetail, ilkbd: e.target.value })} /></td></tr>
                    <tr><td>Web</td><td><input type="text" className="inptxt" value={memberDetail.websitesi || ''} onChange={(e) => setMemberDetail({ ...memberDetail, websitesi: e.target.value })} /></td></tr>
                    <tr><td>İmza</td><td><textarea className="inptxt" rows="3" cols="40" value={memberDetail.imza || ''} onChange={(e) => setMemberDetail({ ...memberDetail, imza: e.target.value })} /></td></tr>
                    <tr><td>Meslek</td><td><input type="text" className="inptxt" value={memberDetail.meslek || ''} onChange={(e) => setMemberDetail({ ...memberDetail, meslek: e.target.value })} /></td></tr>
                    <tr><td>Şehir</td><td><input type="text" className="inptxt" value={memberDetail.sehir || ''} onChange={(e) => setMemberDetail({ ...memberDetail, sehir: e.target.value })} /></td></tr>
                    <tr><td>Mail Kapalı</td><td><input type="text" className="inptxt" value={memberDetail.mailkapali ?? ''} onChange={(e) => setMemberDetail({ ...memberDetail, mailkapali: e.target.value })} /></td></tr>
                    <tr><td>Hit</td><td><input type="text" className="inptxt" value={memberDetail.hit ?? ''} onChange={(e) => setMemberDetail({ ...memberDetail, hit: e.target.value })} /></td></tr>
                    <tr><td>Mezuniyet</td><td><input type="text" className="inptxt" value={memberDetail.mezuniyetyili || ''} onChange={(e) => setMemberDetail({ ...memberDetail, mezuniyetyili: e.target.value })} /></td></tr>
                    <tr><td>Üniversite</td><td><input type="text" className="inptxt" value={memberDetail.universite || ''} onChange={(e) => setMemberDetail({ ...memberDetail, universite: e.target.value })} /></td></tr>
                    <tr><td>Doğum</td><td><input type="text" className="inptxt" value={memberDetail.dogumgun || ''} onChange={(e) => setMemberDetail({ ...memberDetail, dogumgun: e.target.value })} /> . <input type="text" className="inptxt" value={memberDetail.dogumay || ''} onChange={(e) => setMemberDetail({ ...memberDetail, dogumay: e.target.value })} /> . <input type="text" className="inptxt" value={memberDetail.dogumyil || ''} onChange={(e) => setMemberDetail({ ...memberDetail, dogumyil: e.target.value })} /></td></tr>
                    <tr><td>Admin</td><td><input type="text" className="inptxt" value={memberDetail.admin ?? ''} onChange={(e) => setMemberDetail({ ...memberDetail, admin: e.target.value })} /></td></tr>
                    <tr><td>Resim</td><td><input type="text" className="inptxt" value={memberDetail.resim || ''} onChange={(e) => setMemberDetail({ ...memberDetail, resim: e.target.value })} /></td></tr>
                  </tbody>
                </table>
                <button className="sub" onClick={saveMemberDetail}>Düzenle</button>
              </div>
            )}
          </div>
        )}

        {tab === 'search' && (
          <div>
            <b>Üye Ara</b><br />
            <input type="text" className="inptxt" value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} />
            <label style={{ marginLeft: 8 }}>
              <input type="checkbox" checked={searchPhotoOnly} onChange={(e) => setSearchPhotoOnly(e.target.checked)} /> Foto olanlar
            </label>
            <button className="sub" onClick={doSearch}>Ara</button>
            <div style={{ marginTop: 10 }}>
              {searchResults.map((m, idx) => (
                <div key={m.id}>
                  {idx + 1} - <img src={`/api/media/kucukresim?iwidth=50&r=${encodeURIComponent(m.resim || 'nophoto.jpg')}`} alt="" />
                  &nbsp; {m.kadi} - {m.isim} {m.soyisim}
                </div>
              ))}
            </div>
          </div>
        )}

        {tab === 'pages' && (
          <div>
            <b>Sayfalar</b><br />
            <button className="sub" onClick={loadPages}>Listeyi Yükle</button>
            <div style={{ marginTop: 10 }}>
              <table border="0" cellPadding="3" cellSpacing="1">
                <thead>
                  <tr>
                    <td><b>ID</b></td>
                    <td><b>Sayfa</b></td>
                    <td><b>Url</b></td>
                    <td><b>Hit</b></td>
                    <td><b>İşlem</b></td>
                  </tr>
                </thead>
                <tbody>
                  {pages.map((p) => (
                    <tr key={p.id}>
                      <td>{p.id}</td>
                      <td>{p.sayfaismi}</td>
                      <td>{p.sayfaurl}</td>
                      <td>{p.hit}</td>
                      <td>
                        <button className="sub" onClick={() => { setEditPageId(p.id); setPageForm(p); }}>Düzenle</button>
                        <button className="sub" onClick={() => deletePage(p.id)}>Sil</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div style={{ marginTop: 10 }}>
              <b>{editPageId ? `Sayfa Düzenle (#${editPageId})` : 'Yeni Sayfa Ekle'}</b><br />
              <input className="inptxt" placeholder="Sayfa İsmi" value={pageForm.sayfaismi || ''} onChange={(e) => setPageForm({ ...pageForm, sayfaismi: e.target.value })} />
              <input className="inptxt" placeholder="Sayfa URL" value={pageForm.sayfaurl || ''} onChange={(e) => setPageForm({ ...pageForm, sayfaurl: e.target.value })} />
              <input className="inptxt" placeholder="Baba ID" value={pageForm.babaid || ''} onChange={(e) => setPageForm({ ...pageForm, babaid: e.target.value })} />
              <input className="inptxt" placeholder="Menü Görün (1/0)" value={pageForm.menugorun ?? ''} onChange={(e) => setPageForm({ ...pageForm, menugorun: e.target.value })} />
              <input className="inptxt" placeholder="Yönlendir (1/0)" value={pageForm.yonlendir ?? ''} onChange={(e) => setPageForm({ ...pageForm, yonlendir: e.target.value })} />
              <input className="inptxt" placeholder="M.Ozellik (1/0)" value={pageForm.mozellik ?? ''} onChange={(e) => setPageForm({ ...pageForm, mozellik: e.target.value })} />
              <input className="inptxt" placeholder="Resim" value={pageForm.resim || ''} onChange={(e) => setPageForm({ ...pageForm, resim: e.target.value })} />
              <button className="sub" onClick={savePage}>Kaydet</button>
            </div>
          </div>
        )}

        {tab === 'email' && (
          <div>
            <b>Hızlı E-mail Gönder</b><br />
            <input className="inptxt" placeholder="Kime" value={emailForm.to} onChange={(e) => setEmailForm({ ...emailForm, to: e.target.value })} />
            <input className="inptxt" placeholder="Kimden" value={emailForm.from} onChange={(e) => setEmailForm({ ...emailForm, from: e.target.value })} />
            <input className="inptxt" placeholder="Konu" value={emailForm.subject} onChange={(e) => setEmailForm({ ...emailForm, subject: e.target.value })} />
            <textarea className="inptxt" rows="6" cols="60" placeholder="Metin" value={emailForm.html} onChange={(e) => setEmailForm({ ...emailForm, html: e.target.value })} />
            <button className="sub" onClick={sendEmail}>Gönder</button>
            {emailStatus ? <div>{emailStatus}</div> : null}

            <hr />
            <b>Çoklu E-mail Gönder</b><br />
            <button className="sub" onClick={loadEmailCategories}>Kategorileri Yükle</button>
            <div style={{ marginTop: 6 }}>
              <select className="inptxt" value={bulkForm.categoryId} onChange={(e) => setBulkForm({ ...bulkForm, categoryId: e.target.value })}>
                <option value="">Kategori seç</option>
                {emailCategories.map((c) => (
                  <option key={c.id} value={c.id}>{c.ad} ({c.tur}{c.deger ? `:${c.deger}` : ''})</option>
                ))}
              </select>
            </div>
            <input className="inptxt" placeholder="Kimden" value={bulkForm.from} onChange={(e) => setBulkForm({ ...bulkForm, from: e.target.value })} />
            <input className="inptxt" placeholder="Konu" value={bulkForm.subject} onChange={(e) => setBulkForm({ ...bulkForm, subject: e.target.value })} />
            <textarea className="inptxt" rows="6" cols="60" placeholder="Metin" value={bulkForm.html} onChange={(e) => setBulkForm({ ...bulkForm, html: e.target.value })} />
            <button className="sub" onClick={sendBulkEmail}>Gönder</button>

            <hr />
            <b>Kategori Ekle/Düzenle</b><br />
            <button className="sub" onClick={loadEmailCategories}>Listeyi Yükle</button>
            <table border="0" cellPadding="3" cellSpacing="1" style={{ marginTop: 8 }}>
              <thead>
                <tr><td>ID</td><td>Ad</td><td>Tür</td><td>Değer</td><td>İşlem</td></tr>
              </thead>
              <tbody>
                {emailCategories.map((c) => (
                  <tr key={c.id}>
                    <td>{c.id}</td>
                    <td>{c.ad}</td>
                    <td>{c.tur}</td>
                    <td>{c.deger}</td>
                    <td>
                      <button className="sub" onClick={() => { setEditEmailCategoryId(c.id); setEmailCategoryForm({ ad: c.ad, tur: c.tur, deger: c.deger || '', aciklama: c.aciklama || '' }); }}>Düzenle</button>
                      <button className="sub" onClick={() => deleteEmailCategory(c.id)}>Sil</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div style={{ marginTop: 8 }}>
              <input className="inptxt" placeholder="Kategori Adı" value={emailCategoryForm.ad} onChange={(e) => setEmailCategoryForm({ ...emailCategoryForm, ad: e.target.value })} />
              <select className="inptxt" value={emailCategoryForm.tur} onChange={(e) => setEmailCategoryForm({ ...emailCategoryForm, tur: e.target.value })}>
                <option value="active">Aktif Üyeler</option>
                <option value="all">Tüm Üyeler</option>
                <option value="pending">Aktivite Bekleyen</option>
                <option value="banned">Yasaklı</option>
                <option value="year">Mezuniyet</option>
                <option value="custom">Özel Liste</option>
              </select>
              <input className="inptxt" placeholder="Değer (mezuniyet yılı veya e-posta listesi)" value={emailCategoryForm.deger} onChange={(e) => setEmailCategoryForm({ ...emailCategoryForm, deger: e.target.value })} />
              <input className="inptxt" placeholder="Açıklama" value={emailCategoryForm.aciklama} onChange={(e) => setEmailCategoryForm({ ...emailCategoryForm, aciklama: e.target.value })} />
              <button className="sub" onClick={saveEmailCategory}>{editEmailCategoryId ? 'Güncelle' : 'Ekle'}</button>
            </div>

            <hr />
            <b>Şablon Ekle/Düzenle</b><br />
            <button className="sub" onClick={loadEmailTemplates}>Şablonları Yükle</button>
            <table border="0" cellPadding="3" cellSpacing="1" style={{ marginTop: 8 }}>
              <thead>
                <tr><td>ID</td><td>Ad</td><td>Konu</td><td>İşlem</td></tr>
              </thead>
              <tbody>
                {emailTemplates.map((t) => (
                  <tr key={t.id}>
                    <td>{t.id}</td>
                    <td>{t.ad}</td>
                    <td>{t.konu}</td>
                    <td>
                      <button className="sub" onClick={() => { setEditEmailTemplateId(t.id); setEmailTemplateForm({ ad: t.ad, konu: t.konu, icerik: t.icerik || '' }); }}>Düzenle</button>
                      <button className="sub" onClick={() => deleteEmailTemplate(t.id)}>Sil</button>
                      <button className="sub" onClick={() => setEmailForm({ ...emailForm, subject: t.konu, html: t.icerik || '' })}>Tekile Aktar</button>
                      <button className="sub" onClick={() => setBulkForm({ ...bulkForm, subject: t.konu, html: t.icerik || '' })}>Çokluya Aktar</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div style={{ marginTop: 8 }}>
              <input className="inptxt" placeholder="Şablon Adı" value={emailTemplateForm.ad} onChange={(e) => setEmailTemplateForm({ ...emailTemplateForm, ad: e.target.value })} />
              <input className="inptxt" placeholder="Konu" value={emailTemplateForm.konu} onChange={(e) => setEmailTemplateForm({ ...emailTemplateForm, konu: e.target.value })} />
              <textarea className="inptxt" rows="6" cols="60" placeholder="İçerik" value={emailTemplateForm.icerik} onChange={(e) => setEmailTemplateForm({ ...emailTemplateForm, icerik: e.target.value })} />
              <button className="sub" onClick={saveEmailTemplate}>{editEmailTemplateId ? 'Güncelle' : 'Ekle'}</button>
            </div>
          </div>
        )}

        {tab === 'logs' && (
          <div>
            <b>Kayıtlar</b><br />
            <select className="inptxt" value={logType} onChange={(e) => setLogType(e.target.value)}>
              <option value="error">Hata ve IP</option>
              <option value="page">Sayfa Kayıtları</option>
              <option value="member">Üye Detay Kayıtları</option>
            </select>
            <button className="sub" onClick={loadLogs}>Listeyi Yükle</button>
            <div style={{ marginTop: 10 }}>
              {logFiles.map((f) => (
                <div key={f.name}>
                  <button className="sub" onClick={() => openLogFile(f.name)}>{f.name}</button>
                  <small> {Math.round(f.size / 1024)} KB</small>
                </div>
              ))}
            </div>
            {selectedLog ? <div style={{ marginTop: 10 }}><b>{selectedLog}</b><pre>{logContent}</pre></div> : null}
          </div>
        )}

        {tab === 'album' && (
          <div>
            <b>Albüm Kategorileri</b><br />
            <button className="sub" onClick={loadCategories}>Kategorileri Yükle</button>
            <table border="0" cellPadding="3" cellSpacing="1" style={{ marginTop: 10 }}>
              <thead>
                <tr><td>ID</td><td>Kategori</td><td>Aktif</td><td>İşlem</td></tr>
              </thead>
              <tbody>
                {categories.map((c) => (
                  <tr key={c.id}>
                    <td>{c.id}</td>
                    <td>{c.kategori} (Aktif:{categoryCounts[c.id]?.activeCount || 0}, İnaktif:{categoryCounts[c.id]?.inactiveCount || 0})</td>
                    <td>{c.aktif}</td>
                    <td>
                      <button className="sub" onClick={() => { setEditCategoryId(c.id); setCategoryForm({ kategori: c.kategori, aciklama: c.aciklama, aktif: c.aktif }); }}>Düzenle</button>
                      <button className="sub" onClick={() => deleteCategory(c.id)}>Sil</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div style={{ marginTop: 10 }}>
              <input className="inptxt" placeholder="Kategori" value={categoryForm.kategori} onChange={(e) => setCategoryForm({ ...categoryForm, kategori: e.target.value })} />
              <input className="inptxt" placeholder="Açıklama" value={categoryForm.aciklama} onChange={(e) => setCategoryForm({ ...categoryForm, aciklama: e.target.value })} />
              <input className="inptxt" placeholder="Aktif (1/0)" value={categoryForm.aktif} onChange={(e) => setCategoryForm({ ...categoryForm, aktif: e.target.value })} />
              <button className="sub" onClick={saveCategory}>{editCategoryId ? 'Güncelle' : 'Ekle'}</button>
            </div>

            <hr />
            <b>Fotoğraflar</b><br />
            <select className="inptxt" value={photoFilter.krt} onChange={(e) => setPhotoFilter({ ...photoFilter, krt: e.target.value })}>
              <option value="onaybekleyen">Onay Bekleyen</option>
              <option value="kategori">Kategori</option>
            </select>
            <input className="inptxt" placeholder="Kategori ID" value={photoFilter.kid} onChange={(e) => setPhotoFilter({ ...photoFilter, kid: e.target.value })} />
            <input className="inptxt" placeholder="Sıralama" value={photoFilter.diz} onChange={(e) => setPhotoFilter({ ...photoFilter, diz: e.target.value })} />
            <button className="sub" onClick={loadPhotos}>Listele</button>
            <button className="sub" onClick={() => bulkPhoto('aktiv')}>Seçilenleri Aktifleştir</button>
            <button className="sub" onClick={() => bulkPhoto('deaktiv')}>Seçilenleri İnaktif</button>
            <table border="0" cellPadding="3" cellSpacing="1" style={{ marginTop: 10 }}>
              <thead>
                <tr><td>#</td><td>Foto</td><td>Başlık</td><td>Aktif</td><td>İşlem</td></tr>
              </thead>
              <tbody>
                {photos.map((p) => (
                  <tr key={p.id}>
                    <td><input type="checkbox" checked={!!photoSelected[p.id]} onChange={(e) => setPhotoSelected({ ...photoSelected, [p.id]: e.target.checked })} /></td>
                    <td><img src={`/api/media/kucukresim?iwidth=50&r=${encodeURIComponent(p.dosyaadi || 'nophoto.jpg')}`} alt="" /></td>
                    <td>{p.baslik}</td>
                    <td>{p.aktif}</td>
                    <td>
                      <button className="sub" onClick={() => { setPhotoEdit(p); loadPhotoComments(p.id); }}>Düzenle</button>
                      <button className="sub" onClick={() => deletePhoto(p.id)}>Sil</button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {photoEdit && (
              <div style={{ marginTop: 10 }}>
                <b>Fotoğraf Düzenle</b><br />
                <input className="inptxt" value={photoEdit.baslik || ''} onChange={(e) => setPhotoEdit({ ...photoEdit, baslik: e.target.value })} />
                <input className="inptxt" value={photoEdit.aciklama || ''} onChange={(e) => setPhotoEdit({ ...photoEdit, aciklama: e.target.value })} />
                <input className="inptxt" value={photoEdit.aktif ?? ''} onChange={(e) => setPhotoEdit({ ...photoEdit, aktif: e.target.value })} />
                <input className="inptxt" value={photoEdit.katid ?? ''} onChange={(e) => setPhotoEdit({ ...photoEdit, katid: e.target.value })} />
                <button className="sub" onClick={updatePhoto}>Kaydet</button>
                <div style={{ marginTop: 10 }}>
                  <b>Yorumlar</b>
                  {photoComments.map((c) => (
                    <div key={c.id}>
                      <i>{c.uyeadi}</i>: {c.yorum} <button className="sub" onClick={() => deleteComment(photoEdit.id, c.id)}>Sil</button>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {tab === 'tournament' && (
          <div>
            <b>Futbol Turnuvası</b><br />
            <button className="sub" onClick={loadTeams}>Listeyi Yükle</button>
            <table border="0" cellPadding="3" cellSpacing="1" style={{ marginTop: 10 }}>
              <thead>
                <tr><td>#</td><td>Takım</td><td>Kaptan</td><td>Tarih</td><td>İşlem</td></tr>
              </thead>
              <tbody>
                {teams.map((t, idx) => (
                  <tr key={t.id}>
                    <td>{idx + 1}</td>
                    <td>{t.tisim}</td>
                    <td>{t.tkid}</td>
                    <td>{t.tarih}</td>
                    <td><button className="sub" onClick={() => deleteTeam(t.id)}>Sil</button></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </LegacyLayout>
  );
}
