# SDAL Networking Hub & Teacher Network Execution Backlog

Bu doküman, aşağıdaki dört networking dokümanını uygulanabilir backlog'a dönüştürür:

- `docs/networking-hub-teacher-network-playbook.md`
- `docs/networking-hub-teacher-network-executive-summary.md`
- `docs/networking-hub-teacher-network-technical-backlog.md`
- `docs/networking-hub-teacher-network-ux-improvement-plan.md`

Referans faz planı:

- `docs/networking-hub-teacher-network-phased-task-plan.md`

Amaç:

- faz planını günlük implementasyon backlog'una çevirmek,
- işleri `epic > story > task` seviyesinde görünür yapmak,
- doğru implementasyon sırasını belirlemek,
- ilk sprintlerde hangi işlerin gerçekten yapılacağını netleştirmek.

Bu doküman planlama ve sprint hazırlığı içindir. Kod implementasyonu için ayrı teknik task breakdown'ları gerektiğinde buradan türetilmelidir.

---

## 1. Nasıl Okunmalı?

### Epic

Büyük ürün veya mimari yatırım alanı.

### Story

Kullanıcı değeri veya teknik çıktı üreten orta büyüklükte iş paketi.

### Task

Geliştirici düzeyinde yapılabilir somut iş kalemi.

### Öncelik

- `P0`: ilk implementasyon dalgasına girmeli
- `P1`: P0 sonrası alınmalı
- `P2`: daha sonra veya deneysel

### Durum Mantığı

İlk implementasyon dalgası için önerilen hedef:

- Faz 0 kararları sabitlenecek
- Epic 1 ve Epic 2 içindeki `P0` story'ler alınacak
- Epic 3 kısmen hazırlanacak ama tam implementasyon sonraya bırakılacak

---

## 2. Önerilen Implementasyon Sırası

### Wave 0

Plan sabitleme ve ölçüm zemini

- `E0`

### Wave 1

Kullanıcı tarafında en hızlı hissedilen netlik ve zıplama azaltma işleri

- `E1`
- `E2` içindeki düşük riskli state ve feedback işleri

### Wave 2

Networking Hub teknik sadeleştirme ve hız iyileştirmeleri

- `E2` geri kalanı

### Wave 3

Teacher Network güven, kalite ve moderasyon güçlendirmeleri

- `E3`

### Wave 4

Analytics, telemetry, admin görünürlüğü

- `E4`

### Wave 5

Deneysel graph ve recommendation evrimi

- `E5`

---

## 3. Epic Listesi

### E0. Scope, Terminology and Measurement Baseline

Amaç:

- aynı modül için herkesin aynı dili kullanmasını sağlamak
- başarı kriterlerini implementasyon öncesi netleştirmek
- sonraki sprintlerde scope kaymasını azaltmak

#### E0-S1 Terminology ve copy standardı sabitleme

Öncelik: `P0`

Story çıktısı:

- connection, follow, mentorship, teacher link, teacher network, trust badge kavramları sabitlenmiş olur
- UI copy için referans sözlük oluşur

Task list:

- `E0-S1-T1` mevcut ekranlarda geçen networking terimlerini envanterle
- `E0-S1-T2` tek cümlelik ürün sözlüğü oluştur
- `E0-S1-T3` hangi kavramların kullanıcıya gösterileceğini, hangilerinin sistem içi kalacağını belirle
- `E0-S1-T4` standardize copy listesi hazırla
- `E0-S1-T5` future UI review için copy checklist çıkar

Bağımlılık:

- yok

#### E0-S2 Metric baseline ve success criteria

Öncelik: `P0`

Story çıktısı:

- neyi iyileştirdiğimizi ölçebileceğimiz bir temel oluşur

Task list:

- `E0-S2-T1` hub açılış süresi ölçüm tanımı yaz
- `E0-S2-T2` first meaningful panel render tanımını netleştir
- `E0-S2-T3` connection accept conversion metriğini tanımla
- `E0-S2-T4` teacher link completion ve abandonment metriğini tanımla
- `E0-S2-T5` time to first network success metriğini tanımla
- `E0-S2-T6` hangi event'lerin frontend, hangilerinin backend kaynaklı olacağını ayır

Bağımlılık:

