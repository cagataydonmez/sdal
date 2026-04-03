# Kullanıcı Bildirim Envanteri (Tam Liste)

Bu doküman, sistemde kullanıcıya giden bildirim tiplerini, bildirim kartında alınabilen aksiyonları ve bu aksiyonların etkilerini tek yerde toplar.

## 1) Genel davranış

- Her bildirim kartında varsayılan olarak **Aç** (target `href`’e git) aksiyonu vardır.
- Okunmamış bildirimlerde **Okundu yap** aksiyonu vardır (`read_at` set edilir).
- Bazı tiplerde ek iş aksiyonları vardır (kabul, reddet, yoksay vb.).
- Öncelik modeli: `informational`, `important`, `actionable`.
- `actionable` tipler panelde “Aksiyon Gerekli” olarak öne alınır.

## 2) Bildirim tipi matrisi

| Tip | Kategori | Öncelik | Kullanıcıya neden gider? | Varsayılan hedef / odak | Kartta ek aksiyon | Etkisi |
|---|---|---|---|---|---|---|
| `like` | social | informational | Paylaşıma beğeni geldiğinde | `/new?post=:entityId&notification=:id` | - | İlgili postu açar |
| `comment` | social | important | Paylaşıma yorum geldiğinde | `/new?post=:entityId&notification=:id` | - | İlgili postu açar |
| `mention_post` | social | important | Post içinde etiketlenince | `/new?post=:entityId&notification=:id` | - | İlgili postu açar |
| `mention_photo` | social | important | Fotoğraf akışında etiketlenince | `/new/albums/photo/:entityId?notification=:id` | - | İlgili fotoğrafı açar |
| `photo_comment` | social | important | Fotoğrafa yorum geldiğinde | `/new/albums/photo/:entityId?notification=:id` | - | İlgili fotoğrafı açar |
| `follow` | social | informational | Biri kullanıcıyı takip ettiğinde | `/new/members/:sourceUserId?notification=:id&context=follow` | - | Takip eden profiline götürür |
| `mention_message` | messaging | important | Mesaj içinde etiketlenince | `/new/messages/:entityId?notification=:id` | - | Mesaj konuşmasına götürür |
| `mention_group` | groups | important | Grup gönderisinde etiketlenince | `/new/groups/:entityId?tab=posts&notification=:id` | - | Grup post sekmesine götürür |
| `group_join_request` | groups | actionable | Gruba katılım isteği geldiğinde (yönetici) | `/new/groups/:entityId?tab=requests&notification=:id` | - | Grup isteklerini yönetmeye götürür |
| `group_join_approved` | groups | important | Katılım isteği onaylandığında | `/new/groups/:entityId?tab=members&notification=:id` | - | Üye listesini gösterir |
| `group_join_rejected` | groups | important | Katılım isteği reddedildiğinde | `/new/groups/:entityId?tab=members&notification=:id` | - | Grup üyelik bağlamına götürür |
| `group_invite` | groups | actionable | Gruba davet geldiğinde | `/new/groups/:entityId?tab=invite&notification=:id` | `accept_group_invite`, `reject_group_invite` | Daveti kabul/red eder (grup davet durumu güncellenir) |
| `group_invite_accepted` | groups | important | Gönderilen davet kabul edildiğinde | `/new/groups/:entityId?tab=members&notification=:id` | - | Üyelik etkisini gösterir |
| `group_invite_rejected` | groups | important | Gönderilen davet reddedildiğinde | `/new/groups/:entityId?tab=members&notification=:id` | - | Üyelik etkisini gösterir |
| `group_role_changed` | groups | important | Grup rolü değiştiğinde | `/new/groups/:entityId?tab=members&notification=:id` | - | Üye/rol görünümüne götürür |
| `mention_event` | events | important | Etkinlikte etiketlenince | `/new/events?event=:entityId&focus=comments&notification=:id` | - | Etkinlik yorum odak alanını açar |
| `event_comment` | events | important | Etkinliğe yorum geldiğinde | `/new/events?event=:entityId&focus=comments&notification=:id` | - | Yorum akışını açar |
| `event_invite` | events | important | Etkinliğe davet edildiğinde | `/new/events?event=:entityId&focus=response&notification=:id` | - | Katılım cevabı alanına götürür |
| `event_response` | events | important | Etkinlik yanıt akışında değişim olduğunda | `/new/events?event=:entityId&focus=response&notification=:id` | - | Cevap/katılım bağlamını açar |
| `event_reminder` | events | important | Etkinlik hatırlatması zamanı geldiğinde | `/new/events?event=:entityId&focus=details&notification=:id` | - | Etkinlik detayına götürür |
| `event_starts_soon` | events | important | Etkinlik başlamak üzereyken | `/new/events?event=:entityId&focus=details&notification=:id` | - | Etkinlik detayına götürür |
| `connection_request` | networking | actionable | Bağlantı isteği geldiğinde | `/new/network/hub?section=incoming-connections&request=:entityId&notification=:id` | `accept_connection_request`, `ignore_connection_request` | İsteği kabul veya yoksay yapar (request status değişir) |
| `connection_accepted` | networking | important | Gönderilen bağlantı isteği kabul edilince | `/new/members/:sourceUserId?...` veya `/new/network/hub?section=outgoing-connections...` | - | Kabul bilgisini ve kullanıcı/istek bağlamını açar |
| `mentorship_request` | networking | actionable | Mentorluk isteği geldiğinde | `/new/network/hub?section=incoming-mentorship&request=:entityId&notification=:id` | `accept_mentorship_request`, `decline_mentorship_request` | İsteği kabul/ret yapar (mentorship request status değişir) |
| `mentorship_accepted` | networking | important | Gönderilen mentorluk isteği kabul edilince | `/new/members/:sourceUserId?...` veya `/new/network/hub?section=outgoing-mentorship...` | - | Kabul bilgisini ilgili profile/hub’a taşır |
| `teacher_network_linked` | networking | important | Öğretmen ağı bağlantısı oluştuğunda | `/new/network/hub?section=teacher-notifications&notification=:id&link=:entityId` | `mark_teacher_notifications_read` | Öğretmen ağı bildirimlerini toplu okunduya alır |
| `teacher_link_review_confirmed` | networking | important | Öğretmen link incelemesi onaylandığında | `/new/network/teachers?notification=:id&link=:entityId&review=confirmed` | - | Review sonucunu ilgili öğretmen akışında gösterir |
| `teacher_link_review_flagged` | networking | important | Öğretmen link incelemesi flaglendiğinde | `/new/network/teachers?notification=:id&link=:entityId&review=flagged` | - | Moderasyon/review bağlamına götürür |
| `teacher_link_review_rejected` | networking | important | Öğretmen link incelemesi reddedildiğinde | `/new/network/teachers?notification=:id&link=:entityId&review=rejected` | - | Red sonucunu gösterir |
| `teacher_link_review_merged` | networking | important | Öğretmen link kaydı merge edildiğinde | `/new/network/teachers?notification=:id&link=:entityId&review=merged` | - | Birleştirme sonucunu gösterir |
| `job_application` | jobs | actionable | İş ilanına başvuru geldiğinde (ilan sahibi) | `/new/jobs?job=:entityId&tab=applications&notification=:id` | - | Başvuru yönetim sekmesine götürür |
| `job_application_reviewed` | jobs | important | Başvuru inceleme durumuna geçtiğinde | `/new/jobs?job=:jobId&focus=my-application&application=:entityId&notification=:id` | - | Kullanıcının kendi başvuru odağını açar |
| `job_application_accepted` | jobs | important | Başvuru kabul edildiğinde | `/new/jobs?job=:jobId&focus=my-application&application=:entityId&notification=:id` | - | Kabul sonucunu başvuru odağında gösterir |
| `job_application_rejected` | jobs | important | Başvuru reddedildiğinde | `/new/jobs?job=:jobId&focus=my-application&application=:entityId&notification=:id` | - | Red sonucunu başvuru odağında gösterir |
| `verification_approved` | system | important | Profil doğrulama onaylandığında | `/new/profile/verification?notification=:id&status=approved` | - | Doğrulama sonucu ekranına götürür |
| `verification_rejected` | system | important | Profil doğrulama reddedildiğinde | `/new/profile/verification?notification=:id&status=rejected` | - | Doğrulama sonucu ekranına götürür |
| `member_request_approved` | system | important | Üyelik talebi onaylandığında | `/new/requests?request=:entityId&notification=:id&status=approved` | - | Talep karar bağlamını gösterir |
| `member_request_rejected` | system | important | Üyelik talebi reddedildiğinde | `/new/requests?request=:entityId&notification=:id&status=rejected` | - | Talep karar bağlamını gösterir |
| `announcement_approved` | system | important | Duyuru önerisi onaylandığında | `/new/announcements?announcement=:entityId&notification=:id&status=approved` | - | Duyuru karar bağlamını gösterir |
| `announcement_rejected` | system | important | Duyuru önerisi reddedildiğinde | `/new/announcements?announcement=:entityId&notification=:id&status=rejected` | - | Duyuru karar bağlamını gösterir |

