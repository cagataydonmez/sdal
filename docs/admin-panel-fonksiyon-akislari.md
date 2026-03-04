# SDAL Yönetim Paneli – Sayfa/Modül Fonksiyon ve Akış Dokümantasyonu

Bu doküman, projedeki yönetim paneli kapsamındaki ekranların ve modüllerin ne yaptığını, hangi veri kaynaklarına dokunduğunu ve temel işlem akışlarını (giriş, listeleme, düzenleme, silme, moderasyon vb.) tek noktada toplar.

> Kapsam iki parçalıdır:
> - **Legacy Classic ASP yönetim paneli** (`legacy-site/*.asp`)
> - **Modern React + Node yönetim paneli** (`frontend-modern/src/pages/AdminPage.jsx` + `server/app.js` admin endpointleri)

---

## 1) Genel Mimari ve Yetki Katmanları

## 1.1 Legacy (Classic ASP) yetki modeli
- Kullanıcı oturumu kontrolü: `session_uyegiris = "evet"`.
- Yönetici paneline özel ikinci adım: `session_admingiris = "evet"`.
- Admin giriş formu `admingiris.asp` içinde ayrıca kullanıcı kaydındaki `admin = 1` şartını kontrol eder.
- Albüm yönetimi için ayrı yetki: kullanıcı kaydındaki `albumadmin = 1`.

## 1.2 Modern (React + API) yetki modeli
- Rol tabanlı model: `user | mod | admin | root`.
- Panel görünürlüğü: admin/mod kullanıcılarına açılır, bazı sekmelerde izin haritası uygulanır.
- Kritik operasyonlar:
  - `admin/root`: genel yönetim endpointleri.
  - `root`: rol yükseltme/düşürme gibi kök işlemler.
  - `mod`: moderasyon izin matrisi içindeki kapsamlı (scope) yetkilerle belirli modüller.

---

## 2) Legacy Classic ASP Yönetim Paneli

## 2.1 Ana giriş ve yönlendirme

### `admin.asp` (Yönetim Anasayfa)
**Fonksiyon:** Yönetim paneli ana menüsünü açar.

**Gösterdiği modüller:**
- Üyeler (`adminuyeler.asp`)
- Sayfalar (`adminsayfalar.asp`)
- Albüm Yönetim (`albumyonetim.asp`)
- E-Mail Paneli (`adminemailpanel.asp`)
- Hata ve IP kayıtları (`adminlog.asp`)
- Üye detay logları (`uyedetaylog.asp`)
- Turnuva (`futbolturnuva.asp`)
- Yönetici çıkışı (`admincikis.asp`)
- Hızlı üye arama formu (`adminuyeara.asp`)

**Akış:**
1. Üye giriş kontrolü.
2. Admin oturum kontrolü.
3. Sağlanmazsa `admingiris.asp` include edilerek şifre doğrulama formu gösterilir.

### `admingiris.asp`
**Fonksiyon:** Legacy admin panel ikinci faktör benzeri “admin şifresi” ekranı.

**Detay:**
- `uyeler` tablosundan giriş yapan kullanıcının `admin` alanını kontrol eder.
- Sabit şifre karşılaştırması yapar (`asilsifre = "guuk"`).
- Doğruysa `admingiris` çerezini `evet` yapıp `admin.asp`’ye yönlendirir.

**Risk Notu:** Sabit düz metin şifre yaklaşımı güvenlik açısından zayıftır.

### `admincikis.asp`
**Fonksiyon:** Admin oturumunu kapatır.

**Akış:**
1. `session_admingiris = evet` ise `admingiris` çerezini temizler.
2. `admin.asp`’ye döner.

---

## 2.2 Üye yönetimi modülü

### `adminuyeler.asp`
**Fonksiyon:** Üyeleri farklı filtre/sıralara göre listeler.

**Liste kutuları:**
- Genel sıralama (alfabetik)
- Aktif üyeler
- Aktivasyon bekleyen üyeler
- Yasaklı üyeler
- Son giriş tarihine göre
- Online üyeler

**Akış:**
1. Her kutu kendi SQL sorgusunu çalıştırır.
2. Seçilen kayıt `adminuyegor.asp?uyeid=...` ekranına gider.

