# SDAL Professional Social Hub – Strategy Blueprint

Süleyman Demirel Anadolu Lisesi (SDAL) mezunları platformunun üç katmanlı gelişim stratejisi.

---

## Vision

SDAL'ı yalnızca bir mezunlar topluluğu olmaktan çıkarıp, **topluluk**, **profesyonel ağ** ve **dernek altyapısı** katmanlarını kapsayan entegre bir platforma dönüştürmek.

---

## Three-Layer Model

| Layer | Focus | Key Features |
|-------|-------|---------------|
| **Community** | Kimlik, topluluk, temel yapı | Mezuniyet yılı, doğrulama, dönem toplulukları, feed, rehber |
| **Professional** | Kariyer, bağlantılar, mentorluk | Profil uzantıları, karşılıklı bağlantılar, iş ilanları, uzman rehberi |
| **Association** | Yönetişim, aidat, komiteler | Üyelik kademeleri, bağış/ödeme, komiteler, oylama, gönüllü yönetimi |

---

## Phased Rollout

### Phase 1: Strengthen Alumni Network (MVP)
- Mezuniyet yılı zorunlu alan
- KVKK ve rehber açık rıza kaydı
- Admin onaylı doğrulama akışı
- Dönem (cohort) toplulukları otomatik oluşturma
- Dönem feed’leri
- Mezun Rehberi (isim, yıl, konum, meslek filtreleri)

### Phase 1.5: Data Management & Privacy
- Legacy görsel uyumluluğun kaldırılması (variant pipeline)
- Özyinelemeli üye silme (hard delete)

### Phase 2: Professional Networking (V2)
- Profil uzantıları (şirket, unvan, beceriler, LinkedIn)
- Karşılıklı bağlantılar (request/accept)
- İş ilanları panosu
- Uzman rehberi ve mentorluk MVP

### Phase 3: Association Infrastructure (V3)
- Üyelik kademeleri (ücretsiz / ücretli)
- Bağış ve aidat entegrasyonu
- Komiteler ve çalışma grupları
- Oylama ve anket (e-Genel Kurul)
- Gönüllü yönetimi
- Mezun haritası

---

## Success Metrics

| Phase | Metric |
|-------|--------|
| 1 | Doğrulanmış üye oranı, dönem topluluklarına katılım, rehber arama kullanımı |
| 2 | Bağlantı sayısı, iş ilanı başvuruları, mentor eşleşmeleri |
| 3 | Ücretli üye sayısı, oylama katılımı, komite aktivitesi |

---

## Technical Decisions

- **Backend:** Express monolith, SQLite/Postgres
- **Frontend:** React (Vite), modern + legacy
- **Media:** Variant pipeline (thumb/feed/full), local + Spaces
- **Auth:** Session-based, OAuth optional

---

*Last updated: 2026-02*
