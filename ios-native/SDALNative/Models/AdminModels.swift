import Foundation

struct AdminSessionEnvelope: Decodable {
    let admin: AdminUser?
    let user: AdminUser?

    var resolvedUser: AdminUser? { admin ?? user }
}

struct AdminUser: Decodable, Identifiable {
    let id: Int
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let email: String?
    let role: String?

    private enum CodingKeys: String, CodingKey {
        case id, kadi, isim, soyisim, email, role, rol
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing admin user id")
        }
        self.id = id
        kadi = c.decodeLossyString(forKey: .kadi)
        isim = c.decodeLossyString(forKey: .isim)
        soyisim = c.decodeLossyString(forKey: .soyisim)
        email = c.decodeLossyString(forKey: .email)
        role = c.decodeLossyString(forKey: .role) ?? c.decodeLossyString(forKey: .rol)
    }
}

struct AdminStatsEnvelope: Decodable {
    let stats: AdminStats?
    let data: AdminStats?

    var payload: AdminStats? { stats ?? data }
}

struct AdminStats: Decodable {
    let totalUsers: Int?
    let activeUsers: Int?
    let totalPosts: Int?
    let totalStories: Int?
    let pendingVerifications: Int?
    let pendingEvents: Int?
    let pendingAnnouncements: Int?

    private enum CodingKeys: String, CodingKey {
        case totalUsers, activeUsers, totalPosts, totalStories, pendingVerifications, pendingEvents, pendingAnnouncements
        case usersTotal, usersActive, postsTotal, storiesTotal, verificationPending
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalUsers = c.decodeLossyInt(forKey: .totalUsers) ?? c.decodeLossyInt(forKey: .usersTotal)
        activeUsers = c.decodeLossyInt(forKey: .activeUsers) ?? c.decodeLossyInt(forKey: .usersActive)
        totalPosts = c.decodeLossyInt(forKey: .totalPosts) ?? c.decodeLossyInt(forKey: .postsTotal)
        totalStories = c.decodeLossyInt(forKey: .totalStories) ?? c.decodeLossyInt(forKey: .storiesTotal)
        pendingVerifications = c.decodeLossyInt(forKey: .pendingVerifications) ?? c.decodeLossyInt(forKey: .verificationPending)
        pendingEvents = c.decodeLossyInt(forKey: .pendingEvents)
        pendingAnnouncements = c.decodeLossyInt(forKey: .pendingAnnouncements)
    }
}

struct AdminLiveEnvelope: Decodable {
    let data: AdminLiveSnapshot?
    let live: AdminLiveSnapshot?

    var payload: AdminLiveSnapshot? { data ?? live }
}

struct AdminLiveSnapshot: Decodable {
    let onlineMembers: Int?
    let unreadMessages: Int?
    let pendingGroupInvites: Int?
    let activeRooms: Int?
}

struct AdminListEnvelope<T: Decodable>: Decodable {
    let items: [T]?
    let rows: [T]?
    let data: [T]?

    var list: [T] { items ?? rows ?? data ?? [] }
}

struct AdminModerationItem: Decodable, Identifiable {
    let id: Int
    let content: String?
    let message: String?
    let type: String?
    let createdAt: String?
    let authorKadi: String?
    let senderKadi: String?
    let kadi: String?

    private enum CodingKeys: String, CodingKey {
        case id, content, message, type, createdAt, authorKadi, senderKadi, kadi, mesaj, created_at, author_kadi, sender_kadi
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing moderation item id")
        }
        self.id = id
        content = c.decodeLossyString(forKey: .content)
        message = c.decodeLossyString(forKey: .message) ?? c.decodeLossyString(forKey: .mesaj)
        type = c.decodeLossyString(forKey: .type)
        createdAt = c.decodeLossyString(forKey: .createdAt) ?? c.decodeLossyString(forKey: .created_at)
        authorKadi = c.decodeLossyString(forKey: .authorKadi) ?? c.decodeLossyString(forKey: .author_kadi)
        senderKadi = c.decodeLossyString(forKey: .senderKadi) ?? c.decodeLossyString(forKey: .sender_kadi)
        kadi = c.decodeLossyString(forKey: .kadi)
    }
}

