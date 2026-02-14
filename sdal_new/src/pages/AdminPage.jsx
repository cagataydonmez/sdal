import React, { useEffect, useState } from 'react';
import Layout from '../components/Layout.jsx';
import { useAuth } from '../utils/auth.jsx';

async function apiJson(url, options = {}) {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(options.headers || {}) },
    credentials: 'include',
    ...options
  });
  if (!res.ok) {
    const msg = await res.text();
    throw new Error(msg || `Request failed: ${res.status}`);
  }
  return res.json();
}

const tabs = [
  { key: 'dashboard', label: 'Dashboard' },
  { key: 'users', label: 'Üyeler' },
  { key: 'album', label: 'Albüm Kategorileri' },
  { key: 'photos', label: 'Fotoğraf Moderasyon' },
  { key: 'messages', label: 'Mesajlar' },
  { key: 'pages', label: 'Sayfalar' },
  { key: 'email', label: 'E-Posta' },
  { key: 'logs', label: 'Loglar' },
  { key: 'tournament', label: 'Turnuva' },
  { key: 'verification', label: 'Doğrulama' },
  { key: 'events', label: 'Etkinlikler' },
  { key: 'announcements', label: 'Duyurular' },
  { key: 'groups', label: 'Gruplar' },
  { key: 'stories', label: 'Hikayeler' },
  { key: 'chat', label: 'Canlı Sohbet' }
];

