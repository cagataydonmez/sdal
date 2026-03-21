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

struct NotificationPreferences: Decodable {
    let socialEnabled: Bool?
    let messagingEnabled: Bool?
    let groupsEnabled: Bool?
    let eventsEnabled: Bool?
    let networkingEnabled: Bool?
    let jobsEnabled: Bool?
    let systemEnabled: Bool?

    private enum CodingKeys: String, CodingKey {
        case socialEnabled, messagingEnabled, groupsEnabled, eventsEnabled, networkingEnabled, jobsEnabled, systemEnabled
        case social_enabled, messaging_enabled, groups_enabled, events_enabled, networking_enabled, jobs_enabled, system_enabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        socialEnabled = c.decodeLossyBool(forKey: .socialEnabled) ?? c.decodeLossyBool(forKey: .social_enabled)
        messagingEnabled = c.decodeLossyBool(forKey: .messagingEnabled) ?? c.decodeLossyBool(forKey: .messaging_enabled)
        groupsEnabled = c.decodeLossyBool(forKey: .groupsEnabled) ?? c.decodeLossyBool(forKey: .groups_enabled)
        eventsEnabled = c.decodeLossyBool(forKey: .eventsEnabled) ?? c.decodeLossyBool(forKey: .events_enabled)
        networkingEnabled = c.decodeLossyBool(forKey: .networkingEnabled) ?? c.decodeLossyBool(forKey: .networking_enabled)
        jobsEnabled = c.decodeLossyBool(forKey: .jobsEnabled) ?? c.decodeLossyBool(forKey: .jobs_enabled)
        systemEnabled = c.decodeLossyBool(forKey: .systemEnabled) ?? c.decodeLossyBool(forKey: .system_enabled)
    }

    init(
        socialEnabled: Bool?,
        messagingEnabled: Bool?,
        groupsEnabled: Bool?,
        eventsEnabled: Bool?,
        networkingEnabled: Bool?,
        jobsEnabled: Bool?,
        systemEnabled: Bool?
    ) {
        self.socialEnabled = socialEnabled
        self.messagingEnabled = messagingEnabled
        self.groupsEnabled = groupsEnabled
        self.eventsEnabled = eventsEnabled
        self.networkingEnabled = networkingEnabled
        self.jobsEnabled = jobsEnabled
        self.systemEnabled = systemEnabled
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

    init(
        id: Int,
        type: String?,
        entityId: Int?,
        sourceUserId: Int?,
        message: String?,
        readAt: String?,
        createdAt: String?,
        kadi: String?,
        isim: String?,
        soyisim: String?,
        resim: String?,
        verified: Bool?,
        inviteStatus: String?
    ) {
        self.id = id
        self.type = type
        self.entityId = entityId
        self.sourceUserId = sourceUserId
        self.message = message
        self.readAt = readAt
        self.createdAt = createdAt
        self.kadi = kadi
        self.isim = isim
        self.soyisim = soyisim
        self.resim = resim
        self.verified = verified
        self.inviteStatus = inviteStatus
    }

    var isUnread: Bool {
        readAt?.isEmpty != false
    }

    func merged(with incoming: AppNotification) -> AppNotification {
        AppNotification(
            id: id,
            type: incoming.type ?? type,
            entityId: incoming.entityId ?? entityId,
            sourceUserId: incoming.sourceUserId ?? sourceUserId,
            message: incoming.message ?? message,
            readAt: readAt ?? incoming.readAt,
            createdAt: incoming.createdAt ?? createdAt,
            kadi: incoming.kadi ?? kadi,
            isim: incoming.isim ?? isim,
            soyisim: incoming.soyisim ?? soyisim,
            resim: incoming.resim ?? resim,
            verified: incoming.verified ?? verified,
            inviteStatus: incoming.inviteStatus ?? inviteStatus
        )
    }

    init?(pushPayload userInfo: [AnyHashable: Any]) {
        let id = AppNotification.integerValue(
            userInfo["notification_id"] ?? userInfo["notificationId"] ?? userInfo["id"]
        )
        let type = AppNotification.stringValue(userInfo["type"])
        let entityId = AppNotification.integerValue(userInfo["entity_id"] ?? userInfo["entityId"])
        let sourceUserId = AppNotification.integerValue(userInfo["source_user_id"] ?? userInfo["sourceUserId"] ?? userInfo["user_id"])
        let message = AppNotification.messageValue(from: userInfo)
        let createdAt = AppNotification.stringValue(userInfo["created_at"] ?? userInfo["createdAt"])
            ?? ISO8601DateFormatter().string(from: Date())
        let kadi = AppNotification.stringValue(userInfo["kadi"] ?? userInfo["username"] ?? userInfo["source_username"])
        let isim = AppNotification.stringValue(userInfo["isim"] ?? userInfo["first_name"] ?? userInfo["firstName"])
        let soyisim = AppNotification.stringValue(userInfo["soyisim"] ?? userInfo["last_name"] ?? userInfo["lastName"])
        let resim = AppNotification.stringValue(userInfo["resim"] ?? userInfo["avatar"] ?? userInfo["avatar_url"])
        let verified = AppNotification.boolValue(userInfo["verified"])
        let inviteStatus = AppNotification.stringValue(userInfo["invite_status"] ?? userInfo["inviteStatus"])

        guard let resolvedId = id else {
            return nil
        }

        self.init(
            id: resolvedId,
            type: type,
            entityId: entityId,
            sourceUserId: sourceUserId,
            message: message,
            readAt: nil,
            createdAt: createdAt,
            kadi: kadi,
            isim: isim,
            soyisim: soyisim,
            resim: resim,
            verified: verified,
            inviteStatus: inviteStatus
        )
    }

    private static func integerValue(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if let intValue = value as? Int {
            return intValue
        }
        return Int("\(value)")
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        guard let value else { return nil }
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let intValue = value as? Int {
            return intValue != 0
        }
        let stringValue = "\(value)".lowercased()
        if ["1", "true", "yes"].contains(stringValue) {
            return true
        }
        if ["0", "false", "no"].contains(stringValue) {
            return false
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let stringValue = value as? String, !stringValue.isEmpty {
            return stringValue
        }
        return nil
    }

    private static func messageValue(from userInfo: [AnyHashable: Any]) -> String? {
        if let direct = stringValue(userInfo["message"] ?? userInfo["msg"] ?? userInfo["text"] ?? userInfo["yorum"]) {
            return direct
        }
        guard let aps = userInfo["aps"] as? [String: Any] else {
            return nil
        }
        if let alert = aps["alert"] as? String, !alert.isEmpty {
            return alert
        }
        if let alert = aps["alert"] as? [String: Any] {
            return stringValue(alert["body"] ?? alert["subtitle"] ?? alert["title"])
        }
        return nil
    }
}

struct MessengerContactsEnvelope: Decodable {
    let items: [MessageRecipient]
}

struct MessengerThreadsEnvelope: Decodable {
    let items: [MessengerThread]
    let hasMore: Bool?
}

struct MessengerMessagesEnvelope: Decodable {
    let items: [MessengerMessage]
}

struct MessengerThreadCreateEnvelope: Decodable {
    let ok: Bool?
    let threadId: Int?
}

struct MessengerMessageCreateEnvelope: Decodable {
    let ok: Bool?
    let item: MessengerMessage?
}

struct MessengerPeer: Decodable {
    let id: Int?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: Bool?
}

struct MessengerThread: Decodable, Identifiable {
    let id: Int
    let peer: MessengerPeer?
    let lastMessage: MessengerMessage?
    let unreadCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, peer, lastMessage, unreadCount
        case last_message, unread_count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing thread id")
        }
        self.id = id
        self.peer = try? c.decodeIfPresent(MessengerPeer.self, forKey: .peer)
        self.lastMessage = (try? c.decodeIfPresent(MessengerMessage.self, forKey: .lastMessage))
            ?? (try? c.decodeIfPresent(MessengerMessage.self, forKey: .last_message))
        self.unreadCount = c.decodeLossyInt(forKey: .unreadCount) ?? c.decodeLossyInt(forKey: .unread_count)
    }
}