struct VerificationRequestItem: Decodable, Identifiable {
    let id: Int
    let userId: Int?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let email: String?
    let status: String?
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, userId, kadi, isim, soyisim, email, status, createdAt, user_id, created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing verification request id")
        }
        self.id = id
        userId = c.decodeLossyInt(forKey: .userId) ?? c.decodeLossyInt(forKey: .user_id)
        kadi = c.decodeLossyString(forKey: .kadi)
        isim = c.decodeLossyString(forKey: .isim)
        soyisim = c.decodeLossyString(forKey: .soyisim)
        email = c.decodeLossyString(forKey: .email)
        status = c.decodeLossyString(forKey: .status)
        createdAt = c.decodeLossyString(forKey: .createdAt) ?? c.decodeLossyString(forKey: .created_at)
    }
}

struct AdminFollowsEnvelope: Decodable {
    let user: AdminFollowUser?
    let items: [AdminFollowItem]?
    let hasMore: Bool?
}

struct AdminFollowUser: Decodable {
    let id: Int?
    let kadi: String?
    let isim: String?
    let soyisim: String?
}

struct AdminFollowItem: Decodable, Identifiable {
    let id: Int
    let followingId: Int?
    let followedAt: String?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: Bool?
    let messageCount: Int?
    let quoteCount: Int?
    let recentMessages: [AdminRecentMessage]?
    let recentQuotes: [AdminRecentQuote]?

    private enum CodingKeys: String, CodingKey {
        case id, followingId, followedAt, kadi, isim, soyisim, resim, verified, messageCount, quoteCount, recentMessages, recentQuotes
        case following_id, followed_at, message_count, quote_count, recent_messages, recent_quotes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing follow id")
        }
        self.id = id
        followingId = c.decodeLossyInt(forKey: .followingId) ?? c.decodeLossyInt(forKey: .following_id)
        followedAt = c.decodeLossyString(forKey: .followedAt) ?? c.decodeLossyString(forKey: .followed_at)
        kadi = c.decodeLossyString(forKey: .kadi)
        isim = c.decodeLossyString(forKey: .isim)
        soyisim = c.decodeLossyString(forKey: .soyisim)
        resim = c.decodeLossyString(forKey: .resim)
        verified = c.decodeLossyBool(forKey: .verified)
        messageCount = c.decodeLossyInt(forKey: .messageCount) ?? c.decodeLossyInt(forKey: .message_count)
        quoteCount = c.decodeLossyInt(forKey: .quoteCount) ?? c.decodeLossyInt(forKey: .quote_count)
        recentMessages = (try? c.decodeIfPresent([AdminRecentMessage].self, forKey: .recentMessages))
            ?? (try? c.decodeIfPresent([AdminRecentMessage].self, forKey: .recent_messages))
        recentQuotes = (try? c.decodeIfPresent([AdminRecentQuote].self, forKey: .recentQuotes))
            ?? (try? c.decodeIfPresent([AdminRecentQuote].self, forKey: .recent_quotes))
    }
}

struct AdminRecentMessage: Decodable, Identifiable {
    let id: Int
    let konu: String?
    let mesaj: String?
    let tarih: String?
}

struct AdminRecentQuote: Decodable, Identifiable {
    let id: Int
    let content: String?
    let createdAt: String?
    let source: String?

    private enum CodingKeys: String, CodingKey {
        case id, content, createdAt, source, created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing quote id")
        }
        self.id = id
        content = c.decodeLossyString(forKey: .content)
        createdAt = c.decodeLossyString(forKey: .createdAt) ?? c.decodeLossyString(forKey: .created_at)
        source = c.decodeLossyString(forKey: .source)
    }
}

struct AdminGroupItem: Decodable, Identifiable {
    let id: Int
    let name: String?
    let description: String?
    let coverImage: String?
    let ownerId: Int?
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, coverImage, ownerId, createdAt, cover_image, owner_id, created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing group id")
        }
        self.id = id
        name = c.decodeLossyString(forKey: .name)
        description = c.decodeLossyString(forKey: .description)
        coverImage = c.decodeLossyString(forKey: .coverImage) ?? c.decodeLossyString(forKey: .cover_image)
        ownerId = c.decodeLossyInt(forKey: .ownerId) ?? c.decodeLossyInt(forKey: .owner_id)
        createdAt = c.decodeLossyString(forKey: .createdAt) ?? c.decodeLossyString(forKey: .created_at)
    }
}

struct AdminFilterItem: Decodable, Identifiable {
    let id: Int
    let kufur: String?
}

struct EngagementAbEnvelope: Decodable {
    let configs: [EngagementAbConfig]?
    let performance: [EngagementAbPerformance]?
    let recommendations: [EngagementAbRecommendation]?
    let lastCalculatedAt: String?
}

