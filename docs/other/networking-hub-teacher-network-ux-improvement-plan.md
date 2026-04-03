# SDAL Networking Hub & Teacher Network UX Improvement Plan

Bu doküman, `Sosyal Ağ Merkezi` ve `Öğretmen Ağı` modüllerinin ekran bazlı UX iyileştirme planını içerir.

Amaç:

- kullanıcı açısından anlaşılması zor noktaları sadeleştirmek,
- bilişsel yükü azaltmak,
- değer önerisini daha görünür kılmak,
- aksiyon hızını ve güven hissini artırmak,
- ekranları daha öğretici ve daha yönlendirici hale getirmektir.

Referans:

- `docs/networking-hub-teacher-network-playbook.md`

---

## 1. Tasarım Probleminin Özeti

Bugünkü yapı teknik olarak çalışıyor olsa da kullanıcı açısından üç temel sorun alanı var:

### 1.1 Kavram karmaşası

Kullanıcı şu kavramları kolayca karıştırabilir:

- bağlantı kurma,
- takip etme,
- mentorluk talebi,
- öğretmen ağına ekleme.

### 1.2 Değer önerisinin yeterince görünmemesi

Özellikle Teacher Network tarafında kullanıcı şu soruyu sorabilir:

"Bunu neden yapıyorum?"

### 1.3 Eylem önceliğinin net olmaması

Networking Hub çok faydalı ama ilk bakışta hangi işi önce yapmak gerektiği çok net olmayabilir.

---

## 2. UX Tasarım İlkeleri

Bu modüller için önerilen temel UX ilkeleri:

### 2.1 Önce açıklık, sonra yoğunluk

İlk 5 saniyede kullanıcı şu üç şeyi anlamalı:

- bu ekran ne işe yarıyor,
- şu an benden ne bekleniyor,
- bu işlem bana ne kazandıracak.

### 2.2 Durum yönetimi görünür olmalı

Pending, accepted, declined, linked gibi durumlar kullanıcı zihninde kolay izlenebilmelidir.

### 2.3 Aksiyon sonucu anında hissedilmeli

Butona basınca:

- kart anında değişmeli,
- sayaç mantıklı biçimde güncellenmeli,
- kullanıcı "işlem oldu" hissini beklemeden almalı.

### 2.4 Öğretici boş durumlar kullanılmalı

Boş ekranlar sadece "yok" dememeli; "neden yok ve ne yapabilirsin?" de söylemeli.

### 2.5 Güven sinyalleri görünür olmalı

Teacher link, verification ve mentor rozetleri sadece dekoratif olmamalı; anlamı açıklanmalı.

---

## 3. Networking Hub: UX İyileştirme Planı

### 3.1 Amaç

Networking Hub, kullanıcının network operasyonlarını yönettiği ekran olarak daha net davranmalı.

Bugünkü algı:

- bilgi dolu
- güçlü
- ama ilk kullanımda biraz yoğun

Hedef algı:

- ne yapacağı belli
- önceliklendirilmiş
- hızlı
- güven veren

### 3.2 Bilgi mimarisi önerisi

Mevcut bölümler korunabilir, ama görünür öncelik sırası iyileştirilmeli.

Önerilen sıralama:

1. `Şimdi ilgilenmen gerekenler`
2. `Networking sağlığın`
3. `Öğretmen ağı bildirimleri`
4. `Giden kuyruklar`
5. `Sana önerilen kişiler`

Sebep:

- kullanıcı önce bekleyen aksiyonları çözmek ister
- metrikler ikinci sırada okunur
- keşif bölümü operasyon bölümlerinden sonra gelmelidir

### 3.3 Yeni üst bölüm önerisi: Priority Strip

Yeni modül:

- sayfanın üstünde kısa, sabit bir "öncelik şeridi"

İçerik örnekleri:

- `3 bağlantı isteği seni bekliyor`
- `1 mentorluk talebi cevap bekliyor`
- `2 öğretmen ağı bildirimi yeni`

CTA örnekleri:

- `Şimdi İncele`
- `Tümünü Gör`

Beklenen fayda:

- sayfanın amacı ilk saniyede anlaşılır
- kullanıcı nereden başlayacağını bilir

### 3.4 Kart içi microcopy iyileştirmesi

Bugün aksiyon metinleri fonksiyonel ama öğretici değil.

Öneriler:

- `Bağlantıyı Kabul Et`
- alt satır: `Kabul edince karşılıklı bağlantı oluşur`

- `Yoksay`
- alt satır: `Karşı tarafa kabul edilmediği bildirilmez`

Mentorluk için:

- `Kabul Et`
- alt satır: `Bu kullanıcı seni aktif mentor olarak görecek`

Teacher notification için:

- `Bir mezun seni öğretmen graph'ına ekledi`

### 3.5 Metrik kartları için açıklama katmanı

Metrik kartları güçlü ama bağlam eksik olabilir.

Öneri:

Her karta küçük `i` bilgi ikonu veya açılır açıklama:

- `Bağlantılar`
  - bu periyotta kabul edilen networking bağlantıları

- `Bekleyen istekler`
  - cevap bekleyen inbound/outbound request yükü

- `Mentorluk`
  - bu dönemde kabul edilen mentorluk akışları

- `Öğretmen Ağı`
  - senin oluşturduğun teacher link sayısı

### 3.6 Suggestion kartları için daha açıklayıcı tasarım

Bugün reason bilgisi var ama daha güçlü gösterilebilir.

Öneriler:

- reason chip kullanımı
- trust badge ile suggestion reason ayrılmalı
- örnek chip'ler:
  - `2 ortak bağlantı`
  - `Aynı mezuniyet yılı`
  - `Öğretmen ağında yakın`
  - `Mentor`

Kart düzeni:

- üstte kişi bilgisi
- ortada "neden önerildi"
- altta aksiyonlar

### 3.7 Session feedback alanı

Şu an feedback alanı sabitlenmiş durumda, bu iyi.

Ek öneri:

- işlem başarılıysa yeşil toast yerine kartın üzerinde de kısa süreli state değişimi göster
- örnek:
  - `İstek gönderildi`
  - `Bağlantı kabul edildi`

### 3.8 Empty state önerileri

#### Gelen bağlantı isteği boşsa

Önerilen metin:

`Şu an bekleyen bir bağlantı isteğin yok. Yeni kişiler keşfetmek için öneri kartlarına göz atabilirsin.`

#### Mentorluk kuyruğu boşsa

Önerilen metin:

`Aktif mentorluk talebi yok. Mentor görünürlüğünü artırmak için profilini güncelleyebilirsin.`

#### Teacher notification boşsa

Önerilen metin:

`Henüz öğretmen ağı bildirimi yok. Öğretmen profilleri mezunlar tarafından eklendikçe burada görünür.`

---

## 4. Teacher Network: UX İyileştirme Planı

### 4.1 Ana sorun

Teacher Network'ün teknik işlevi güçlü ama "neden faydalı" kısmı kullanıcıya yeterince görünür değil.

Hedef:

- kullanıcı sadece form doldurmasın,
- ne inşa ettiğini de hissetsin.

### 4.2 Form yanına kalıcı değer paneli

Önerilen sağ panel:

Başlık:

- `Bu kayıt ne işe yarar?`

İçerik:

- öğretmen bağını görünür hale getirir
- profil güven sinyalini güçlendirir
- öneri motoruna ek bağlam sağlar
- öğretmene bildirim gider

Bu panel ekranın vazgeçilmez parçası olmalı.

### 4.3 İlişki türü seçimini daha anlaşılır yapmak

Bugün select çalışıyor ama eğitimsel değil.

Öneri:

Seçim altında açıklama alanı:

- `Aynı sınıfta ders aldım`
  - sınıf veya dönem bazlı öğretmen ilişkisi

- `Mentor`
  - okul sonrası veya kariyer sürecinde rehberlik eden öğretmen

- `Danışman`
  - akademik veya bireysel yönlendirme yapan öğretmen

### 4.4 Deep-link durumunu daha görünür yapmak

Profile'dan gelen kullanıcı için bugün chip var. Bu iyi ama daha da görünür olabilir.

Öneri:

- `Bu öğretmeni profil üzerinden seçtin`
- `İstersen ilişki bilgisini tamamlayıp doğrudan kaydedebilirsin`

### 4.5 Seçili öğretmen önizlemesinin güçlendirilmesi

Mevcut önizleme yapısı korunabilir ama şunlar eklenebilir:

- linked alumni count
- subject/role bilgisi
- mini trust açıklaması

Örnek:

`Bu kayıt, öğretmen profilinin mezun graph'ında görünmesine katkı sağlar.`

### 4.6 History alanı için daha güçlü etiketleme

Bugün `Öğretmenlerim / Öğrencilerim` ayrımı var.

Öneriler:

- segment control olarak daha görünür sun
- aktif segment altına kısa açıklama yaz
- kartlarda relationship_type'ı daha görsel chip yap

### 4.7 Post-submit success state

Kullanıcı kayıt yaptığında başarı mesajı sadece işlemin başarılı olduğunu söylemekle kalmamalı.

Önerilen başarı mesajı:

`Öğretmen bağlantısı kaydedildi. İlgili öğretmen hesabına bildirim gönderildi ve bu ilişki SDAL öğretmen graph'ına eklendi.`

### 4.8 Empty history state

Önerilen metin:

`Henüz kayıtlı bir öğretmen bağı yok. Profil ekranlarından veya öğretmen araması yaparak ilk bağlantını oluşturabilirsin.`

---

## 5. Profil ve Explore Entegrasyonları İçin UX Önerileri

### 5.1 Member detail CTA kümesi

Bugün aynı ekranda şu aksiyonlar bulunabiliyor:

- mesaj gönder
- hızlı erişime ekle
- bağlantı kur
- öğretmen ağına ekle
- mentorluk talep et