### `adminuyeara.asp`
**Fonksiyon:** Üye arama.

**Arama kriterleri:** `kadi`, `isim`, `soyisim` (LIKE).

**Ek davranış:**
- `res` query parametresi varsa resimli üyeleri listeler (`resim <> 'yok'`).
- Sonuçlardan üye detay düzenleme ekranına geçiş verir.

### `adminuyegor.asp`
**Fonksiyon:** Tek üyeyi çok detaylı alanlarla açar ve düzenleme formu üretir.

**Görünen alanlar (özet):**
- Kimlik ve oturum: id, kadi, son işlem tarihi/saati, online, son IP
- Kişisel: isim, soyisim, şehir, meslek, üniversite, mezuniyet yılı, doğum tarihi
- Hesap: aktivasyon kodu, email, aktiv, yasak, admin, mailkapali, hit
- Profil: web sitesi, imza, resim

**Özel kural:**
- Şifre alanı sadece `session_uyeid = 1` için görünür (super-admin davranışı).

**Akış:**
1. `uyeid` alınır, kayıt getirilir.
2. Form `adminuyeduzenle.asp`’ye POST edilir.

### `adminuyeduzenle.asp`
**Fonksiyon:** Üye kayıt güncelleme.

**Validasyonlar (özet):**
- Zorunlu alan kontrolü (isim, soyisim, aktivasyon, email vb.)
- Sayısal alan kontrolü (`aktiv`, `yasak`, `ilkbd`, `mailkapali`, `hit`)
- `session_uyeid != 1` ise `uyeid=1` düzenleme bloklanır.
- Şifre güncellemesi yalnızca `session_uyeid=1` için.

**Akış:**
1. Form alanları doğrulanır.
2. `uyeler` kaydı açılır ve alanlar update edilir.
3. Başarı mesajı + ilgili üyeye geri dönüş linki.

---

## 2.3 Sayfa (CMS benzeri) yönetim modülü

### `adminsayfalar.asp`
**Fonksiyon:** `sayfalar` tablosunun yönetim listesi.

**Kolonlar (özet):**
`id, sayfaismi, sayfaurl, hit, sontarih, sonuye, babaid, menugorun, yonlendir, sayfametin, mozellik, resim, sonip`

**Önemli işlevler:**
- Sil (`adminsayfasil.asp`)
- Düzenle (`adminsayfaduz.asp`)
- Sayfa log dosyasına link (`adminsayfalog.asp?dg=e&da=...`)

### `adminsayfaekle.asp`
**Fonksiyon:** Yeni sayfa kaydı ekler.

**Alanlar:**
- sayfaismi, sayfaurl, babaid
- menugorun (1/0)
- yonlendir (1/0)
- mozellik (1/0)
- resim

**Akış:**
1. Zorunlu alan + tür kontrolleri.
2. `sayfalar` tablosuna `addnew` ile kayıt.
3. Liste ekranına yönlendirme.

### `adminsayfaduz.asp`
**Fonksiyon:** Mevcut sayfa kaydını günceller.

**Akış:**
1. GET ile kayıt açılır, forma basılır.
2. POST ile validasyonlar uygulanır.
3. `sayfalar` kaydı update edilir.

### `adminsayfasil.asp`
**Fonksiyon:** Sayfa silme.

**Akış:**
1. `sfid` query parametresi alınır.
2. İlgili kayıt doğrudan silinir.

---

## 2.4 Albüm yönetim modülü (albumadmin)

### `albumyonetim.asp`
**Fonksiyon:** Albüm admin ana menüsü.

**Menü:**
- Kategori Ekle (`albumyonkatekle.asp`)
- Kategoriler (`albumyonkategori.asp`)
- Onay bekleyen fotoğraflar (`albumyonfoto.asp?krt=onaybekleyen`)

### `albumyonkategori.asp`
**Fonksiyon:** Kategori listesi ve kategori bazlı metrikler.

**Yaptıkları:**
- Her kategori için aktif/inaktif fotoğraf sayısı çıkarır.
- Kategori bazlı foto listeye geçiş verir.
- Kategori düzenle/sil işlemi sunar.

### `albumyonkatekle.asp`
**Fonksiyon:** Yeni albüm kategorisi oluşturma.

