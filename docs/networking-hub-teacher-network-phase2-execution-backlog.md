# SDAL Networking Hub & Teacher Network Phase 2 Execution Backlog

Bu doküman, re-baseline sonrası networking alanı için yeni resmi execution backlog'dur.

Referans dokümanlar:

- `docs/networking-hub-teacher-network-rebaseline-phase2-plan.md`
- `docs/networking-hub-teacher-network-execution-backlog.md`
- `docs/networking-hub-teacher-network-playbook.md`

Amaç:

- yeni planı `epic > story > task` seviyesinde uygulanabilir backlog'a çevirmek,
- bundan sonraki implementasyonların hangi epik altında yapılacağını netleştirmek,
- artık tamamlanan eski backlog ile yeni backlog'u karıştırmamaktır.

Bu doküman eski execution backlog'un yerini almaz. Eski backlog referans olarak kalır. Ancak yeni implementasyon işleri bu doküman altında izlenmelidir.

---

## 1. Okuma Kılavuzu

### Epic

Büyük yatırım alanı.

### Story

Somut kullanıcı değeri veya teknik operasyon çıktısı.

### Task

Geliştirici seviyesinde uygulanabilir iş kalemi.

### Öncelik

- `P0`: sıradaki implementasyon dalgasına girmeli
- `P1`: P0 sonrası alınmalı
- `P2`: deneysel veya daha geç

### Durum

Bu backlog yeni başlangıç durumunda kabul edilir.

- eski backlog'tan devralınan işler burada tekrar açılmaz
- yalnızca kapanmayan veya yeni doğan işler burada yer alır

---

## 2. Önerilen Implementasyon Sırası

### Wave A

Evaluation açığını kapatma

- `N2`

### Wave B

Kalan UX parity ve clarity işleri

- `N1`

### Wave C

Recommendation operasyon otomasyonu

- `N3`

### Wave D

Segment ve surface intelligence

- `N4`

### Wave E

Kapanış, handoff ve ownership

- `N5`

---

## 3. Epic Listesi

### N1. UX Parity and Clarity Closure

Amaç:

- ilk plan sonrası kalan UX boşluklarını kapatmak
- networking yüzeylerinde kavramsal ve davranışsal tutarlılığı tamamlamak

#### N1-S1 Member Detail CTA hierarchy cleanup

Öncelik: `P0`

Story çıktısı:

- member detail ekranındaki networking aksiyonları daha net hiyerarşi ile görünür olur

Task list:

- `N1-S1-T1` mevcut member detail networking CTA sıralamasını envanterle
- `N1-S1-T2` primary ve secondary CTA karar kurallarını tanımla
- `N1-S1-T3` desktop ve mobile action grouping tasarla
- `N1-S1-T4` connection, mentorship ve teacher-network CTA çakışmalarını temizle
- `N1-S1-T5` empty / disabled / already-done durumlarını standartlaştır

Bağımlılık:

- yok

#### N1-S2 Trust badge education layer

Öncelik: `P0`

Story çıktısı:

- trust badge anlamları kullanıcı için görünür ve anlaşılır hale gelir

Task list:

- `N1-S2-T1` badge anlam sözlüğünü finalize et
- `N1-S2-T2` tooltip, drawer veya inline help desenini seç
- `N1-S2-T3` Member Detail, Explore ve Networking Hub yüzeylerine uygula
- `N1-S2-T4` teacher_network, mentor, verified_alumni badge metinlerini netleştir
- `N1-S2-T5` yanlış güven algısı yaratabilecek metinleri gözden geçir

Bağımlılık:

- `N1-S1`

#### N1-S3 Networking copy parity review

Öncelik: `P0`

Story çıktısı:

- tüm networking yüzeylerinde aynı kavram aynı dil ile anlatılır

Task list:

- `N1-S3-T1` Explore, Networking Hub, Teacher Network ve Member Detail kopyalarını karşılaştır
- `N1-S3-T2` aynı kavramın farklı etiket aldığı yerleri temizle
- `N1-S3-T3` helper text, error text ve success text parity kontrolü yap
- `N1-S3-T4` admin panel experiment metinlerini ürün diliyle hizala

Bağımlılık:

- `N1-S2`

#### N1-S4 Admin experiment panel clarity pass

Öncelik: `P1`

Story çıktısı:

- admin apply, rollback, cooldown ve guardrail akışlarını daha az yorumla kullanabilir

Task list:

- `N1-S4-T1` recommendation satırlarında status tonlarını netleştir
- `N1-S4-T2` apply ve rollback sonrası feedback metinlerini sadeleştir
- `N1-S4-T3` recent changes kartlarını okunabilir hale getir
- `N1-S4-T4` düşük sample, cooldown ve confirm durumlarına ayrı görünüm ver

Bağımlılık:

- `N1-S3`

