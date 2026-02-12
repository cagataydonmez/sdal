# Legacy Inventory (Classic ASP)

## Databases
- `datamizacx.mdb` (main)
- `aiacx.mdb` (shoutbox / instant messages)
- `oyunlar.mdb` (tetris scores)
- `turnuvadata.mdb` (football tournament)

## Core Includes
- `kafa.asp` (header, session, menu, left column widgets, online users, newest members/photos, game scores)
- `ayak.asp` (footer, breadcrumb, menu footer)
- `kodlar.asp` (helpers: error handling, validation, text formatting, date formatting, email, online cleanup)
- `stil.asp` (main CSS)
- `ayax.asp`, `sdalajax.js` (AJAX helpers)

## Key Feature Areas (routes)
- Auth & session: `default.asp`, `uyegiris.asp`, `cikis.asp`, `sifrehatirla.asp`, `uyekayit.asp`, `aktivet.asp`, `aktgnd.asp`
- User profile & directory: `uyeler.asp`, `uyedetay.asp`, `uyeduzenle.asp`, `uyeara.asp`, `ozeldegistir.asp`
- Messaging: `mesajlar.asp`, `mesajgor.asp`, `mesajgonder.asp`, `mesajsil.asp`
- Forum/panolar: `pano.asp`, `panolar.asp`, `forum.asp`
- Albums: `album.asp`, `albumkat.asp`, `fotogoster.asp`, `albumfotoekle.asp`, `albumyorumekle.asp`
- Admin: `admin.asp`, `adminuyeler.asp`, `adminuyeduzenle.asp`, `adminsayfalar.asp`, `adminsayfaekle.asp`, `adminsayfaduz.asp`, `adminsayfasil.asp`
- Games: `oyun.asp`, `oyunyilan.asp`, `oyunyilanislem.asp`, `oyuntetris.asp`, `oyuntetrisislem.asp`
- Misc/utility: `kucukresim*.asp`, `aspcaptcha.asp`, `textimage.asp`, `threshold.asp`, `grayscale.asp`, `resimler_xml.asp`

## Known Tables (from ASP queries)
- `uyeler`, `sayfalar`, `gelenkutusu`, `mesaj`, `mesaj_kategori`, `album_kat`, `album_foto`, `album_fotoyorum`, `oyun_yilan`, `oyun_tetris`, `filtre`, `hmes`, `takimlar`

