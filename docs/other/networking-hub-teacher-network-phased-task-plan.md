# SDAL Networking Hub & Teacher Network Phased Task Plan

Bu doküman, aşağıdaki dört networking dokümanını tek bir uygulanabilir çalışma planına dönüştürür:

- `docs/networking-hub-teacher-network-playbook.md`
- `docs/networking-hub-teacher-network-executive-summary.md`
- `docs/networking-hub-teacher-network-technical-backlog.md`
- `docs/networking-hub-teacher-network-ux-improvement-plan.md`

Amaç:

- uygulamaya geçmeden önce net bir faz planı oluşturmak,
- işleri doğru sıraya koymak,
- bağımlılıkları görünür hale getirmek,
- düşük riskli ve yüksek etkili işleri erken almak,
- teknik ve UX yatırımlarını birbirine bağlamaktır.

Bu plan implementasyon dokümanı değildir. Bu plan, implementasyona geçmeden önce üzerinde anlaşılması gereken yol haritasıdır.

---

## 1. Planlama Prensibi

Bu alan için en doğru yaklaşım tek seferde büyük bir rewrite değildir.

Doğru strateji:

1. önce ürün dili ve ekran mantığını netleştirmek,
2. sonra hub performans ve state mimarisini sadeleştirmek,
3. sonra teacher graph kalitesini ve moderasyon katmanını güçlendirmek,
4. en son ileri analitik ve deney katmanına geçmektir.

Yani faz sırası şu öncelik mantığıyla ilerler:

- önce anlaşılabilirlik,
- sonra hız ve operasyon,
- sonra kalite ve güven,
- sonra analitik,
- sonra deneysel optimizasyon.

---

## 2. Fazlar Arası Genel Sıralama

### Faz 0

Plan doğrulama, kapsam sabitleme, başarı metriği tanımı

### Faz 1

Düşük riskli UX netleştirmeleri ve dil standardizasyonu

### Faz 2

Networking Hub performans ve state mimarisi iyileştirmesi

### Faz 3

Teacher Network kalite, güven ve moderasyon güçlendirmeleri

### Faz 4

Analytics, telemetry ve admin görünürlüğü

### Faz 5

İleri seviye graph kalite sistemleri, A/B testleri ve deneysel öneri geliştirmeleri

---

## 3. Faz 0: Planning & Baseline

Bu fazın amacı kod yazmak değil, implementasyonun güvenli ve ölçülebilir başlamasını sağlamaktır.

### Hedef

- ürün terminolojisini sabitlemek
- başarı ölçütlerini tanımlamak
- hangi işlerin aynı sprint'e alınacağını netleştirmek
- "ne yapmayacağız" sınırını çizmek

### Task list

#### F0-T1 Terminoloji sözlüğünü sabitle

Karar verilecek terimler:

- bağlantı
- takip
- mentorluk
- öğretmen bağı
- öğretmen ağı
- trust badge

Çıktı:

- kısa ürün sözlüğü
- UI copy standardı

#### F0-T2 Başarı metriklerini tanımla

Minimum takip edilecek metrikler:

- hub açılış süresi
- ilk meaningful panel render süresi
- connection request -> accept oranı
- teacher link oluşturma oranı
- teacher link form abandonment oranı
- time to first network success

Çıktı:

- metrik listesi
- nasıl ölçüleceği

#### F0-T3 Faz kapsamını sabitle

Karar:

- Faz 1 ve Faz 2 birlikte mi yapılacak?
- Teacher Network kalite işleri Faz 3'e mi bırakılacak?
- Aggregate endpoint Faz 2'de zorunlu mu?

Çıktı:

- implementation scope freeze

#### F0-T4 Risk kaydı oluştur

Riskler:

- kavram karmaşası
- veri portability
- state regressions
- performans iyileşirken contract kırılması

Çıktı:

- risk register

### Acceptance criteria

- ürün ekibi aynı kavramları aynı dil ile kullanıyor olmalı
- hangi fazda ne yapılacağı netleşmiş olmalı
- implementasyonda referans alınacak metrikler belirlenmiş olmalı

### Faz 0 çıktıları

- scope freeze
- metric baseline
- terminology sheet
- risk register

