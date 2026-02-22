import Foundation

struct MessagesEnvelope: Decodable {
    let rows: [MessageSummary]
    let page: Int?
    let pages: Int?
    let total: Int?
    let box: String?
    let pageSize: Int?
}

struct MessageSummary: Decodable, Identifiable {
    let id: Int
    let konu: String?
    let mesaj: String?
    let tarih: String?
    let kimdenKadi: String?
    let kimdenResim: String?
    let kimeKadi: String?
    let yeni: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, konu, mesaj, tarih, kimdenKadi, kimdenResim, kimeKadi, yeni
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = container.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Missing message id")
        }
        self.id = id
        self.konu = container.decodeLossyString(forKey: .konu)
        self.mesaj = container.decodeLossyString(forKey: .mesaj)
        self.tarih = container.decodeLossyString(forKey: .tarih)
        self.kimdenKadi = container.decodeLossyString(forKey: .kimdenKadi)
        self.kimdenResim = container.decodeLossyString(forKey: .kimdenResim)
        self.kimeKadi = container.decodeLossyString(forKey: .kimeKadi)
        self.yeni = container.decodeLossyBool(forKey: .yeni)
    }
}

struct MessageUser: Decodable {
    let id: Int?
    let kadi: String?
    let resim: String?
}

struct MessageDetailEnvelope: Decodable {
    let row: MessageSummary?
    let sender: MessageUser?
    let receiver: MessageUser?
}

struct RecipientsEnvelope: Decodable {
    let items: [MessageRecipient]
}

struct MessageRecipient: Decodable, Identifiable {
    let id: Int
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, kadi, isim, soyisim, resim, verified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = container.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Missing recipient id")
        }
        self.id = id
        self.kadi = container.decodeLossyString(forKey: .kadi)
        self.isim = container.decodeLossyString(forKey: .isim)
        self.soyisim = container.decodeLossyString(forKey: .soyisim)
        self.resim = container.decodeLossyString(forKey: .resim)
        self.verified = container.decodeLossyBool(forKey: .verified)
    }
}

struct NotificationsEnvelope: Decodable {
    let items: [AppNotification]
    let hasMore: Bool?

    private enum CodingKeys: String, CodingKey {
        case items, rows, data, notifications, hasMore
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([AppNotification].self, forKey: .items))
            ?? (try? c.decodeIfPresent([AppNotification].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([AppNotification].self, forKey: .data))
            ?? (try? c.decodeIfPresent([AppNotification].self, forKey: .notifications))
            ?? []
        hasMore = c.decodeLossyBool(forKey: .hasMore)
    }
}

struct CountEnvelope: Decodable {
    let count: Int?

    private enum CodingKeys: String, CodingKey {
        case count, unread, total
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        count = c.decodeLossyInt(forKey: .count)
            ?? c.decodeLossyInt(forKey: .unread)
            ?? c.decodeLossyInt(forKey: .total)
    }
}

struct ChatMessagesEnvelope: Decodable {
    let items: [ChatMessage]

    private enum CodingKeys: String, CodingKey {
        case items, rows, data, messages
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let direct = try? single.decode([ChatMessage].self) {
            items = direct
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([ChatMessage].self, forKey: .items))
            ?? (try? c.decodeIfPresent([ChatMessage].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([ChatMessage].self, forKey: .data))
            ?? (try? c.decodeIfPresent([ChatMessage].self, forKey: .messages))
            ?? []
    }
}

struct ChatSendEnvelope: Decodable {
    let ok: Bool?
    let id: Int?
    let item: ChatMessage?

    private enum CodingKeys: String, CodingKey {
        case ok, id, item, message, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.decodeLossyBool(forKey: .ok)
        id = c.decodeLossyInt(forKey: .id)
        item = (try? c.decodeIfPresent(ChatMessage.self, forKey: .item))
            ?? (try? c.decodeIfPresent(ChatMessage.self, forKey: .message))
            ?? (try? c.decodeIfPresent(ChatMessage.self, forKey: .data))
    }
}

struct ChatUpdateEnvelope: Decodable {
    let ok: Bool?
    let item: ChatMessage?

    private enum CodingKeys: String, CodingKey {
        case ok, item, message, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.decodeLossyBool(forKey: .ok)
        item = (try? c.decodeIfPresent(ChatMessage.self, forKey: .item))
            ?? (try? c.decodeIfPresent(ChatMessage.self, forKey: .message))
            ?? (try? c.decodeIfPresent(ChatMessage.self, forKey: .data))
    }
}

struct ChatMessage: Decodable, Identifiable {
    let id: Int
    let userId: Int?
    let message: String?
    let createdAt: String?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, userId, message, createdAt, kadi, isim, soyisim, resim, verified
        case user_id, created_at, mesaj, content
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing chat message id")
        }
        self.id = id
        userId = c.decodeLossyInt(forKey: .userId) ?? c.decodeLossyInt(forKey: .user_id)
        message = c.decodeLossyString(forKey: .message)
            ?? c.decodeLossyString(forKey: .mesaj)
            ?? c.decodeLossyString(forKey: .content)
        createdAt = c.decodeLossyString(forKey: .createdAt) ?? c.decodeLossyString(forKey: .created_at)
        kadi = c.decodeLossyString(forKey: .kadi)
        isim = c.decodeLossyString(forKey: .isim)
        soyisim = c.decodeLossyString(forKey: .soyisim)
        resim = c.decodeLossyString(forKey: .resim)
        verified = c.decodeLossyBool(forKey: .verified)
    }
}

struct AppNotification: Decodable, Identifiable {
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
    let verified: Bool?
    let inviteStatus: String?

    private enum CodingKeys: String, CodingKey {
        case id, type, entityId, sourceUserId, message, readAt, createdAt, kadi, isim, soyisim, resim, verified, inviteStatus
        case entity_id, source_user_id, read_at, created_at, invite_status, msg, text, yorum
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = container.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Missing notification id")
        }
        self.id = id
        self.type = container.decodeLossyString(forKey: .type)
        self.entityId = container.decodeLossyInt(forKey: .entityId)
            ?? container.decodeLossyInt(forKey: .entity_id)
        self.sourceUserId = container.decodeLossyInt(forKey: .sourceUserId)
            ?? container.decodeLossyInt(forKey: .source_user_id)
        self.message = container.decodeLossyString(forKey: .message)
            ?? container.decodeLossyString(forKey: .msg)
            ?? container.decodeLossyString(forKey: .text)
            ?? container.decodeLossyString(forKey: .yorum)
        self.readAt = container.decodeLossyString(forKey: .readAt)
            ?? container.decodeLossyString(forKey: .read_at)
        self.createdAt = container.decodeLossyString(forKey: .createdAt)
            ?? container.decodeLossyString(forKey: .created_at)
        self.kadi = container.decodeLossyString(forKey: .kadi)
        self.isim = container.decodeLossyString(forKey: .isim)
        self.soyisim = container.decodeLossyString(forKey: .soyisim)
        self.resim = container.decodeLossyString(forKey: .resim)
        self.verified = container.decodeLossyBool(forKey: .verified)
        self.inviteStatus = container.decodeLossyString(forKey: .inviteStatus)
            ?? container.decodeLossyString(forKey: .invite_status)
    }
}