export default function AdminPage() {
  const { user } = useAuth();
  const [tab, setTab] = useState('dashboard');
  const [status, setStatus] = useState('');
  const [adminOk, setAdminOk] = useState(false);
  const [adminPassword, setAdminPassword] = useState('');

  const [stats, setStats] = useState(null);
  const [users, setUsers] = useState([]);
  const [userFilter, setUserFilter] = useState('active');
  const [userQuery, setUserQuery] = useState('');
  const [userDetail, setUserDetail] = useState(null);
  const [userForm, setUserForm] = useState(null);

  const [categories, setCategories] = useState([]);
  const [categoryForm, setCategoryForm] = useState({ kategori: '', aciklama: '', aktif: 1 });

  const [photos, setPhotos] = useState([]);
  const [photoFilter, setPhotoFilter] = useState({ krt: 'onaybekleyen', kid: '', diz: '' });
  const [photoEdit, setPhotoEdit] = useState(null);

  const [pages, setPages] = useState([]);
  const [pageForm, setPageForm] = useState({ sayfaismi: '', sayfaurl: '', sayfaicerik: '' });

  const [logs, setLogs] = useState([]);
  const [logFile, setLogFile] = useState('');
  const [logContent, setLogContent] = useState('');

  const [emailCats, setEmailCats] = useState([]);
  const [emailTemplates, setEmailTemplates] = useState([]);
  const [emailSend, setEmailSend] = useState({ to: '', from: '', subject: '', html: '' });
  const [emailBulk, setEmailBulk] = useState({ categoryId: '', from: '', subject: '', html: '' });
  const [emailCatForm, setEmailCatForm] = useState({ ad: '', tur: 'all', deger: '', aciklama: '' });
  const [emailTplForm, setEmailTplForm] = useState({ ad: '', konu: '', icerik: '' });

  const [teams, setTeams] = useState([]);

  const [verifRequests, setVerifRequests] = useState([]);
  const [verifyUpdate, setVerifyUpdate] = useState({ userId: '', verified: '1' });

  const [events, setEvents] = useState([]);
  const [eventForm, setEventForm] = useState({ title: '', body: '', date: '' });

  const [announcements, setAnnouncements] = useState([]);
  const [announcementForm, setAnnouncementForm] = useState({ title: '', body: '' });

  const [groups, setGroups] = useState([]);
  const [stories, setStories] = useState([]);
  const [chatMessages, setChatMessages] = useState([]);
  const [adminMessages, setAdminMessages] = useState([]);

  useEffect(() => {
    if (!user) return;
    fetch('/api/admin/session', { credentials: 'include' })
      .then((r) => r.json())
      .then((p) => setAdminOk(!!p.adminOk))
      .catch(() => {});
  }, [user]);

  useEffect(() => {
    if (user?.admin !== 1 || !adminOk) return;
    if (tab === 'dashboard') loadStats();
    if (tab === 'users') loadUsers();
    if (tab === 'album') loadCategories();
    if (tab === 'photos') loadPhotos();
    if (tab === 'pages') loadPages();
    if (tab === 'logs') loadLogs();
    if (tab === 'email') loadEmailMeta();
    if (tab === 'tournament') loadTeams();
    if (tab === 'verification') loadVerification();
    if (tab === 'events') loadEvents();
    if (tab === 'announcements') loadAnnouncements();
    if (tab === 'groups') loadGroups();
    if (tab === 'stories') loadStories();
    if (tab === 'chat') loadChat();
    if (tab === 'messages') loadAdminMessages();
  }, [tab, user, adminOk]);

  async function adminLogin(e) {
    e.preventDefault();
    setStatus('');
    const res = await fetch('/api/admin/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      credentials: 'include',
      body: JSON.stringify({ password: adminPassword })
    });
    if (!res.ok) {
      setStatus(await res.text());
      return;
    }
    setAdminOk(true);
    setAdminPassword('');
    setStatus('Admin girişi başarılı.');
  }

  async function loadStats() {
    const data = await apiJson('/api/new/admin/stats');
    setStats(data);
  }

  async function loadUsers() {
    const data = await apiJson(`/api/admin/users/lists?filter=${userFilter}`);
    setUsers(data.users || []);
  }

  async function searchUsers() {
    if (!userQuery.trim()) return;
    const data = await apiJson(`/api/admin/users/search?q=${encodeURIComponent(userQuery)}`);
    setUsers(data.users || []);
  }

  async function loadUserDetail(id) {
    const data = await apiJson(`/api/admin/users/${id}`);
    setUserDetail(data.user);
    setUserForm(data.user);
  }

  async function saveUser() {
    if (!userForm?.id) return;
    await apiJson(`/api/admin/users/${userForm.id}`, { method: 'PUT', body: JSON.stringify(userForm) });
    setStatus('Üye güncellendi.');
    loadUsers();
  }

  async function updateVerify() {
    await apiJson('/api/new/admin/verify', { method: 'POST', body: JSON.stringify(verifyUpdate) });
    setStatus('Doğrulama güncellendi.');
  }

  async function loadCategories() {
    const data = await apiJson('/api/admin/album/categories');
    setCategories(data.categories || []);
  }

  async function addCategory() {
    await apiJson('/api/admin/album/categories', { method: 'POST', body: JSON.stringify(categoryForm) });
    setCategoryForm({ kategori: '', aciklama: '', aktif: 1 });
    loadCategories();
  }

  async function saveCategory(cat) {
    await apiJson(`/api/admin/album/categories/${cat.id}`, { method: 'PUT', body: JSON.stringify(cat) });
    loadCategories();
  }

  async function deleteCategory(id) {
    await apiJson(`/api/admin/album/categories/${id}`, { method: 'DELETE' });
    loadCategories();
  }

  async function loadPhotos() {
    const qs = new URLSearchParams(photoFilter).toString();
    const data = await apiJson(`/api/admin/album/photos?${qs}`);
    setPhotos(data.photos || []);
  }

  async function updatePhoto() {
    if (!photoEdit) return;
    await apiJson(`/api/admin/album/photos/${photoEdit.id}`, { method: 'PUT', body: JSON.stringify(photoEdit) });
    setPhotoEdit(null);
    loadPhotos();
  }

  async function deletePhoto(id) {
    await apiJson(`/api/admin/album/photos/${id}`, { method: 'DELETE' });
    loadPhotos();
  }

  async function bulkPhoto(action) {
    const ids = photos.filter((p) => p.selected).map((p) => p.id);
    if (!ids.length) return;
    await apiJson('/api/admin/album/photos/bulk', { method: 'POST', body: JSON.stringify({ ids, action }) });
    loadPhotos();
  }

  async function loadPages() {
    const data = await apiJson('/api/admin/pages');
    setPages(data.pages || []);
  }

  async function savePage() {
    await apiJson('/api/admin/pages', { method: 'POST', body: JSON.stringify(pageForm) });
    setPageForm({ sayfaismi: '', sayfaurl: '', sayfaicerik: '' });
    loadPages();
  }

  async function updatePage(p) {
    await apiJson(`/api/admin/pages/${p.id}`, { method: 'PUT', body: JSON.stringify(p) });
    loadPages();
  }

  async function deletePage(id) {
    await apiJson(`/api/admin/pages/${id}`, { method: 'DELETE' });
    loadPages();
  }

  async function loadLogs() {
    const data = await apiJson('/api/admin/logs');
    setLogs(data.files || []);
  }

  async function openLog(file) {
    const data = await apiJson(`/api/admin/logs?file=${encodeURIComponent(file)}`);
    setLogFile(file);
    setLogContent(data.content || '');
  }

  async function loadEmailMeta() {
    const cats = await apiJson('/api/admin/email/categories');
    const tpls = await apiJson('/api/admin/email/templates');
    setEmailCats(cats.categories || []);
    setEmailTemplates(tpls.templates || []);
  }

  async function sendEmail() {
    await apiJson('/api/admin/email/send', { method: 'POST', body: JSON.stringify(emailSend) });
    setStatus('E-posta gönderildi.');
  }

  async function sendBulk() {
    await apiJson('/api/admin/email/bulk', { method: 'POST', body: JSON.stringify(emailBulk) });
    setStatus('Toplu e-posta gönderildi.');
  }

  async function addEmailCategory() {
    await apiJson('/api/admin/email/categories', { method: 'POST', body: JSON.stringify(emailCatForm) });
    setEmailCatForm({ ad: '', tur: 'all', deger: '', aciklama: '' });
    loadEmailMeta();
  }

  async function addEmailTemplate() {
    await apiJson('/api/admin/email/templates', { method: 'POST', body: JSON.stringify(emailTplForm) });
    setEmailTplForm({ ad: '', konu: '', icerik: '' });
    loadEmailMeta();
  }

  async function updateEmailCategory(cat) {
    await apiJson(`/api/admin/email/categories/${cat.id}`, { method: 'PUT', body: JSON.stringify(cat) });
    loadEmailMeta();
  }

  async function deleteEmailCategory(id) {
    await apiJson(`/api/admin/email/categories/${id}`, { method: 'DELETE' });
    loadEmailMeta();
  }

  async function updateEmailTemplate(tpl) {
    await apiJson(`/api/admin/email/templates/${tpl.id}`, { method: 'PUT', body: JSON.stringify(tpl) });
    loadEmailMeta();
  }

  async function deleteEmailTemplate(id) {
    await apiJson(`/api/admin/email/templates/${id}`, { method: 'DELETE' });
    loadEmailMeta();
  }

  async function loadTeams() {
    const data = await apiJson('/api/admin/tournament');
    setTeams(data.teams || []);
  }

  async function deleteTeam(id) {
    await apiJson(`/api/admin/tournament/${id}`, { method: 'DELETE' });
    loadTeams();
  }

  async function loadVerification() {
    const data = await apiJson('/api/new/admin/verification-requests');
    setVerifRequests(data.items || []);
  }

  async function reviewRequest(id, statusValue) {
    await apiJson(`/api/new/admin/verification-requests/${id}`, { method: 'POST', body: JSON.stringify({ status: statusValue }) });
    loadVerification();
  }

  async function loadEvents() {
    const data = await apiJson('/api/new/events');
    setEvents(data.items || []);
  }

  async function addEvent() {
    await apiJson('/api/new/events', { method: 'POST', body: JSON.stringify(eventForm) });
    setEventForm({ title: '', body: '', date: '' });
    loadEvents();
  }

  async function deleteEvent(id) {
    await apiJson(`/api/new/events/${id}`, { method: 'DELETE' });
    loadEvents();
  }

  async function loadAnnouncements() {
    const data = await apiJson('/api/new/announcements');
    setAnnouncements(data.items || []);
  }

  async function addAnnouncement() {
    await apiJson('/api/new/announcements', { method: 'POST', body: JSON.stringify(announcementForm) });
    setAnnouncementForm({ title: '', body: '' });
    loadAnnouncements();
  }

  async function deleteAnnouncement(id) {
    await apiJson(`/api/new/announcements/${id}`, { method: 'DELETE' });
    loadAnnouncements();
  }

  async function loadGroups() {
    const data = await apiJson('/api/new/admin/groups');
    setGroups(data.items || []);
  }

  async function deleteGroup(id) {
    await apiJson(`/api/new/admin/groups/${id}`, { method: 'DELETE' });
    loadGroups();
  }

  async function loadStories() {
    const data = await apiJson('/api/new/admin/stories');
    setStories(data.items || []);
  }

  async function deleteStory(id) {
    await apiJson(`/api/new/admin/stories/${id}`, { method: 'DELETE' });
    loadStories();
  }

  async function loadChat() {
    const data = await apiJson('/api/new/admin/chat/messages');
    setChatMessages(data.items || []);
  }

  async function deleteChat(id) {
    await apiJson(`/api/new/admin/chat/messages/${id}`, { method: 'DELETE' });
    loadChat();
  }

  async function loadAdminMessages() {
    const data = await apiJson('/api/new/admin/messages');
    setAdminMessages(data.items || []);
  }

  async function deleteAdminMessage(id) {
    await apiJson(`/api/new/admin/messages/${id}`, { method: 'DELETE' });
    loadAdminMessages();
  }

  if (user?.admin !== 1) {
    return (
      <Layout title="Yönetim">
        <div className="panel">
          <div className="panel-body">Bu sayfaya erişiminiz yok.</div>
        </div>
      </Layout>
    );
  }

  if (!adminOk) {
    return (
      <Layout title="Yönetim">
        <div className="panel">
          <div className="panel-body">
            <form className="stack" onSubmit={adminLogin}>
              <input className="input" type="password" placeholder="Admin şifresi" value={adminPassword} onChange={(e) => setAdminPassword(e.target.value)} />
              <button className="btn primary" type="submit">Admin Giriş</button>
              {status ? <div className="muted">{status}</div> : null}
            </form>
          </div>
        </div>
      </Layout>
    );
  }

  return (
    <Layout title="Yönetim">
      <div className="panel">
        <div className="panel-body admin-tabs">
          {tabs.map((t) => (
            <button key={t.key} className={`btn ${tab === t.key ? 'primary' : 'ghost'}`} onClick={() => setTab(t.key)}>
              {t.label}
            </button>
          ))}
        </div>
      </div>

      {tab === 'dashboard' && stats ? (
        <div className="grid">
          <div className="col-main">
            <div className="panel">
              <h3>Genel İstatistikler</h3>
              <div className="panel-body">
                <div className="list">
                  <div className="list-item">Üye: {stats.counts.users}</div>
                  <div className="list-item">Aktif: {stats.counts.activeUsers}</div>
                  <div className="list-item">Bekleyen: {stats.counts.pendingUsers}</div>
                  <div className="list-item">Yasaklı: {stats.counts.bannedUsers}</div>
                  <div className="list-item">Gönderi: {stats.counts.posts}</div>
                  <div className="list-item">Fotoğraf: {stats.counts.photos}</div>
                  <div className="list-item">Hikaye: {stats.counts.stories}</div>
                  <div className="list-item">Gruplar: {stats.counts.groups}</div>
                  <div className="list-item">Mesajlar: {stats.counts.messages}</div>
                  <div className="list-item">Duyuru: {stats.counts.announcements}</div>
                  <div className="list-item">Etkinlik: {stats.counts.events}</div>
                  <div className="list-item">Canlı Sohbet: {stats.counts.chat}</div>
                </div>
              </div>
            </div>
          </div>
          <div className="col-side">
            <div className="panel">
              <h3>Yeni Üyeler</h3>
              <div className="panel-body">
                {stats.recentUsers.map((u) => (
                  <div key={u.id} className="list-item">@{u.kadi}</div>
                ))}
              </div>
            </div>
            <div className="panel">
              <h3>Son Paylaşımlar</h3>
              <div className="panel-body">
                {stats.recentPosts.map((p) => (
                  <div key={p.id} className="list-item">{(p.content || '').slice(0, 60)}</div>
                ))}
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'users' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="stack">
              <div className="form-row">
                <label>Filtre</label>
                <select className="input" value={userFilter} onChange={(e) => setUserFilter(e.target.value)}>
                  <option value="active">Aktif</option>
                  <option value="pending">Bekleyen</option>
                  <option value="banned">Yasaklı</option>
                  <option value="online">Online</option>
                  <option value="recent">Son giriş</option>
                  <option value="all">Tümü</option>
                </select>
                <button className="btn" onClick={loadUsers}>Listele</button>
              </div>
              <div className="form-row">
                <label>Arama</label>
                <input className="input" value={userQuery} onChange={(e) => setUserQuery(e.target.value)} />
                <button className="btn" onClick={searchUsers}>Ara</button>
              </div>
            </div>
            <div className="list">
              {users.map((u) => (
                <button key={u.id} className="list-item" onClick={() => loadUserDetail(u.id)}>
                  {u.kadi} ({u.isim} {u.soyisim})
                </button>
              ))}
            </div>
            {userForm ? (
              <div className="panel-body">
                <h3>Üye Düzenle</h3>
                <div className="form-row">
                  <label>İsim</label>
                  <input className="input" value={userForm.isim || ''} onChange={(e) => setUserForm({ ...userForm, isim: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Soyisim</label>
                  <input className="input" value={userForm.soyisim || ''} onChange={(e) => setUserForm({ ...userForm, soyisim: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Email</label>
                  <input className="input" value={userForm.email || ''} onChange={(e) => setUserForm({ ...userForm, email: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Şifre (yalnızca gerekiyorsa)</label>
                  <input className="input" type="password" value={userForm.sifre || ''} onChange={(e) => setUserForm({ ...userForm, sifre: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Aktivasyon</label>
                  <input className="input" value={userForm.aktivasyon || ''} onChange={(e) => setUserForm({ ...userForm, aktivasyon: e.target.value })} />
                </div>
                <div className="form-row">
                  <label>Aktif</label>
                  <select className="input" value={userForm.aktiv ?? 1} onChange={(e) => setUserForm({ ...userForm, aktiv: Number(e.target.value) })}>
                    <option value={1}>Aktif</option>
                    <option value={0}>Pasif</option>
                  </select>
                </div>
                <div className="form-row">
                  <label>Yasak</label>
                  <select className="input" value={userForm.yasak ?? 0} onChange={(e) => setUserForm({ ...userForm, yasak: Number(e.target.value) })}>
                    <option value={0}>Hayır</option>
                    <option value={1}>Evet</option>
                  </select>
                </div>
                <div className="form-row">
                  <label>Admin</label>
                  <select className="input" value={userForm.admin ?? 0} onChange={(e) => setUserForm({ ...userForm, admin: Number(e.target.value) })}>
                    <option value={0}>Hayır</option>
                    <option value={1}>Evet</option>
                  </select>
                </div>
                <button className="btn primary" onClick={saveUser}>Kaydet</button>
              </div>
            ) : null}
            <div className="form-row">
              <label>Doğrulama Rozeti</label>
              <input className="input" placeholder="Üye ID" value={verifyUpdate.userId} onChange={(e) => setVerifyUpdate({ ...verifyUpdate, userId: e.target.value })} />
              <select className="input" value={verifyUpdate.verified} onChange={(e) => setVerifyUpdate({ ...verifyUpdate, verified: e.target.value })}>
                <option value="1">Doğrula</option>
                <option value="0">Kaldır</option>
              </select>
              <button className="btn" onClick={updateVerify}>Güncelle</button>
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'album' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="form-row">
              <label>Yeni Kategori</label>
              <input className="input" placeholder="Kategori" value={categoryForm.kategori} onChange={(e) => setCategoryForm({ ...categoryForm, kategori: e.target.value })} />
              <input className="input" placeholder="Açıklama" value={categoryForm.aciklama} onChange={(e) => setCategoryForm({ ...categoryForm, aciklama: e.target.value })} />
              <select className="input" value={categoryForm.aktif} onChange={(e) => setCategoryForm({ ...categoryForm, aktif: Number(e.target.value) })}>
                <option value={1}>Aktif</option>
                <option value={0}>Pasif</option>
              </select>
              <button className="btn primary" onClick={addCategory}>Ekle</button>
            </div>
            <div className="list">
              {categories.map((c) => (
                <div key={c.id} className="list-item">
                  <input className="input" value={c.kategori || ''} onChange={(e) => setCategories((prev) => prev.map((x) => x.id === c.id ? { ...x, kategori: e.target.value } : x))} />
                  <input className="input" value={c.aciklama || ''} onChange={(e) => setCategories((prev) => prev.map((x) => x.id === c.id ? { ...x, aciklama: e.target.value } : x))} />
                  <select className="input" value={c.aktif ?? 1} onChange={(e) => setCategories((prev) => prev.map((x) => x.id === c.id ? { ...x, aktif: Number(e.target.value) } : x))}>
                    <option value={1}>Aktif</option>
                    <option value={0}>Pasif</option>
                  </select>
                  <button className="btn" onClick={() => saveCategory(c)}>Kaydet</button>
                  <button className="btn ghost" onClick={() => deleteCategory(c.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'photos' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="form-row">
              <label>Filtre</label>
              <select className="input" value={photoFilter.krt} onChange={(e) => setPhotoFilter({ ...photoFilter, krt: e.target.value })}>
                <option value="onaybekleyen">Onay Bekleyen</option>
                <option value="aktif">Aktif</option>
                <option value="pasif">Pasif</option>
              </select>
              <input className="input" placeholder="Kategori ID" value={photoFilter.kid} onChange={(e) => setPhotoFilter({ ...photoFilter, kid: e.target.value })} />
              <input className="input" placeholder="Sıralama" value={photoFilter.diz} onChange={(e) => setPhotoFilter({ ...photoFilter, diz: e.target.value })} />
              <button className="btn" onClick={loadPhotos}>Getir</button>
            </div>
            <div className="panel-body">
              <button className="btn" onClick={() => bulkPhoto('aktif')}>Toplu Aktif</button>
              <button className="btn ghost" onClick={() => bulkPhoto('pasif')}>Toplu Pasif</button>
              <button className="btn ghost" onClick={() => bulkPhoto('sil')}>Toplu Sil</button>
            </div>
            <div className="list">
              {photos.map((p) => (
                <div key={p.id} className="list-item">
                  <input type="checkbox" checked={!!p.selected} onChange={(e) => setPhotos((prev) => prev.map((x) => x.id === p.id ? { ...x, selected: e.target.checked } : x))} />
                  <img src={`/api/media/kucukresim?iwidth=50&r=${encodeURIComponent(p.dosyaadi || 'nophoto.jpg')}`} alt="" />
                  <span>{p.baslik}</span>
                  <button className="btn ghost" onClick={() => setPhotoEdit(p)}>Düzenle</button>
                  <button className="btn ghost" onClick={() => deletePhoto(p.id)}>Sil</button>
                </div>
              ))}
            </div>
            {photoEdit ? (
              <div className="panel-body">
                <h3>Fotoğraf Düzenle</h3>
                <input className="input" value={photoEdit.baslik || ''} onChange={(e) => setPhotoEdit({ ...photoEdit, baslik: e.target.value })} />
                <input className="input" value={photoEdit.aciklama || ''} onChange={(e) => setPhotoEdit({ ...photoEdit, aciklama: e.target.value })} />
                <input className="input" value={photoEdit.aktif ?? ''} onChange={(e) => setPhotoEdit({ ...photoEdit, aktif: e.target.value })} />
                <input className="input" value={photoEdit.katid ?? ''} onChange={(e) => setPhotoEdit({ ...photoEdit, katid: e.target.value })} />
                <button className="btn primary" onClick={updatePhoto}>Kaydet</button>
              </div>
            ) : null}
          </div>
        </div>
      ) : null}

      {tab === 'messages' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="list">
              {adminMessages.map((m) => (
                <div key={m.id} className="list-item">
                  <div>
                    <div className="name">{m.konu}</div>
                    <div className="meta">{m.kimden_kadi} → {m.kime_kadi}</div>
                  </div>
                  <button className="btn ghost" onClick={() => deleteAdminMessage(m.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'pages' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="form-row">
              <label>Yeni Sayfa</label>
              <input className="input" placeholder="Başlık" value={pageForm.sayfaismi} onChange={(e) => setPageForm({ ...pageForm, sayfaismi: e.target.value })} />
              <input className="input" placeholder="URL" value={pageForm.sayfaurl} onChange={(e) => setPageForm({ ...pageForm, sayfaurl: e.target.value })} />
              <textarea className="input" placeholder="İçerik" value={pageForm.sayfaicerik} onChange={(e) => setPageForm({ ...pageForm, sayfaicerik: e.target.value })} />
              <button className="btn primary" onClick={savePage}>Kaydet</button>
            </div>
            <div className="list">
              {pages.map((p) => (
                <div key={p.id} className="list-item">
                  <input className="input" value={p.sayfaismi || ''} onChange={(e) => setPages((prev) => prev.map((x) => x.id === p.id ? { ...x, sayfaismi: e.target.value } : x))} />
                  <input className="input" value={p.sayfaurl || ''} onChange={(e) => setPages((prev) => prev.map((x) => x.id === p.id ? { ...x, sayfaurl: e.target.value } : x))} />
                  <button className="btn" onClick={() => updatePage(p)}>Güncelle</button>
                  <button className="btn ghost" onClick={() => deletePage(p.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'email' ? (
        <div className="grid">
          <div className="col-main">
            <div className="panel">
              <h3>Tekil E-posta</h3>
              <div className="panel-body">
                <input className="input" placeholder="To" value={emailSend.to} onChange={(e) => setEmailSend({ ...emailSend, to: e.target.value })} />
                <input className="input" placeholder="From" value={emailSend.from} onChange={(e) => setEmailSend({ ...emailSend, from: e.target.value })} />
                <input className="input" placeholder="Subject" value={emailSend.subject} onChange={(e) => setEmailSend({ ...emailSend, subject: e.target.value })} />
                <textarea className="input" placeholder="HTML" value={emailSend.html} onChange={(e) => setEmailSend({ ...emailSend, html: e.target.value })} />
                <button className="btn primary" onClick={sendEmail}>Gönder</button>
              </div>
            </div>
            <div className="panel">
              <h3>Toplu E-posta</h3>
              <div className="panel-body">
                <select className="input" value={emailBulk.categoryId} onChange={(e) => setEmailBulk({ ...emailBulk, categoryId: e.target.value })}>
                  <option value="">Kategori</option>
                  {emailCats.map((c) => <option key={c.id} value={c.id}>{c.ad}</option>)}
                </select>
                <input className="input" placeholder="From" value={emailBulk.from} onChange={(e) => setEmailBulk({ ...emailBulk, from: e.target.value })} />
                <input className="input" placeholder="Subject" value={emailBulk.subject} onChange={(e) => setEmailBulk({ ...emailBulk, subject: e.target.value })} />
                <textarea className="input" placeholder="HTML" value={emailBulk.html} onChange={(e) => setEmailBulk({ ...emailBulk, html: e.target.value })} />
                <button className="btn primary" onClick={sendBulk}>Gönder</button>
              </div>
            </div>
          </div>
          <div className="col-side">
            <div className="panel">
              <h3>Kategoriler</h3>
              <div className="panel-body">
                <input className="input" placeholder="Ad" value={emailCatForm.ad} onChange={(e) => setEmailCatForm({ ...emailCatForm, ad: e.target.value })} />
                <select className="input" value={emailCatForm.tur} onChange={(e) => setEmailCatForm({ ...emailCatForm, tur: e.target.value })}>
                  <option value="all">Tümü</option>
                  <option value="active">Aktif</option>
                  <option value="pending">Bekleyen</option>
                  <option value="banned">Yasaklı</option>
                  <option value="year">Mezuniyet</option>
                  <option value="custom">Özel</option>
                </select>
                <input className="input" placeholder="Değer" value={emailCatForm.deger} onChange={(e) => setEmailCatForm({ ...emailCatForm, deger: e.target.value })} />
                <input className="input" placeholder="Açıklama" value={emailCatForm.aciklama} onChange={(e) => setEmailCatForm({ ...emailCatForm, aciklama: e.target.value })} />
                <button className="btn" onClick={addEmailCategory}>Ekle</button>
                {emailCats.map((c) => (
                  <div key={c.id} className="list-item">
                    <input className="input" value={c.ad || ''} onChange={(e) => setEmailCats((prev) => prev.map((x) => x.id === c.id ? { ...x, ad: e.target.value } : x))} />
                    <button className="btn" onClick={() => updateEmailCategory(c)}>Kaydet</button>
                    <button className="btn ghost" onClick={() => deleteEmailCategory(c.id)}>Sil</button>
                  </div>
                ))}
              </div>
            </div>
            <div className="panel">
              <h3>Şablonlar</h3>
              <div className="panel-body">
                <input className="input" placeholder="Ad" value={emailTplForm.ad} onChange={(e) => setEmailTplForm({ ...emailTplForm, ad: e.target.value })} />
                <input className="input" placeholder="Konu" value={emailTplForm.konu} onChange={(e) => setEmailTplForm({ ...emailTplForm, konu: e.target.value })} />
                <textarea className="input" placeholder="İçerik" value={emailTplForm.icerik} onChange={(e) => setEmailTplForm({ ...emailTplForm, icerik: e.target.value })} />
                <button className="btn" onClick={addEmailTemplate}>Ekle</button>
                {emailTemplates.map((t) => (
                  <div key={t.id} className="list-item">
                    <input className="input" value={t.ad || ''} onChange={(e) => setEmailTemplates((prev) => prev.map((x) => x.id === t.id ? { ...x, ad: e.target.value } : x))} />
                    <button className="btn" onClick={() => updateEmailTemplate(t)}>Kaydet</button>
                    <button className="btn ghost" onClick={() => deleteEmailTemplate(t.id)}>Sil</button>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'logs' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="list">
              {logs.map((f) => (
                <button key={f} className="list-item" onClick={() => openLog(f)}>{f}</button>
              ))}
            </div>
            {logFile ? (
              <div className="panel-body">
                <h3>{logFile}</h3>
                <textarea className="input" rows={12} value={logContent} readOnly />
              </div>
            ) : null}
          </div>
        </div>
      ) : null}

      {tab === 'tournament' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="list">
              {teams.map((t) => (
                <div key={t.id} className="list-item">
                  <div>{t.takimadi || t.isim}</div>
                  <button className="btn ghost" onClick={() => deleteTeam(t.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'verification' ? (
        <div className="panel">
          <div className="panel-body">
            {verifRequests.map((r) => (
              <div key={r.id} className="list-item">
                <div>@{r.kadi} • {r.status}</div>
                <button className="btn" onClick={() => reviewRequest(r.id, 'approved')}>Onayla</button>
                <button className="btn ghost" onClick={() => reviewRequest(r.id, 'rejected')}>Reddet</button>
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {tab === 'events' ? (
        <div className="panel">
          <div className="panel-body">
            <input className="input" placeholder="Başlık" value={eventForm.title} onChange={(e) => setEventForm({ ...eventForm, title: e.target.value })} />
            <input className="input" placeholder="Tarih" value={eventForm.date} onChange={(e) => setEventForm({ ...eventForm, date: e.target.value })} />
            <textarea className="input" placeholder="İçerik" value={eventForm.body} onChange={(e) => setEventForm({ ...eventForm, body: e.target.value })} />
            <button className="btn primary" onClick={addEvent}>Ekle</button>
            <div className="list">
              {events.map((e) => (
                <div key={e.id} className="list-item">
                  <div>{e.title}</div>
                  <button className="btn ghost" onClick={() => deleteEvent(e.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'announcements' ? (
        <div className="panel">
          <div className="panel-body">
            <input className="input" placeholder="Başlık" value={announcementForm.title} onChange={(e) => setAnnouncementForm({ ...announcementForm, title: e.target.value })} />
            <textarea className="input" placeholder="İçerik" value={announcementForm.body} onChange={(e) => setAnnouncementForm({ ...announcementForm, body: e.target.value })} />
            <button className="btn primary" onClick={addAnnouncement}>Ekle</button>
            <div className="list">
              {announcements.map((a) => (
                <div key={a.id} className="list-item">
                  <div>{a.title}</div>
                  <button className="btn ghost" onClick={() => deleteAnnouncement(a.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'groups' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="list">
              {groups.map((g) => (
                <div key={g.id} className="list-item">
                  <div>{g.name}</div>
                  <button className="btn ghost" onClick={() => deleteGroup(g.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'stories' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="list">
              {stories.map((s) => (
                <div key={s.id} className="list-item">
                  <div>@{s.kadi}</div>
                  <button className="btn ghost" onClick={() => deleteStory(s.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {tab === 'chat' ? (
        <div className="panel">
          <div className="panel-body">
            <div className="list">
              {chatMessages.map((c) => (
                <div key={c.id} className="list-item">
                  <div>@{c.kadi}: {c.message}</div>
                  <button className="btn ghost" onClick={() => deleteChat(c.id)}>Sil</button>
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : null}

      {status ? <div className="muted">{status}</div> : null}
    </Layout>
  );
}