**Kontroller:**
- kategori adı ve açıklama zorunlu.
- Aynı isimde kategori varsa hata.

### `albumyonkatduz.asp`
**Fonksiyon:** Kategori düzenleme.

**Kontroller:**
- Kategori adı/açıklama zorunlu.
- Başka kayıtla isim çakışması engellenir.

### `albumyonkatsil.asp`
**Fonksiyon:** Kategori silme.

**Kural:**
- Kategori altında foto varsa silmeye izin vermez.
- Foto yoksa kategori kaydını siler.

### `albumyonfoto.asp`
**Fonksiyon:** Fotoğraf moderasyon/listesi.

**Kapsam:**
- `krt=onaybekleyen`: aktif=0 kayıtları
- `krt=kategori&kid=...`: kategoriye göre liste
- `diz=...`: başlık/açıklama/aktiflik/ekleyen/tarih/hit artan-azalan sıralama

**İşlemler:**
- Toplu checkbox seçimi
- “Seçilenleri aktifleştir / inaktifleştir” (`albumyonaktivet.asp`)
- Tekil düzenle (`albumyonfotoduz.asp`)
- Tekil sil (`albumyonfotosil.asp`)
- Yorum yönetimi (`albumyonfotoyorum.asp`)

### `albumyonaktivet.asp`
**Fonksiyon:** Toplu aktif/pasif güncelleme.

**Akış:**
1. Formdaki `fotolar[]` koleksiyonunu döner.
2. `isl=aktiv|deaktiv` durumuna göre `aktif` alanını günceller.
3. Referer’a geri yönlendirir.

### `albumyonfotoduz.asp`
**Fonksiyon:** Fotoğraf metadata düzenleme.

**Alanlar:** `baslik`, `aciklama`, `aktif`, `katid`.

### `albumyonfotosil.asp`
**Fonksiyon:** Fotoğraf silme (dosya + DB).

**Akış:**
1. `album_foto` kaydını bulur.
2. Fiziksel dosyayı `foto0905` klasöründen silmeye çalışır.
3. Foto kaydını siler.
4. İlgili foto yorumlarını (`album_fotoyorum`) da temizler.

### `albumyonfotoyorum.asp`
**Fonksiyon:** Foto yorumlarını listeleme/silme.

**Akış:**
- `yid` varsa tek yorum siler ve listeye geri döner.
- `yid` yoksa ilgili foto yorumlarını tabloda listeler.

---

## 2.5 E-posta paneli

### `adminemailpanel.asp`
**Fonksiyon:** E-posta yönetimi giriş ekranı.

**Menü linkleri:**
- Hızlı tekil gönderim (`admineptekgonder.asp`)
- Çoklu gönderim (`adminepcokgonder.asp`) – legacy dosyası repo’da görünmüyor
- Kategori yönetimi (`adminepkategori.asp`) – legacy dosyası repo’da görünmüyor
- Şablon yönetimi (`adminepsablon.asp`) – legacy dosyası repo’da görünmüyor

### `admineptekgonder.asp`
**Fonksiyon:** Tek e-posta gönderim formu (legacy).

**Notlar:**
- Kod içinde yazım/sözdizimi kusurları bulunuyor (`session_uyegiris")`, `request.form("")` vb.).
- Form alanları için zorunlu kontrol var; ancak gönderim fonksiyon çağrısı kodda tamamlanmış görünmüyor.

---

## 2.6 Log ve kayıt izleme ekranları

### `adminlog.asp`
**Fonksiyon:** Hata/IP/sayaç log klasörlerini dosya bazlı görüntüler.

**Akış:**
1. `hatalog` klasöründeki dosyaları listeler.
2. Bu ay/geçmiş ay ayrımı yapar.
3. `dg=e&da=dosya` ile dosya içeriğini satır blokları halinde render eder.

### `adminsayfalog.asp`
**Fonksiyon:** `sayfalog` klasörü log görüntüleme.

### `uyedetaylog.asp`
**Fonksiyon:** `uyedetaylog` klasörü log görüntüleme.

---

## 2.7 Yardımcı/kısmi yönetim araçları

### `hizlierisim.asp`
**Fonksiyon:** Kullanıcının hızlı erişim listesini kutu içinde gösterir (mini yönetim/kısayol modülü).

