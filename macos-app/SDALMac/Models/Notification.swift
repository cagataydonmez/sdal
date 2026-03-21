import Foundation

struct AppNotification: Codable, Identifiable, Hashable {
    let id: Int
    let type: String?
    let entityId: Int?
    let sourceUserId: Int?
    let message: String?
    let readAt: String?
    let createdAt: String?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: IntOrBool?

    var isRead: Bool { readAt != nil }

    var sourceDisplayName: String {
        let first = isim ?? ""
        let last = soyisim ?? ""
        let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (kadi ?? "") : full
    }

    var sourcePhotoURL: URL? {
        guard let resim, !resim.isEmpty else { return nil }
        if resim.hasPrefix("http") { return URL(string: resim) }
        return URL(string: "\(APIConfig.baseURL)/\(resim)")
    }

    var relativeTime: String {
        guard let createdAt else { return "" }
        return DateFormatter.relativeString(from: createdAt)
    }

    var icon: String {
        switch type {
        case "connection_request": return "person.badge.plus"
        case "connection_accepted": return "person.2.fill"
        case "mentorship_request": return "graduationcap"
        case "mentorship_accepted": return "graduationcap.fill"
        case "group_join_request": return "person.3"
        case "group_invite": return "envelope.badge.person.crop"
        case "post_like": return "heart.fill"
        case "post_comment": return "bubble.left.fill"
        case "event_invite": return "calendar.badge.plus"
        case "event_comment": return "text.bubble"
        case "job_application": return "briefcase"
        case "message": return "message.fill"
        case "story_view": return "eye"
        case "announcement": return "megaphone"
        default: return "bell.fill"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, type, message, kadi, isim, soyisim, resim, verified
        case entityId = "entity_id"
        case sourceUserId = "source_user_id"
        case readAt = "read_at"
        case createdAt = "created_at"
    }
}

// The actual response is wrapped: { ok, code, message, data: { items, hasMore, next_cursor } }
struct NotificationsEnvelope: Codable {
    let ok: Bool?
    let code: String?
    let data: NotificationsData?
}

struct NotificationsData: Codable {
    let items: [AppNotification]?
    let hasMore: Bool?
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items, hasMore
        case nextCursor = "next_cursor"
    }
}

struct UnreadCountResponse: Codable {
    let count: Int?
}