struct EngagementAbConfig: Decodable, Identifiable {
    let variant: String
    let name: String?
    let description: String?
    let trafficPct: Int?
    let enabled: Bool?
    let params: [String: Double]?
    let updatedAt: String?

    var id: String { variant }

    private enum CodingKeys: String, CodingKey {
        case variant, name, description, trafficPct, enabled, params, updatedAt, traffic_pct, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        variant = c.decodeLossyString(forKey: .variant) ?? "A"
        name = c.decodeLossyString(forKey: .name)
        description = c.decodeLossyString(forKey: .description)
        trafficPct = c.decodeLossyInt(forKey: .trafficPct) ?? c.decodeLossyInt(forKey: .traffic_pct)
        enabled = c.decodeLossyBool(forKey: .enabled)
        params = try? c.decodeIfPresent([String: Double].self, forKey: .params)
        updatedAt = c.decodeLossyString(forKey: .updatedAt) ?? c.decodeLossyString(forKey: .updated_at)
    }
}

struct EngagementAbPerformance: Decodable, Identifiable {
    let variant: String
    let users: Int?
    let avgScore: Double?
    let engagementRate: Double?

    var id: String { variant }

    private enum CodingKeys: String, CodingKey {
        case variant, users, avgScore, engagementRate, avg_score, engagement_rate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        variant = c.decodeLossyString(forKey: .variant) ?? "A"
        users = c.decodeLossyInt(forKey: .users)
        if let d = try? c.decodeIfPresent(Double.self, forKey: .avgScore) {
            avgScore = d
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .avg_score) {
            avgScore = d
        } else if let i = c.decodeLossyInt(forKey: .avgScore) ?? c.decodeLossyInt(forKey: .avg_score) {
            avgScore = Double(i)
        } else {
            avgScore = nil
        }
        if let d = try? c.decodeIfPresent(Double.self, forKey: .engagementRate) {
            engagementRate = d
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .engagement_rate) {
            engagementRate = d
        } else if let i = c.decodeLossyInt(forKey: .engagementRate) ?? c.decodeLossyInt(forKey: .engagement_rate) {
            engagementRate = Double(i)
        } else {
            engagementRate = nil
        }
    }
}

struct EngagementAbRecommendation: Decodable, Identifiable {
    let variant: String?
    let confidence: Double?
    let reasons: [String]?

    var id: String { "\(variant ?? "unknown")-\(confidence ?? 0)" }
}

struct EngagementScoresEnvelope: Decodable {
    let items: [EngagementScoreItem]?
    let page: Int?
    let pages: Int?
    let total: Int?
    let lastCalculatedAt: String?
}

