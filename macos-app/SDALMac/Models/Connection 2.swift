import Foundation

struct ConnectionResponse: Codable {
    let ok: Bool?
    let code: String?
    let message: String?
    let data: ConnectionResponseData?
}

struct ConnectionResponseData: Codable {
    let requestId: Int?
    let status: String?
}

struct NetworkHubEnvelope: Codable {
    let ok: Bool?
    let data: NetworkHubData?
}

struct NetworkHubData: Codable {
    let hub: NetworkHub?
}

struct NetworkHub: Codable {
    let teacherLinks: [User]?
    let suggestions: [User]?

    enum CodingKeys: String, CodingKey {
        case teacherLinks = "teacher_links"
        case suggestions
    }
}

struct OpportunityEnvelope: Codable {
    let ok: Bool?
    let data: OpportunityData?
}

struct OpportunityData: Codable {
    let opportunities: [Opportunity]?
}

struct Opportunity: Codable, Identifiable, Hashable {
    let id: String?
    let type: String?
    let userId: Int?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let reason: String?
    let score: Double?

    var identity: String { id ?? UUID().uuidString }
    // Identifiable conformance
    var opportunityId: String { id ?? UUID().uuidString }

    var displayName: String {
        let first = isim ?? ""
        let last = soyisim ?? ""
        let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (kadi ?? "User") : full
    }

    var photoURL: URL? {
        guard let resim, !resim.isEmpty else { return nil }
        if resim.hasPrefix("http") { return URL(string: resim) }
        return URL(string: "\(APIConfig.baseURL)/\(resim)")
    }

    enum CodingKeys: String, CodingKey {
        case id, type, kadi, isim, soyisim, resim, reason, score
        case userId = "user_id"
    }
}

// MARK: - Site Access

struct SiteAccessResponse: Codable {
    let siteOpen: Bool?
    let maintenanceMessage: String?
    let modules: [String: Bool]?
    let moduleKey: String?
    let moduleOpen: Bool?
}

// MARK: - Admin Models

struct AdminSessionResponse: Codable {
    let user: User?
    let adminOk: Bool?
}

struct AdminUserListResponse: Codable {
    let users: [User]?
    let meta: AdminListMeta?
}

struct AdminListMeta: Codable {
    let total: Int?
    let returned: Int?
    let page: Int?
    let pages: Int?
    let limit: Int?
    let filter: String?
    let sort: String?
}

struct AdminContentListResponse: Codable {
    let items: [AdminContentItem]?
    let meta: AdminListMeta?
}

struct AdminContentItem: Codable, Identifiable {
    let id: Int
    let content: String?
    let comment: String?
    let body: String?
    let kufur: String?
    let createdAt: String?
    let userId: Int?
    let kadi: String?
    let isim: String?
    let soyisim: String?

    var displayContent: String {
        content ?? comment ?? body ?? kufur ?? ""
    }

    var authorName: String {
        let first = isim ?? ""
        let last = soyisim ?? ""
        let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (kadi ?? "User \(userId ?? 0)") : full
    }

    enum CodingKeys: String, CodingKey {
        case id, content, comment, body, kufur, kadi, isim, soyisim
        case createdAt = "created_at"
        case userId = "user_id"
    }
}

struct SiteControlsResponse: Codable {
    let siteOpen: Bool?
    let maintenanceMessage: String?
    let modules: [String: Bool]?
}

struct AdminStatsResponse: Codable {
    let ok: Bool?
}
