# Opportunity Inbox V1 Phased Implementation Plan

Bu doküman, Opportunity Inbox V1 kararını doğrudan uygulanabilir bir faz planına çevirir.

Referans omurga:

- `server/src/networking/createNetworkDiscoveryPayloadRuntime.js`
- `server/routes/networkDiscoveryRoutes.js`
- `frontend-modern/src/App.jsx`

Bu planın amacı:

- yeni fırsat yüzeyini mevcut SDAL akışlarına çarpmadan eklemek,
- networking, mentorluk, iş ve kritik güncellemeleri tek bir aksiyon sırasına dönüştürmek,
- V1 için gereksiz karmaşıklığı dışarıda bırakmak,
- implementasyon ve sonradan backlog üretimini karar gerektirmeden mümkün hale getirmektir.

Bu doküman execution backlog değildir. Bu doküman, execution backlog yazılmadan önce implementasyon kararlarını sabitleyen phased implementation planıdır.

---

## 1. V1 Karar Özeti

Son karar:

- ana yüzey yeni bir sayfa olacaktır: `/new/opportunities`
- V1 ilk günden cross-product olacaktır
- ranking tamamen deterministic ve explainable olacaktır
- networking nav entry point bu yeni yüzeye taşınacaktır
- mevcut networking hub, jobs ve notifications sayfaları downstream action destination olarak yaşamaya devam edecektir

V1 kapsamına giren fırsat aileleri:

- pending mentorship requests
- pending connection requests
- unread teacher-network updates
- incoming job applications to review
- applicant-facing job decision updates
- warm intro style networking suggestions
- fresh jobs to inspect

V1 kapsamı dışında kalanlar:

- ML tabanlı ranking
- schema migration
- admin tuning paneli
- mevcut jobs, notifications veya networking flow'larının rewrite edilmesi
- multi-step automation veya auto-apply benzeri riskli aksiyonlar

---

## 2. Mimari Hüküm

Opportunity Inbox V1, yeni bir domain sistemi değil, mevcut domainlerden veri toplayan ve onları tek bir sıralı aksiyon listesine çeviren orchestration layer olacaktır.

### Temel yüzeyler

- backend endpoint: `GET /api/new/opportunities`
- frontend route: `/new/opportunities`

### Backend kaynakları

- networking inbox payload
- networking discovery suggestions payload
- jobs + job_applications state
- high-signal teacher-link style updates

### V1 item contract

Her item aşağıdaki canonical alanları taşımalıdır:

- `id`
- `kind`
- `source`
- `category`
- `score`
- `priority_bucket`
- `title`
- `summary`
- `why_now`
- `reasons`
- `target`
- `primary_action`
- `entity_type`
- `entity_id`
- `created_at`
- `read_at`

### Dedupe kuralı

V1 içinde aynı aksiyon iki farklı kaynaktan gelirse source-derived object önceliklidir.

Örnek:

- pending connection request varsa ayrıca aynı olayı notification mantığı ile ikinci kez listeleme
- applicant job status update doğrudan `job_applications` üzerinden bulunuyorsa aynı aksiyonu notification kopyası olarak tekrar üretme

V1 implementation notu:

- ilk kesitte notification ailesi yalnızca doğrudan source object bulunmayan high-signal update tipleri için düşünülmelidir
- mümkün olan her yerde primary source query kullanılmalıdır

---

## 3. Başarı Tanımı

Bu feature başarılı sayılabilmesi için yalnızca yeni bir sayfa eklemiş olmak yetmez.

Minimum başarı kriterleri:

- kullanıcı tek ekrandan bugün ne yapması gerektiğini anlayabilmeli
- networking queue ve job review queue aynı yüzeyde görünür hale gelmeli
- item'lar neden gösterildiğini açıklamalı
- mevcut downstream akışlar bozulmadan çalışmalı
- backend response deterministic olmalı
- feature, mevcut hub davranışını kırmadan eklenebilmeli

İlk ölçüm seti:

- opportunity inbox view rate
- opportunity item CTR
- opportunity kind bazında primary action rate
- pending mentorship response latency
- pending connection clearance rate
- job review response speed

---

## 4. Fazlar Arası Genel Sıralama

### Faz 0

Contract freeze ve source inventory

### Faz 1

Backend aggregation foundation

### Faz 2

Ranking, explanation ve dedupe

### Faz 3

Frontend surface ve navigation cutover