---

## 4. Faz 1: UX Clarity & Product Friction Reduction

Bu fazın amacı mevcut sistemin mantığını kullanıcı için daha görünür hale getirmektir.

Bu faz özellikle düşük riskli ama yüksek etkili işler içerir.

### Hedef

- kullanıcıya ekranların ne işe yaradığını daha net anlatmak
- kavramsal yükü azaltmak
- empty-state ve helper text kalitesini artırmak
- Teacher Network değerini görünür yapmak

### Task list

#### F1-T1 Networking Hub priority strip tasarla ve uygula

Yeni blok:

- `Şimdi ilgilenmen gerekenler`

Gösterecek:

- gelen bağlantı sayısı
- mentorluk bekleyen talepler
- yeni teacher notification sayısı

Neden bu fazda:

- en hızlı değer sağlayan UX netlik işlerinden biri

#### F1-T2 Networking Hub empty-state metinlerini yeniden yaz

Bölümler:

- incoming connections
- outgoing connections
- incoming mentorship
- outgoing mentorship
- teacher notifications
- suggestions

Neden bu fazda:

- kullanıcı eğitimine düşük maliyetle katkı verir

#### F1-T3 Teacher Network value panel ekle

Yeni içerik:

- bu kayıt ne işe yarar
- profile ne katar
- öğretmene ne yansır
- trust graph'a nasıl etki eder

Neden bu fazda:

- Teacher Network'ün anlaşılmasını doğrudan artırır

#### F1-T4 Relation type helper text ekle

Alanlar:

- taught_in_class
- mentor
- advisor

Neden bu fazda:

- form completion kalitesini artırır

#### F1-T5 Trust badge açıklama katmanı

Öneri:

- tooltip veya info drawer

Özellikle:

- `teacher_network`
- `mentor`
- `verified_alumni`

#### F1-T6 Member detail CTA gruplaması tasarla

Hedef:

- çok fazla aksiyonu tek satırda göstermemek

Çıktı:

- yeni action hierarchy önerisi

#### F1-T7 Copy standardizasyonu

Güncellenecek yüzeyler:

- member detail
- explore
- networking hub
- teacher network

### Acceptance criteria

- Teacher Network ekranı ilk kez açan kullanıcı neden değerli olduğunu anlayabiliyor olmalı
- Networking Hub'da ilk aksiyon noktası daha açık olmalı
- boş durumlar yönlendirici olmalı
- rozetler sadece görsel değil, anlam taşımalı

### Bağımlılıklar

- Faz 0 terminoloji kararı

### Risk

- copy değişiklikleri backend davranışı değiştirmez ama kavram standardı olmadan tutarsızlık yaratabilir

---

## 5. Faz 2: Networking Hub Performance & State Architecture

Bu faz teknik olarak en kritik fazdır.

### Hedef

- hub yüklenmesini hızlandırmak
- zıplamayı azaltmak
- state yönetimini sadeleştirmek
- aksiyonların hissedilen gecikmesini azaltmak

### Task list

#### F2-T1 `useNetworkingHubState` tasarımı

Bugünkü hub state parçaları:

- inbox listeleri
- metrics
- discovery listesi
- request maps
- pending actions
- feedback

Yapılacak:

- custom hook veya reducer tabanı

Çıktı:

- daha okunabilir state modeli

#### F2-T2 Networking hub aggregate endpoint tasarımı

Önerilen endpoint:

- `GET /api/new/network/hub`

Minimum payload:

- inbox
- metrics
- suggestion summary
- request state maps

Karar:

- tek endpoint mi
- yoksa hub core + discovery summary mı

#### F2-T3 Endpoint response standardizasyonu

Amaç:

- networking endpoint'lerinde tutarlı JSON shape

Standart:

- `ok`
- `code`
- `message`
- `data`

#### F2-T4 Silent refresh desenini ortaklaştır

Senaryolar:

- action sonrası doğrulama
- polling
- background update
- discovery refresh

#### F2-T5 Shared network action component

Ortaklaştırılacak:

- connection request button logic
- follow button logic
- mentorship request button logic

Hedef yüzeyler:

