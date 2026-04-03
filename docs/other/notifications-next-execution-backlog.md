# Bildirim Sistemi Next Execution Backlog

Bu doküman, [notifications-rebaseline-after-sprint2.md](/Users/cagataydonmez/Desktop/SDAL/docs/notifications-rebaseline-after-sprint2.md) içindeki yeni epikleri uygulanabilir backlog'a çevirir.

---

## 1. Yeni Epic Haritası

- `NN1`: Coverage Expansion
- `NN2`: Realtime and Telemetry
- `NN3`: Reliability and Performance
- `NN4`: Preferences and Governance

---

## 2. Backlog

## EPIC `NN1` Coverage Expansion

### `NN1-S1` Networking Coverage Completion

Priority:

- `P0`

Tasks:

- `mentorship_declined` notification ürün kararını netleştir
- teacher link moderation sonuç eventlerini tanımla
- `teacher_link_review_confirmed` notification ekle
- `teacher_link_review_flagged` notification ekle
- review-result target resolver ekle
- member detail ve network hub landing message’lerini yeni type’larla genişlet

Definition of Done:

- teacher link moderation sonuçları kullanıcılara görünür
- networking coverage matrisi güncel

### `NN1-S2` Jobs Status Notifications

Priority:

- `P0`

Tasks:

- job application status state modelini tanımla
- applicant decision notifications ekle
- poster tarafında result mutation eventleri tasarla
- jobs page target context’ini status sonucuna göre genişlet

Definition of Done:

- job application lifecycle sadece apply anıyla sınırlı değil

### `NN1-S3` Events Reminder Coverage

Priority:

- `P1`

Tasks:

- event reminder policy yaz
- `starts_soon` notification eventi tanımla
- event RSVP change notification gereksinimini karar altına al
- events page focus state’ini reminder akışına bağla

### `NN1-S4` Groups Coverage Completion

Priority:

- `P1`

Tasks:

- role changed event tasarla
- moderation result notification ekle
- group invite lifecycle’ı daha net notification state’lerine ayır

### `NN1-S5` System Notifications

Priority:

- `P1`

Tasks:

- verification result notifications
- support/request resolution notifications
- announcement decision notifications

---

## EPIC `NN2` Realtime and Telemetry

### `NN2-S1` Notification Telemetry Foundation

Priority:

- `P0`

Tasks:

- impression telemetry
- open telemetry
- action telemetry
- per-type conversion metric mapping
- per-surface metric mapping

Definition of Done:

- notification kullanımı okunabilir hale gelir

### `NN2-S2` Wrong Target and Bounce Signals

Priority:

- `P1`

Tasks:

- open sonrası kısa sürede geri dönme sinyali
- no-action-after-open sinyali
- dead target / missing context logging

### `NN2-S3` Realtime Refresh Contract

Priority:

- `P1`

Tasks:

- `notification:new` emit noktalarını bağla
- panel/page/badge refresh contract’ini standardize et
- polling fallback kurallarını yaz

### `NN2-S4` Toast and Inbox Coordination

Priority:

- `P1`

Tasks:

- toast surface tasarla
- toast click target contract’i bağla
- duplicate toast/inbox fatigue kontrolü ekle

---

## EPIC `NN3` Reliability and Performance

### `NN3-S1` Delivery Failure Audit

Priority:

- `P1`

Tasks:

- failed notification insert logları
- critical type’lar için audit trail
- enqueue/retry gereksinimini doğrula

### `NN3-S2` Query Hardening

Priority:

- `P1`

Tasks:

- unread counter query audit
- listing index audit
- category/priority filtre query optimizasyonu

### `NN3-S3` Dedupe and Aggregation

Priority:

- `P1`

Tasks:

- like/comment burst dedupe
- repeated reminder collapse
- dedupe key standardı

### `NN3-S4` Admin Notification Ops Visibility

Priority:

- `P2`

Tasks:

- notification ops metrics
- unread aging
- failed deliveries
- noisy types paneli

---

## EPIC `NN4` Preferences and Governance

### `NN4-S1` User Preferences

Priority:

- `P2`

Tasks:

- category bazlı preference modeli
- high priority override policy
- quiet mode foundation

### `NN4-S2` Governance Policy

Priority:

- `P2`

Tasks:

- yeni type checklist
- target zorunluluğu
- analytics zorunluluğu
- dedupe standardı

### `NN4-S3` Experiment Layer

Priority:

- `P2`

Tasks:

- sort order experiment
- CTA wording experiment
- grouped vs flat list experiment

---

## 3. Yeni İlk Sprint Önerisi

Bir sonraki implementasyon sprinti için önerilen kapsam:

1. `NN1-S1`
2. `NN1-S2`
3. `NN2-S1`

Bu sıranın nedeni:

- coverage eksikleri hemen kullanıcı etkisi üretir
- telemetry foundation olmadan sonraki kalite kararları kör kalır

---

## 4. Planlama Sonucu

Eski notification backlog’un foundation ve core UX bölümü kapalıdır.

Bundan sonraki resmi implementasyon sırası:

- önce `NN1`
- sonra `NN2`
- ardından `NN3`
- en son `NN4`

olmalıdır.