### Faz 4

Telemetry ve ölçümleme

### Faz 5

Hardening ve regression safety

### Faz 6

Rollout ve first-week readout

---

## 5. Faz 0: Contract and Inventory Freeze

### Amaç

Kod yazmaya başlamadan önce V1 opportunity ailesini, source matrisini ve API wire-shape'i sabitlemek.

### Kapsam

- item family inventory
- tab taxonomy
- canonical payload shape
- dedupe policy
- target routing matrix

### Bağımlılıklar

- mevcut networking inbox payload
- mevcut jobs routing modeli
- mevcut notification deep-link convention

### Task list

#### F0-T1 Opportunity family matrix'ini sabitle

Liste:

- mentorship request
- connection request
- teacher-link update
- job application review
- job application update
- member suggestion
- job recommendation

Çıktı:

- type -> source -> category -> target matrisi

#### F0-T2 Tab taxonomy'yi sabitle

Tab seti:

- `all`
- `now`
- `networking`
- `jobs`
- `updates`

Karar:

- `now` bucket'ı priority bucket üzerinden mi yoksa category üzerinden mi çalışacak

#### F0-T3 Payload contract'ı yaz

Zorunlu alanlar:

- identity
- display text
- explanation
- CTA
- entity reference
- timestamps

#### F0-T4 Dedupe precedence'i yaz

Kural:

- source-derived aksiyon notification-derived kopyayı ezer

#### F0-T5 Canonical target matrix'i yaz

Her item için:

- hangi route'a gidecek
- hangi query state ile açılacak
- mevcut sayfa bu state'i consume ediyor mu

### Acceptance criteria

- V1'e hangi item ailelerinin girdiği tartışmasız net
- API contract tek yerde yazılı
- hiçbir item için target route belirsiz değil
- dedupe policy implementasyon öncesi tanımlı

### Faz 0 çıktıları

- opportunity family matrix
- tab model
- API shape freeze
- dedupe precedence note
- target routing matrix

---

## 6. Faz 1: Backend Aggregation Foundation

### Amaç

Opportunity Inbox için mevcut domainlerden veri toplayan backend orchestration layer'ı kurmak.

### Kapsam

- opportunity runtime
- `GET /api/new/opportunities`
- mevcut networking ve jobs query'lerinden candidate üretimi

### Bağımlılıklar

- `buildNetworkInboxPayload`
- `buildExploreSuggestionsPayload`
- jobs ve job_applications tabloları
- mevcut auth session modeli

### Task list

#### F1-T1 Opportunity runtime oluştur

Önerilen yapı:

- `server/src/opportunities/createOpportunityInboxRuntime.js`

Bu runtime:

- source query'leri çağırmalı
- internal candidate shape üretmeli
- final payload üretmeli

#### F1-T2 Networking source builders'ı bağla

Kullanılacak kaynaklar:

- incoming mentorship
- incoming connections
- unread teacher-link updates
- discovery suggestions

#### F1-T3 Jobs source builders'ı bağla

Kullanılacak kaynaklar:

- poster'a gelen pending applications
- applicant tarafındaki reviewed/accepted/rejected state
- henüz apply edilmemiş fresh jobs

#### F1-T4 Source normalizer katmanı kur

Her kaynaktan gelen veriyi tek internal forma çevir:

- `kind`
- `category`
- `score_seed`
- `target`
- `created_at`

#### F1-T5 Pagination modelini kur

V1 için:

- `limit`
- `cursor`

Cursor V1'de offset-based olabilir; ancak response deterministic sıralama vermelidir.

### Acceptance criteria

- endpoint authenticated member için çalışıyor olmalı
- hiç veri olmasa bile boş payload dönmeli
- source'lardan biri eksik olsa bile endpoint patlamamalı
- payload tek formatta dönmeli

### Faz 1 çıktıları

- opportunity runtime
- `/api/new/opportunities`
- normalized candidate builders
- empty-state safe payload

---

## 7. Faz 2: Ranking, Explanation and Dedupe

### Amaç

Opportunity Inbox'ın basit bir aggregate liste değil, gerçekten önceliklendirilmiş aksiyon kuyruğu olmasını sağlamak.

### Kapsam

- deterministic score model
- priority buckets
- why-now generation
- duplicate suppression

### Bağımlılıklar

- Faz 1 candidate layer
- mevcut network suggestion reasons
- jobs ve networking timestamps