struct EngagementScoreItem: Decodable, Identifiable {
    let id: Int
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let abVariant: String?
    let score: Double?
    let rawScore: Double?
    let creatorScore: Double?
    let engagementReceivedScore: Double?
    let communityScore: Double?
    let networkScore: Double?
    let qualityScore: Double?
    let penaltyScore: Double?
    let posts30d: Int?
    let likesReceived30d: Int?
    let commentsReceived30d: Int?
    let updatedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, kadi, isim, soyisim, score
        case abVariant, rawScore, creatorScore, engagementReceivedScore, communityScore, networkScore, qualityScore, penaltyScore
        case posts30d, likesReceived30d, commentsReceived30d, updatedAt
        case ab_variant, raw_score, creator_score, engagement_received_score, community_score, network_score, quality_score, penalty_score
        case posts_30d, likes_received_30d, comments_received_30d, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing engagement item id")
        }
        self.id = id
        kadi = c.decodeLossyString(forKey: .kadi)
        isim = c.decodeLossyString(forKey: .isim)
        soyisim = c.decodeLossyString(forKey: .soyisim)
        abVariant = c.decodeLossyString(forKey: .abVariant) ?? c.decodeLossyString(forKey: .ab_variant)
        score = EngagementScoreItem.decodeLossyDouble(c, forKey: .score)
        rawScore = EngagementScoreItem.decodeLossyDouble(c, forKey: .rawScore) ?? EngagementScoreItem.decodeLossyDouble(c, forKey: .raw_score)
        creatorScore = EngagementScoreItem.decodeLossyDouble(c, forKey: .creatorScore) ?? EngagementScoreItem.decodeLossyDouble(c, forKey: .creator_score)
        engagementReceivedScore = EngagementScoreItem.decodeLossyDouble(c, forKey: .engagementReceivedScore) ?? EngagementScoreItem.decodeLossyDouble(c, forKey: .engagement_received_score)
        communityScore = EngagementScoreItem.decodeLossyDouble(c, forKey: .communityScore) ?? EngagementScoreItem.decodeLossyDouble(c, forKey: .community_score)
        networkScore = EngagementScoreItem.decodeLossyDouble(c, forKey: .networkScore) ?? EngagementScoreItem.decodeLossyDouble(c, forKey: .network_score)
        qualityScore = EngagementScoreItem.decodeLossyDouble(c, forKey: .qualityScore) ?? EngagementScoreItem.decodeLossyDouble(c, forKey: .quality_score)
        penaltyScore = EngagementScoreItem.decodeLossyDouble(c, forKey: .penaltyScore) ?? EngagementScoreItem.decodeLossyDouble(c, forKey: .penalty_score)
        posts30d = c.decodeLossyInt(forKey: .posts30d) ?? c.decodeLossyInt(forKey: .posts_30d)
        likesReceived30d = c.decodeLossyInt(forKey: .likesReceived30d) ?? c.decodeLossyInt(forKey: .likes_received_30d)
        commentsReceived30d = c.decodeLossyInt(forKey: .commentsReceived30d) ?? c.decodeLossyInt(forKey: .comments_received_30d)
        updatedAt = c.decodeLossyString(forKey: .updatedAt) ?? c.decodeLossyString(forKey: .updated_at)
    }

    private static func decodeLossyDouble(_ c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let i = c.decodeLossyInt(forKey: key) { return Double(i) }
        if let s = c.decodeLossyString(forKey: key) { return Double(s) }
        return nil
    }
}

struct AdminUsersListEnvelope: Decodable {
    let users: [AdminManagedUser]?
    let meta: AdminUsersMeta?
}

struct AdminUsersMeta: Decodable {
    let total: Int?
    let returned: Int?
    let filter: String?
    let sort: String?
    let q: String?
}

struct AdminManagedUserEnvelope: Decodable {
    let user: AdminManagedUser?
}

struct AdminManagedUser: Decodable, Identifiable {
    let id: Int
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let email: String?
    let aktivasyon: String?
    let aktiv: Int?
    let yasak: Int?
    let ilkbd: Int?
    let websitesi: String?
    let imza: String?
    let meslek: String?
    let sehir: String?
    let mailkapali: Int?
    let hit: Int?
    let mezuniyetyili: String?
    let universite: String?
    let dogumgun: String?
    let dogumay: String?
    let dogumyil: String?
    let admin: Int?
    let resim: String?
    let sifre: String?
    let verified: Bool?
    let online: Bool?
    let engagementScore: Double?

    private enum CodingKeys: String, CodingKey {
        case id, kadi, isim, soyisim, email, aktivasyon, aktiv, yasak, ilkbd, websitesi, imza, meslek, sehir, mailkapali, hit, mezuniyetyili, universite, dogumgun, dogumay, dogumyil, admin, resim, sifre, verified, online, engagementScore, engagement_score
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing user id")
        }
        self.id = id
        kadi = c.decodeLossyString(forKey: .kadi)
        isim = c.decodeLossyString(forKey: .isim)
        soyisim = c.decodeLossyString(forKey: .soyisim)
        email = c.decodeLossyString(forKey: .email)
        aktivasyon = c.decodeLossyString(forKey: .aktivasyon)
        aktiv = c.decodeLossyInt(forKey: .aktiv)
        yasak = c.decodeLossyInt(forKey: .yasak)
        ilkbd = c.decodeLossyInt(forKey: .ilkbd)
        websitesi = c.decodeLossyString(forKey: .websitesi)
        imza = c.decodeLossyString(forKey: .imza)
        meslek = c.decodeLossyString(forKey: .meslek)
        sehir = c.decodeLossyString(forKey: .sehir)
        mailkapali = c.decodeLossyInt(forKey: .mailkapali)
        hit = c.decodeLossyInt(forKey: .hit)
        mezuniyetyili = c.decodeLossyString(forKey: .mezuniyetyili)
        universite = c.decodeLossyString(forKey: .universite)
        dogumgun = c.decodeLossyString(forKey: .dogumgun)
        dogumay = c.decodeLossyString(forKey: .dogumay)
        dogumyil = c.decodeLossyString(forKey: .dogumyil)
        admin = c.decodeLossyInt(forKey: .admin)
        resim = c.decodeLossyString(forKey: .resim)
        sifre = c.decodeLossyString(forKey: .sifre)
        verified = c.decodeLossyBool(forKey: .verified)
        online = c.decodeLossyBool(forKey: .online)
        if let d = try? c.decodeIfPresent(Double.self, forKey: .engagementScore) {
            engagementScore = d
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .engagement_score) {
            engagementScore = d
        } else if let i = c.decodeLossyInt(forKey: .engagementScore) ?? c.decodeLossyInt(forKey: .engagement_score) {
            engagementScore = Double(i)
        } else {
            engagementScore = nil
        }
    }
}

