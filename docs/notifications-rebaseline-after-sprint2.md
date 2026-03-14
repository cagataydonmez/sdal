# Bildirim Sistemi Rebaseline After Sprint 2

## 1. Amaç

Bu doküman, notification sistemi için tamamlanan ilk iki sprintten sonra kalan işi yeniden önceliklendirmek için hazırlanmıştır.

Bu aşamada:

- foundation tamamlandı
- core inbox UX tamamlandı
- bundan sonrası coverage, realtime, analytics ve governance odaklıdır

Bu nedenle eski backlog olduğu gibi devam ettirilmek yerine yeni bir yürütme sırası tanımlanmıştır.

---

## 2. Tamamlanan Kapsam

### Sprint A tamamlanan işler

- `NTF0-S1` Notification type inventory
- `NTF0-S2` Canonical routing matrix
- `NTF0-S3` Category and priority model
- `NTF1-S1` Frontend notification registry
- `NTF1-S2` Backend enriched notification payload
- `NTF1-S3` Per-item read / open model
- `NTF1-S4` Deep-link state consumption

### Sprint B tamamlanan işler

- `NTF2-S1` Full inbox information architecture
- `NTF2-S2` Notification card system
- `NTF2-S4` Inline actions
- `NTF2-S6` Compact panel redesign

### Mevcut kazanımlar

- notification target resolver tek yerde
- bildirimler artık type-derived `category`, `priority`, `target`, `actions` ile dönüyor
- per-item `open` ve `read` modeli kuruldu
- notification page kör bulk-read davranışından çıktı
- global inbox ve compact panel ortak kart dili kullanıyor
- groups / events / jobs / networking / member detail deep-link tüketimi çalışıyor
- core actionable notifications inline yönetilebilir hale geldi

---

## 3. Kalan Ana Temalar

Bu aşamadan sonra kalan iş dört ana hatta ayrılıyor:

### Hat 1. Coverage expansion

Eksik notification aileleri tamamlanacak.

### Hat 2. Realtime and quality signals

Notification sadece listelenmeyecek, daha canlı ve ölçülebilir hale gelecek.

### Hat 3. Delivery reliability and performance

Load, unread counter ve event propagation daha sağlam hale gelecek.

### Hat 4. Preferences and governance

Sistem uzun vadede yönetilebilir hale getirilecek.

---

## 4. Yeni Epic Çerçevesi

Yeni rebaseline sonrası önerilen epikler:

- `NN1`: Coverage Expansion
- `NN2`: Realtime and Telemetry
- `NN3`: Reliability and Performance
- `NN4`: Preferences and Governance

---

## 5. Yeni Önceliklendirme

## `NN1` Coverage Expansion

Amaç:

- Bildirim sistemi ürün kapsamını eksik olaylar açısından tamamlamak

### `NN1-S1` Networking Coverage Completion

Öncelik:

- `P0`

Kapsam:

- `mentorship_declined` gerekip gerekmediğini netleştir
- `teacher_link_review_confirmed`
- `teacher_link_review_flagged`
- teacher link review sonucu için doğru hedef davranışı
- connection accepted sonrası daha net CTA dili

Neden önce:

- networking şu an en yoğun yeni sistem alanı
- moderasyon ve trust graph akışları hâlâ eksik notification coverage taşıyor

### `NN1-S2` Jobs Status Notifications

Öncelik:

- `P0`

Kapsam:

- application status update eventleri
- poster tarafında applications queue refinement
- applicant tarafında decision/result notifications

### `NN1-S3` Events Coverage Completion

Öncelik:

- `P1`

Kapsam:

- event reminder
- event starts soon
- RSVP state değişimlerinin notification değeri
- event comment anchor/context zenginleştirme

### `NN1-S4` Groups Coverage Completion

Öncelik:

- `P1`

Kapsam:

- role changed
- moderation result
- request reviewer context
- invitation lifecycle refinement

### `NN1-S5` System Notifications

Öncelik:

- `P1`

Kapsam:

- verification approved/rejected
- request resolution
- moderation/system notices
- announcement decision notifications

---

## `NN2` Realtime and Telemetry

Amaç:

- Bildirimlerin canlılık ve kalite ölçümü tarafını güçlendirmek

