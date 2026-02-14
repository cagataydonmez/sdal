import React from 'react';
import Layout from '../components/Layout.jsx';

export default function HelpPage() {
  return (
    <Layout title="Yardım">
      <div className="panel">
        <h3>Nasıl Kullanılır?</h3>
        <div className="panel-body">
          <div><b>Akış:</b> Paylaşım yap, yorum yaz, beğen. Fotoğraf yüklerken filtre seçebilirsin.</div>
          <div><b>Keşfet:</b> Üye arama ve takip etme ekranı.</div>
          <div><b>Takip Ettiklerim:</b> Takip ettiğin üyeleri listele, tek tıkla takibi bırak.</div>
          <div><b>Mesajlar:</b> Özel mesaj gönder/al, arama ile hızlı bul.</div>
          <div><b>Fotoğraflar:</b> Albüm gez, fotoğraf yorumla.</div>
          <div><b>Etkinlikler:</b> Etkinlik önerisi gönder, yorum yap, takipçilerini haberdar et.</div>
          <div><b>Duyurular:</b> Duyuru önerisi gönder; admin onayı sonrası yayınlanır.</div>
          <div><b>Gruplar:</b> İlgi alanına göre grup oluştur, katıl, grup içinde paylaşım yap.</div>
          <div><b>Bahsetme:</b> Gönderi/yorum içinde <code>@kullaniciadi</code> yazarak bildirim gönderebilirsin.</div>
          <div><b>Biçimlendirme:</b> <code>[b]kalın[/b]</code>, <code>[i]italik[/i]</code>, <code>[u]altı çizili[/u]</code> gibi etiketler desteklenir.</div>
        </div>
      </div>
    </Layout>
  );
}
