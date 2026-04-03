# SDAL Networking Hub & Teacher Network Sprint 1 Baseline

Bu doküman, Sprint 1 implementasyonuna başlamadan önce sabitlenen temel zemini içerir.

Amaç:

- ürün dilini netleştirmek,
- hangi metriklerle ilerlemeyi ölçeceğimizi belirlemek,
- Sprint 1 kapsamını dondurmak,
- bilinen riskleri görünür kılmaktır.

Referans:

- `docs/networking-hub-teacher-network-playbook.md`
- `docs/networking-hub-teacher-network-phased-task-plan.md`
- `docs/networking-hub-teacher-network-execution-backlog.md`

---

## 1. Terminology Sheet

Sprint 1 boyunca aşağıdaki ürün dili kullanılacaktır.

### Connection

İki mezun arasında karşılıklı networking ilişkisi.

UI dili:

- `Bağlantı`
- `Bağlantı isteği`
- `Bağlantıyı kabul et`

### Follow

Bir üyeyi tek taraflı takip etme davranışı.

UI dili:

- `Takip et`
- `Takibi bırak`

Not:

- Follow, connection ile aynı şey değildir.
- Sprint 1 içinde bu ayrım copy seviyesinde korunacaktır.

### Mentorship Request

Bir kullanıcının başka bir kullanıcıdan mentorluk talep etmesi.

UI dili:

- `Mentorluk talebi`
- `Gelen mentorluk talepleri`
- `Gönderdiğin mentorluk talepleri`

### Teacher Link

Bir mezunun, bir öğretmen ile olan bağını kayıt altına aldığı ilişki.

UI dili:

- `Öğretmen bağı`
- `Öğretmen bağlantısı`

Not:

- Teknik olarak `teacher link` olarak anılabilir.
- Kullanıcıya gösterimde öncelikli dil `öğretmen bağlantısı` olacaktır.

### Teacher Network

Öğretmen bağlarının biriktiği ürün yüzeyi ve graph katmanı.

UI dili:

- `Öğretmen Ağı`
- `Teacher Network`

Not:

- Menü ve ekran adı olarak mevcut kullanım korunur.

### Trust Badge

Profil güven sinyallerini ifade eden rozet katmanı.

UI dili:

- `Güven rozeti`
- `Öğretmen Ağına Dahil`
- `Doğrulanmış Mezun`
- `Mentor`

---

## 2. Metric Baseline

Sprint 1 sonunda takip edilmesi gereken minimum metrik seti:

### M1 Hub açılış süresi

Tanım:

- `/new/network/hub` rotasının açılışından ilk anlamlı panel görünümüne kadar geçen süre.

Amaç:

- kullanıcı tarafından hissedilen başlangıç hızını izlemek.

### M2 First meaningful panel render

Tanım:

- Hub sayfasında hero sonrası ilk operasyonel blokların kullanıcıya görünür hale gelmesi.

Sprint 1 yorumu:

- priority strip + metrics + ilk queue kartları kullanıcıya görünmelidir.

### M3 Connection request accept rate

Tanım:

- gelen bağlantı isteklerinden kabul edilenlerin oranı.

Amaç:

- queue açıklığı ve CTA netliğinin etkisini izlemek.

### M4 Teacher link completion rate

Tanım:

- Teacher Network formunu açan kullanıcıların başarıyla öğretmen bağlantısı oluşturma oranı.

Amaç:

- değer paneli ve helper text etkisini izlemek.

### M5 Teacher link abandonment rate

Tanım:

- formu başlatıp bağlantıyı kaydetmeden ayrılan kullanıcı oranı.

Amaç:

- form sürtünmesini görmek.

### M6 Time to first network success

Tanım:

- bir kullanıcının ilk başarılı networking çıktısını elde etmesine kadar geçen gün.

Başarılı çıktı örnekleri:

- connection accept
- accepted mentorship
- teacher link creation

---

## 3. Sprint 1 Scope Freeze

Sprint 1 içine dahil:

- Networking Hub priority strip
- Hub section helper text iyileştirmeleri
- Hub empty-state microcopy iyileştirmeleri
- Teacher Network kalıcı değer paneli
- Teacher Network ilişki türü helper text
- Sprint 1 terminology, metrics, risk ve scope dokümantasyonu

Sprint 1 dışında:

- aggregate hub endpoint
- reducer tabanlı yeni hub state mimarisi
- networking API response shape standardizasyonu
- teacher graph confidence score sistemi
- admin moderation genişletmeleri
- telemetry pipeline implementasyonu

Karar:

- Sprint 1, hissedilen ürün açıklığını artıran düşük riskli UX işleri ile sınırlı kalacaktır.
- Teknik sadeleştirme işleri Sprint 2 ve Sprint 3'e taşınacaktır.

---

## 4. Risk Register

### R1 Kavramların hâlâ birbirine yakın görünmesi

Risk:

- connection, mentorship ve teacher network aksiyonları aynı sayfada olduğu için kullanıcı zihninde karışabilir.

Yanıt:

- section description ve priority strip dili daha öğretici hale getirildi.

### R2 Copy artışıyla ekranın fazla yoğun görünmesi

Risk:

- daha çok açıklama eklemek sayfayı kalabalık hissettirebilir.

Yanıt:

- açıklamalar kısa tutulmalı, her panelde tek cümleyi geçmemelidir.

### R3 CTA anchor akışlarının tutarsız davranması

Risk:

- sayfa içi yönlendirmeler beklenmedik scroll davranışı oluşturabilir.

Yanıt:

- Sprint 1 sonrası elle scroll ve mobile viewport testi yapılmalıdır.

### R4 Teacher Network formunun bilgi yükü artması

Risk:

- değer paneli doğru kurgulanmazsa formun yanında ek dikkat dağıtıcı blok oluşabilir.

Yanıt:

- değer paneli bilgi yoğun değil, fayda odaklı ve kısa bloklarla sınırlandırılmalıdır.

### R5 Ölçüm zemininin henüz teknik olarak tam bağlı olmaması

Risk:

- metrikler tanımlansa da telemetry implementasyonu daha sonraki sprinttedir.

Yanıt:

- Sprint 1 sonunda ölçüm tanımları kesinleşmiş olacak, telemetry implementasyonu Sprint 5'te alınacaktır.

---

## 5. Sprint 1 Acceptance Frame

Sprint 1 sonunda şu sorulara net cevap verilebilmelidir:

- Hub sayfasına ilk gelen kullanıcı nereden başlayacağını anlıyor mu?
- Boş state'ler kullanıcıya sonraki adımı söylüyor mu?
- Teacher Network ekranında "neden bu kaydı ekliyorum?" sorusu ek açıklama olmadan anlaşılabiliyor mu?
- Ürün ekibi aynı kavramları aynı dil ile kullanıyor mu?

Bu çerçeve sağlanmadan Sprint 2'nin state ve performans yatırımlarına geçilmemelidir.
