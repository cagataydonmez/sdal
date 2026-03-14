# Bildirim Sistemi Rebaseline ve Fazli Uygulama Plani

## 1. Amaç

Bu dokümanin hedefi, SDAL içindeki bildirim sistemini ürün, UX, frontend ve backend açilarindan yeniden çerçevelemek ve uygulanabilir fazlara bölmek.

Bu plan özellikle şu problemleri çözmek için yazildi:

- Bildirim tiplerinin eksik kapsanmasi
- Bildirime tiklaninca yanliş sayfaya gitme veya doğru context açilmamasi
- Kullanici için kritik olaylarin hiç bildirim üretmemesi
- Bildirim sayfasinin pasif bir liste olarak kalmasi
- Networking, groups, events, jobs ve feed bildirimlerinin ayni kalite seviyesinde olmamasi
- Okundu/okunmadi modelinin kaba olmasi
- Bildirim tiplerinin frontend ve backend'de dağinik string literal olarak yaşamasI

Bu doküman plan dokümanidir. Kod değişikliği içermez.

---

## 2. Ürün Çerçevesi

### 2.1 Bildirim sisteminin ürün rolü

Bildirim sistemi sadece "bir şey oldu" listesi olmamali. Üç ana rol üstlenmeli:

1. Kullaniciyi doğru aksiyona götürmeli
2. Kullaniciya ilişkisel ve sosyal bağlam vermeli
3. Ürünün farkli modüllerini tek bir operasyon merkezi gibi bağlamali

### 2.2 Başari tanimi

Başarili bir notification sistemi şu sorulara iyi cevap verir:

- Ne oldu?
- Kim yapti?
- Bu benim için neden önemli?
- Şimdi ne yapmaliyim?
- Tiklarsam beni doğru yere ve doğru state'e götürecek mi?

### 2.3 "Her şeyin bildirimi olsun" isteğinin doğru çevirisi

"Her şeyin bildirimi olsun" ifadesini doğrudan her event için push liste üretmek olarak yorumlamak doğru değil.

Doğru ürün çevirisi şudur:

- Kullanici için anlamli bütün event aileleri kapsanmali
- Ayni olay için gereksiz çoğaltim olmamali
- Aksiyon gerektiren bildirimler pasif bilgilere göre öne alinmali
- Kullanici fatigue yaratacak spam tekrarlar dedupe veya digest ile kontrol edilmeli

Yani hedef "maksimum gürültü" değil, "maksimum anlamli kapsama" olmalidir.

---

## 3. Mevcut Durum Özeti

## 3.1 Frontend yüzeyleri

Bugün bildirimler şu yüzeylerde görünüyor:

- `frontend-modern/src/components/NotificationPanel.jsx`
- `frontend-modern/src/pages/NotificationsPage.jsx`
- `frontend-modern/src/components/Layout.jsx` içindeki unread badge
- `frontend-modern/src/pages/FeedPage.jsx` içindeki notifications panel sekmesi
- `frontend-modern/src/pages/NetworkingHubPage.jsx` içindeki teacher notifications benzeri özel networking inbox yüzeyi

### Gözlem

- Global notification deneyimi ikiye bölünmüş durumda:
  - genel notification listesi
  - networking hub içindeki domain-specific notification yüzeyi
- Bu iki yüzey ortak contract, ortak routing resolver ve ortak UI hiyerarşisi paylaşmiyor

## 3.2 Backend yüzeyleri

Bugün temel backend uçlari:

- `GET /api/new/notifications`
- `GET /api/new/notifications/unread`
- `POST /api/new/notifications/read`

Özel domain bazli notification akişlari da var:

- `GET /api/new/network/hub`
- `POST /api/new/network/inbox/teacher-links/read`

### Gözlem

- Genel notifications API çok ince
- Per-item read, bulk action, filter, category, type, actionable payload, target contract, click tracking yok
- Networking özel inbox'u genel notification modelinden ayrilmiş durumda

## 3.3 Mevcut notification üretim tipleri

Kod taramasinda görülen aktif veya fiilen üretilen notification/event tipleri:

### Sosyal / içerik

- `like`
- `comment`
- `mention_post`
- `mention_photo`
- `photo_comment`
- `follow`

### Mesaj / iletişim