- explore
- member detail
- networking hub

#### F2-T6 Networking hub telemetry ekle

İzlenecek:

- first paint
- hub data load
- discovery load
- action response latency

#### F2-T7 Query portability cleanup

Özellikle:

- SQLite/Postgres uyum farkları
- timestamp order expressions
- null / empty string fallback standardı

### Acceptance criteria

- hub ekranı ilk yüklemede daha az çağrı ile ayağa kalkmalı
- action sonrası tam sayfa loader davranışı minimuma inmeli
- hissedilen gecikme anlamlı şekilde düşmeli
- portability kaynaklı query hataları kapanmalı

### Bağımlılıklar

- Faz 0 metrik baseline
- Faz 1 copy kararları faydalı ama zorunlu değil

### Risk

- state refactor regression üretebilir
- aggregate endpoint yanlış tasarlanırsa payload şişebilir

---

## 6. Faz 3: Teacher Network Quality, Trust & Moderation

Bu faz Teacher Network'ü sadece çalışan değil, güvenilir ve yönetilebilir hale getirmeyi hedefler.

### Hedef

- graph kalitesini artırmak
- teacher link kayıtlarını daha iyi gözlemlemek
- moderasyon kapasitesini artırmak
- confidence score'u işlevsel hale getirmek

### Task list

#### F3-T1 Teacher link metadata enrichment

Yeni alan adayları:

- `created_via`
- `source_surface`
- `review_status`
- `reviewed_by`
- `reviewed_at`

#### F3-T2 Confidence score model tasarımı

Girdi adayları:

- hedef teacher doğrulaması
- ilişki tipi
- class year varlığı
- admin review
- duplicate/abnormal pattern

#### F3-T3 Teacher link report flow tasarımı

Amaç:

- yanlış ilişkiyi raporlayabilme

Parçalar:

- user-facing report action
- admin review queue

#### F3-T4 Admin moderation görünümünü genişlet

Yeni filtreler:

- class year
- teacher cohort
- review status
- confidence band

#### F3-T5 Teacher profile aggregate summary

Gösterilebilecek özetler:

- linked alumni count
- cohort dağılımı
- son eklenen bağlar

#### F3-T6 Verification ve trust copy'sini güçlendir

Teacher link ile trust badge ilişkisi kullanıcıya daha net anlatılmalı

### Acceptance criteria

- teacher graph kayıtları daha iyi denetlenebilir olmalı
- confidence score sahte bir alan olmaktan çıkmalı
- yanlış kayıtları raporlama yolu olmalı
- admin tarafı sadece liste değil, kalite paneli haline gelmeli

### Bağımlılıklar

- Faz 1 value panel ve copy standardı
- Faz 2 response standardı önerilir ama zorunlu değildir

### Risk

- metadata genişlemesi migration gerektirebilir
- moderation tasarımı erken yapılırsa ürün akışı ağırlaşabilir

---

## 7. Faz 4: Analytics & Observability

Bu faz, networking sisteminin yönetilebilir ve ölçülebilir hale gelmesini hedefler.

### Hedef

- networking'in gerçekten işe yarayıp yaramadığını ölçmek
- cohort bazlı davranışı izlemek
- admin karar üretimini desteklemek

### Task list

#### F4-T1 Networking event analytics sözlüğü

Event adayları:

- connection request sent
- connection request accepted
- mentorship request sent
- mentorship request accepted
- teacher link created
- teacher notification read

#### F4-T2 Daily summary tablo tasarımı

Önerilen tablo:

- `member_networking_daily_summary`

#### F4-T3 Admin networking funnel dashboard

Metrikler:

- request sent
- accepted
- ignored/declined
- acceptance rate
- response time

#### F4-T4 Cohort benchmark görünümü

Ölçülecek:

- class year bazlı request yoğunluğu
- teacher network adoption
- mentor demand/supply

#### F4-T5 Time to first network success benchmark

Kullanım:

- onboarding kalitesini ölçmek

### Acceptance criteria

- admin manuel SQL olmadan networking funnel görebilmeli
- cohort bazlı farklar görülebilmeli
- ürün yatırımlarının etkisi ölçülebilmeli

### Bağımlılıklar

