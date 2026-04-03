# SDAL Networking Hub & Teacher Network Re-Baseline and Phase 2 Plan

Bu doküman, ilk networking implementasyon backlog'unun mevcut durumunu yeniden bazlar ve bundan sonra izlenecek yeni planı tanımlar.

Referans dokümanlar:

- `docs/networking-hub-teacher-network-execution-backlog.md`
- `docs/networking-hub-teacher-network-phased-task-plan.md`
- `docs/networking-hub-teacher-network-playbook.md`

Bu dokümanın amacı:

- ilk planın nerede tamamlandığını netleştirmek,
- backlog drift oluşmasını engellemek,
- bundan sonraki işi yeni bir faz planına bağlamak,
- uygulama, deney, operasyon ve karar destek katmanlarını ayrılaştırmaktır.

---

## 1. Yönetici Kararı

Sonuç:

- ilk planın ana implementasyon omurgası büyük ölçüde tamamlandı,
- son sprintlerde yapılan işler artık ilk planın uzantısı niteliğinde ileri operasyonalizasyon işleri oldu,
- bu nedenle buradan sonra "aynı plana kör devam etmek" yerine yeni bir plan ile ilerlemek gerekir.

Kısa hüküm:

- `E0` tamamlandı
- `E1` büyük ölçüde tamamlandı, küçük UX açıklama ve hiyerarşi işleri kaldı
- `E2` tamamlandı
- `E3` tamamlandı
- `E4` tamamlandı
- `E5` çekirdek olarak tamamlandı, ancak evaluation ve operasyon otomasyonu katmanı yeni plan içinde ele alınmalı

---

## 2. Eski Planın Re-Baseline Durumu

| Epic | Durum | Not |
|---|---|---|
| `E0` Scope, terminology, measurement baseline | Tamamlandı | Dokümantasyon seti, phased plan, execution backlog ve sprint baseline üretildi |
| `E1` UX clarity and action prioritization | Büyük ölçüde tamamlandı | Priority strip, empty-state, helper text, Teacher Network value panel ve copy netliği geldi; daha derin CTA/badge education işi kalabilir |
| `E2` Networking Hub performance and state architecture | Tamamlandı | Aggregate bootstrap, reducer hook, optimistic update, response envelope, registry ve layout stability uygulandı |
| `E3` Teacher Network trust, quality and moderation | Tamamlandı | Audit trail, confidence scoring, duplicate prevention, moderation state machine, decision support ve admin review katmanı geldi |
| `E4` Analytics, telemetry and admin visibility | Tamamlandı | Telemetry, precomputed summary, admin visibility panel, alerts ve analytics yüzeyi kuruldu |
| `E5` Recommendation and graph evolution | Çekirdek tamamlandı | Suggestion engine extraction, experiment config, analytics, recommendations, apply, rollback, guardrails kuruldu |

---

## 3. Tamamlanan Başlıca Çıktılar

### Ürün ve UX

- Networking Hub daha hızlı, daha stabil ve daha açıklayıcı hale geldi
- Teacher Network ekranı ürün değeri açısından anlaşılır hale getirildi
- Empty-state, helper text ve action hierarchy kısmen iyileştirildi

### Backend ve Contract

- user-facing networking response shape standardize edildi
- aggregate hub bootstrap endpoint kuruldu
- Teacher Network veri modeli audit ve moderation alanlarıyla büyütüldü
- suggestion engine servis katmanına ayrıldı

### Analytics ve Operasyon

- networking telemetry event yapısı kuruldu
- daily summary precompute katmanı eklendi
- admin networking visibility panel ve anomaly alerts kuruldu
- recommendation experiment analytics, apply, rollback ve guardrail akışı eklendi

---

## 4. Eski Plandan Kalan veya Tam Kapanmayan Alanlar

### `E1` içinde kısmi kalanlar

- Member detail networking CTA hierarchy daha rafine hale getirilebilir
- trust badge anlamlarını kullanıcıya açıklayan katman daha görünür yapılabilir
- networking kavramlarının tüm yüzeylerde tam copy parity kontrolü yeniden yapılmalı

### `E5` içinde yeni operasyonalizasyon ihtiyacı

- applied recommendation gerçekten işe yaradı mı sorusuna cevap veren evaluation katmanı eksik
- recommendation history için before/after delta görünürlüğü eksik
- winner promotion, auto-suggest rebalance ve safety automation katmanı eksik

### Genel risk alanları

- analytics doğru olsa bile ürün kararına dönüşecek admin iş akışı henüz tam olgun değil
- experiment akışı backend olarak güçlü, fakat operatör deneyimi hâlâ temel seviyede
- residual UX tutarsızlıkları Explore, Member Detail ve diğer networking yüzeylerinde devam edebilir

---

## 5. Yeni Planın Amacı

Yeni plan artık şu soruya odaklanmalıdır:

"Kurulan networking sistemi nasıl sürekli optimize edilir, güvenli biçimde işletilir ve ürün kararına çevrilir?"

Bu nedenle yeni planın omurgası:

1. ölçüm ve evaluation,
2. operasyonel kontrol,
3. UX parity,
4. deney otomasyonu,
5. kapanış ve handoff

üzerinden kurulmalıdır.

---

## 6. Yeni Fazlar

### Faz P2-1: Stabilization and UX Parity

Amaç:

- ilk plan sonrası kalan UX boşluklarını kapatmak
- networking yüzeyleri arasında dil ve davranış tutarlılığı sağlamak

Kapsam:

- Member Detail CTA hierarchy refinement
- trust badge explanation layer
- Explore, Networking Hub, Teacher Network copy parity pass
- admin experiment panel microcopy ve state polish