- `mention_message`

### Groups

- `mention_group`
- `group_join_request`
- `group_join_approved`
- `group_join_rejected`
- `group_invite`

### Events

- `mention_event`
- `event_comment`
- `event_invite`

### Networking

- `connection_request`
- `connection_accepted`
- `mentorship_request`
- `mentorship_accepted`
- `teacher_network_linked`

### Jobs

- `job_application`

## 3.4 Kritik mevcut sorunlar

### Sorun 1. Hedef çözümleme dağinik

`NotificationPanel.jsx` ve `NotificationsPage.jsx` kendi `getTarget` fonksiyonlarini ayri ayri tutuyor.

Sonuç:

- mantik duplicasyonu
- tip eklenince iki yerin birden unutulma riski
- sayfa/panel arasında tutarsizlik

### Sorun 2. Birçok tip doğru yere gitmiyor

Şu tipler bugün global notification target resolver tarafinda eksik veya yetersiz:

- `connection_request`
- `connection_accepted`
- `mentorship_request`
- `mentorship_accepted`
- `teacher_network_linked`
- `job_application`

Bu tipler listede görünse bile ya `/new` ana sayfasina düşüyor ya da yeterli bağlam açilmiyor.

### Sorun 3. Deep-link context zayif

Bugünkü routing yaklaşimi çoğu durumda sadece kaba sayfaya götürüyor:

- event bildirimi -> `/new/events`
- mention_event -> `/new/events`
- job notification -> hedef yok
- networking bildirimleri -> hedef yok

Bu, kullanicinin "hangi event?", "hangi istek?", "hangi kart?" diye tekrar arama yapmasina neden olur.

### Sorun 4. Okundu modeli kaba

`POST /api/new/notifications/read` bütün unread bildirimleri tek seferde okundu yapıyor.

Bu yaklaşimin problemleri:

- kullanici sadece sayfayi açinca her şey okunmuş oluyor
- gerçekten tiklanan item bilinmiyor
- hangi tipin açildiği ve hangisinin sadece görüldüğü ayrilmiyor
- okunmayan kritik item'lari daha sonra tekrar bulmak zorlaşıyor

### Sorun 5. Realtime modeli zayif

Frontend tarafinda `notification:new` event dinleniyor fakat uygulama içinde bu event sistematik şekilde emit edilmiyor.

Sonuç:

- yeni bildirim geldiğinde badge anlik güncellenmeyebilir
- deneyim çoğunlukla polling'e kalir
- action sonucu local UI ile server durumu arasinda gecikme olabilir

### Sorun 6. Actionable notification modeli yok

Bugün aksiyon alınabilir notification davranışı esasen sadece `group_invite` için var.

Eksik olanlar:

- connection request accept / ignore
- mentorship request accept / decline
- teacher network notification için "graphi aç" / "mark read"
- job application için "başvuruları aç"
- event invite için "evente git" veya cevap ver

### Sorun 7. Kategori, öncelik ve hiyerarşi yok

Bugünkü liste düz kronolojik akiyor.

Eksikler:

- aksiyon gerektiren bildirimler üstte değil
- bilgi amaçli olanlarla operasyonel olanlar ayrilmiyor
- networking / groups / jobs / events / feed ayrimi yok

### Sorun 8. Admin tarafi kullanıcı bildirim sisteminden kopuk

Adminde `NotificationsSection` esasen support request ve verification queue mantiginda.

Eksik olanlar:

- gerçek user notifications için operasyon görünürlüğü
- type dağılımı
- delivery sağlığı
- failed / noisy / spammy notification tespiti

### Sorun 9. Payload contract zayif

`notifications` tablosu çok dar:

- `type`
- `entity_id`
- `message`
- `source_user_id`
- `read_at`

Eksikler:

- category
- priority
- action payload
- target route
- target context
- dedupe key
- clicked_at
- seen_at
- archived_at
- metadata json

### Sorun 10. Kapsama eksikleri

Bugün sistem birçok kritik ürün event'ini bildirimleştirmiyor veya ürünleşmiş biçimde yönetmiyor.

Örnek aday alanlar:

- mentorship decline sonucu
- teacher link review sonucu
- verification request sonucu
- announcement approval sonucu
- group role değişimi
- event reminder / starts soon
- job application status updates
- profile verification accepted/rejected