- `E0-S1`

#### E0-S3 Scope freeze ve risk register

Öncelik: `P0`

Story çıktısı:

- ilk implementasyon dalgasının sınırı netleşir

Task list:

- `E0-S3-T1` Faz 1 ve Faz 2 için in-scope / out-of-scope listesi çıkar
- `E0-S3-T2` aggregate endpoint'in ilk dalga zorunluluğunu karara bağla
- `E0-S3-T3` regressions için risk register oluştur
- `E0-S3-T4` QA kontrol senaryolarını önceden tanımla

Bağımlılık:

- `E0-S2`

---

### E1. UX Clarity and Action Prioritization

Amaç:

- kullanıcı hangi ekranın ne işe yaradığını ilk bakışta anlamalı
- network aksiyonlarında bilişsel yük düşmeli
- Teacher Network'ün değeri görünür hale gelmeli

#### E1-S1 Networking Hub priority strip

Öncelik: `P0`

Story çıktısı:

- kullanıcı sayfaya girer girmez önce neye bakacağını anlar

Task list:

- `E1-S1-T1` priority strip içerik kurallarını tanımla
- `E1-S1-T2` incoming connections, mentorship ve teacher notifications için summary logic hazırla
- `E1-S1-T3` üst bölüm layout tasarımı yap
- `E1-S1-T4` CTA davranışlarını belirle
- `E1-S1-T5` empty durumda şeridin fallback davranışını ekle

Bağımlılık:

- `E0-S1`

#### E1-S2 Hub empty-state ve helper text yenilemesi

Öncelik: `P0`

Story çıktısı:

- boş durumlar öğretici hale gelir

Task list:

- `E1-S2-T1` her section için yeni empty-state microcopy yaz
- `E1-S2-T2` section altı helper text standardı hazırla
- `E1-S2-T3` no-data ve loading state görsel ayrımını belirle
- `E1-S2-T4` metinleri mevcut component yapısına yerleştir

Bağımlılık:

- `E0-S1`

#### E1-S3 Teacher Network değer paneli

Öncelik: `P0`

Story çıktısı:

- kullanıcı neden teacher link eklediğini anlar

Task list:

- `E1-S3-T1` panel bilgi mimarisini çıkar
- `E1-S3-T2` "ne işe yarar / ne kazandırır / öğretmene nasıl yansır" copy'sini yaz
- `E1-S3-T3` desktop ve mobile yerleşimini tasarla
- `E1-S3-T4` form ile panel arasındaki görsel önceliği belirle

Bağımlılık:

- `E0-S1`

#### E1-S4 Relation type helper ve trust badge açıklama katmanı

Öncelik: `P1`

Story çıktısı:

- ilişki türleri ve rozetler yorum gerektirmeden anlaşılır

Task list:

- `E1-S4-T1` relation type açıklama metinlerini yaz
- `E1-S4-T2` trust badge tooltip veya info drawer desenini seç
- `E1-S4-T3` badge anlamlarını ürün sözlüğü ile eşleştir
- `E1-S4-T4` yanlış anlaşılabilecek rozet metinlerini düzelt

Bağımlılık:

- `E0-S1`

#### E1-S5 Member detail CTA hierarchy

Öncelik: `P1`

Story çıktısı:

- profil sayfasındaki networking aksiyonları daha temiz hiyerarşi ile sunulur

Task list:

- `E1-S5-T1` mevcut CTA yoğunluğunu analiz et
- `E1-S5-T2` primary / secondary / overflow action kuralı tanımla
- `E1-S5-T3` öğretmen hedefleri için CTA görünürlük mantığını teyit et
- `E1-S5-T4` mobil görünüm için taşma stratejisi belirle

Bağımlılık:

- `E0-S1`

---

### E2. Networking Hub Performance and State Architecture

Amaç:

- sayfayı daha hızlı açmak
- aksiyonlardan sonra zıplamayı azaltmak
- state yönetimini sürdürülebilir hale getirmek

#### E2-S1 Hub aggregate bootstrap endpoint

Öncelik: `P0`

Story çıktısı:

- hub ana verisi tek bootstrap contract ile yüklenir

Task list:

- `E2-S1-T1` `GET /api/new/network/hub` response contract'ını tasarla
- `E2-S1-T2` inbox, metrics, discovery summary alanlarını belirle
- `E2-S1-T3` unread counts ve request maps ihtiyaçlarını contract'a ekle
- `E2-S1-T4` backend aggregation query planını çıkar
- `E2-S1-T5` endpoint'i uygula
- `E2-S1-T6` mevcut frontend bootstrap akışını yeni endpoint'e geçir
- `E2-S1-T7` backward compatibility gereksinimi varsa geçiş planı yaz

Bağımlılık:

- `E0-S2`
- `E0-S3`

#### E2-S2 `useNetworkingHubState` hook ve reducer mimarisi

Öncelik: `P0`

Story çıktısı:

- hub state'i daha öngörülebilir hale gelir

Task list:

- `E2-S2-T1` mevcut page state parçalarını haritalandır
- `E2-S2-T2` reducer action sözlüğünü tanımla
- `E2-S2-T3` bootstrap, optimistic action, silent refresh state'lerini ayır
- `E2-S2-T4` özel hook yapısını kur
- `E2-S2-T5` component içindeki dağınık state'i hook'a taşı
- `E2-S2-T6` reducer transition test senaryolarını yaz

Bağımlılık:

- `E2-S1`

#### E2-S3 Silent refresh ve optimistic update standardı

Öncelik: `P0`

Story çıktısı:

- kullanıcı aksiyon sonrası beklemeden sonuç görür

Task list:

- `E2-S3-T1` action türlerini sınıflandır: accept, ignore, send, cancel, mentorship, teacher read
- `E2-S3-T2` her action için optimistic state kuralını yaz
- `E2-S3-T3` background refresh timing stratejisini belirle
- `E2-S3-T4` error rollback davranışını tanımla
- `E2-S3-T5` sabit feedback alanı ile yeni state akışını eşleştir

Bağımlılık:

- `E2-S2`

#### E2-S4 Networking response shape standardizasyonu

Öncelik: `P0`

Story çıktısı:

- frontend her networking endpoint'i aynı şekilde işler

Task list:

- `E2-S4-T1` standart response shape'i sabitle: `ok`, `code`, `message`, `data`
- `E2-S4-T2` networking endpoint envanteri çıkar
- `E2-S4-T3` text dönen endpoint'leri JSON contract'a geçir
- `E2-S4-T4` frontend error handling katmanını güncelle
- `E2-S4-T5` contract regression checklist yaz

Bağımlılık:

- `E0-S1`
- `E2-S1`

#### E2-S5 Networking event ve message registry

Öncelik: `P1`

Story çıktısı:

- event isimleri, feedback metinleri ve telemetry anahtarları tek yerde tutulur

Task list:

- `E2-S5-T1` mevcut string literal event ve message envanterini çıkar
- `E2-S5-T2` ortak event registry modülü oluştur
- `E2-S5-T3` ortak UI message registry modülü oluştur
- `E2-S5-T4` hub ve teacher network yüzeylerini bu registry'ye taşı

Bağımlılık:

- `E2-S4`

#### E2-S6 Layout stability ve scroll davranışı

Öncelik: `P0`

Story çıktısı:

- loader, feedback ve section refresh sırasında sayfa daha az zıplar

Task list:

- `E2-S6-T1` section bazlı minimum height ve skeleton stratejisini standardize et
- `E2-S6-T2` feedback alanı için sabit yer kuralını gözden geçir
- `E2-S6-T3` aksiyon sonrası scroll reset veya anchor kaybı olup olmadığını test et
- `E2-S6-T4` mobile viewport için layout stability kontrolü ekle

Bağımlılık:

- `E1-S1`
- `E2-S3`

---

### E3. Teacher Network Trust, Quality and Moderation

Amaç:

- teacher graph verisinin güvenilirliğini artırmak
- yanlış veya düşük kaliteli link'leri daha yönetilebilir yapmak
- ürünün güven katmanını güçlendirmek

#### E3-S1 Teacher Network audit trail

Öncelik: `P1`

Story çıktısı:

- her teacher link'in kaynağı ve gözden geçirilme durumu izlenebilir

Task list:

- `E3-S1-T1` `created_via`, `source_surface`, `last_reviewed_by`, `review_status` alanlarını veri modeli açısından değerlendir
- `E3-S1-T2` migration taslağı hazırla
- `E3-S1-T3` create/read endpoint contract'larını genişlet
- `E3-S1-T4` admin görünümüne yeni alanları ekle

Bağımlılık:

- `E2-S4`

#### E3-S2 Confidence score'un işlevsel hale gelmesi

Öncelik: `P1`

Story çıktısı:

- teacher link kalitesi sayısal sinyallerle izlenir

Task list:

- `E3-S2-T1` confidence score sinyallerini tanımla
- `E3-S2-T2` scoring weight taslağı çıkar
- `E3-S2-T3` duplicate proximity ve verified teacher etkisini modele ekle
- `E3-S2-T4` admin onayı ve raporlama etkisini skora bağla
- `E3-S2-T5` skorun UI'da görünür olup olmayacağına karar ver

Bağımlılık:

- `E3-S1`

#### E3-S3 Teacher options ve duplicate prevention iyileştirmesi

Öncelik: `P1`

Story çıktısı:

- yanlış öğretmen seçimi ve tekrar kayıt riski azalır

Task list:

- `E3-S3-T1` teacher options endpoint arama davranışını gözden geçir
- `E3-S3-T2` include-id, selected-option persistence ve search fallback kurallarını standardize et
- `E3-S3-T3` duplicate creation öncesi backend kontrolü güçlendir
- `E3-S3-T4` kullanıcıya duplicate veya yakın eşleşme uyarısı tasarla

Bağımlılık:

- `E1-S3`
- `E3-S1`

#### E3-S4 Moderation akışı güçlendirmesi

Öncelik: `P1`

Story çıktısı:

- admin tarafı teacher graph kalitesine daha bilinçli müdahale edebilir

Task list:

- `E3-S4-T1` moderation queue alanlarını yeniden tanımla
- `E3-S4-T2` review status state machine'i belirle
- `E3-S4-T3` reject / merge / confirm akışlarını netleştir
- `E3-S4-T4` moderation event log ihtiyacını değerlendir

Bağımlılık:

- `E3-S1`
- `E3-S2`

---

### E4. Analytics, Telemetry and Admin Visibility

Amaç:

- networking yatırımlarının etkisini görünür kılmak
- admin tarafında operasyonel sinyal üretmek
- ürün kararlarını veriyle beslemek

#### E4-S1 Networking telemetry event planı

Öncelik: `P1`

Story çıktısı:

- kullanıcı yolculuğu event bazında ölçülebilir hale gelir

Task list:

- `E4-S1-T1` event taxonomy hazırla
- `E4-S1-T2` frontend telemetry noktalarını belirle
- `E4-S1-T3` backend source-of-truth event'lerini ayır
- `E4-S1-T4` funnel'lar için gerekli alanları tanımla

Bağımlılık:

- `E0-S2`
- `E2-S5`

#### E4-S2 Networking metrics precomputation

Öncelik: `P1`

Story çıktısı:

- dashboard ve admin görünümü daha hızlı hesaplanır

Task list:

- `E4-S2-T1` precompute edilecek metrikleri seç
- `E4-S2-T2` summary tablo veya materialized yapı tasarla
- `E4-S2-T3` update stratejisini belirle: request-time, async job, daily aggregation
- `E4-S2-T4` admin metric consumer'larını bu yeni kaynağa geçir

Bağımlılık:

- `E4-S1`

#### E4-S3 Admin networking visibility panel

Öncelik: `P1`

Story çıktısı:

- admin networking sağlığını tek bakışta görür

Task list:

- `E4-S3-T1` kritik admin KPI listesini oluştur
- `E4-S3-T2` teacher link kalite göstergelerini belirle
- `E4-S3-T3` alert veya anomaly eşiklerini tanımla
- `E4-S3-T4` admin ekranı için bilgi mimarisi tasarla

Bağımlılık:

- `E4-S2`
- `E3-S4`

---

### E5. Recommendation and Graph Evolution

Amaç:

- suggestion kalitesini Teacher Network ve trust sinyalleriyle geliştirmek
- deneysel iyileştirmeleri güvenli biçimde yapmak

#### E5-S1 Suggestion engine ayrıştırması

Öncelik: `P2`

