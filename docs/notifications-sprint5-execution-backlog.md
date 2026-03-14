# Bildirim Sistemi Sprint 5 Execution Backlog

Bu doküman, [notifications-rebaseline-after-sprint4.md](/Users/cagataydonmez/Desktop/SDAL/docs/notifications-rebaseline-after-sprint4.md) içindeki yeni epikleri uygulanabilir backlog'a çevirir.

---

## 1. Epic Haritası

- `NS1`: Performance and UX Coordination
- `NS2`: Coverage Completion
- `NS3`: Ops Visibility
- `NS4`: Preferences and Governance

---

## 2. Backlog

## EPIC `NS1` Performance and UX Coordination

### `NS1-S1` Notification Query Hardening

Priority:

- `P0`

Tasks:

- unread counter query maliyetini ölç
- notifications listing query planını incele
- gerekiyorsa index ve order stratejisini güncelle
- actionable-first listeleme kuralını data katmanında sabitle
- polling sonrası gereksiz ikinci refresh tetiklerini azalt

Definition of Done:

- unread counter ve inbox listing daha düşük maliyetle çalışır

### `NS1-S2` Toast and Inbox Coordination

Priority:

- `P0`

Tasks:

- high-value notification toast eligibility matrisi oluştur
- toast surface component tasarla
- toast click davranışını canonical target resolver ile bağla
- aynı notification için toast + inbox tekrarını sınırlayan kural ekle

Definition of Done:

- toast ve inbox birlikte çalışır, UX gürültüsü azalır

### `NS1-S3` Dedupe and Aggregation

Priority:

- `P1`

Tasks:

- like/comment burst dedupe stratejisi
- repeated reminder collapse
- low-value repetitive eventler için dedupe key standardı

---

## EPIC `NS2` Coverage Completion

### `NS2-S1` Events Coverage Completion

Priority:

- `P1`

Tasks:

- `event_reminder` ve `event_starts_soon` type kararını netleştir
- reminder target behavior yaz
- RSVP transition notification gereksinimini ürün bazında doğrula
- event comment anchor/context bilgisini güçlendir

Definition of Done:

- events yüzeyinde yüksek değerli notification boşlukları kapanır

### `NS2-S2` Groups Coverage Completion

Priority:

- `P1`

Tasks:

- group role changed notification
- moderation result notification
- reviewer context enrichment
- invite lifecycle refinement

### `NS2-S3` System Notifications

Priority:

- `P1`

Tasks:

- verification result notifications
- request resolution notifications
- announcement decision notifications
- moderation/system notice tipi standardı

---

## EPIC `NS3` Ops Visibility

### `NS3-S1` Admin Notification Ops Visibility

Priority:

- `P1`

Tasks:

- failure counts paneli
- unread aging görünümü
- noisy notification types paneli
- surface conversion özeti

### `NS3-S2` Alerting Thresholds

Priority:

- `P2`

Tasks:

- bounce rate alert eşiği
- no-action rate alert eşiği
- failed critical insert alert eşiği

---

## EPIC `NS4` Preferences and Governance

### `NS4-S1` User Preferences

Priority:

- `P2`

Tasks:

- category bazlı opt-in/opt-out modeli
- high-priority override kuralı
- quiet mode başlangıç şeması

### `NS4-S2` Governance Policy

Priority:

- `P2`

Tasks:

- yeni notification type checklist
- target zorunluluğu
- analytics zorunluluğu
- dedupe zorunluluğu

### `NS4-S3` Experiment Layer

Priority:

- `P2`

Tasks:

- sort order experiment
- CTA wording experiment
- grouped vs flat list experiment

---

## 3. Sprint 5 Önerisi

Bir sonraki implementasyon sprinti için önerilen kapsam:

1. `NS1-S1`
2. `NS1-S2`
3. `NS2-S1`

Bu sprint paketi şu sorunu hedefler:

- notification yüzeyi yük altında daha hızlı olsun
- toast ve inbox birbirini tamamlasın
- event notification coverage ürün açısından görünür değer üretsin

---

## 4. Definition of Ready

Bir story implementasyona alınmadan önce:

- etkileyeceği notification type veya surface net olmalı
- target contract açık olmalı
- telemetry veya performance beklentisi yazılmış olmalı
- kabul kriteri belirlenmiş olmalı

---

## 5. Definition of Done

Bir story tamamlanmış sayılmadan önce:

- backend contract uygulanmış olmalı
- frontend surface tüketimi tamamlanmış olmalı
- gerekiyorsa telemetry / audit / perf etkisi doğrulanmış olmalı
- ilgili test veya build doğrulaması geçmiş olmalı

---

## 6. Planlama Sonucu

Notification sistemi için bundan sonraki resmi sıra:

- önce `NS1`
- sonra `NS2`
- ardından `NS3`
- en son `NS4`

Bu backlog, bir sonraki implementasyon turunun resmi başlangıç noktasıdır.