---

### N2. Experiment Evaluation

Amaç:

- uygulanan recommendation değişikliğinin etkisini ölçmek
- admin'in karar kalitesini artırmak

#### N2-S1 Apply history delta model

Öncelik: `P0`

Story çıktısı:

- her apply kaydı için before/after kıyaslaması yapılabilir hale gelir

Task list:

- `N2-S1-T1` evaluation için takip edilecek metrik setini belirle
- `N2-S1-T2` apply history kaydıyla metric snapshot bağını kur
- `N2-S1-T3` before ve after pencereleri için hesap mantığını tanımla
- `N2-S1-T4` yetersiz veri durumunu işaretle
- `N2-S1-T5` evaluation state enum'unu oluştur

Bağımlılık:

- yok

#### N2-S2 Before/after metric snapshot rendering

Öncelik: `P0`

Story çıktısı:

- admin panelde apply kayıtlarının etkisi satır bazında görülebilir

Task list:

- `N2-S2-T1` change history item UI alanlarını tanımla
- `N2-S2-T2` before/after metrik kartı veya compact row tasarla
- `N2-S2-T3` activation, connection request, mentorship request ve teacher-link delta'larını göster
- `N2-S2-T4` insufficient data ve neutral durumlarını ayrı sun

Bağımlılık:

- `N2-S1`

#### N2-S3 Recommendation outcome labeling

Öncelik: `P0`

Story çıktısı:

- her recommendation geçmiş kaydı `positive`, `neutral`, `negative`, `insufficient_data` etiketi alır

Task list:

- `N2-S3-T1` label eşikleri için ürün kuralı yaz
- `N2-S3-T2` delta -> outcome mapping helper'ı yaz
- `N2-S3-T3` admin panelde label görselleştirmesini ekle
- `N2-S3-T4` rollback edilmiş kayıtlar için ayrı statü tanımla

Bağımlılık:

- `N2-S2`

#### N2-S4 Experiment evaluation summary endpoint

Öncelik: `P1`

Story çıktısı:

- admin tek endpoint üzerinden değişikliklerin toplu etkisini okuyabilir

Task list:

- `N2-S4-T1` evaluation summary response shape tasarla
- `N2-S4-T2` positive vs negative apply oranını hesapla
- `N2-S4-T3` en iyi ve en zayıf son değişiklikleri döndür
- `N2-S4-T4` dashboard summary kartına bağla

Bağımlılık:

- `N2-S3`

---

### N3. Recommendation Ops Automation

Amaç:

- recommendation operasyonunu daha güvenli, denetlenebilir ve tekrar kullanılabilir hale getirmek

#### N3-S1 Guardrail config externalization

Öncelik: `P0`

Story çıktısı:

- min sample, cooldown ve confirm kuralları kod sabiti yerine konfigüre edilebilir hale gelir

Task list:

- `N3-S1-T1` mevcut hard-coded guardrail değerlerini envanterle
- `N3-S1-T2` config storage stratejisini seç
- `N3-S1-T3` admin read endpoint ekle
- `N3-S1-T4` admin update endpoint ekle
- `N3-S1-T5` guardrail değişikliğini audit log'a bağla

Bağımlılık:

- `N2-S1`

#### N3-S2 Winner promotion recommendation

Öncelik: `P1`

Story çıktısı:

- sistem hangi varyantın promote edilmesi gerektiğini daha net söyler

Task list:

- `N3-S2-T1` winner promotion kuralını yaz
- `N3-S2-T2` quality ve confidence birlikte değerlendiren skor tanımla
- `N3-S2-T3` promotion suggestion payload'ı ekle
- `N3-S2-T4` admin panelde özel promote suggestion kartı oluştur

Bağımlılık:

- `N2-S4`

#### N3-S3 Rebalance recommendation engine

Öncelik: `P1`

Story çıktısı:

- traffic dağılımı için öneriler daha sistematik hale gelir

Task list:

- `N3-S3-T1` mevcut rebalance mantığını ayrıştır
- `N3-S3-T2` traffic shift limitleri tanımla
- `N3-S3-T3` risky rebalance önerilerini guardrail ile bloke et
- `N3-S3-T4` rebalance önerisine explanatory copy ekle

Bağımlılık:

- `N3-S2`

#### N3-S4 Operator note and audit enrichment

Öncelik: `P1`

Story çıktısı:

- apply ve rollback işlemleri operatör notu ile daha anlamlı hale gelir

Task list:

- `N3-S4-T1` apply note alanı ekle
- `N3-S4-T2` rollback reason alanı ekle
- `N3-S4-T3` audit log response'unda note alanını göster
- `N3-S4-T4` history listesinde operatör notunu göster

Bağımlılık:

- `N3-S1`

---

### N4. Segment and Surface Intelligence

Amaç:

- recommendation kalitesini segment bazında anlamak

#### N4-S1 Cohort-specific experiment view

Öncelik: `P1`

Story çıktısı:

- cohort bazlı recommendation kalite farkı görünür olur

Task list:

- `N4-S1-T1` cohort filtresinin experiment analytics ile tam uyumunu doğrula
- `N4-S1-T2` cohort bazlı performance tablosu oluştur
- `N4-S1-T3` admin panelde cohort switch ekle
- `N4-S1-T4` low-sample cohort uyarısı ekle

Bağımlılık:

- `N2-S4`

#### N4-S2 Surface-specific conversion comparison

Öncelik: `P1`

Story çıktısı:

- Hub ve Explore suggestion kalitesi karşılaştırmalı okunabilir

Task list:

- `N4-S2-T1` source_surface bazlı exposure ve action attribution çıkar
- `N4-S2-T2` Hub vs Explore conversion tablosu üret
- `N4-S2-T3` yüzey bazlı winner detection mantığı yaz
- `N4-S2-T4` admin panelde surface comparison kartı göster

Bağımlılık:

- `N4-S1`

#### N4-S3 Teacher signal impact analytics

Öncelik: `P2`

Story çıktısı:

- Teacher Network sinyalinin suggestion performansına etkisi görünür olur

Task list:

- `N4-S3-T1` teacher-linked users için ayrı slice üret
- `N4-S3-T2` teacher proximity ve activation korelasyonunu çıkar
- `N4-S3-T3` teacher signal lift metriği tanımla
- `N4-S3-T4` recommendation parametrelerine yansıyacak yorum katmanı ekle

Bağımlılık:

- `N4-S2`

---

### N5. Closure and Handoff

Amaç:

- networking alanını sürdürülebilir ownership modeline geçirmek

#### N5-S1 QA regression pack

Öncelik: `P0`

Story çıktısı:

- networking modülü için tekrar kullanılabilir regresyon paketi oluşur

Task list:

- `N5-S1-T1` kritik user journeys listesini çıkar
- `N5-S1-T2` manual QA checklist oluştur
- `N5-S1-T3` mevcut contract test kapsamasını envanterle
- `N5-S1-T4` eksik otomasyon alanlarını backlog'a bağla

Bağımlılık:

- `N1-S3`

#### N5-S2 Operator runbook

Öncelik: `P0`

Story çıktısı:

- admin recommendation sistemini nasıl kullanacağını dokümandan öğrenebilir

Task list:

- `N5-S2-T1` experiment reading guide yaz
- `N5-S2-T2` apply/rollback operasyon akışını yaz
- `N5-S2-T3` alert ve anomaly interpretasyon rehberi ekle
- `N5-S2-T4` guardrail ihlali durumunda ne yapılacağını yaz

Bağımlılık:

- `N3-S4`

#### N5-S3 Final system architecture addendum

Öncelik: `P1`

Story çıktısı:

- networking alanının yeni teknik resmi kayıt altına alınır

Task list:

- `N5-S3-T1` backend data-flow özetini yaz
- `N5-S3-T2` telemetry-summary-experiment zincirini şematize et
- `N5-S3-T3` recommendation ops boundary'lerini dokümante et
- `N5-S3-T4` open risks bölümünü güncelle

Bağımlılık:

- `N2-S4`

#### N5-S4 Quarterly roadmap draft

Öncelik: `P2`

Story çıktısı:

- networking alanı için bir sonraki ürün çeyreğine taşınacak öneri seti oluşur

Task list:

- `N5-S4-T1` product and ops learnings özetini çıkar
- `N5-S4-T2` hangi deneylerin büyütüleceğini belirle
- `N5-S4-T3` hangi alanların dondurulacağını belirle
- `N5-S4-T4` next-quarter proposal dokümanını hazırla

Bağımlılık:

- `N5-S2`

---

## 4. İlk Sprint Önerisi

Yeni execution backlog için en doğru ilk sprint:

- `N2-S1`
- `N2-S2`
- `N2-S3`
- `N1-S1`

Bu kombinasyonun nedeni:

- experiment operasyonu artık production-benzeri olgunlukta olduğundan, bir sonraki eksik halka evaluation tarafıdır
- paralelde kullanıcı yüzündeki son CTA hiyerarşi işleri de kapatılmalıdır

---

## 5. Definition of Ready

Bir story implementasyona alınmadan önce:

- hangi yüzeyleri etkileyeceği belli olmalı
- backend mi frontend mi yoksa ikisi birden mi olduğu açık olmalı
- başarı metriği veya acceptance sonucu tanımlı olmalı
- mevcut contract etkisi bilinmeli

## 6. Definition of Done

Bir story tamamlanmış sayılmadan önce:

#+#+#+#+functions.exec_command to=functions.exec_command  菲律宾申博json
