# Bildirim Sistemi Execution Backlog

## 1. Amaç

Bu doküman, [notifications-rebaseline-phased-task-plan.md](/Users/cagataydonmez/Desktop/SDAL/docs/notifications-rebaseline-phased-task-plan.md) içindeki stratejik planı doğrudan uygulanabilir backlog'a çevirir.

Yapı:

- `Epic`
- `Story`
- `Task`
- `Priority`
- `Dependencies`
- `Definition of Ready`
- `Definition of Done`

Bu backlog'un hedefi, implementasyona geçildiğinde sıranın ve kapsamın tartışma gerektirmeden net olmasıdır.

---

## 2. Öncelik Dili

- `P0`: ürün doğruluğu veya temel akış için kritik
- `P1`: güçlü iyileştirme, ilk dalgadan hemen sonra alınmalı
- `P2`: değerli ama ikinci dalga / polish / governance

---

## 3. Epic Haritası

- `NTF0`: Inventory and Spec Foundation
- `NTF1`: Navigation and Contract Correctness
- `NTF2`: Inbox UX and Interaction Model
- `NTF3`: Event Coverage Expansion
- `NTF4`: Realtime, Reliability and Performance
- `NTF5`: Preferences, Admin Visibility and Governance

---

## 4. Execution Backlog

## EPIC NTF0. Inventory and Spec Foundation

Amaç:

- Bildirim sisteminin tiplerini, hedeflerini ve önceliklerini resmi hale getirmek

### `NTF0-S1` Notification Type Inventory

Priority:

- `P0`

Dependencies:

- yok

Tasks:

- backend'de notification üreten tüm call-site'lari listele
- her tip için source module belirle
- frontend'te bugün hangi tipin nasıl render edildiğini çıkar
- "üretiliyor ama doğru consume edilmiyor" tiplerini işaretle
- type matrix'i living table haline getir

Definition of Ready:

- mevcut plan dokümani mevcut

Definition of Done:

- notification type matrix tek yerde yazili
- her tip için source ve mevcut target biliniyor

### `NTF0-S2` Canonical Routing Matrix

Priority:

- `P0`

Dependencies:

- `NTF0-S1`

Tasks:

- her tip için canonical route belirle
- gerekli query param, section id, focus state sözleşmesini yaz
- yeni route gerektiren alanları işaretle
- route tüketici sayfaları çıkar

Definition of Done:

- her notification tipi için canonical target net
- route tüketici modüller listelenmiş

### `NTF0-S3` Category and Priority Model

Priority:

- `P0`

Dependencies:

- `NTF0-S1`

Tasks:

- category setini sabitle
- priority setini sabitle
- hangi tipin hangi category/priority aldığını yaz
- actionable vs informational ayrımını netleştir

Definition of Done:

- type -> category -> priority matrisi hazır

### `NTF0-S4` Coverage Gap Register

Priority:

- `P1`

Dependencies:

- `NTF0-S1`
- `NTF0-S2`

Tasks:

- hiç bildirimi olmayan kritik eventleri listele
- gürültülü event ailelerini listele
- dedupe gerektiren event ailelerini listele
- P0/P1/P2 coverage register hazırla

Definition of Done:

- coverage gap register backlog'a bağlanmış

---

## EPIC NTF1. Navigation and Contract Correctness

Amaç:

- Bildirime tıklayınca doğru hedefe, doğru UI state ile gitmek

### `NTF1-S1` Frontend Notification Registry

Priority:

- `P0`

Dependencies:

- `NTF0-S2`
- `NTF0-S3`

Tasks:

- `frontend-modern/src/utils/notificationRegistry.js` oluştur
- `resolveNotificationTarget(notification)` helper ekle
- `buildNotificationViewModel(notification)` helper ekle
- `NotificationPanel.jsx` ve `NotificationsPage.jsx` target duplicasyonunu kaldır
- ortak label/icon/category mapping kur

Definition of Done:

- target çözümleme tek dosyada
- panel ve page aynı resolver'ı kullanıyor

### `NTF1-S2` Backend Enriched Notification Payload

Priority:

- `P0`

Dependencies:

- `NTF0-S2`
- `NTF0-S3`

Tasks:

- `/api/new/notifications` response'una derived alanlar ekle
- `category`, `priority`, `target`, `target_context`, `actions`, `is_actionable` üret
- backward compatibility gerekiyorsa legacy alanları koru
- contract test ekle

Definition of Done:

- frontend target'i tahmin etmek zorunda kalmıyor
- API response type bazlı zenginleşmiş

### `NTF1-S3` Per-item Read / Open Model

Priority:

- `P0`

Dependencies:

- `NTF1-S2`

Tasks:

- `POST /api/new/notifications/:id/open`
- `POST /api/new/notifications/:id/read`
- `POST /api/new/notifications/bulk-read`
- `POST /api/new/notifications/bulk-archive` için temel contract tasarla
- mevcut "page open => mark all read" davranışını kaldır
- unread counter senaryolarını test et

Definition of Done:

- notification page açılınca tüm liste kör şekilde read olmuyor
- tiklanan item read/open olarak işaretleniyor

### `NTF1-S4` Deep-link State Consumption

Priority:

- `P0`

Dependencies:

- `NTF0-S2`
- `NTF1-S1`
- `NTF1-S2`

Tasks:

- feed'te `post` focus state'i güçlendir
- events sayfasına `event`, `focus`, `comment` query desteği ekle
- groups detail'e `tab`, `request`, `invite` query desteği ekle
- jobs sayfasına `job`, `tab` query desteği ekle
- network hub'a `section`, `request`, `notification` query desteği ekle
- messages tarafında `thread/message/focus` yönlendirmesini netleştir

Definition of Done:

- notification'dan gelen kullanıcı ilgili sayfada arama yapmak zorunda kalmıyor

### `NTF1-S5` Notification Click Analytics

Priority:

- `P1`

Dependencies:

- `NTF1-S3`

Tasks:

- impression event modeli tanımla
- open event modeli tanımla
- action event modeli tanımla
- target resolution success/failure eventleri ekle
- analytics payload standardını yaz

Definition of Done:

- notification journey ölçülebilir

---

## EPIC NTF2. Inbox UX and Interaction Model

Amaç:

- Bildirim sayfasını ve compact paneli güçlü karar yüzeyine dönüştürmek

### `NTF2-S1` Full Inbox Information Architecture

Priority:

- `P0`

Dependencies:

- `NTF1-S1`
- `NTF1-S2`

Tasks:

- full inbox için sekme veya grouped IA kararı ver
- `All`, `Action Required`, `Networking`, `Groups`, `Events`, `Jobs`, `Social` yapısını çıkar
- top summary strip / count chips tasarla
- URL ile filtre state senkronunu tasarla

Definition of Done:

- notification page bilgi mimarisi onaylı ve implementasyona hazır

### `NTF2-S2` Notification Card System

Priority:

- `P0`

Dependencies:

- `NTF2-S1`

Tasks:

- kart anatomy belirle
- avatar, title, body, meta, unread, priority, CTA slotları tasarla
- mobile davranışı tanımla
- category renk/ikon dilini belirle
- skeleton ve error halleriyle birlikte reusable component tasarla

Definition of Done:

- reusable notification card component spec'i hazır

### `NTF2-S3` Bulk Actions

Priority:

- `P1`

Dependencies:

- `NTF1-S3`
- `NTF2-S1`

Tasks:

- mark all read
- mark current filter read
- archive current filter
- selected-items bulk action opsiyonunu tasarla
- destructive olmayan guardrail metinlerini yaz

Definition of Done:

- bulk actionlar UI ve API seviyesinde net

### `NTF2-S4` Inline Actions

Priority:

- `P0`

Dependencies:

- `NTF1-S2`
- `NTF1-S3`

Tasks:

- connection request accept/ignore inline action
- mentorship request accept/decline inline action
- group invite accept/reject inline action
- teacher network notification için open/mark-read action
- optimistic state ve rollback davranışını tasarla

Definition of Done:

- en kritik aksiyonlar notification içinden yapılabiliyor

### `NTF2-S5` Empty, Error, Loading and Recovery States

Priority:

- `P1`

Dependencies:

- `NTF2-S1`

Tasks:

- kategori bazlı empty-state metinleri yaz
- loading skeleton kuralları belirle
- background refresh durumu tanımla
- retry davranışı tasarla

Definition of Done:

- state design eksiksiz

### `NTF2-S6` Compact Panel Redesign

Priority:

- `P0`

Dependencies:

- `NTF2-S2`
- `NTF2-S4`

Tasks:

- panel için max visible item stratejisi belirle
- actionable-first ordering kur
- panelden full inbox'a stateful geçiş kurgula
- panelde high priority chip / badge modeli tasarla

Definition of Done:

- compact panel artık mini operasyon yüzeyi gibi çalışıyor

---

## EPIC NTF3. Event Coverage Expansion

Amaç:

- Ürünün önemli olaylarında eksik notification coverage'ı kapatmak

### `NTF3-S1` Networking Notification Coverage

Priority:

- `P0`

Dependencies:

- `NTF1-S1`
- `NTF1-S2`
- `NTF1-S4`