## 3) Kart aksiyonları ve etki özeti (teknik)

| Aksiyon kind | HTTP | Endpoint | Etki |
|---|---|---|---|
| `open` | - (navigasyon + open API çağrısı) | Kart `href` + `/api/new/notifications/:id/open` | Bildirimi açar, genelde okunduya da düşer, open telemetrisi üretir |
| `read` (UI butonu) | `POST` | `/api/new/notifications/:id/read` | Tek bildirimi okundu yapar |
| `bulk_read` (sayfa akışı) | `POST` | `/api/new/notifications/bulk-read` | Çoklu bildirimi okundu yapar |
| `accept_group_invite` | `POST` | `/api/new/groups/:groupId/invitations/respond` (`action=accept`) | Grup davetini kabul eder |
| `reject_group_invite` | `POST` | `/api/new/groups/:groupId/invitations/respond` (`action=reject`) | Grup davetini reddeder |
| `accept_connection_request` | `POST` | `/api/new/connections/accept/:requestId` | Bağlantı isteğini kabul eder |
| `ignore_connection_request` | `POST` | `/api/new/connections/ignore/:requestId` | Bağlantı isteğini yoksayar |
| `accept_mentorship_request` | `POST` | `/api/new/mentorship/accept/:requestId` | Mentorluk isteğini kabul eder |
| `decline_mentorship_request` | `POST` | `/api/new/mentorship/decline/:requestId` | Mentorluk isteğini reddeder |
| `mark_teacher_notifications_read` | `POST` | `/api/new/network/inbox/teacher-links/read` | Teacher network bildirimlerini okunduya çeker |

