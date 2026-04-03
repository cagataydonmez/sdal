# SDAL Networking Hub & Teacher Network Executive Summary

Bu doküman, SDAL içindeki `Sosyal Ağ Merkezi` ve `Öğretmen Ağı` modüllerini teknik detaya girmeden, karar verici ve ürün sahibi perspektifinden özetlemek için hazırlanmıştır.

Ana referans doküman:

- `docs/networking-hub-teacher-network-playbook.md`

Bu özetin amacı:

- bu iki modülün neden önemli olduğunu netleştirmek,
- ürün değerini kısa ve anlaşılır biçimde ortaya koymak,
- mevcut güçlü yönleri ve riskleri üst seviyede toplamak,
- sonraki yatırım alanlarını işaret etmektir.

---

## 1. Yönetici Özeti

SDAL'ın modern ürün vizyonunda networking katmanı sadece "birbirine mesaj atan kullanıcılar" üretmek için değil, okul bağlamında güvene dayalı bir dijital mezun graph'ı kurmak için vardır.

Bu bağlamda iki modül öne çıkar:

### 1.1 Sosyal Ağ Merkezi

Sosyal Ağ Merkezi, kullanıcının bağlantı, mentorluk ve öğretmen ağı ile ilgili bekleyen tüm hareketlerini tek ekranda yönettiği operasyon panelidir.

Bu ekran:

- gelen bağlantı taleplerini,
- giden talepleri,
- mentorluk akışını,
- öğretmen ağı bildirimlerini,
- networking sağlığına dair temel metrikleri,
- sistemin önerdiği yeni ilişki adaylarını

aynı yerde toplar.

Bu nedenle ürün içindeki rolü bir "network operations console" olarak okunmalıdır.

### 1.2 Öğretmen Ağı

Öğretmen Ağı, mezunların geçmiş öğretmen ilişkilerini platforma anlamlı ve güven üretici bir bağ olarak eklediği modüldür.

Bu modül:

- okul geçmişini dijital graph'a dönüştürür,
- öğretmen-mezun bağına görünürlük kazandırır,
- trust badge sistemini besler,
- öneri motoru için yeni bir kalite sinyali üretir.

Bu nedenle ürün içindeki rolü yalnızca bir form ekranı değil, trust graph builder olarak değerlendirilmelidir.

---

## 2. Neden Stratejik Olarak Önemli?

Bu modüller SDAL'ı klasik mezun listesi yaklaşımından ayırır.

### 2.1 Topluluk değerini güçlendirir

Kullanıcılar sadece profil görmez; ilişki kurar, ilişki yönetir ve geçmiş bağlarını görünür kılar.

### 2.2 Güven üretir

Verification ve teacher-link yapısı sayesinde oluşan graph rastgele değil, bağlamsal ve kontrollüdür.

### 2.3 Profesyonel katmanı destekler

Mentorluk, bağlantı kurma ve öğretmen graph'ı birlikte çalıştığında platformdaki profesyonel ağ daha anlamlı hale gelir.

### 2.4 Suggestion kalitesini artırır

Teacher network ve accepted connections, öneri motoruna ek sinyal sağlar.

### 2.5 Admin görünürlüğü sağlar

Teacher Network kayıtları ve networking funnel metrikleri yönetimsel gözlem için kullanılabilir.

---

## 3. Kullanıcıya Sağladığı Ana Faydalar

### 3.1 Mezun için

- kimden istek geldiğini kaçırmaz,
- bağlantı ve mentorluk akışını tek ekranda görür,
- öğretmenlerini sisteme bağlayarak profil bağlamını zenginleştirir,
- önerilen kişilerle tanışmayı kolaylaştırır.

### 3.2 Öğretmen için

- hangi mezunların kendisini sisteme bağladığını görür,
- school memory ve alumni continuity hissi oluşur,
- mentorluk ve görünürlük açısından doğal bir konum kazanır.

### 3.3 Platform için

- güvene dayalı sosyal graph oluşur,
- onboarding sonrası ilk networking başarısı ölçülebilir,
- keşif motoru daha akıllı hale gelir,
- moderasyon ve analitik mümkün olur.

---

## 4. Bugün Ne Kadar Olgun?

Mevcut durumda bu modüller temel olarak çalışır durumdadır.

### 4.1 Güçlü taraflar

- route ve ekran yapısı net
- verification gate var
- connection, mentorship ve teacher link akışları backend'de tanımlı
- contract testler mevcut
- teacher network için admin görünürlüğü var
- suggestion engine teacher graph sinyalini kullanıyor

### 4.2 Son dönemde iyileşen noktalar

- teacher deep-link akışı düzeltildi
- networking hub performansı iyileştirildi
- optimistic UI ile aksiyon gecikmesi azaltıldı
- sayfa zıplaması azaltıldı

---

## 5. Ana Problemler

Bu modüller güçlü olsa da ilk bakışta anlaşılması zor olabilir.

### 5.1 Kavramsal karmaşıklık

Kullanıcı açısından şu kavramlar birbirine yakın duruyor:

- connection
- follow
- mentorship
- teacher link

Bu ayrım ürün mantığında net, ama kullanıcı arayüzünde yeterince açıklanmıyor olabilir.

### 5.2 Teacher Network değeri kendini hemen anlatmıyor

Kullanıcı "öğretmenimi ekleyince tam olarak ne kazanıyorum?" sorusunu sorabilir.

### 5.3 Networking Hub çok fazla işlevi tek yerde topluyor

Bu iyi bir merkeziyet sağlasa da ilk kullanımda bilişsel yük yaratabilir.

### 5.4 Teknik olarak hâlâ fazladan ağ çağrısı var

Sayfa son iyileştirmelerle hızlandı ama tam tekil aggregate endpoint yaklaşımına henüz geçilmiş değil.

---

## 6. İş Değeri Açısından Karar Cümlesi

Bu iki modül SDAL'ın topluluk ve profesyonel ağ stratejisinde çekirdek özelliklerdir. Kaldırılması veya geri plana itilmesi gereken yan özellikler değildir. Tersine, daha net anlatılması, daha görünür hale getirilmesi ve ürün içinde daha güçlü konumlandırılması gerekir.

---

## 7. Kısa Öneri Seti

### 7.1 Kısa vadede

- Teacher Network değerini daha iyi anlatan açıklama katmanı eklenmeli
- Networking Hub içinde "öncelikli aksiyon" alanı olmalı
- trust badge anlamları daha görünür yapılmalı

### 7.2 Orta vadede

- tek aggregate networking endpoint tasarlanmalı
- teacher graph etkisi profile seviyesinde daha görünür kılınmalı
- networking başarı metrikleri dashboard'a bağlanmalı

### 7.3 Uzun vadede

- teacher graph yoğunluk analizi
- graph güven skoru
- cohort bazlı networking benchmark
- teacher network tabanlı öneri kişiselleştirme

---

## 8. Bu Özet Hangi Kararlar İçin Kullanılır?

Bu doküman şu sorular için uygundur:

- Bu modüller yatırım yapılacak kadar önemli mi?
- Hangi ürün hikayesi ile anlatılmalı?
- Yönetim veya ürün tarafına nasıl özetlenmeli?
- Neyi koruyup neyi sadeleştirmeliyiz?

Detaylı teknik ve ürün açıklamaları için ana dokümana dönülmelidir:

- `docs/networking-hub-teacher-network-playbook.md`