Tasks:

- `connection_request` UX contract
- `connection_accepted` UX contract
- `mentorship_request` UX contract
- `mentorship_accepted` UX contract
- `mentorship_declined` gereksinimini kararlaştır
- `teacher_network_linked` global inbox ve hub koordinasyonunu netleştir
- review-result notification ihtiyacını kararlaştır

Definition of Done:

- networking event ailesi tam kapsanmış

### `NTF3-S2` Jobs Notification Coverage

Priority:

- `P0`

Dependencies:

- `NTF1-S4`

Tasks:

- `job_application` için deep link tanımla
- poster için application queue entry state'i tanımla
- application status değişim notification'ı gerekiyorsa event ve contract ekle
- jobs page query consumption tasarla

Definition of Done:

- job application notification doğru yere götürüyor

### `NTF3-S3` Events Notification Coverage

Priority:

- `P1`

Dependencies:

- `NTF1-S4`

Tasks:

- `event_comment` focus state
- `event_invite` RSVP CTA
- `mention_event` focus state
- event reminder ihtiyacını ürün kararı olarak netleştir

Definition of Done:

- event bildirimleri kaba liste yönlendirmesi olmaktan çıkmış

### `NTF3-S4` Groups Notification Coverage

Priority:

- `P1`

Dependencies:

- `NTF1-S4`

Tasks:

- `group_join_request` request tab yönlendirmesi
- `group_join_approved/rejected` explanation state
- `group_invite` inline action + target detail
- role changed notification ihtiyacını kararlaştır

Definition of Done:

- groups bildirimleri domain-uyumlu hale gelmiş

### `NTF3-S5` System Notification Coverage

Priority:

- `P1`

Dependencies:

- `NTF0-S4`

Tasks:

- verification result notifications
- request resolution notifications
- moderation/system notices
- announcement approval/reject sonuçları

Definition of Done:

- system-level kritik kararlar bildirimleşmiş

### `NTF3-S6` Dedupe and Aggregation

Priority:

- `P2`

Dependencies:

- `NTF3-S1`
- `NTF3-S3`
- `NTF3-S4`

Tasks:

- like/comment burst dedupe kuralları
- repeated event reminder collapse
- noisy follow/engagement event policy
- dedupe key standardı tasarla

Definition of Done:

- high-noise eventlerde kontrollü aggregation var

---

## EPIC NTF4. Realtime, Reliability and Performance

Amaç:

- Notification deneyimini canlı, hızlı ve güvenilir hale getirmek

### `NTF4-S1` Realtime Refresh Contract

Priority:

- `P1`

Dependencies:

- `NTF1-S5`

Tasks:

- mevcut event bus kullanımını audit et
- `notification:new` gerçekten üretilecek mi yoksa SSE/WebSocket mi kullanılacak karar ver
- unread badge, panel ve page için update contract yaz
- visibility-aware refresh davranışı tanımla

Definition of Done:

- notification refresh modeli net

### `NTF4-S2` Delivery Durability

Priority:

- `P1`

Dependencies:

- `NTF1-S2`

Tasks:

- failed notification insert loglama
- critical eventlerde silent failure riskini tespit et
- gerekiyorsa queue/retry yaklaşımı tasarla
- audit trail ihtiyacını netleştir

Definition of Done:

- delivery güvenilirliği için teknik yaklaşım belirlenmiş

### `NTF4-S3` Toast and Inbox Coordination

Priority:

- `P1`

Dependencies:

- `NTF4-S1`

Tasks:

- page üzerindeyken soft toast davranışı tasarla
- toast -> inbox record ilişkisini netleştir
- double-surface fatigue riskini kontrol et

Definition of Done:

- toast ve inbox birbirini bozmuyor

### `NTF4-S4` Seen / Open / Action Telemetry

Priority:

- `P1`

Dependencies:

- `NTF1-S5`

Tasks:

- seen/open/action telemetry tablosu veya event akışı tasarla
- per-type conversion ölçümlerini tanımla
- wrong-target bounce sinyalini tanımla

Definition of Done:

- quality ölçümleri okunabilir

### `NTF4-S5` Performance Hardening

Priority:

- `P1`

Dependencies:

- `NTF1-S2`
- `NTF1-S3`

Tasks:

- notifications listing index kontrolü
- unread counter query optimizasyonu
- category/priority filtrelerinin query planı
- gerekirse recent summary cache veya daily summary yaklaşımı

Definition of Done:

- notification surfaces yük altında da hızlı

---

## EPIC NTF5. Preferences, Admin Visibility and Governance

Amaç:

- Sistemi uzun vadeli yönetilebilir ürün bileşeni haline getirmek