Story çıktısı:

- öneri mantığı modüler hale gelir

Task list:

- `E5-S1-T1` mevcut suggestion logic'i app seviyesinde envanterle
- `E5-S1-T2` scoring, reason generation ve badge generation katmanlarını ayır
- `E5-S1-T3` yeni service sınırlarını tanımla
- `E5-S1-T4` unit test stratejisi yaz

Bağımlılık:

- `E3-S2`
- `E4-S1`

#### E5-S2 Experiment framework for networking recommendations

Öncelik: `P2`

Story çıktısı:

- farklı suggestion stratejileri kontrollü şekilde denenebilir

Task list:

- `E5-S2-T1` hangi recommendation parametrelerinin deneysel olacağını belirle
- `E5-S2-T2` experiment assignment yaklaşımını seç
- `E5-S2-T3` primary ve guardrail metric'leri tanımla
- `E5-S2-T4` rollback kuralı yaz

Bağımlılık:

- `E5-S1`
- `E4-S1`

---

## 4. İlk Sprintler İçin Önerilen Kesim

### Sprint 1

Hedef:

- implementasyon zemini ve kullanıcıya en hızlı hissedilen netlik işleri

Alınacak story'ler:

- `E0-S1`
- `E0-S2`
- `E0-S3`
- `E1-S1`
- `E1-S2`
- `E1-S3`

### Sprint 2

Hedef:

- hub state ve davranış stabilitesini iyileştirmek

Alınacak story'ler:

- `E2-S2`
- `E2-S3`
- `E2-S6`
- `E1-S4`

Not:

- `E2-S1` aggregate endpoint bu sprintte spike veya full implementation olarak alınabilir

### Sprint 3

Hedef:

- networking API contract ve bootstrap akışını sadeleştirmek

Alınacak story'ler:

- `E2-S1`
- `E2-S4`
- `E2-S5`

### Sprint 4

Hedef:

- teacher graph kalite ve moderasyon katmanı

Alınacak story'ler:

- `E3-S1`
- `E3-S2`
- `E3-S3`
- `E3-S4`

### Sprint 5

Hedef:

- analytics ve admin görünürlüğü

Alınacak story'ler:

- `E4-S1`
- `E4-S2`
- `E4-S3`

### Sprint 6+

Hedef:

- deneysel graph ve recommendation iyileştirmeleri

Alınacak story'ler:

- `E5-S1`
- `E5-S2`

---

## 5. İlk İmplementasyon Dalgası İçin Kesin Öneri

Eğer hemen implementasyona geçilecekse ilk dalga şu set olmalı:

1. `E0-S1`, `E0-S2`, `E0-S3`
2. `E1-S1`, `E1-S2`, `E1-S3`
3. `E2-S2`, `E2-S3`, `E2-S6`
4. ardından teknik risk durumuna göre `E2-S1` ve `E2-S4`

Bunun nedeni:

- önce kullanıcı ne gördüğünü anlamalı,
- sonra hub davranışı stabil hale gelmeli,
- sonra network contract sadeleştirilmelidir.

Bu sıra, hem hissedilen kaliteyi hem teknik sağlamlığı dengeler.

---

## 6. Definition of Ready

Bir story sprint'e alınmadan önce en az şu net olmalı:

- ürün amacı
- ilgili ekran veya endpoint
- kabul kriteri
- bağımlı olduğu önceki story
- test ihtiyacı
- rollout riski

---

## 7. Definition of Done

Bir story tamamlandı sayılmadan önce en az şu doğrulanmalı:

- kullanıcı akışı elle test edildi
- mevcut networking davranışlarında regression yok
- loading, error ve empty-state davranışı kontrol edildi
- backend contract değiştiyse frontend uyumu doğrulandı
- gerekiyorsa telemetry veya log ekleri güncellendi

---

## 8. Sonuç

Bu backlog'un ana önerisi şudur:

- önce kavram netliği ve ekran yönlendirmesi,
- sonra hub state ve performans mimarisi,
- sonra teacher graph trust ve moderation,
- en son analytics ve deneysel optimizasyon.

Bu sıra korunursa hem kullanıcı tarafında hızlı kalite artışı görülür, hem de gereksiz büyük rewrite riskinden kaçınılır.