**İşlevler:**
- Hızlı erişime eklenen üyeleri küçük kartlarla listeler.
- Kart üstünden mesaj gönderme / listeden çıkarma aksiyonu.

### `hizlierisimekle.asp`
**Fonksiyon:** Belirli kullanıcıyı hızlı erişim listesine ekleme.

### `hizlierisimcikart.asp`
**Fonksiyon:** Belirli kullanıcıyı hızlı erişim listesinden çıkarma.

### `admintaslak.asp`, `taslak.asp`
**Fonksiyon:** Taslak/skeleton sayfalar.

---

## 3) Modern Yönetim Paneli (React AdminPage + API)

## 3.1 Admin sayfası sekme yapısı
Modern panelde `AdminPage.jsx` sekme tabanlıdır. Başlıca sekmeler:
- Dashboard
- Üyeler
- Moderatör Yetkileri
- Takip İlişkileri
- Etkileşim Skorları
- Doğrulama
- Yönetim Talepleri
- Gruplar
- Postlar
- Hikayeler
- Canlı Sohbet
- Mesajlar
- Sayfalar
- Etkinlikler
- Duyurular
- Medya Depolama
- Site/Modül Erişimi
- Root Erişimi
- Albüm Kategorileri
- Fotoğraf Moderasyon
- E-Posta
- Turnuva
- Loglar
- Yasaklı Kelimeler
- Veritabanı

Ayrıca sekmelerin bir kısmında `TAB_PERMISSION_MAP` ile izne göre görünürlük/erişim sınırı uygulanır.

## 3.2 Erişim bileşenleri
- `AccessDeniedView`: Yetkisiz kullanıcı için sade engel ekranı.
- `AdminPageHeader`: Üst başlık/aksiyon alanı.
- `AdminPreviewModal`: Aktivite, kullanıcı, post, follow, event, announcement gibi içerikler için tek modal önizleme katmanı.

## 3.3 Modern panelin ana iş akışları

### A) Dashboard ve canlı metrik
- `GET /api/new/admin/stats`
- `GET /api/new/admin/live`
- Otomatik yenileme mekanizması ile panel KPI’ları canlı tutulur.

### B) Üye yönetimi
- Liste/filtre: `GET /api/admin/users/lists`
- Tekil kullanıcı: `GET /api/admin/users/:id`
- Güncelleme: `PUT /api/admin/users/:id`
- Silme: `DELETE /api/admin/users/:id` (alias: `/api/new/admin/members/:id`)

### C) Rol ve moderasyon izinleri
- Root/admin durum bilgisi: `GET /api/admin/root-status`
- Rol değişimi: `POST /admin/users/:id/role` (root odaklı)
- Moderasyon izin kataloğu: `GET /api/admin/moderation/permissions/catalog`
- Kullanıcı izinleri: `GET/PUT /api/admin/moderation/permissions/:userId`
- Kendi moderasyon izinleri: `GET /api/admin/moderation/my-permissions`

### D) İçerik moderasyonu
- Gruplar: `GET /api/new/admin/groups`, `DELETE /api/new/admin/groups/:id`
- Postlar: `GET /api/new/admin/posts`, `DELETE /api/new/admin/posts/:id`
- Hikayeler: `GET /api/new/admin/stories`, `DELETE /api/new/admin/stories/:id`
- Sohbet mesajları: `GET /api/new/admin/chat/messages`, `DELETE /api/new/admin/chat/messages/:id`
- Sistem içi mesajlar: `GET /api/new/admin/messages`, `DELETE /api/new/admin/messages/:id`

### E) Doğrulama ve yönetim talepleri
- Doğrulama talepleri: `GET /api/new/admin/verification-requests`
- Talep kararı: `POST /api/new/admin/verification-requests/:id`
- Talep bildirimleri: `GET /api/new/admin/requests/notifications`
- Talep kuyruğu: `GET /api/new/admin/requests`
- Talep inceleme: `POST /api/new/admin/requests/:id/review`

### F) Legacy benzeri yönetim modüllerinin modern API karşılığı
- Sayfalar: `GET/POST /api/admin/pages`, `PUT/DELETE /api/admin/pages/:id`
- Loglar: `GET /api/admin/logs`
- E-posta:
  - Tekil: `POST /api/admin/email/send`
  - Toplu: `POST /api/admin/email/bulk`
  - Kategori CRUD: `/api/admin/email/categories`
  - Şablon CRUD: `/api/admin/email/templates`