---

## 4. Gap Matrisi

| Tip | Bugünkü hedef | Durum | Hedeflenen davranış |
| --- | --- | --- | --- |
| `like` | `/new?post=:id` | kabul edilebilir | ilgili postu focus'lu aç |
| `comment` | `/new?post=:id` | kabul edilebilir | ilgili post + yorum bağlami |
| `mention_post` | `/new?post=:id` | kabul edilebilir | ilgili post + mention vurgusu |
| `mention_photo` | `/new/albums/photo/:id` | iyi | photo detailde mention scroll |
| `photo_comment` | `/new/albums/photo/:id` | iyi | ilgili yoruma kaydirma eklenecek |
| `follow` | `/new/members/:sourceUserId` | iyi | profil CTA vurgusu ile aç |
| `mention_message` | `/new/messages/:id` | kismi | message detailde mention/highlight gerekli |
| `mention_group` | `/new/groups/:id` | kismi | ilgili post/comment anchor gerekli |
| `group_join_request` | `/new/groups/:id` | kismi | request drawer veya queue sekmesi açilmali |
| `group_join_approved` | `/new/groups/:id` | iyi | gruba giris durumu vurgulanmali |
| `group_join_rejected` | `/new/groups/:id` | kismi | sebep ve next step alanı olmali |
| `group_invite` | `/new/groups/:id` | iyiye yakin | inline accept/reject + detail context |
| `mention_event` | `/new/events` | zayif | ilgili event kartini focus’lu aç |
| `event_comment` | `/new/events` | zayif | event detail state veya query-based focus |
| `event_invite` | `/new/events` | zayif | evente derin link + RSVP CTA |
| `connection_request` | `/new` | kırık | networking hub incoming connection section |
| `connection_accepted` | `/new` | kırık | target member detail veya hub success state |
| `mentorship_request` | `/new` | kırık | networking hub incoming mentorship section |
| `mentorship_accepted` | `/new` | kırık | member detail / messages compose / mentor context |
| `teacher_network_linked` | `/new` | kırık | networking hub teacher notifications veya teacher network geçmişi |
| `job_application` | `/new` | kırık | jobs sayfasında ilgili ilan kartı veya applications paneli |

---

## 5. Ürün İlkeleri

Yeni notification sistemi şu ilkelerle tasarlanmali:

### 5.1 Action-first

Aksiyon isteyen bildirimler, pasif bilgi bildirimlerinden ayrilmali.

Örnek:

- `Bağlantı isteği geldi` pasif like bildiriminden daha üstte görünmeli

### 5.2 Context-preserving navigation

Bildirime tiklamak sadece sayfa değiştirmemeli; sayfa içinde doğru state'i açmali.

Örnek:

- ilgili kart focus
- ilgili section auto-scroll
- drawer açilişi
- filtre ön ayari
- query param ile highlight

### 5.3 Unified but domain-aware

Genel notification merkezi tek yer olmalı, ama domain-specific işlemler kendi özel yüzeyine gönderebilmeli.

Örnek:

- global inbox'ta `teacher_network_linked` görünür
- tiklaninca `/new/network/hub#teacher-notifications` ya da teacher network geçmişine gider

### 5.4 Read state precision

Şunlar birbirinden ayrilmali:

- delivered
- seen
- opened
- acted_on
- archived

### 5.5 Fatigue control

Her olay ayrı satir üretmemeli.

Gerekirse:

- dedupe
- aggregation
- digest
- low priority collapse

### 5.6 Explainable UX

Kullanici ne olduğunu ve niye önemli olduğunu ilk bakışta anlamali.

Kart içinde şu sorular cevaplanmali:

- kim?
- ne oldu?
- bu ne anlama geliyor?
- bir sonraki aksiyon ne?

---

## 6. Hedef Mimari

## 6.1 Notification type registry

Hem backend hem frontend için merkezi registry kurulmalı.

Önerilen yapı:

- backend: `server/src/services/notificationRegistry.js`
- frontend: `frontend-modern/src/utils/notificationRegistry.js`

Registry'nin taşımasi gereken alanlar:

- `type`
- `category`
- `priority`
- `defaultTarget`
- `targetResolver`
- `actionKind`
- `supportsInlineAction`
- `defaultIcon`
- `defaultLabel`
- `analyticsEventNames`

Beklenen fayda:

- string literal dağinikliğini bitirir
- yeni tip eklemeyi kontrollü hale getirir
- target routing tek yerden yönetilir

## 6.2 Notification payload contract

Mevcut tablo çok dar. Aşağidaki genişleme önerilir:

- `category`
- `priority`
- `metadata_json`
- `target_path`
- `target_context_json`
- `action_payload_json`
- `dedupe_key`
- `seen_at`
- `opened_at`
- `clicked_at`
- `archived_at`

Not:

Bu alanlar bir anda fiziksel migration ile gelmek zorunda değil. Faz 1'de önce API response shape zenginleştirilebilir, sonra migration uygulanabilir.

## 6.3 Deep-link contract

Her notification tipi için çözüm şu iki parçaya ayrilmali:

1. Hangi route?
2. Hangi UI state?

Örnek hedef stratejileri:

- post: `/new?post=:id`
- event: `/new/events?event=:id&focus=comments`
- group join request: `/new/groups/:id?tab=requests&request=:requestId`
- group invite: `/new/groups/:id?tab=about&invite=1`
- connection request: `/new/network/hub?section=incoming-connections&request=:id`
- mentorship request: `/new/network/hub?section=incoming-mentorship&request=:id`
- teacher link: `/new/network/hub?section=teacher-notifications&notification=:id`
- job application: `/new/jobs?job=:jobId&tab=applications`

## 6.4 UI yüzeyleri

Yeni sistemde dört ana yüzey düşünülmeli:

### Yüzey A. Global unread badge

- sadece toplam unread değil
- high-priority unread sayisi da opsiyonel görünmeli

### Yüzey B. Compact notification panel

- feed veya side panel için
- max 5-7 satir
- action-first öncelik
- inline primary CTA

### Yüzey C. Full notifications inbox

- filtreler
- kategori sekmeleri
- grouped list
- bulk actions
- saved views

### Yüzey D. Domain inbox surfaces

- networking hub
- jobs owner queue
- groups moderation queue

Bu yüzeyler tek notification contract'i paylaşmali.

---

## 7. Fazli Uygulama Plani

## Faz 0. Audit ve Product Spec

Amaç:

- notification sistemini kontrolsüz büyümekten çıkarmak
- tip matrisi ve hedef davranışları resmileştirmek

### Faz 0 görevleri

#### NTF0-S1 Notification inventory çıkar

- backend'de fiilen üretilen tüm notification tiplerini listele
- her tipin üretildiği endpoint veya service'i çıkar
- mevcut frontend target davranışını eşle
- "üretiliyor ama UI'da doğru tüketilmiyor" tipleri işaretle

#### NTF0-S2 Routing matrix oluştur

- her notification tipi için canonical target tanımla
- route + query + section + focus state sözleşmesini yaz
- detail route gerektiren modülleri işaretle

#### NTF0-S3 Priority ve category modeli tanımla

Önerilen category set:

- `social`
- `messaging`
- `networking`
- `groups`
- `events`
- `jobs`
- `system`

Önerilen priority set:

- `critical`
- `actionable`
- `important`
- `informational`

#### NTF0-S4 Coverage gap listesi çıkar

- hiç bildirimi olmayan ama olması gereken eventler
- çok sık ve gürültülü eventler
- dedupe gerektiren eventler

### Faz 0 kabul kriterleri

- notification type matrix yazılı hale gelmiş olacak
- her tip için canonical target netleşmiş olacak
- P0 coverage gap listesi onaylanmiş olacak

---

## Faz 1. Routing Doğruluğu ve Contract Foundation

Amaç:

- bildirime tiklandiginda kullaniciyi doğru yere götürmek
- frontend ve backend notification contract'ini birleştirmek

### Faz 1 görevleri

#### NTF1-S1 Frontend notification registry

- `NotificationPanel` ve `NotificationsPage` içindeki `getTarget` duplicasyonunu kaldır
- ortak `resolveNotificationTarget(notification)` helper'ı yaz
- ortak `notificationViewModel` mapper kur

#### NTF1-S2 Backend enriched response

