# Bildirim Sistemi Rebaseline After Sprint 3

## 1. Amaç

Bu doküman, notification sistemi için son sprintte tamamlanan coverage ve telemetry foundation işlerinden sonra kalan işi yeniden önceliklendirmek için hazırlanmıştır.

Bu aşamada:

- core inbox ve panel deneyimi tamamlandı
- networking moderation ve jobs decision coverage kapandı
- notification telemetry foundation kuruldu

Bundan sonraki ana ihtiyaç artık yeni type eklemekten çok:

- hedef doğruluğunu ölçmek
- realtime davranışı standardize etmek
- delivery güvenilirliğini artırmak
- kalan coverage alanlarını tamamlamaktır

---

## 2. Tamamlanan Kapsam

### Daha önce tamamlanan alanlar

- notification inventory
- canonical target resolver
- category / priority modeli
- per-item read / open modeli
- full inbox bilgi mimarisi
- compact panel redesign
- inline action sistemi
- deep-link consumption

### Son sprintte tamamlanan alanlar

- `NN1-S1` Networking coverage completion
- `NN1-S2` Jobs status notifications
- `NN2-S1` Notification telemetry foundation

### Son sprint kazanımları

- teacher network moderasyon sonuçları artık notification üretiyor
- teacher review notification tıklanınca teacher network ekranında doğru kayda iniliyor
- jobs apply lifecycle artık `pending / reviewed / accepted / rejected` taşıyor
- applicant tarafında result notification ve “my application” deep-link akışı çalışıyor
- notification telemetry için `impression / open / action` eventleri kaydoluyor
- panel ve full inbox surface ayrımı telemetry içinde görünür hale geldi

---

## 3. Yeni Durum Özeti

Sistem artık işlevsel bir notification ürünü haline gelmiştir.

Ancak kalan ana kalite boşlukları şunlardır:

- notification açıldıktan sonra hedefin gerçekten işe yarayıp yaramadığını bilmiyoruz
- realtime propagation hâlâ tam standart değil
- kritik bildirim insert/delivery başarısızlıkları için operasyon görünürlüğü zayıf
- events, groups ve system notification coverage hâlâ eksik

Bu yüzden yeni resmi öncelik sırası coverage’den çok doğruluk ve güvenilirlik merkezlidir.

---

## 4. Yeni Epic Çerçevesi

Bu rebaseline sonrasında önerilen epikler:

- `NR1`: Target Accuracy and Realtime
- `NR2`: Delivery Reliability and Performance
- `NR3`: Coverage Completion
- `NR4`: Preferences and Governance

---

## 5. Yeni Önceliklendirme

## `NR1` Target Accuracy and Realtime

Amaç:

- notification açılışından sonra doğru hedefe inildiğini ölçmek
- inbox, badge, panel ve toast davranışını ortak contract altında toplamak

### `NR1-S1` Wrong Target and Bounce Signals

Öncelik:

- `P0`

Kapsam:

- open sonrası kısa geri dönüş sinyali
- open sonrası aksiyonsuz kalma sinyali
- target resolution success/failure kaydı
- dead target ve missing-context tespiti

### `NR1-S2` Realtime Refresh Contract

Öncelik:

- `P0`

Kapsam:

- `notification:new` emit noktalarını standartlaştır
- panel / page / unread badge refresh sırasını netleştir
- polling fallback ile event-based refresh dengesini kur

### `NR1-S3` Toast and Inbox Coordination

Öncelik:

- `P1`

Kapsam:

- toast surface tasarımı
- toast click target contract
- duplicate toast / inbox fatigue kontrolü

---

## `NR2` Delivery Reliability and Performance

Amaç:

- notification ekleme, listeleme ve okunmamış sayaç tarafını daha güvenilir hale getirmek

### `NR2-S1` Delivery Audit and Failure Visibility

Öncelik:

- `P1`

Kapsam:

- critical notification insert audit
- failure log standardı
- gerekiyorsa enqueue / retry tasarım kararı

### `NR2-S2` Notification Query Hardening

Öncelik:

- `P1`

Kapsam:

- unread counter query audit
- listing query index audit
- actionable-first listeleme optimizasyonu

### `NR2-S3` Dedupe and Aggregation

Öncelik:

- `P1`

Kapsam:

- like/comment burst collapse
- repeated reminder collapse
- low-value repetitive events için dedupe key standardı

### `NR2-S4` Admin Notification Ops Visibility

Öncelik:

- `P2`

Kapsam:

- unread aging
- failure counts
- noisy notification types
- surface conversion özeti

---

## `NR3` Coverage Completion

Amaç:

- kalan ürün yüzeylerinde notification kapsamını tamamlamak

### `NR3-S1` Events Coverage Completion

Öncelik:

- `P1`

Kapsam:

- event reminder
- event starts soon
- RSVP state transition değeri
- comment anchor/context zenginleştirme

### `NR3-S2` Groups Coverage Completion

Öncelik:

- `P1`

Kapsam:

- role changed
- moderation result
- reviewer context
- invite lifecycle refinement

### `NR3-S3` System Notifications

Öncelik:

- `P1`

Kapsam:

- verification approved/rejected
- request resolution
- moderation/system notices
- announcement decision notifications

---

## `NR4` Preferences and Governance

Amaç:

- notification sistemini uzun vadede yönetilebilir hale getirmek

### `NR4-S1` User Preferences

Öncelik:

- `P2`

Kapsam:

- category bazlı preferences
- high-priority override
- quiet mode foundation

### `NR4-S2` Governance Policy

Öncelik:

- `P2`

Kapsam:

- yeni type checklist
- target zorunluluğu
- analytics zorunluluğu
- dedupe standardı

### `NR4-S3` Experiment Layer

Öncelik:

- `P2`

Kapsam:

- sort order experiment
- CTA wording experiment
- grouped vs flat list experiment

---

## 6. Yeni Sprint Önerisi

Bir sonraki implementasyon sprinti için önerilen kapsam:

1. `NR1-S1`
2. `NR1-S2`
3. `NR2-S1`

Bu sıranın nedeni:

- telemetry kuruldu, şimdi kalite sinyali üretmek gerekiyor
- realtime contract oturmadan UX sorunları devam eder
- delivery audit olmadan kritik notification hataları görünmez kalır

---

## 7. Planlama Sonucu

Bu aşamada notification sistemi için:

- foundation tamamlandı
- core UX tamamlandı
- networking/jobs high-value coverage tamamlandı
- telemetry foundation tamamlandı

Bundan sonraki resmi iş sırası:

- önce `NR1`
- sonra `NR2`
- ardından `NR3`
- en son `NR4`

olmalıdır.