- Albüm:
  - Kategori CRUD: `/api/admin/album/categories`
  - Foto liste/toplu işlem: `/api/admin/album/photos`, `/api/admin/album/photos/bulk`
  - Foto tekil düzen/sil: `/api/admin/album/photos/:id`
  - Yorum liste/sil: `/api/admin/album/photos/:id/comments`
- Turnuva: `GET /api/admin/tournament`, `DELETE /api/admin/tournament/:id`

### G) Sistem kontrol modülleri
- Site/modül erişim kontrolleri: `GET/PUT /api/admin/site-controls`
- Medya ayarları + test: `GET/PUT /api/admin/media-settings`, `POST /api/admin/media-settings/test`
- Yasaklı kelimeler (filtre):
  - `GET/POST /api/new/admin/filters`
  - `PUT/DELETE /api/new/admin/filters/:id`
- Veritabanı gözlem/yedek:
  - Tablo listesi: `GET /api/new/admin/db/tables`
  - Tablo satırları: `GET /api/new/admin/db/table/:name`
  - Yedek liste/oluştur/indir/restore: `/api/new/admin/db/backups*`, `/api/new/admin/db/restore`

---

## 4) Uçtan Uca Akış Özeti (Senaryo Bazlı)

## 4.1 Legacy: “Üye düzenle” akışı
1. `admin.asp` → `adminuyeler.asp`.
2. Filtre kutusundan üye seçimi → `adminuyegor.asp`.
3. Alan düzenleme formu submit → `adminuyeduzenle.asp`.
4. Validasyon + DB update + başarı mesajı.

## 4.2 Legacy: “Fotoğraf moderasyonu” akışı
1. `albumyonetim.asp`.
2. Onay bekleyen veya kategori bazlı foto listesi (`albumyonfoto.asp`).
3. Toplu aktif/pasif (`albumyonaktivet.asp`) veya tekil düzen/sil.
4. Gerekirse foto yorumlarının temizlenmesi (`albumyonfotoyorum.asp`).

## 4.3 Modern: “Topluluk moderasyonu” akışı
1. `AdminPage` içinde ilgili sekme (post/story/chat/messages).
2. Liste endpoint’inden kayıtlar çekilir.
3. Önizleme modalı ile hızlı inceleme.
4. Silme endpoint’i ile aksiyon ve canlı statü yenilemesi.

## 4.4 Modern: “Yetki yönetimi” akışı
1. Üyeler sekmesinden kullanıcı seçimi.
2. Rol değişimi (root/admin kurallarına bağlı).
3. Moderasyon izin kataloğundan kullanıcıya permission set atanması.
4. Yetkiye göre sekme görünürlüğü/aksiyon kullanılabilirliği otomatik güncellenir.

---

## 5) Teknik Borç ve Dikkat Noktaları

- Legacy admin tarafında bazı dosyalarda güvenlik ve kalite riskleri var:
  - SQL sorguları string birleştirme temelli.
  - Sabit admin şifresi yaklaşımı.
  - E-posta alt modüllerinde eksik dosyalar/bozuk kod satırları.
- Modern panelde bu alanların önemli bir kısmı API tabanlı ve rol/izin kontrollü olarak yeniden ele alınmış durumda.

---

## 6) Güncelleme Talebi İçin Kullanım Rehberi

Bu doküman üzerinden güncelleme talep ederken aşağıdaki format işinizi hızlandırır:

- **Hedef modül/sayfa:** (örn. Legacy `adminuyeduzenle.asp` veya Modern `AdminPage > Üyeler`)  
- **İstenen değişiklik:** (örn. “Yasaklı kullanıcı filtresine tarih aralığı ekle”)  
- **Beklenen akış:** (adım adım)  
- **Yetki kuralı:** (kim görecek/kim işlem yapacak)  
- **Veri etkisi:** (hangi tablo/alan/endpoint değişecek)

Bu şekilde ilettiğiniz tüm talepleri doğrudan bu haritaya göre kırıp planlayabilirim.
