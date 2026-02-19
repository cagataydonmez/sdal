import React from 'react';
import Layout from '../components/Layout.jsx';

export default function HelpPage() {
  return (
    <Layout title="Yardım Merkezi">
      <div className="panel">
        <h3>Hızlı Başlangıç</h3>
        <div className="panel-body stack">
          <div><b>1. Profilini tamamla:</b> `/new/profile` sayfasında isim, şehir, meslek ve imza bilgilerini güncelle.</div>
          <div><b>2. Akışa katıl:</b> `/new` sayfasında gönderi paylaş, yorum yap, beğeni bırak.</div>
          <div><b>3. Üye keşfet:</b> `/new/explore` ile takip edeceğin kişileri bul.</div>
          <div><b>4. Bildirimlerini kontrol et:</b> `/new/notifications` sayfasından tüm geçmişe eriş.</div>
          <div><b>5. Etkinlik ve duyuru:</b> `/new/events` ve `/new/announcements` üzerinden topluluğu takip et.</div>
        </div>
      </div>

      <div className="panel">
        <h3>Akış ve Hikayeler</h3>
        <div className="panel-body stack">
          <div><b>Gönderi filtreleri:</b> Akışta <code>Tümü</code>, <code>Takip Ettiklerim</code> ve <code>Popüler</code> sekmelerini kullan.</div>
          <div><b>Hikaye gezinme:</b> Swipe yanında fotoğrafın soluna dokunarak geri, sağına dokunarak ileri geçebilirsin.</div>
          <div><b>Görsel yükleme:</b> Sistem görselleri kırpmadan uygun çözünürlüğe optimize eder, tam görünüm korunur.</div>
        </div>
      </div>

      <div className="panel">
        <h3>Metin Biçimlendirme</h3>
        <div className="panel-body stack">
          <div>Gönderi düzenleyicideki <b>A+</b> butonu gelişmiş biçimlendirme panelini açar.</div>
          <div>Anlık önizleme ile yazdığın içeriği yayınlamadan görebilirsin.</div>
          <div>Desteklenen etiket örnekleri:</div>
          <code>[b]kalın[/b] [i]italik[/i] [u]altı çizili[/u] [s]üstü çizili[/s]</code>
          <code>[left]sol[/left] [center]orta[/center] [right]sağ[/right]</code>
          <code>[size=18]büyük yazı[/size] [color=#1b7f6b]renkli yazı[/color]</code>
          <code>[quote]alıntı bloğu[/quote]</code>
        </div>
      </div>

      <div className="panel" id="engagement-score">
        <h3>Etkileşim Skoru Nasıl Kullanılır?</h3>
        <div className="panel-body stack">
          <div><b>Ne işe yarar:</b> Üyelerin topluluk içindeki etkileşim düzeyini ölçer; öneri ve sıralama mekanizmalarında kullanılır.</div>
          <div><b>Skoru artırmak için:</b> düzenli paylaşım, kaliteli yorum, doğal takip etkileşimi, hikaye ve mesaj aktivitesi önemlidir.</div>
          <div><b>Skoru düşürebilecek durumlar:</b> düşük kaliteli yoğun paylaşım, agresif takip davranışı, uzun süre pasif kalma.</div>
          <div><b>Pratik örnek:</b> Haftada 3 anlamlı paylaşım + ilgili yorumlar + gerçek etkileşimli takip ilişkileri, skor trendini istikrarlı artırır.</div>
          <div><b>Yönetim için:</b> `/new/admin` altındaki <b>Etkileşim Skorları</b> sekmesinden metrik kırılımı, A/B varyantları ve önerileri görüntüleyebilirsin.</div>
        </div>
      </div>

      <div className="panel">
        <h3>Sık Sorulanlar</h3>
        <div className="panel-body stack">
          <div><b>Reddet butonu ne yapar?</b> Etkinlik/duyuru önerisini yayına almadan reddeder; içerik herkese görünmez.</div>
          <div><b>Canlı sohbette eski mesajları nasıl görürüm?</b> Sohbet kutusunda yukarı kaydırdıkça daha eski mesajlar yüklenir.</div>
          <div><b>Dil değiştirme:</b> Üst barda bulunan dil seçiciden Türkçe, İngilizce, Almanca, Fransızca arasında geçiş yapabilirsin.</div>
        </div>
      </div>
    </Layout>
  );
}