struct MessengerMessage: Decodable, Identifiable {
    let id: Int
    let threadId: Int?
    let senderId: Int?
    let receiverId: Int?
    let isMine: Bool?
    let body: String?
    let clientWrittenAt: String?
    let serverReceivedAt: String?
    let deliveredAt: String?
    let createdAt: String?
    let readAt: String?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, threadId, senderId, receiverId, isMine, body
        case clientWrittenAt, serverReceivedAt, deliveredAt
        case createdAt, readAt, kadi, isim, soyisim, resim, verified
        case thread_id, sender_id, receiver_id, is_mine, client_written_at, server_received_at, delivered_at, created_at, read_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing messenger message id")
        }
        self.id = id
        self.threadId = c.decodeLossyInt(forKey: .threadId) ?? c.decodeLossyInt(forKey: .thread_id)
        self.senderId = c.decodeLossyInt(forKey: .senderId) ?? c.decodeLossyInt(forKey: .sender_id)
        self.receiverId = c.decodeLossyInt(forKey: .receiverId) ?? c.decodeLossyInt(forKey: .receiver_id)
        if let mineInt = c.decodeLossyInt(forKey: .isMine) ?? c.decodeLossyInt(forKey: .is_mine) {
            self.isMine = mineInt == 1
        } else {
            self.isMine = c.decodeLossyBool(forKey: .isMine) ?? c.decodeLossyBool(forKey: .is_mine)
        }
        self.body = c.decodeLossyString(forKey: .body)
        self.clientWrittenAt = c.decodeLossyString(forKey: .clientWrittenAt) ?? c.decodeLossyString(forKey: .client_written_at)
        self.serverReceivedAt = c.decodeLossyString(forKey: .serverReceivedAt) ?? c.decodeLossyString(forKey: .server_received_at)
        self.deliveredAt = c.decodeLossyString(forKey: .deliveredAt) ?? c.decodeLossyString(forKey: .delivered_at)
        self.createdAt = c.decodeLossyString(forKey: .createdAt) ?? c.decodeLossyString(forKey: .created_at)
        self.readAt = c.decodeLossyString(forKey: .readAt) ?? c.decodeLossyString(forKey: .read_at)
        self.kadi = c.decodeLossyString(forKey: .kadi)
        self.isim = c.decodeLossyString(forKey: .isim)
        self.soyisim = c.decodeLossyString(forKey: .soyisim)
        self.resim = c.decodeLossyString(forKey: .resim)
        self.verified = c.decodeLossyBool(forKey: .verified)
    }
}
