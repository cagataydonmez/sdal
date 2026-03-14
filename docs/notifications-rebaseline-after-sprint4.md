# Bildirim Sistemi Rebaseline After Sprint 4

## 1. Amaç

Bu doküman, notification sistemi için target accuracy, realtime refresh contract ve delivery audit sprintinden sonra kalan işi yeniden önceliklendirmek için hazırlanmıştır.

Bu aşamada:

- landing doğruluğu ölçülüyor
- cross-tab ve cross-surface live refresh contract kuruldu
- kritik notification insert/delivery audit kaydı oluşuyor

Dolayısıyla bundan sonraki ana ihtiyaç artık temel notification doğruluğunu kurmak değil:

- performans ve query sertleştirmesi
- toast/inbox koordinasyonu
- events / groups / system coverage tamamlama
- admin visibility ve preferences katmanına geçiştir

---

## 2. Tamamlanan Kapsam

### Önceki sprintlerden gelen tamamlanmış alanlar

- notification inventory
- canonical target resolver
- enriched payload contract
- per-item read/open modeli
- reusable inbox card system
- compact panel redesign
- networking moderation notifications
- jobs decision notifications
- telemetry foundation

### Son sprintte tamamlanan alanlar

- `NR1-S1` Wrong target and bounce signals
- `NR1-S2` Realtime refresh contract
- `NR2-S1` Delivery audit and failure visibility

### Son sprint kazanımları

- notification landing artık `landed / bounce / no_action` sinyalleriyle ölçülebiliyor
- notification query param kullanan ana yüzeylerde target resolution görünür hale geldi
- `notification:new` event’i cross-tab ve cross-surface yayılabiliyor
- layout, inbox page ve compact panel yeni notification tespitini ortak event bus’a taşıyor
- kritik notification insert’leri için audit trail oluşuyor

---

## 3. Yeni Durum Özeti

Notification sistemi artık ürün doğruluğu açısından daha güvenilir bir aşamaya geçti.

Kalan ana boşluklar:

- unread ve list query tarafında performans sertleştirmesi eksik
- toast katmanı ile inbox katmanı henüz koordineli değil
- events, groups ve system notification coverage eksik
- admin tarafında notification operations görünürlüğü sınırlı

Bu yüzden yeni resmi öncelik sırası:

- önce performance ve UX coordination
- sonra coverage completion
- ardından ops visibility
- en son preferences / governance

---

## 4. Yeni Epic Çerçevesi

Bu rebaseline sonrası önerilen epikler:

- `NS1`: Performance and UX Coordination
- `NS2`: Coverage Completion
- `NS3`: Ops Visibility
- `NS4`: Preferences and Governance

---

## 5. Yeni Önceliklendirme

## `NS1` Performance and UX Coordination

Amaç:

- notification sistemini daha hızlı, daha sakin ve daha tutarlı hale getirmek

### `NS1-S1` Notification Query Hardening

Öncelik:

- `P0`

Kapsam:

- unread counter query audit
- notifications list query audit
- gerekli index ve order optimizasyonu
- actionable-first davranışın veri katmanında netleştirilmesi

### `NS1-S2` Toast and Inbox Coordination

Öncelik:

- `P0`

Kapsam:

- hangi notification type’ların toast göstereceğini netleştir
- toast click target contract
- duplicate toast/inbox fatigue kontrolü
- high-value signal önceliği

### `NS1-S3` Dedupe and Aggregation

Öncelik:

- `P1`

Kapsam:

- like/comment burst collapse
- repeated reminder collapse
- repetitive low-value events için dedupe standardı

---

## `NS2` Coverage Completion

Amaç:

- kalan ürün yüzeylerindeki notification boşluklarını kapatmak

### `NS2-S1` Events Coverage Completion

Öncelik:

- `P1`

Kapsam:

- event reminder
- event starts soon
- RSVP transition değeri
- event comment anchor/context zenginleştirme

### `NS2-S2` Groups Coverage Completion

Öncelik:

- `P1`

Kapsam:

- role changed
- moderation result
- reviewer context
- invite lifecycle refinement

### `NS2-S3` System Notifications

Öncelik:

- `P1`

Kapsam:

- verification approved/rejected
- request resolution
- moderation/system notices
- announcement decision notifications

---

## `NS3` Ops Visibility

Amaç:

- notification sistemini admin ve product ops açısından görünür hale getirmek

### `NS3-S1` Admin Notification Ops Visibility

Öncelik:

- `P1`

Kapsam:

- unread aging
- failed delivery counts
- noisy notification types
- surface conversion özeti

### `NS3-S2` Alerting Thresholds

Öncelik:

- `P2`

Kapsam:

- abnormal bounce rate
- abnormal no-action rate
- failed critical insert eşiği

---

## `NS4` Preferences and Governance

Amaç:

- notification sistemini sürdürülebilir ve yönetilebilir hale getirmek

### `NS4-S1` User Preferences

Öncelik:

- `P2`

Kapsam:

- category bazlı preference modeli
- high-priority override
- quiet mode foundation

### `NS4-S2` Governance Policy

Öncelik:

- `P2`

Kapsam:

- yeni type checklist
- target zorunluluğu
- analytics zorunluluğu
- dedupe zorunluluğu

### `NS4-S3` Experiment Layer

Öncelik:

- `P2`

Kapsam:

- sort order experiment
- CTA wording experiment
- grouped vs flat list experiment

---

## 6. Yeni Sprint Önerisi

Bir sonraki implementasyon sprinti için önerilen kapsam:

1. `NS1-S1`
2. `NS1-S2`
3. `NS2-S1`

Bu sıranın nedeni:

- performance sertleşmeden notification yüzeyleri büyüdükçe maliyet artar
- toast koordinasyonu olmadan UX parçalı kalır
- event reminder coverage ürün değeri üretir ama önce altyapı sakinleşmelidir

---

## 7. Planlama Sonucu

Bu aşamada notification sistemi için:

- foundation tamamlandı
- target doğruluğu ölçülebilir hale geldi
- realtime refresh contract kuruldu
- delivery audit tabanı oluştu

Bundan sonraki resmi sıra:

- önce `NS1`
- sonra `NS2`
- ardından `NS3`
- en son `NS4`

olmalıdır.