- `/api/new/notifications` response'una type-derived alanlar ekle:
  - `category`
  - `priority`
  - `target`
  - `target_context`
  - `actions`

#### NTF1-S3 Per-item read / open modeli

- `POST /api/new/notifications/:id/open`
- `POST /api/new/notifications/:id/read`
- `POST /api/new/notifications/bulk-read`
- tüm listeyi sayfa açilir açilmaz okundu yapma davranışini kaldir

#### NTF1-S4 Deep link state consumption

Şu sayfalar query/section/focus state tüketebilmeli:

- feed
- events
- groups detail
- jobs
- network hub
- messages / message detail

#### NTF1-S5 Click analytics

- notification impression
- notification open
- notification action
- notification conversion

### Faz 1 kabul kriterleri

- global notification listesindeki tüm mevcut tipler doğru route'a gidiyor olacak
- en az P0 tipler için doğru section/focus state açilacak
- notification page açilinca kör toplu-read olmayacak

---

## Faz 2. Inbox UX ve Interaction Modeli

Amaç:

- bildirim sayfasini pasif listeden operasyon merkezi haline getirmek

### Faz 2 görevleri

#### NTF2-S1 Full inbox bilgi mimarisi

Bildirim sayfasinda şu yapıyı kur:

- `Action Required`
- `Recent Updates`
- `Earlier`

veya kategori sekmeleri:

- All
- Action Required
- Networking
- Groups
- Events
- Jobs
- Social

#### NTF2-S2 Card redesign

Her kartta:

- actor avatar
- human-readable title
- kısa body
- relative/absolute timestamp
- priority indicator
- unread state
- inline CTA
- secondary CTA

#### NTF2-S3 Bulk actions

- hepsini okundu yap
- sadece bu kategoriyi okundu yap
- archive / dismiss
- actionable kartlari topluca temizlememe guardrail'i

#### NTF2-S4 Inline actions

İlk dalgada en az:

- connection request accept / ignore
- mentorship request accept / decline
- group invite accept / reject
- teacher link mark read / open hub

#### NTF2-S5 Empty / error / loading states

- her kategori için amaca uygun empty-state
- skeleton layout
- retry state
- background refresh state

#### NTF2-S6 Compact panel upgrade

- panelde raw chronological liste yerine priority-aware liste
- en üstte actionable items
- high-priority item varsa badge veya chip
- "see all" geçişi filtre/state korumalı olsun

### Faz 2 kabul kriterleri

- notification page karar alma yüzeyi gibi hissedilmeli
- panel ile full inbox arasında aynı tasarım dili kurulmuş olmalı
- en kritik aksiyonlar sayfadan ayrılmadan sonuçlandirilabilmeli

---

## Faz 3. Coverage Expansion

Amaç:

- eksik ürün eventlerini bildirim modeline almak

### Faz 3 görevleri

#### NTF3-S1 Networking coverage tamamla

- `connection_request`
- `connection_accepted`
- `mentorship_request`
- `mentorship_accepted`
- gerekirse `mentorship_declined`
- `teacher_network_linked`
- gerekirse `teacher_link_review_confirmed / flagged`

#### NTF3-S2 Jobs coverage tamamla

- `job_application`
- application status change
- poster follow edilen biri ise yeni job ilanı opsiyonel event

#### NTF3-S3 Events coverage tamamla

- `event_invite`
- `event_comment`
- RSVP response değişimleri
- event starts soon reminder

#### NTF3-S4 Groups coverage tamamla

- `group_join_request`
- `group_join_approved`
- `group_join_rejected`
- `group_invite`
- role changed
- moderation result notifications

#### NTF3-S5 System notifications

- verification approved / rejected
- request resolution
- announcement approval / rejection
- safety / moderation decisions

#### NTF3-S6 Dedupe ve aggregation

Örnekler:

- ayni kişiden arka arkaya gelen like'lar tek cluster
- ayni post altindaki çoklu yorum eventleri cluster
- ayni event için arka arkaya reminder collapse

### Faz 3 kabul kriterleri

- P0/P1 event alanlarinin tamaminda notification coverage olacak
- yeni tiplerin hepsi registry ve routing matrix'e kaydedilmiş olacak

---

## Faz 4. Realtime, Delivery ve Güvenilirlik

