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

### Phase 1: Foundation Reset (MVP)

**Status:** 🚧 Started (Execution window: immediately)

#### Phase 1 Kickoff Plan (Start)

| Workstream | First Action | Owner | Target |
|---|---|---|---|
| Identity & Signup | Mezuniyet yılı + KVKK onay alanlarının production doğrulamasını checklist ile doğrula | Product + Backend | Week 1 |
| Verification | Admin onay akışında kanıt dokümanı (`proof`) alanı için teknik tasarımı çıkar | Backend | Week 1 |
| Community Core | Dönem topluluklarının otomatik oluşumunu canlı veride smoke test ile doğrula | Backend + QA | Week 1 |
| Directory | Rehber filtreleri (yıl/konum/meslek) için kullanım metriği dashboard'unu aç | Product + Data | Week 2 |

#### Phase 1 Definition of Done

- Kayıt olan kullanıcılarda mezuniyet yılı ve gerekli rıza alanları eksiksiz tutulur.
- Doğrulama tamamlanmadan rehber erişimi kapalı kalır.
- Doğrulanan mezunlar doğru dönem topluluğuna otomatik atanır.
- Rehber arama kullanım metriği haftalık takip edilir.

#### 1) Identity & Signup Strategy
- Mezuniyet yılı zorunlu alan
- KVKK ve rehber açık rıza kaydı
- Kayıt stratejisi:
  1. Okuldan alınacak veritabanı üzerinden mezun doğrulaması
  2. Web üzerinden serbest kayda izin verilmezse, mobil uygulamada çipli T.C. kimlik kartının NFC ile okutulması

#### 2) Verification & Access
- Admin onaylı doğrulama akışı
- Doğrulama tamamlanmadan rehber/listeme erişiminin kısıtlanması

#### 3) Core Community Experience
- Dönem (cohort) topluluklarının otomatik oluşturulması
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

*Last updated: 2026-03 (Phase 1 started)*
