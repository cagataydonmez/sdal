# SDAL Networking Hub & Teacher Network Technical Backlog

Bu doküman, `Sosyal Ağ Merkezi` ve `Öğretmen Ağı` modülleri için teknik revizyon backlog'unu toplar.

Ana amaç:

- mevcut teknik borcu görünür kılmak,
- iyileştirmeleri önceliklendirmek,
- backend, frontend, veri modeli ve gözlemlenebilirlik düzeyinde yapılacak işleri netleştirmek,
- gelecekteki sprint planlamasını kolaylaştırmaktır.

Referans:

- `docs/networking-hub-teacher-network-playbook.md`

---

## 1. Hedef Mimari Özeti

İdeal durumda networking stack şu özelliklere sahip olmalıdır:

- tekil aggregate endpoint ile hızlı ilk boyama,
- optimistic UI + sessiz arka plan doğrulaması,
- tutarlı state modeli,
- daha iyi cache/invalidasyon davranışı,
- teacher graph için daha güçlü moderasyon ve kalite sinyali,
- analytics ve admin görünürlüğü için özet veri katmanı,
- PostgreSQL uyumlu sorgu standardizasyonu.

---

## 2. Öncelik Seviyeleri

Bu backlog üç seviyede düşünülmelidir:

### P0

Ürünün akış kalitesini doğrudan etkileyen, hissedilir sorunları çözen işler.

### P1

Ölçek, bakım kolaylığı ve ürün netliği sağlayan iyileştirmeler.

### P2

İleri seviye veri kalitesi, moderasyon, analitik ve optimizasyon işleri.

---

## 3. P0 Backlog

### P0.1 Tek aggregate networking endpoint

Durum:

- bugün hub ekranı birden çok endpoint ile yükleniyor
- son optimizasyonlarla iki aşamalı yüklenmeye düşürüldü
- ancak tam aggregate endpoint hâlâ yok

Öneri:

- `GET /api/new/network/hub`

İçerik:

- inbox
- metrics
- discovery summary
- connection request maps
- unread counts

Beklenen fayda:

- daha az network roundtrip
- daha hızlı first meaningful paint
- daha basit frontend state
- daha kolay cache stratejisi

Çıkış kriteri:

- NetworkingHubPage ilk yüklemede tek API çağrısıyla ana state'i almalı

### P0.2 Frontend state'in parçalanması

Durum:

- hub state'i aynı bileşende çok fazla parça içeriyor
- aynı veri hem listede hem map'te hem sayaçta tutuluyor

Öneri:

- `useNetworkingHubState` adında özel hook
- reducer tabanlı state yönetimi
- action bazlı state transition fonksiyonları

Beklenen fayda:

- daha tahmin edilebilir update davranışı
- daha az regressions
- test edilebilirlik artışı

### P0.3 Silent refresh standardı

Durum:

- bazı aksiyonlar sonrası sessiz refresh var
- ama bu desen ayrı bileşenlerde tam standardize değil

Öneri:

- `silent refresh`, `bootstrap`, `discovery refresh`, `action refresh` kavramlarını ortak utility/hook seviyesine çek

Beklenen fayda:

- zıplama ve loader geri gelişi azalır
- davranış tutarlı olur

### P0.4 Connection/mentorship/teacher event sözlüklerinin merkezileştirilmesi

Durum:

- event isimleri ve UI feedback metinleri dağınık durumda

Öneri:

- ortak `networkingEvents.js`
- ortak `networkingMessages.js`

Beklenen fayda:

- daha az duplication
- daha kolay localization
- daha tutarlı telemetry

### P0.5 API response shape standardizasyonu

Durum:

- bazı endpoint'ler sadece text döndürüyor
- bazıları JSON dönüyor

Öneri:

- networking modülündeki tüm endpoint'lerde standart response shape:
  - `ok`
  - `code`
  - `message`
  - `data`

Beklenen fayda:

- frontend hata yönetimi kolaylaşır
- alert/string parsing ihtiyacı azalır

---

## 4. P1 Backlog

### P1.1 Teacher Network için audit trail