### Task list

#### F2-T1 Base score table'ı tanımla

Önerilen öncelik:

- mentorship request
- connection request
- job application review
- job application update
- teacher-link update
- member suggestion
- fresh job recommendation

#### F2-T2 Freshness bonus ekle

Mantık:

- yeni aksiyonlar yukarı çıkmalı
- eski ama hâlâ kritik aksiyonlar düşmemeli

#### F2-T3 Trust / graph bonus ekle

Özellikle:

- verified
- suggestion reasons count
- trust badges

#### F2-T4 Why-now ve reasons alanlarını üret

Kural:

- her item insan tarafından okunabilir kısa açıklama taşımalı
- açıklama generic değil source-specific olmalı

#### F2-T5 Dedupe resolver ekle

İlk kesitte:

- source-first suppression
- aynı entity için birden fazla item üretmeme

### Acceptance criteria

- ranking order deterministic
- aynı data iki kez görünmüyor
- item açıklamaları neden şimdi gösterildiğini açıkça anlatıyor
- cold list hissi yerine guided action hissi oluşuyor

### Faz 2 çıktıları

- score model
- priority bucket model
- explanation generator
- dedupe resolver

---

## 8. Faz 3: Frontend Surface and Navigation

### Amaç

Yeni orchestration layer'ı kullanıcıya tek bir command-center yüzeyi olarak sunmak.

### Kapsam

- `/new/opportunities` route
- state hook
- tab model
- card UI
- nav cutover

### Bağımlılıklar

- Faz 1 endpoint
- Faz 2 explanation alanları
- mevcut `Layout` navigation sistemi

### Task list

#### F3-T1 Page component oluştur

Önerilen dosya:

- `frontend-modern/src/pages/OpportunityInboxPage.jsx`

Sayfa şunları göstermeli:

- hero summary
- tab strip
- ranked opportunity cards
- empty / loading / error states

#### F3-T2 Data hook oluştur

Önerilen dosya:

- `frontend-modern/src/hooks/useOpportunityInboxState.js`

Sorumluluklar:

- initial load
- tab changes
- cursor pagination
- retry

#### F3-T3 Card information hierarchy'yi kur

Kart üzerinde:

- title
- summary
- why now
- reason chips
- primary CTA

#### F3-T4 Navigation cutover yap

Kural:

- ana nav içindeki networking entry point artık fırsat yüzeyine gitmeli

Not:

- eski networking hub route'u ilk kesitte yaşamaya devam edebilir
- bu yaklaşım downstream flow güvenliği için daha düşük risklidir

#### F3-T5 Query-state modelini netleştir

Tab state:

- search param üzerinden taşınmalı

### Acceptance criteria

- kullanıcı yeni yüzeye nav'den erişebiliyor
- tab değişimleri backend data yükleme ile uyumlu
- CTA'ler mevcut sayfalara doğru query state ile yönleniyor
- loading ve empty state kullanıcıyı yönsüz bırakmıyor

### Faz 3 çıktıları

- new route
- new state hook
- new page
- nav cutover
- opportunity card UI

---

## 9. Faz 4: Telemetry and Measurement

### Amaç

Feature'ı yalnızca ship etmek değil, etkisini ölçülebilir hale getirmek.

### Kapsam

- page view
- item impression
- item open
- primary action trigger
- dismiss

### Bağımlılıklar

- stable item ids
- final tab taxonomy

### Task list

#### F4-T1 Event taxonomy'yi yaz

Önerilen eventler:

- `opportunity_inbox_viewed`
- `opportunity_item_impression`
- `opportunity_item_opened`
- `opportunity_item_action_triggered`
- `opportunity_item_dismissed`

#### F4-T2 Attribution alanlarını sabitle

Gerekli metadata:

- `kind`
- `source`
- `category`
- `priority_bucket`
- `tab`
- `position`

#### F4-T3 KPI okuma setini tanımla

Minimum:

- item CTR by kind
- action rate by kind
- now bucket clearance behavior
- jobs vs networking mix usage

### Acceptance criteria

- feature usage ölçülebiliyor olmalı
- item family bazında davranış ayrışması görülebilmeli
- post-launch readout için temel dashboard soruları cevaplanabilir olmalı

### Faz 4 çıktıları

- telemetry event taxonomy
- attribution metadata set
- KPI readout list

---

## 10. Faz 5: Hardening and Regression Safety

### Amaç