### `NTF5-S1` User Notification Preferences

Priority:

- `P2`

Dependencies:

- `NTF3-S1`
- `NTF3-S3`
- `NTF3-S4`

Tasks:

- category bazlı preference modeli
- high priority override policy
- quiet mode / channel strategy ilk taslak
- preference UI yüzeyi taslağı

Definition of Done:

- preferences backlog'u implementasyona hazır

### `NTF5-S2` Admin Notification Ops Console

Priority:

- `P2`

Dependencies:

- `NTF4-S4`

Tasks:

- type volume dashboard
- unread aging görünümü
- failed delivery görünümü
- noisy type görünümü
- alert threshold önerileri

Definition of Done:

- admin notification ops yüzeyi tasarlanmış

### `NTF5-S3` Quality Analytics

Priority:

- `P2`

Dependencies:

- `NTF4-S4`

Tasks:

- per-type open rate
- per-type action rate
- per-surface CTR
- target accuracy proxy metrics

Definition of Done:

- ürün tarafı kaliteyi okuyabiliyor

### `NTF5-S4` Experiment Layer

Priority:

- `P2`

Dependencies:

- `NTF2-S1`
- `NTF4-S4`

Tasks:

- sort order experiment
- card CTA experiment
- grouped vs flat list experiment
- title/body wording experiment

Definition of Done:

- experiment-ready structure tanımlı

### `NTF5-S5` Governance and New-Type Policy

Priority:

- `P2`

Dependencies:

- `NTF0-S3`
- `NTF1-S2`

Tasks:

- yeni notification tipi checklist'i yaz
- naming convention belirle
- analytics zorunluluğu koy
- dedupe policy standardı yaz
- default target policy yaz

Definition of Done:

- yeni type eklemek artık kişisel yoruma kalmıyor

---

## 5. Önerilen Implementasyon Dalgası

### Dalga 1. Foundation

- `NTF0-S1`
- `NTF0-S2`
- `NTF0-S3`
- `NTF1-S1`
- `NTF1-S2`
- `NTF1-S3`
- `NTF1-S4`

Amaç:

- Doğruluk, routing ve read state problemlerini çözmek

### Dalga 2. UX Core

- `NTF2-S1`
- `NTF2-S2`
- `NTF2-S4`
- `NTF2-S6`

Amaç:

- Bildirim yüzeylerini güçlü hale getirmek

### Dalga 3. Coverage

- `NTF3-S1`
- `NTF3-S2`
- `NTF3-S3`
- `NTF3-S4`

Amaç:

- Eksik event alanlarını kapatmak

### Dalga 4. Reliability

- `NTF4-S1`
- `NTF4-S3`
- `NTF4-S5`

Amaç:

- Canlılık ve performans

### Dalga 5. Governance

- `NTF5-S1`
- `NTF5-S2`
- `NTF5-S3`
- `NTF5-S5`

Amaç:

- Ölçülebilir ve sürdürülebilir notification sistemi

---

## 6. İlk Sprint Önerisi

İlk gerçek implementasyon sprinti için önerilen kapsam:

1. `NTF0-S1`
2. `NTF0-S2`
3. `NTF0-S3`
4. `NTF1-S1`
5. `NTF1-S2`
6. `NTF1-S3`
7. `NTF1-S4`

Bu sprintte özellikle çözülmesi gereken kullanıcı problemleri:

- bildirime tıklayınca yanlış yere gitme
- networking ve jobs bildirimlerinin boşa düşmesi
- sayfa açılınca hepsinin okunmuş olması
- panel ve full page arasında target tutarsızlığı

---

## 7. Definition of Ready

Bir story implementasyona alınmadan önce:

- canonical target kararı verilmiş olmalı
- ilgili backend response shape net olmalı
- ilgili frontend surface belli olmalı
- acceptance criteria yazılmış olmalı
- test yüzeyi belli olmalı

---

## 8. Definition of Done

Bir story tamamlanmış sayılmadan önce:

- ilgili notification tipi registry'de tanımlı olacak
- backend response contract güncel olacak
- tıklama doğru route ve doğru UI state açacak
- unread/read/open davranışı test edilmiş olacak
- en az bir contract veya UI-level doğrulama olacak
- dokümantasyon gerekiyorsa güncellenecek

---

## 9. Planlama Sonucu

Bu backlog'a göre en doğru başlangıç:

- önce `NTF0` ve `NTF1`
- sonra `NTF2` içindeki P0 UX işleri
- sonra coverage genişletmeleri

Yani ilk sprintte görsel polish'ten önce navigation doğruluğu ve notification contract temeli çözülmeli.