struct AdminManagedUserUpdateBody: Encodable {
    let isim: String
    let soyisim: String
    let aktivasyon: String
    let email: String
    let aktiv: Int
    let yasak: Int
    let ilkbd: Int
    let websitesi: String
    let imza: String
    let meslek: String
    let sehir: String
    let mailkapali: Int
    let hit: Int
    let mezuniyetyili: String
    let universite: String
    let dogumgun: String
    let dogumay: String
    let dogumyil: String
    let admin: Int
    let resim: String
    let sifre: String?
}

struct AdminEmailCategoriesEnvelope: Decodable {
    let categories: [AdminEmailCategory]?
}

struct AdminEmailCategory: Decodable, Identifiable {
    let id: Int
    let ad: String?
    let tur: String?
    let deger: String?
    let aciklama: String?
}

struct AdminEmailTemplatesEnvelope: Decodable {
    let templates: [AdminEmailTemplate]?
}

struct AdminEmailTemplate: Decodable, Identifiable {
    let id: Int
    let ad: String?
    let konu: String?
    let icerik: String?
    let olusturma: String?
}

struct AdminPagesEnvelope: Decodable {
    let pages: [AdminPageItem]?
}

struct AdminPageItem: Decodable, Identifiable {
    let id: Int
    let sayfaismi: String?
    let sayfaurl: String?
    let babaid: Int?
    let menugorun: Int?
    let yonlendir: Int?
    let mozellik: Int?
    let resim: String?

    private enum CodingKeys: String, CodingKey {
        case id, sayfaismi, sayfaurl, babaid, menugorun, yonlendir, mozellik, resim
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing page id")
        }
        self.id = id
        sayfaismi = c.decodeLossyString(forKey: .sayfaismi)
        sayfaurl = c.decodeLossyString(forKey: .sayfaurl)
        babaid = c.decodeLossyInt(forKey: .babaid)
        menugorun = c.decodeLossyInt(forKey: .menugorun)
        yonlendir = c.decodeLossyInt(forKey: .yonlendir)
        mozellik = c.decodeLossyInt(forKey: .mozellik)
        resim = c.decodeLossyString(forKey: .resim)
    }
}

struct AdminPageWriteBody: Encodable {
    let sayfaismi: String
    let sayfaurl: String
    let babaid: Int
    let menugorun: Int
    let yonlendir: Int
    let mozellik: Int
    let resim: String
}

struct AdminLogsEnvelope: Decodable {
    let files: [AdminLogFile]?
    let file: String?
    let content: String?
    let total: Int?
    let matched: Int?
    let returned: Int?
    let offset: Int?
    let limit: Int?
}

struct AdminLogFile: Decodable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let size: Int?
    let mtime: String?
}

struct AdminAlbumCategoriesEnvelope: Decodable {
    let categories: [AdminAlbumCategory]?
    let counts: [String: AdminAlbumCategoryCount]?
}

struct AdminAlbumCategoryCount: Decodable {
    let activeCount: Int?
    let inactiveCount: Int?
}

struct AdminAlbumCategory: Decodable, Identifiable {
    let id: Int
    let kategori: String?
    let aciklama: String?
    let ilktarih: String?
    let aktif: Int?

    private enum CodingKeys: String, CodingKey {
        case id, kategori, aciklama, ilktarih, aktif
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing album category id")
        }
        self.id = id
        kategori = c.decodeLossyString(forKey: .kategori)
        aciklama = c.decodeLossyString(forKey: .aciklama)
        ilktarih = c.decodeLossyString(forKey: .ilktarih)
        aktif = c.decodeLossyInt(forKey: .aktif)
    }
}

struct AdminAlbumCategoryWriteBody: Encodable {
    let kategori: String
    let aciklama: String
    let aktif: Int
}