Amaç:

- bildirimleri daha canlı ve güvenilir hale getirmek

### Faz 4 görevleri

#### NTF4-S1 Realtime sinyal modeli

Seçenekler:

- mevcut polling'i iyileştir
- websocket / SSE tabanli lightweight notification channel ekle
- en azindan client event bus'a gerçek `notification:new` emission bağla

#### NTF4-S2 Delivery durability

- enqueue / persist / deliver ayrımı
- failed insert veya silent drop logları
- retry veya dead letter mantığı gerekiyorsa tasarla

#### NTF4-S3 Toast + inbox koordinasyonu

- kullanıcı başka sayfadayken soft toast
- tıklayınca doğru hedef
- toast kapansa bile inbox kaydı kalır

#### NTF4-S4 Seen/open telemetry

- sadece unread count değil
- open rate
- action rate
- time to action
- per-type conversion

#### NTF4-S5 Performance hardening

- unread count sorgusu
- paginated listing
- category index
- recent item index
- optional summary table

### Faz 4 kabul kriterleri

- yeni bildirimler görünür gecikme ile değil, hissedilir derecede canlı gelmeli
- unread badge, compact panel ve full inbox tutarlı güncellenmeli

---

## Faz 5. Preferences, Admin Visibility ve Governance

Amaç:

- notification sistemini sürdürülebilir ürün bileşeni haline getirmek

### Faz 5 görevleri

#### NTF5-S1 User notification preferences

- category bazlı opt-in/opt-out
- email / in-app / quiet mode ayrımı için temel model
- high priority override kuralları

#### NTF5-S2 Admin operations console

- notification hacmi
- type dağılımı
- unread aging
- noisiest eventler
- failed deliveries
- spam suspect patterns

#### NTF5-S3 Quality analytics

- hangi tipler açılıyor
- hangi tipler ignored kalıyor
- hangi tipler aksiyona dönüşüyor
- hangi tipler yanlış hedefe götürdüğü için bounce üretiyor

#### NTF5-S4 Experiment framework

- title/body varyantları
- CTA varyantları
- action-first sort etkisi
- grouped vs flat list etkisi

#### NTF5-S5 Governance

- yeni notification tipi ekleme checklist'i
- naming convention
- analytics zorunluluğu
- dedupe policy
- default target policy

### Faz 5 kabul kriterleri

- notification sistemi product ops tarafindan ölçülebilir olacak
- yeni tip eklemek için standardize süreç olacak

---

## 8. Önerilen Epic > Story Yapisi

### EPIC NTF0. Inventory and Spec

- `NTF0-S1` Tip envanteri
- `NTF0-S2` Route/target matrisi
- `NTF0-S3` Category/priority modeli
- `NTF0-S4` Coverage gap listesi

### EPIC NTF1. Correct Navigation and Contract

- `NTF1-S1` Frontend registry
- `NTF1-S2` Backend enriched payload
- `NTF1-S3` Per-item read/open
- `NTF1-S4` Deep-link state support
- `NTF1-S5` Click analytics

### EPIC NTF2. Inbox UX

- `NTF2-S1` Information architecture
- `NTF2-S2` Notification card system
- `NTF2-S3` Bulk actions
- `NTF2-S4` Inline actions
- `NTF2-S5` Empty/loading/error states
- `NTF2-S6` Compact panel redesign

### EPIC NTF3. Event Coverage

- `NTF3-S1` Networking notifications
- `NTF3-S2` Jobs notifications
- `NTF3-S3` Events notifications
- `NTF3-S4` Groups notifications
- `NTF3-S5` System notifications
- `NTF3-S6` Dedupe/aggregation

### EPIC NTF4. Realtime and Reliability

- `NTF4-S1` Realtime update channel
- `NTF4-S2` Delivery durability
- `NTF4-S3` Toast/inbox coordination
- `NTF4-S4` Seen/open telemetry
- `NTF4-S5` Performance hardening

### EPIC NTF5. Preferences and Governance

- `NTF5-S1` User preferences
- `NTF5-S2` Admin console
- `NTF5-S3` Quality analytics
- `NTF5-S4` Experiments
- `NTF5-S5` Governance policy

---

## 9. Sprint Önerisi

### Sprint A. P0 doğruluk sprinti