- Faz 0 başarı metrikleri
- Faz 2 telemetry

### Risk

- veri hacmi arttıkça özet tablo olmadan performans maliyeti büyür

---

## 8. Faz 5: Experiments & Advanced Graph Evolution

Bu faz erken değil, sistem olgunlaştıktan sonra gelmelidir.

### Hedef

- graph tabanlı optimizasyonları denemek
- suggestion kalitesini artırmak
- riskli ama yüksek potansiyelli fikirleri kontrollü denemek

### Task list

#### F5-T1 A/B test framework for networking copy

Test adayları:

- `Bağlantı Kur` vs `Tanışma İsteği Gönder`
- `Öğretmen Ağına Ekle` vs `Öğretmen Olarak Bağla`

#### F5-T2 Graph anomaly detection

Hedef:

- sıra dışı yoğunlukları bulmak

#### F5-T3 Recommendation model experiments

Hedef:

- teacher overlap ağırlığı
- mentor overlap ağırlığı
- direct teacher link etkisi

#### F5-T4 Social graph score

Hedef:

- trust + graph + activity bazlı bileşik networking skoru

### Acceptance criteria

- deneyler üretim akışını bozmayacak şekilde kontrollü yapılmalı
- başarı/başarısızlık net ölçülmeli

### Bağımlılıklar

- Faz 4 analytics olmadan bu faza geçilmemeli

---

## 9. Hangi Fazdan Başlamalıyız?

Önerilen gerçek başlangıç sırası:

### Önce yapılacak

- Faz 0
- ardından Faz 1'in tamamı
- paralelde Faz 2 tasarım hazırlığı

### İlk implementasyon fazı

En mantıklı ilk implementasyon fazı:

- `Faz 1 + Faz 2'nin P0 işleri`

Sebep:

- kullanıcı hemen fark eder
- hissedilen kalite yükselir
- sonraki fazlar için sağlam temel oluşur

### Daha sonra

- Faz 3
- Faz 4
- Faz 5

---

## 10. Önerilen Sprint Paketleri

Bu bölüm fazları sprint'e çevirmek için pratik öneridir.

### Sprint 1

- Faz 0 tamamı
- Faz 1 copy standardı
- Faz 1 value panel
- Faz 1 empty-state iyileştirmeleri

### Sprint 2

- Faz 1 priority strip
- Faz 2 state hook/reducer tasarımı
- Faz 2 silent refresh standardı
- Faz 2 shared action bileşeni başlangıcı

### Sprint 3

- Faz 2 aggregate endpoint
- Faz 2 response standardı
- Faz 2 telemetry
- portability cleanup

### Sprint 4

- Faz 3 metadata enrichment
- Faz 3 moderation genişletme
- Faz 3 confidence score tasarımı

### Sprint 5

- Faz 4 summary table
- Faz 4 funnel dashboard
- Faz 4 cohort analytics

### Sprint 6+

- Faz 5 deneyler

---

## 11. Fazlar İçin Go / No-Go Kriterleri

### Faz 1'e geçmek için

- terminoloji sabitlenmiş olmalı

### Faz 2'ye geçmek için

- Faz 1 ekran dili netleşmiş olmalı
- hangi endpoint yapısına geçileceği kararlaştırılmış olmalı

### Faz 3'e geçmek için

- Teacher Network ekranının temel UX'i oturmuş olmalı
- mevcut akış stabil olmalı

### Faz 4'e geçmek için

- event ve state standardizasyonu tamamlanmış olmalı

### Faz 5'e geçmek için

- güvenilir analitik tabanı oluşmuş olmalı

---

## 12. Sonuç

Bu planın önerdiği yol şudur:

- önce anlamı netleştir,
- sonra hızı ve operasyonel kaliteyi artır,
- sonra güven ve kalite katmanını derinleştir,
- en son analitik ve deneylere geç.

Implementasyona başlamak için en doğru başlangıç:

- Faz 0 planlama onayı
- ardından Faz 1 ve Faz 2 P0 işleri

Yani bir sonraki pratik adım, Faz 1 ve Faz 2 için sprint 1-3 kapsamını sabitlemek olmalıdır.