struct AdminAlbumPhotosEnvelope: Decodable {
    let photos: [AdminAlbumPhoto]?
    let categories: [AdminAlbumCategory]?
    let userMap: [String: String]?
    let commentCounts: [String: Int]?
}

struct AdminAlbumPhoto: Decodable, Identifiable {
    let id: Int
    let katid: Int?
    let dosyaadi: String?
    let baslik: String?
    let aciklama: String?
    let aktif: Int?
    let ekleyenid: Int?
    let tarih: String?
    let hit: Int?

    private enum CodingKeys: String, CodingKey {
        case id, katid, dosyaadi, baslik, aciklama, aktif, ekleyenid, tarih, hit
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing album photo id")
        }
        self.id = id
        katid = c.decodeLossyInt(forKey: .katid)
        dosyaadi = c.decodeLossyString(forKey: .dosyaadi)
        baslik = c.decodeLossyString(forKey: .baslik)
        aciklama = c.decodeLossyString(forKey: .aciklama)
        aktif = c.decodeLossyInt(forKey: .aktif)
        ekleyenid = c.decodeLossyInt(forKey: .ekleyenid)
        tarih = c.decodeLossyString(forKey: .tarih)
        hit = c.decodeLossyInt(forKey: .hit)
    }
}

struct AdminAlbumPhotoWriteBody: Encodable {
    let baslik: String
    let aciklama: String
    let aktif: Int
    let katid: Int
}

struct AdminAlbumPhotoBulkBody: Encodable {
    let ids: [Int]
    let action: String
}

struct AdminAlbumPhotoCommentsEnvelope: Decodable {
    let comments: [AdminAlbumPhotoComment]?
}

struct AdminAlbumPhotoComment: Decodable, Identifiable {
    let id: Int
    let fotoid: Int?
    let uyeid: Int?
    let yorum: String?
    let tarih: String?

    private enum CodingKeys: String, CodingKey {
        case id, fotoid, uyeid, yorum, tarih
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing album comment id")
        }
        self.id = id
        fotoid = c.decodeLossyInt(forKey: .fotoid)
        uyeid = c.decodeLossyInt(forKey: .uyeid)
        yorum = c.decodeLossyString(forKey: .yorum)
        tarih = c.decodeLossyString(forKey: .tarih)
    }
}

struct AdminTournamentEnvelope: Decodable {
    let teams: [AdminTournamentTeam]?
}

struct AdminTournamentTeam: Decodable, Identifiable {
    let id: Int
    let tisim: String?
    let takimadi: String?
    let isim: String?
    let tarih: String?

    private enum CodingKeys: String, CodingKey {
        case id, tisim, takimadi, isim, tarih
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing team id")
        }
        self.id = id
        tisim = c.decodeLossyString(forKey: .tisim)
        takimadi = c.decodeLossyString(forKey: .takimadi)
        isim = c.decodeLossyString(forKey: .isim)
        tarih = c.decodeLossyString(forKey: .tarih)
    }
}

struct AdminDbTablesEnvelope: Decodable {
    let items: [AdminDbTableInfo]?
}

struct AdminDbTableInfo: Decodable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let rowCount: Int?
}

struct AdminDbBackupsEnvelope: Decodable {
    let items: [AdminDbBackupItem]?
    let dbPath: String?
}

struct AdminDbBackupItem: Decodable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let path: String?
    let size: Int?
    let mtime: String?
}

struct AdminDbColumn: Decodable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let type: String?
    let notnull: Int?
    let pk: Int?
}

struct JSONValue: Decodable, CustomStringConvertible {
    let value: Any

    var description: String {
        if value is NSNull { return "null" }
        return String(describing: value)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            value = NSNull()
        } else if let b = try? c.decode(Bool.self) {
            value = b
        } else if let i = try? c.decode(Int.self) {
            value = i
        } else if let d = try? c.decode(Double.self) {
            value = d
        } else if let s = try? c.decode(String.self) {
            value = s
        } else if let arr = try? c.decode([JSONValue].self) {
            value = arr.map(\.value)
        } else if let obj = try? c.decode([String: JSONValue].self) {
            value = obj.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
        }
    }
}

struct AdminDbTableEnvelope: Decodable {
    let table: String?
    let columns: [AdminDbColumn]?
    let rows: [[String: JSONValue]]?
    let total: Int?
    let page: Int?
    let pages: Int?
    let limit: Int?
}