Yeni orchestration yüzeyinin mevcut networking ve jobs flow'larını bozmadığını doğrulamak.

### Kapsam

- new contract test
- regression runs
- partial data safety

### Bağımlılıklar

- endpoint tamamlanmış olmalı
- target routes stabilize olmuş olmalı

### Task list

#### F5-T1 Opportunity Inbox contract test ekle

Test etmesi gerekenler:

- mentorship request ranking
- connection request ranking
- job review item üretimi
- applicant job update item üretimi
- teacher-link update item üretimi
- suggestion item üretimi
- jobs recommendation item üretimi
- tab filtering
- pagination

#### F5-T2 Reused regression suite'leri çalıştır

Özellikle:

- networking hub contract
- jobs applications contract

#### F5-T3 Empty and partial-state güvenliği test et

Senaryolar:

- jobs tablosu yok
- job_applications tablosu yok
- notifications içinde `read_at` yok
- networking discovery boş

### Acceptance criteria

- new endpoint contract test ile korunuyor olmalı
- mevcut ilgili suite'ler geçmeli
- eksik tablo veya boş source durumunda endpoint 500 üretmemeli

### Faz 5 çıktıları

- contract coverage
- regression pass list
- partial-data hardening note

---

## 11. Faz 6: Rollout and First-Week Readout

### Amaç

Feature'ı düşük riskle görünür hale getirmek ve ilk haftada gerçekten değer üretip üretmediğini anlamak.

### Kapsam

- launch sequence
- rollback yaklaşımı
- first-week scorecard

### Bağımlılıklar

- Faz 5 doğrulaması

### Task list

#### F6-T1 Launch sequence yaz

Önerilen sıra:

1. internal verification
2. nav exposure
3. controlled observation
4. wider default usage

#### F6-T2 Rollback note yaz

İlk rollback adımı:

- nav'i eski networking hub route'una döndür

#### F6-T3 First-week scorecard hazırla

Karşılaştırma başlıkları:

- opportunity page usage
- hub'a kıyasla queue action speed
- jobs review speed
- mentorship response speed
- item family CTR

### Acceptance criteria

- launch ve rollback tek cümlelik kararlarla uygulanabilir olmalı
- ilk hafta sonunda feature'in tutulup tutulmayacağına dair yeterli veri okunabiliyor olmalı

### Faz 6 çıktıları

- launch checklist
- rollback note
- week-one scorecard template

---

## 12. Test and Verification Strategy

Ana automated coverage backend contract test üzerinden kurulmalıdır.

### Yeni test

- `server/tests/contracts/phase2-opportunity-inbox.mjs`

### Reused regression

- `server/tests/contracts/phase2-network-hub.mjs`
- `server/tests/contracts/phase2-jobs-applications.mjs`

### Manual frontend acceptance checklist

- `/new/opportunities` route authenticated member için açılıyor mu
- tab değişimleri doğru data getiriyor mu
- nav item yeni yüzeye gidiyor mu
- kart CTA'leri doğru downstream sayfaya gidiyor mu
- mixed-source items aynı sayfada okunabilir duruyor mu
- empty state yönlendirici mi
- error state retry ile toparlanıyor mu

Planlama sırasında mevcut frontend için yerleşik bir test harness bulunmadığı için V1 frontend doğrulaması manuel smoke + route verification ile yapılmalıdır.

---

## 13. Varsayımlar

- V1'de schema migration yapılmayacak
- nav cutover yapılacak, ancak eski networking hub ilk kesitte erişilebilir tutulabilir
- existing domain endpoints mutation source of truth olarak kalacak
- deterministic ranking code içinde tutulacak
- admin tuning paneli sonraki iterasyona bırakılacak
- notification layer yalnızca stronger source object yoksa secondary source olarak ele alınacak

---

## 14. Sonuç

Opportunity Inbox V1'in doğru ilk versiyonu, yeni bir feature island yaratmak değildir.

Doğru ilk versiyon:

- mevcut SDAL graph ve action surface'lerini tek bir orchestration layer'da toplamak,
- kullanıcıya en yüksek değerli bir sonraki adımı açıklanabilir biçimde göstermek,
- bunu mevcut akışları bozmadan yapmak,
- ve launch sonrası davranışı ölçebilmektir.

Bu phased plan bu hedefi düşük riskli ve implementasyon açısından karar-tamamlanmış bir sıraya bağlar.