Başarı kriteri:

- networking yüzeylerinde aynı kavram farklı anlamda kullanılmıyor olmalı
- admin panelde apply, rollback ve guardrail akışları yorum gerektirmeden anlaşılmalı

### Faz P2-2: Experiment Evaluation Layer

Amaç:

- uygulanan recommendation değişikliklerinin etkisini ölçmek

Kapsam:

- change log kayıtları için before/after metric snapshot
- apply sonrası delta hesabı
- variant-level improvement summary
- evaluation status: `insufficient_data`, `neutral`, `positive`, `negative`
- admin panelde change history altında delta görünümü

Başarı kriteri:

- her apply kaydı için etkisi okunabilir hale gelmeli
- operatör "hangi değişiklik işe yaradı?" sorusunu panelden cevaplayabilmeli

### Faz P2-3: Recommendation Ops and Safety Automation

Amaç:

- recommendation operasyonunu daha güvenli ve tekrarlanabilir hale getirmek

Kapsam:

- cooldown ve sample threshold parametrelerini config seviyesine taşıma
- winner promotion önerisi
- automatic rebalance suggestion
- apply notu veya operator note alanı
- rollback reason alanı
- conflict detection: yakın aralıkta birden fazla apply engeli

Başarı kriteri:

- apply/rollback zinciri denetlenebilir ve anlaşılır olmalı
- recommendation operasyonu kişisel hafızaya değil sistem kurallarına dayanmalı

### Faz P2-4: Cohort and Surface Expansion

Amaç:

- recommendation ve analytics akışını daha hedefli kullanmak

Kapsam:

- cohort bazlı recommendation görünümü
- surface bazlı attribution karşılaştırması
- Explore ve Hub suggestion kalite farkı analizi
- Teacher Network sinyalini suggestion kalitesiyle daha net bağlama

Başarı kriteri:

- hangi yüzeyin hangi cohort için daha iyi çalıştığı görülebilmeli
- recommendation tuning sadece global değil segment bazlı da yapılabilmeli

### Faz P2-5: Product Closure and Handoff

Amaç:

- bu alanı geçici sprint işinden kalıcı ürün modülüne çevirmek

Kapsam:

- final technical write-up
- admin/operator runbook
- QA regression checklist
- product metric ownership sheet
- next-quarter roadmap proposal

Başarı kriteri:

- başka bir ekip üyesi bu sistemi okuyup işletebilir durumda olmalı
- networking alanı için kapanış ve devam planı tek pakette bulunmalı

---

## 7. Yeni Epic Yapısı

### `N1` UX Parity and Clarity Closure

Story set:

- `N1-S1` Member Detail CTA hierarchy cleanup
- `N1-S2` Trust badge education layer
- `N1-S3` Networking copy parity review
- `N1-S4` Admin panel clarity pass

### `N2` Experiment Evaluation

Story set:

- `N2-S1` Apply history delta model
- `N2-S2` Before/after metric snapshot rendering
- `N2-S3` Recommendation outcome labeling
- `N2-S4` Experiment evaluation summary endpoint

### `N3` Recommendation Ops Automation

Story set:

- `N3-S1` Guardrail config externalization
- `N3-S2` Winner promotion recommendation
- `N3-S3` Rebalance recommendation engine
- `N3-S4` Operator note and audit enrichment

### `N4` Segment and Surface Intelligence

Story set:

- `N4-S1` Cohort-specific experiment view
- `N4-S2` Surface-specific conversion comparison
- `N4-S3` Teacher signal impact analytics

### `N5` Closure and Handoff

Story set:

- `N5-S1` QA regression pack
- `N5-S2` Operator runbook
- `N5-S3` Final system architecture addendum
- `N5-S4` Quarterly roadmap draft

---

## 8. Önerilen Uygulama Sırası

### Wave A

- `N2-S1`
- `N2-S2`
- `N2-S3`

Gerekçe:

- artık en kritik açık "ölçüm var ama etkisinin yorumu eksik" problemidir

### Wave B

- `N1-S1`
- `N1-S2`
- `N1-S3`

Gerekçe:

- kullanıcı ve admin yüzeylerinde kalan açıklık sorunları kapatılmalı

### Wave C

- `N3-S1`
- `N3-S2`
- `N3-S3`

Gerekçe:

- recommendation operasyonu sistematik hale getirilmeli

### Wave D

- `N4-S1`
- `N4-S2`
- `N4-S3`

Gerekçe:

- optimizasyon segment bazına taşınmalı

### Wave E

- `N5-S1`
- `N5-S2`
- `N5-S3`
- `N5-S4`

Gerekçe:

- ürün hattı sürdürülebilir ownership modeline geçirilmeli

---

## 9. Hemen Sonraki Mantıklı Sprint

Yeni plan için en doğru ilk sprint:

- `N2-S1` Apply history delta model
- `N2-S2` Before/after metric snapshot rendering
- `N1-S1` Member Detail CTA hierarchy cleanup

Bu kombinasyonun nedeni:

- biri operasyonel değerlendirme boşluğunu kapatır,
- diğeri kullanıcı yüzündeki son netlik açıklarını azaltır,
- yeni planın hem teknik hem ürün tarafında sağlam başladığını gösterir.

---

## 10. Karar

Bu noktadan sonra doğru yaklaşım:

- eski execution backlog'u "çekirdek implementasyon tamamlandı" olarak kabul etmek,
- bundan sonrasını bu yeni plan altında yürütmek,
- yeni işleri `N1`–`N5` epiklerine bağlamaktır.

Bu doküman, networking alanı için yeni resmi çalışma başlangıç noktası olarak kullanılmalıdır.