### `NN2-S1` Notification Impression / Open / Action Telemetry

Öncelik:

- `P0`

Kapsam:

- impression event
- open event
- action event
- per-type conversion
- per-surface conversion

### `NN2-S2` Wrong Target / Bounce Signals

Öncelik:

- `P1`

Kapsam:

- open sonrası hızlı back / no-action signal
- target resolution success/failure
- dead target analizi

### `NN2-S3` Realtime Refresh Contract

Öncelik:

- `P1`

Kapsam:

- `notification:new` emission standardı
- toast / badge / panel / page koordinasyonu
- polling ile event-based refresh dengesini kurma

### `NN2-S4` Toast + Inbox Coordination

Öncelik:

- `P1`

Kapsam:

- sayfa üstü lightweight notification toasts
- toast -> target navigation
- duplicate fatigue kontrolü

---

## `NN3` Reliability and Performance

Amaç:

- Bildirim sistemini daha güvenilir ve ölçeklenebilir hale getirmek

### `NN3-S1` Delivery Audit and Failure Visibility

Öncelik:

- `P1`

Kapsam:

- silent failure tespiti
- critical notification insert logları
- gerekiyorsa enqueue/retry tasarımı

### `NN3-S2` Notification Query Hardening

Öncelik:

- `P1`

Kapsam:

- listing query indexleri
- unread counter optimizasyonu
- actionable-first query stratejisi

### `NN3-S3` Dedupe and Aggregation

Öncelik:

- `P1`

Kapsam:

- like/comment burst collapse
- reminder grouping
- repetitive low-value events için dedupe key standardı

### `NN3-S4` Admin Notification Ops Visibility

Öncelik:

- `P2`

Kapsam:

- type volume
- unread aging
- noisy types
- failed deliveries

---

## `NN4` Preferences and Governance

Amaç:

- Sistemi ürünleşmiş ve sürdürülebilir hale getirmek

### `NN4-S1` User Notification Preferences

Öncelik:

- `P2`

Kapsam:

- category bazlı opt-in/opt-out
- high-priority override policy
- quiet mode foundation

### `NN4-S2` New Notification Type Governance

Öncelik:

- `P2`

Kapsam:

- naming convention
- target zorunluluğu
- analytics zorunluluğu
- dedupe policy

### `NN4-S3` Experiment Layer

Öncelik:

- `P2`

Kapsam:

- sort experiments
- CTA wording tests
- grouped vs flat list learning

---

## 6. Yeni Sprint Sırası

## Sprint C

Odak:

- coverage expansion başlangıcı

Önerilen kapsam:

- `NN1-S1`
- `NN1-S2`
- `NN2-S1`

Beklenen çıktı:

- networking ve jobs için eksik coverage kapanır
- notification kalitesi ölçülmeye başlanır

## Sprint D

Odak:

- realtime ve güvenilirlik

Önerilen kapsam:

- `NN2-S3`
- `NN2-S4`
- `NN3-S1`
- `NN3-S2`

Beklenen çıktı:

- canlılık artar
- delivery ve refresh daha güvenilir hale gelir

## Sprint E

Odak:

- system coverage ve dedupe

Önerilen kapsam:

- `NN1-S3`
- `NN1-S4`
- `NN1-S5`
- `NN3-S3`

## Sprint F

Odak:

- governance ve ops

Önerilen kapsam:

- `NN3-S4`
- `NN4-S1`
- `NN4-S2`
- `NN4-S3`

---

## 7. Yeni Resmi Başlangıç Önerisi

Bir sonraki implementasyon turu için en doğru başlangıç:

1. `NN1-S1`
2. `NN1-S2`
3. `NN2-S1`

Yani:

- eksik networking notification coverage
- jobs result/status notification coverage
- telemetry foundation

Bu üçlü, mevcut inbox UX yatırımının gerçek ürün değerini belirgin biçimde artırır.

---

## 8. Karar

Bu rebaseline’a göre eski backlog’un ilk iki sprinti kapalı kabul edilmelidir.

Bundan sonra resmi yürütme çizgisi:

- `NN1`
- `NN2`
- `NN3`
- `NN4`

şeklinde devam etmelidir.
