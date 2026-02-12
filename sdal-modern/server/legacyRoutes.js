export const legacyToModern = {
  'default.asp': '/',
  'uyegiris.asp': '/login',
  'cikis.asp': '/logout',
  'uyeler.asp': '/uyeler',
  'uyedetay.asp': '/uyeler',
  'uyeduzenle.asp': '/profil',
  'uyekayit.asp': '/uye-kayit',
  'sifrehatirla.asp': '/sifre-hatirla',
  'aktivet.asp': '/aktivet',
  'aktgnd.asp': '/aktivasyon-gonder',
  'mesajlar.asp': '/mesajlar',
  'mesajgor.asp': '/mesajlar',
  'mesajgonder.asp': '/mesajlar/yeni',
  'album.asp': '/album',
  'albumkat.asp': '/album',
  'fotogoster.asp': '/album',
  'albumfotoekle.asp': '/album/yeni',
  'forum.asp': '/forum',
  'pano.asp': '/panolar',
  'panolar.asp': '/panolar',
  'mesajpanosu.asp': '/panolar',
  'herisim.asp': '/herisim',
  'hizlierisimekle.asp': '/hizli-erisim/ekle',
  'hizlierisimcikart.asp': '/hizli-erisim/cikart',
  'enyenifotolar.asp': '/enyeni-fotolar',
  'enyeniuyeler.asp': '/enyeni-uyeler',
  'vesikalikekle.asp': '/profil/fotograf',
  'ozeldegistir.asp': '/profil',
  'futbolturnuva.asp': '/turnuva',
  'oyun.asp': '/oyunlar',
  'oyunyilan.asp': '/oyunlar/yilan',
  'oyuntetris.asp': '/oyunlar/tetris',
  'admin.asp': '/admin'
};

export function mapLegacyUrl(url) {
  if (!url) return '/';
  const key = url.toLowerCase();
  return legacyToModern[key] || `/${key.replace(/\.asp$/i, '')}`;
}