Önerilen kapsam:

- `NTF0-S1`
- `NTF0-S2`
- `NTF1-S1`
- `NTF1-S2`
- `NTF1-S3`
- `NTF1-S4`

Beklenen çıktı:

- bildirime tıklayınca doğru yere gitme problemi çözülür
- toplu kör-read kalkar
- foundation contract oturur

### Sprint B. P0 UX sprinti

Önerilen kapsam:

- `NTF2-S1`
- `NTF2-S2`
- `NTF2-S4`
- `NTF2-S6`

Beklenen çıktı:

- notification page ve panel belirgin şekilde güçlenir
- kullanıcı aksiyonları daha hızlı tamamlar

### Sprint C. Coverage sprinti

Önerilen kapsam:

- `NTF3-S1`
- `NTF3-S2`
- `NTF3-S3`
- `NTF3-S4`

Beklenen çıktı:

- networking, jobs, events ve groups eksikleri kapanir

### Sprint D. Reliability sprinti

Önerilen kapsam:

- `NTF4-S1`
- `NTF4-S3`
- `NTF4-S5`

Beklenen çıktı:

- sistem daha canlı, daha stabil ve daha hizli görünür

### Sprint E. Governance sprinti

Önerilen kapsam:

- `NTF5-S1`
- `NTF5-S2`
- `NTF5-S3`
- `NTF5-S5`

Beklenen çıktı:

- sistem uzun vadede yönetilebilir hale gelir

---

## 10. P0 Öncelik Listesi

İlk implementasyon dalgasinda mutlaka çözülmesi gerekenler:

1. Ortak notification registry
2. Ortak target resolver
3. `connection_request`, `connection_accepted`, `mentorship_request`, `mentorship_accepted`, `teacher_network_linked`, `job_application` için doğru routing
4. Page-open ile toplu read davranışinin kaldirilmasi
5. Per-item read/open endpointleri
6. Notification page action-first IA
7. Inline actionlarin ilk dalgasi

---

## 11. Başari Metrikleri

Önerilen temel metrikler:

### Kullanım

- daily notification opens
- unread to open rate
- panel to full inbox click-through

### Etkinlik

- notification action rate
- time-to-action
- actionable notification completion rate

### Kalite

- wrong-target bounce rate
- notification open sonrası 10 saniye içinde geri dönüş oranı
- per-type ignore rate

### Güvenilirlik

- unread count sync başarisi
- delivery failure rate
- realtime lag

---

## 12. Riskler

### Risk 1. "Her şeyi bildir" yaklaşimi spam üretir

Kontrol:

- category/priority modeli
- dedupe
- preferences

### Risk 2. Deep-link contract modülleri zorlayabilir

Kontrol:

- gerekli yerlerde query-state destekli incremental çözüm
- hemen yeni detail page açmadan mevcut sayfalar focus-state tüketebilir

### Risk 3. Read state migration karmaşiklaşabilir

Kontrol:

- önce API davranışı düzelt
- sonra şema genişlet

### Risk 4. Networking ve genel inbox ayrışabilir

Kontrol:

- tek registry
- tek payload contract
- domain surface'ler sadece alternatif render yüzeyi olsun

---

## 13. Planlama Sonucu

Bu alanda önerilen resmi başlangıç şudur:

### İlk resmi implementasyon dalgasi

- `NTF0-S1`
- `NTF0-S2`
- `NTF1-S1`
- `NTF1-S2`
- `NTF1-S3`
- `NTF1-S4`

Yani önce:

- doğruluk
- contract
- deep link
- read modeli

çözülmeli.

Görsel iyileştirmeler ve kapsam genişletmeleri bunun üzerine gelmeli.

---

## 14. Mevcut Kod Referanslari

Bu planı hazırlarken özellikle şu mevcut dosyalar baz alindi:

- `server/app.js`
- `frontend-modern/src/components/NotificationPanel.jsx`
- `frontend-modern/src/pages/NotificationsPage.jsx`
- `frontend-modern/src/components/Layout.jsx`
- `frontend-modern/src/pages/NetworkingHubPage.jsx`
- `frontend-modern/src/pages/admin/sections/NotificationsSection.jsx`
- `frontend-modern/src/App.jsx`