## 4) Tercih/öncelik etkisi

- Kullanıcı tercihleri kategori bazlıdır: `social`, `messaging`, `groups`, `events`, `networking`, `jobs`, `system`.
- `informational` bildirimler ilgili kategori kapatıldıysa baskılanabilir.
- `important` / `actionable` bildirimler için high-priority override nedeniyle kategori kapalı olsa da iletim devam eder.
- Quiet mode açıkken actionable olmayan toast’lar baskılanır.

## 5) Not

- Bu tablo, notification sunum ve yönetişim katmanındaki **aktif inventory** üzerinden hazırlanmıştır; yeni tip eklenirse bu dosya da güncellenmelidir.

## 6) 2026-04-03 doğrulama/audit ve uygulanan düzenlemeler

Bu turda `docs` altındaki envanter dışı bildirim dokümanları yerine doğrudan canlı akışlar kontrol edilerek kart aksiyonlarının etkisi ve yönlendirme doğruluğu doğrulandı.

### 6.1 Kontrol özeti (kart aksiyonu → hedef ekran etkisi)

- `like`, `comment`, `mention_post`:
  - Hedef `/new?post=:id&notification=:id` doğru.
  - İyileştirme: Feed ekranında hedef post için **otomatik scroll + kısa süreli fokus rengi** eklendi.
- `mention_photo`, `photo_comment`:
  - Hedef `/new/albums/photo/:id?notification=:id` doğru.
  - İyileştirme: Fotoğraf detayında **bildirim bağlam paneli + kısa süreli fokus vurgusu** eklendi.
- `mention_message`:
  - Hedef `/new/messages/:id?notification=:id` doğru.
  - İyileştirme: Mesaj detayında **bildirim bağlam paneli + kısa süreli fokus vurgusu** eklendi.
- `group_*` akışları:
  - Hedef tab yönlendirmeleri doğru.
  - İyileştirme: Grup detayında `tab=posts` ve `tab=members` için eksik olan **scroll/hedef panel vurgusu** eklendi.
- `events`, `jobs`, `member_request_*`, `announcement_*`, `teacher_link_review_*`, `networking`:
  - Mevcut durumda hedef scroll/vurgu davranışları ve sonuç geri bildirimi zaten mevcut ve çalışır durumda doğrulandı.

### 6.2 Ek bildirim ihtiyacı analizi

- Bu turda yeni bir **notification type** ekleme ihtiyacı doğuracak kritik boşluk tespit edilmedi.
- Ancak mevcut tiplerin hedefte kullanıcıya “hangi kayda geldiğini” gösteren etki tutarlılığında boşluk vardı (Feed, Mesaj detay, Fotoğraf detay, Grup posts/members). Bu boşluklar kapatıldı.

### 6.3 Kod seviyesinde yapılan düzeltmeler

- Feed:
  - Bildirim parametresinden gelen post id için hedef karta scroll.
  - Bildirim kaynağından gelen post için zaman kontrollü fokus (`~3.2s`) ve navigation telemetry izleme.
- Mesaj detay:
  - Bildirimden iniş telemetry takibi.
  - Mesaj gövdesinde kısa süreli bildirim fokus vurgusu ve bağlam paneli.
- Fotoğraf detay:
  - Bildirimden iniş telemetry takibi.
  - Fotoğrafta kısa süreli bildirim fokus vurgusu ve bağlam paneli.
- Grup detay:
  - `tab=posts` ve `tab=members` için section ref/scroll desteği.
  - İlgili panellerde notification-focus vurgusu.
