# TestFlight Build & Release Notes Guide

Bu rehber, TestFlight'a yüklenen build'ler arasındaki değişiklikleri otomatik olarak izlemeyi ve kullanıcı dostu changelog oluşturmayı açıklamaktadır.

## 📋 Sistem Özellikleri

### 1. **Build Numarası İzleme**
- Son yüklenen TestFlight build numarası otomatik olarak kaydedilir
- `~/.sdal_testflight_state/last_build_number` dosyasında tutulur
- Her başarılı upload'dan sonra güncellenir

### 2. **Otomatik Changelog Oluşturma**
- Git commit'leri taranır ve değişiklikler kategorize edilir:
  - ✨ **Yeni Özellikler** — "Add" başlayan commit'ler
  - 🐛 **Hata Düzeltmeleri** — "Fix" başlayan commit'ler
  - 🔄 **Güncellemeler** — "Update" başlayan commit'ler
  - 📝 **Diğer Değişiklikler** — Diğer commit'ler

### 3. **Kullanıcı Dostu Format**
```
Version: 0.3.0 (Build 74)

✨ New Features:
  • image upload
  • work_mode field

🐛 Bug Fixes:
  • feed entity routing
  • null warnings

---
Test and provide feedback on TestFlight!
```

## 🚀 Nasıl Kullanılır

### Adım 1: Build Numarasını Güncelleyin
`pubspec.yaml` dosyasında version'u artırın:

```yaml
version: 0.3.0+74  # +75'e değiştirin
```

### Adım 2: TestFlight Build'i Başlatın
```bash
./tool/install_local.sh
# Seçenek 4: TestFlight (iOS + App Watch olmadan)
# Seçenek 7: watchOS TestFlight (App Watch ile)
```

### Adım 3: Otomatik Olarak Oluşan Changelog'u Görün
Script çalışırken:
1. Mevcut ve son uploaded build numarası gösterilir
2. Otomatik changelog oluşturulur ve görüntülenir
3. Release notes dosyası kaydedilir: 
   ```
   ~/Library/Caches/flutter_sdal_ios_archives/release_notes_75.txt
   ```

### Adım 4: App Store Connect'te Notları Ekleyin
1. https://appstoreconnect.apple.com → Uygulamanız → TestFlight'a gidin
2. Yeni build'i bulun (processing'den geçtikten sonra)
3. Build'i edit edin
4. **Release Notes** bölümüne generated dosyadaki içeriği yapıştırın
5. Save edin

## 📝 Release Notes Dosya Konumu

Her build'in release notes'u ayrı bir dosyada tutulur:
```
~/.cache/flutter_sdal_ios_archives/release_notes_<BUILD_NUMBER>.txt
```

Örnek:
```
release_notes_74.txt
release_notes_75.txt
release_notes_76.txt
```

## 🔧 Teknik Detaylar

### Script Dosyaları
- **`install_local.sh`** — Ana build script (entegre edildi)
- **`testflight_utils.sh`** — TestFlight utility fonksiyonları

### Kullanılan Fonksiyonlar

#### `get_current_build_number <root_dir>`
pubspec.yaml'dan mevcut build numarasını alır.

#### `get_last_testflight_build`
Önceki yüklenen build numarasını döndürür (ilk run'da "0").

#### `generate_release_notes <root_dir> <start_ref> <end_ref>`
Git log'dan changelog oluşturur, commit'leri kategorize eder.

#### `save_testflight_build_number <build_num>`
Mevcut build numarasını kaydeder.

## ⚠️ Önemli Notlar

### Build Numarasını Unutmayın!
Eğer `pubspec.yaml`'da build numarasını güncellemezseniz:
- Script sizi uyarır
- Yine de devam etmenize izin verir (ama önerilmez)

### Commit Mesajları Önemli
Changelog'un kalitesi commit mesajlarına bağlıdır. İyi yapılandırılmış mesajlar kullanın:
- ✅ `Fix feed entity post likes count`
- ✅ `Add image upload support`
- ✅ `Update dependencies to latest version`
- ❌ `fix stuff`
- ❌ `update`

### Release Notes Limit
TestFlight release notes maksimum 4000 karakter ile sınırlıdır. Script otomatik olarak kes.

## 🔄 Workflow Örneği

```bash
# 1. Coding'e başlayın
git commit -m "Add new feature"
git commit -m "Fix bug in feed"

# 2. pubspec.yaml'da version'u güncelleyin
version: 0.3.0+75

# 3. TestFlight build'i başlatın
./tool/install_local.sh
# Seçenek 4 veya 7'yi seçin

# Script otomatik olarak:
# ✓ Commit'leri tarar
# ✓ Changelog oluşturur
# ✓ Release notes dosyasını kaydeder
# ✓ IPA upload'ını yapar
# ✓ Build numarasını kaydeder

# 4. App Store Connect'te release notes'u yapıştırın
```

## 📞 Troubleshooting

### "Build number unchanged" Uyarısı
**Sorun:** Build numarası değişmedi ama yapıştırmaya çalışıyorsunuz.

**Çözüm:** 
```bash
# pubspec.yaml'da version'u güncelleyin
version: 0.3.0+75  # 74'den 75'e
```

### Release Notes Dosyası Bulunamıyor
**Sorun:** `~/.sdal_testflight_state/` klasörü oluşturulmadı.

**Çözüm:** Script ilk run'da otomatik oluşturur. Eğer hala sorun varsa:
```bash
mkdir -p ~/.sdal_testflight_state
```

### Boş Changelog
**Sorun:** Release notes alanı boş gösteriyor.

**Çözüm:** İlk build'in yapılmasıdır. Düşün changelog otomatik oluşacak:
```
Initial TestFlight build
```

## 📚 İlgili Dosyalar

- [install_local.sh](./install_local.sh) — Ana script
- [testflight_utils.sh](./testflight_utils.sh) — Utilities
- `pubspec.yaml` — Build numarası için
