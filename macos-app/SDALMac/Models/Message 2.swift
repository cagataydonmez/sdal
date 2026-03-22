import Foundation

// Messenger thread - matches actual API response with peer_* fields
struct MessengerThread: Codable, Identifiable, Hashable {
    let id: Int
    let peerId: Int?
    let peerKadi: String?
    let peerIsim: String?
    let peerSoyisim: String?
    let peerResim: String?
    let peerVerified: IntOrBool?
    let lastMessageId: Int?
    let lastMessageBody: String?
    let lastMessageCreatedAt: String?
    let lastMessageSenderId: Int?
    let unreadCount: Int?

    var displayName: String {
        let first = peerIsim ?? ""
        let last = peerSoyisim ?? ""
        let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (peerKadi ?? "User") : full
    }

    var peerPhotoURL: URL? {
        guard let peerResim, !peerResim.isEmpty else { return nil }
        if peerResim.hasPrefix("http") { return URL(string: peerResim) }
        return URL(string: "\(APIConfig.baseURL)/\(peerResim)")
    }

    var lastMessagePreview: String {
        lastMessageBody ?? ""
    }

    var relativeTime: String {
        guard let lastMessageCreatedAt else { return "" }
        return DateFormatter.relativeString(from: lastMessageCreatedAt)
    }

    var peerInitials: String {
        let first = peerIsim?.prefix(1) ?? ""
        let last = peerSoyisim?.prefix(1) ?? ""
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? "?" : result
    }

    enum CodingKeys: String, CodingKey {
        case id
        case peerId = "peer_id"
        case peerKadi = "peer_kadi"
        case peerIsim = "peer_isim"
        case peerSoyisim = "peer_soyisim"
        case peerResim = "peer_resim"
        case peerVerified = "peer_verified"
        case lastMessageId = "last_message_id"
        case lastMessageBody = "last_message_body"
        case lastMessageCreatedAt = "last_message_created_at"
        case lastMessageSenderId = "last_message_sender_id"
        case unreadCount = "unread_count"
    }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: Int
    let threadId: Int?
    let senderId: Int?
    let receiverId: Int?
    let body: String?
    let createdAt: String?
    let deliveredAt: String?
    let readAt: String?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?

    var relativeTime: String {
        guard let createdAt else { return "" }
        return DateFormatter.relativeString(from: createdAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, body, kadi, isim, soyisim, resim
        case threadId = "thread_id"
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case createdAt = "created_at"
        case deliveredAt = "delivered_at"
        case readAt = "read_at"
    }
}

struct ThreadsResponse: Codable {
    let items: [MessengerThread]?
    let hasMore: Bool?
}

struct MessagesResponse: Codable {
    let items: [ChatMessage]?
    let hasMore: Bool?
}

struct CreateThreadResponse: Codable {
    let ok: Bool?
    let threadId: Int?
}

struct SendMessageResponse: Codable {
    let ok: Bool?
    let id: Int?
}

struct MessengerContact: Codable, Identifiable, Hashable {
    let id: Int
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: IntOrBool?

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
}

struct ContactsResponse: Codable {
    let items: [MessengerContact]?
}

struct UnreadMessagesResponse: Codable {
    let count: Int?
}