Bu yoğunluğu azaltmak için:

- primary action bir tane olmalı
- secondary action gruplandırılmalı

Öneri:

- primary: `Mesaj Gönder` veya `Bağlantı Kur`
- secondary dropdown: `Diğer Aksiyonlar`

### 5.2 Teacher CTA açıklaması

`Öğretmen Ağına Ekle` butonu daha açıklayıcı hale getirilebilir:

- `Öğretmen Olarak Bağla`
- alt açıklama: `Geçmiş öğretmen ilişkini SDAL ağına ekle`

### 5.3 Explore kartlarında Teacher Network badge anlatımı

Badge'e hover/tooltip:

- `Bu kullanıcı öğretmen graph'ında yer alıyor`

---

## 6. İçerik ve Dil Önerileri

Bu modüllerin anlaşılmasında dil kritik.

### 6.1 Önerilen kelime standardı

- `Bağlantı` = modern networking relation
- `Takip` = daha hafif, yönlü sosyal ilgi
- `Mentorluk` = rehberlik ilişkisi
- `Öğretmen Bağı` = tarihsel öğretmen ilişkisi

### 6.2 Kullanılmaması önerilen belirsiz diller

- sadece `istek` demek
- sadece `ekle` demek
- sadece `ağ` demek

Bunlar bağlamı zayıflatır.

### 6.3 Önerilen ifade örnekleri

- `Bağlantı isteği gönder`
- `Mentorluk talebi gönder`
- `Öğretmen bağı oluştur`
- `Öğretmen graph'ına ekle`

---

## 7. Bilgi Yoğunluğu Yönetimi

### 7.1 Progressive disclosure

Her şeyi aynı anda göstermemek gerekir.

Öneri:

- önce özet
- sonra detay
- sonra açıklama

Örneğin:

- kartta 1 reason
- açılır detayda tüm reason'lar

### 7.2 Bölüm başına tek ana mesaj

#### Networking Hub

- Gelen bağlantılar: `bunları yönet`
- Metrikler: `durumunu ölç`
- Öneriler: `bunları değerlendir`

#### Teacher Network

- Form: `ilişki oluştur`
- Önizleme: `seçimi doğrula`
- Geçmiş: `graph'ını gör`

---

## 8. Erişilebilirlik ve Mobil Önerileri

### 8.1 Mobilde section collapse

Hub çok uzun olduğunda mobilde section collapse faydalı olabilir.

Öneri:

- `Gelen bağlantılar`
- `Mentorluk`
- `Öneriler`

alanları collapsible olabilir.

### 8.2 Sticky action footer

Teacher Network formunda mobilde submit butonu ekran altına sabitlenebilir.

### 8.3 Form label açıklıkları

Teacher Network relation type ve class year alanlarında helper text görünür olmalı.

---

## 9. Deney Tasarımı İçin A/B Test Önerileri

### Test 1

`Bağlantı Kur` vs `Tanışma İsteği Gönder`

Amaç:

- hangi dil daha fazla conversion üretiyor?

### Test 2

Teacher Network CTA:

- `Öğretmen Ağına Ekle`
- `Öğretmen Olarak Bağla`

Amaç:

- daha açıklayıcı ifade adoption'ı artırıyor mu?

### Test 3

Suggestion card reason görünümü:

- tek satır metin
- chip listesi

Amaç:

- hangi görünüm daha çok connection action üretiyor?

---

## 10. Önerilen UX Sprint Sırası

### UX Sprint 1

- Hub priority strip
- better empty states
- trust badge tooltip'leri
- success microcopy güncellemesi

### UX Sprint 2

- Teacher Network value panel
- relation type helper text
- deep-link state açıklaması
- history görünümü iyileştirmesi

### UX Sprint 3

- Member detail action grouping
- Explore suggestion chips iyileştirmesi
- A/B test hazırlıkları

---

## 11. Başarı Ölçütleri

Bu UX iyileştirmelerinin başarılı sayılması için:

- kullanıcı Teacher Network'ün amacını daha hızlı anlamalı
- hub ekranındaki ilk aksiyon süresi düşmeli
- connection / teacher link conversion artmalı
- yanlış veya yarım bırakılmış öğretmen link formu oranı azalmalı
- boş ekranlardan çıkış oranı artmalı

---

## 12. Sonuç

Bu iki modülün ana problemi fikir zayıflığı değil, fikir yoğunluğudur. İçlerinde güçlü bir ürün değeri var, ancak bu değer kullanıcıya ilk bakışta tam aktarılmıyor.

Bu nedenle UX yatırımının odağı:

- açıklama,
- önceliklendirme,
- kavram ayrıştırma,
- güven sinyali görünürlüğü,
- aksiyon sonuçlarının daha net hissettirilmesi

olmalıdır.

Doğru UX katmanı eklendiğinde bu modüller SDAL'ın en ayırt edici ve en yüksek bağ kuran özellikleri arasına girebilir.

