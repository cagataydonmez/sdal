# Bildirim Sistemi Sprint 4 Execution Backlog

Bu doküman, [notifications-rebaseline-after-sprint3.md](/Users/cagataydonmez/Desktop/SDAL/docs/notifications-rebaseline-after-sprint3.md) içindeki yeni epikleri uygulanabilir backlog'a çevirir.

---

## 1. Epic Haritası

- `NR1`: Target Accuracy and Realtime
- `NR2`: Delivery Reliability and Performance
- `NR3`: Coverage Completion
- `NR4`: Preferences and Governance

---

## 2. Backlog

## EPIC `NR1` Target Accuracy and Realtime

### `NR1-S1` Wrong Target and Bounce Signals

Priority:

- `P0`

Tasks:

- notification open sonrası target landing metric modelini tanımla
- hızlı geri dönüş sinyalini belirle
- `no_action_after_open` sinyalini tanımla
- missing target context durumlarını logla
- dead target durumları için code/message standardı yaz

Definition of Done:

- yanlış hedefe giden veya bağlamsız açılan notification’lar ölçülebilir hale gelir

### `NR1-S2` Realtime Refresh Contract

Priority:

- `P0`

Tasks:

- `notification:new` emit edilen tüm ana noktaları inventory’ye bağla
- panel / page / unread badge refresh sırasını standardize et
- event gelmediğinde polling fallback davranışını yazılı contract haline getir
- optimistic unread update ile server refresh çakışmalarını azalt

Definition of Done:

- notification üretildiğinde panel, page ve badge yüzeyleri daha tutarlı yenilenir

### `NR1-S3` Toast and Inbox Coordination

Priority:

- `P1`

Tasks:

- high-value notification types için toast eligibility matrisi yaz
- toast click davranışını canonical target resolver ile bağla
- aynı olay için toast + inbox tekrarını sınırlayan kural ekle

Definition of Done:

- toast ve inbox birbirini bozmadan birlikte çalışır

---

## EPIC `NR2` Delivery Reliability and Performance

### `NR2-S1` Delivery Audit and Failure Visibility

Priority:

- `P1`

Tasks:

- addNotification başarısızlıkları için audit formatı tanımla
- critical type listesi çıkar
- insert failure / skip reason loglarını ekle
- retry gereksinimi varsa tasarım notu hazırla

Definition of Done:

- kritik notification insert/delivery problemleri görünür hale gelir

### `NR2-S2` Notification Query Hardening

Priority:

- `P1`

Tasks:

- unread counter query audit
- notifications listing query audit
- gerekli index veya query order iyileştirmelerini tasarla
- actionable-first listeleme davranışını data katmanında netleştir

### `NR2-S3` Dedupe and Aggregation

Priority:

- `P1`

Tasks:

- like/comment burst için dedupe stratejisi
- repeated reminder collapse
- dedupe key şeması

### `NR2-S4` Admin Notification Ops Visibility

Priority:

- `P2`

Tasks:

- failure counts paneli
- unread aging paneli
- noisy types görünürlüğü
- telemetry surface conversion özeti

---

## EPIC `NR3` Coverage Completion

### `NR3-S1` Events Coverage Completion

Priority:

- `P1`

Tasks:

- `event_reminder` ve `event_starts_soon` type kararını netleştir
- reminder target behavior yaz
- RSVP state notification gereksinimini ürün açısından değerlendir
- event comment anchor/context bilgisini zenginleştir

### `NR3-S2` Groups Coverage Completion

Priority:

- `P1`

Tasks:

- group role changed notification
- moderation result notification
- reviewer context enrichment
- invite lifecycle refinement

### `NR3-S3` System Notifications

Priority:

- `P1`

Tasks:

- verification result notifications
- request resolution notifications
- announcement decision notifications
- moderation/system notice tipi standardı

---

## EPIC `NR4` Preferences and Governance

### `NR4-S1` User Preferences

Priority:

- `P2`

Tasks:

- category bazlı opt-in/opt-out modeli
- high-priority override kuralı
- quiet mode başlangıç şeması

### `NR4-S2` Governance Policy

Priority:

- `P2`

Tasks:

- yeni notification type checklist
- target zorunluluğu
- analytics zorunluluğu
- dedupe zorunluluğu

### `NR4-S3` Experiment Layer

Priority:

- `P2`

Tasks:

- sort order experiment
- CTA wording experiment
- grouped vs flat list experiment

---

## 3. Sprint 4 Önerisi

Bir sonraki implementasyon sprinti için önerilen kapsam:

1. `NR1-S1`
2. `NR1-S2`
3. `NR2-S1`

Bu sprint paketi şu sorunu hedefler:

- notification doğru yere mi götürüyor
- yeni notification anında görünür mü
- kritik notification başarısız olursa bunu görebiliyor muyuz

---

## 4. Definition of Ready

Bir story implementasyona alınmadan önce:

- hangi notification type veya surface’i etkilediği net olmalı
- target contract açık olmalı
- metric ve telemetry beklentisi yazılmış olmalı
- acceptance kriteri belirlenmiş olmalı

---

## 5. Definition of Done

Bir story tamamlanmış sayılmadan önce:

- backend contract uygulanmış olmalı
- frontend target consumption tamamlanmış olmalı
- gerekliyse telemetry ve audit bağlanmış olmalı
- ilgili contract test veya build doğrulaması geçmiş olmalı

---

## 6. Planlama Sonucu

Notification sistemi için bundan sonraki resmi sıra:

- önce `NR1`
- sonra `NR2`
- ardından `NR3`
- en son `NR4`

Bu backlog, bir sonraki implementasyon turunun resmi başlangıç noktasıdır.