Durum:

- kayıt yaratılıyor ama neden ve hangi akıştan geldiği sınırlı görünüyor

Öneri:

- `created_via`
- `source_surface`
- `last_reviewed_by`
- `review_status`

alanları eklenebilir

Beklenen fayda:

- moderasyon kolaylaşır
- product analytics güçlenir

### P1.2 Confidence score'un işlevsel hale getirilmesi

Durum:

- `confidence_score` alanı var
- ancak pratikte sabit/etkisiz

Öneri:

- kullanıcı ekleme tipi
- doğrulanmış teacher hedefi
- duplicate proximity
- admin onayı
- raporlanma durumu

gibi sinyallerle confidence hesaplamak

Beklenen fayda:

- teacher graph kalitesi sayısal olarak izlenebilir

### P1.3 Suggestion engine ayrıştırması

Durum:

- suggestion logic ağır ve `app.js` içinde büyük blok halinde

Öneri:

- `server/src/services/networkSuggestionService.js`
- scoring, reason generation, trust badge generation ayrılmalı

Beklenen fayda:

- bakım kolaylığı
- unit test yazılabilirlik
- performans optimizasyonu daha kolay

### P1.4 Networking metrics precomputation

Durum:

- bazı metrikler istek anında hesaplanıyor

Öneri:

- günlük/periodic özet tablo
- materialized summary yaklaşımı

Örnek tablo:

- `member_networking_daily_summary`

Beklenen fayda:

- hızlı dashboard
- daha ucuz sorgular

### P1.5 Notification type registry

Durum:

- notification tipleri string literal olarak dağınık

Öneri:

- merkezi tip registry
- tip bazlı payload contract

Beklenen fayda:

- yeni event tipleri eklemek kolaylaşır
- yanlış type yazımı azalır

### P1.6 Teacher options endpoint pagination/search iyileştirmesi

Durum:

- teacher options form odaklı
- veri büyüdükçe arama yeterli gelmeyebilir

Öneri:

- tokenized search
- ranking
- cohort / subject filtresi
- server side debounced query policy

---

## 5. P2 Backlog

### P2.1 Graph anomaly detection

Amaç:

- kısa sürede aşırı teacher link üretimi
- sıra dışı aynı hedef yoğunluğu
- spam benzeri graph yapıları

Öneri:

- admin anomaly panel
- nightly graph checks

### P2.2 Teacher Network report flow

Amaç:

- kullanıcıların yanlış teacher link'i raporlayabilmesi

Öneri:

- `report teacher link` endpoint
- admin review queue

### P2.3 Social graph score

Amaç:

- connection, mentorship, teacher link ve verification katmanlarını tek bir graph quality score içinde toplamak

### P2.4 Cohort benchmark analytics

Amaç:

- mezuniyet yılı bazında networking adoption,
- first success time,
- mentor demand/supply

### P2.5 Graph-based recommendation experiments

Amaç:

- farklı suggestion model varyantlarını A/B test etmek

---

## 6. Frontend Backlog

### FE-1 Networking hub reducer yapısı

Öncelik:

- P0

İş:

- NetworkingHubPage state'i reducer/hook yapısına taşınacak

### FE-2 Empty state ve helper copy standardizasyonu

Öncelik:

- P1

İş:

- connection
- mentorship
- teacher link

boş durum mesajları ürün diliyle yeniden yazılacak

### FE-3 Teacher Network onboarding aside

Öncelik:

- P1

İş:

- form yanında kalıcı "neden önemli?" açıklama paneli

### FE-4 Shared network action button component

Öncelik:

- P1

İş:

- profile
- explore
- networking hub

üzerindeki action butonları ortaklaştırılacak

### FE-5 Query-driven prefetch

Öncelik:

- P2

İş:

- profile -> teacher network geçişinde route prefetch

### FE-6 Skeleton system refinement

Öncelik:

- P1

İş:

- networking kartları için sabit yükseklikli skeleton

---

## 7. Backend Backlog

### BE-1 `GET /api/new/network/hub`

Öncelik:

- P0

Tanım:

- tek response içinde hub için gerekli ana payload

### BE-2 Networking module service split

Öncelik:

- P1

Tanım:

- `connectionService`
- `mentorshipService`
- `teacherNetworkService`
- `networkMetricsService`

### BE-3 Query portability cleanup

Öncelik:

- P0

Tanım:

- SQLite/Postgres ortak pattern standardizasyonu
- boş string timestamp fallback cleanup

### BE-4 Standard error contract

Öncelik:

- P0

Tanım:

- networking endpoint'lerinde JSON error standardı

### BE-5 Moderation metadata

Öncelik:

- P1

Tanım:

- teacher links için moderation review metadata

### BE-6 Bulk analytics endpoint

Öncelik:

- P2

Tanım:

- admin dashboard için cohort bazlı networking analytics

---

## 8. Data / Schema Backlog

### DB-1 `teacher_alumni_links` enrichment

Alan adayları:

- `created_via`
- `source_surface`
- `review_status`
- `reviewed_by`
- `reviewed_at`

### DB-2 summary table

Yeni tablo:

- `member_networking_daily_summary`

Alan adayları:

- `user_id`
- `date`
- `connections_sent`
- `connections_accepted`
- `mentorship_requested`
- `mentorship_accepted`
- `teacher_links_created`

### DB-3 moderation report table

Yeni tablo:

- `teacher_link_reports`

### DB-4 graph confidence derivation

Yeni alan veya derived materialization:

- `teacher_link_confidence_reason`

---

## 9. Test Backlog

### T-1 Aggregate hub contract test

Yeni test:

- `/api/new/network/hub`

### T-2 Teacher link deep-link flow test

Alan:

- `include_id`
- frontend integration smoke

### T-3 JSON error shape tests

Alan:

- verification gate
- invalid teacher target
- invalid class year
- duplicate request

### T-4 Postgres compatibility test pack

Alan:

- timestamp ordering
- empty string fallbacks
- nullable class_year uniqueness

### T-5 Suggestion trust badge regression tests

Alan:

- teacher network badge
- mentor badge
- verified alumni badge

---

## 10. Gözlemlenebilirlik ve Telemetri Backlog

### OBS-1 Networking event analytics

Event adayları:

- `network_connection_request_sent`
- `network_connection_request_accepted`
- `network_mentorship_request_sent`
- `network_teacher_link_created`
- `network_teacher_link_read`

### OBS-2 Latency tracking

İzlenecekler:

- hub load latency
- suggestion latency
- teacher options latency
- teacher link create latency

### OBS-3 Funnel dashboard

İzlenecek huni:

- request sent
- response received
- accepted
- time to first success

---

## 11. Sprint Önerisi

### Sprint A

- P0.1 aggregate endpoint tasarımı
- P0.2 frontend reducer
- P0.4 event/message standardizasyonu
- P0.5 JSON response standardı

### Sprint B

- P1.3 suggestion service split
- P1.2 confidence score işletilmesi
- FE-3 onboarding aside
- DB-1 enrichment

### Sprint C

- moderation/reporting
- summary table
- analytics dashboard

---

## 12. Teknik Başarı Kriterleri

Bu backlog'un başarılı sayılması için:

- hub ekranı daha az roundtrip ile yüklenmeli
- aksiyon sonrası full refetch ihtiyacı minimuma inmeli
- query portability sorunları bitmeli
- teacher graph moderasyonu güçlenmeli
- analytics karar üretir hale gelmeli

---

## 13. Sonuç

Networking Hub ve Teacher Network modülleri iyi bir ürün fikrine dayanıyor. Bundan sonraki teknik yatırımın ana amacı yeni özellik eklemekten çok mevcut mimariyi sadeleştirmek, hızlandırmak ve ölçeklenebilir hale getirmek olmalıdır.

Bu nedenle ilk faz teknik revizyonun odağı:

- aggregate data loading,
- state sadeleşmesi,
- query portability,
- tutarlı API sözleşmesi,
- graph kalite mekanizmaları

olmalıdır.

