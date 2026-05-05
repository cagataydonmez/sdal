import Foundation

// MARK: - Feed Post

struct WatchPost: Identifiable {
    let id: Int
    let authorName: String
    let authorHandle: String
    let authorPhoto: String
    let content: String
    let likeCount: Int
    let commentCount: Int
    let createdAt: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        self.authorName = (json["isim"] as? String) ?? (json["name"] as? String) ?? ""
        self.authorHandle = (json["kadi"] as? String) ?? (json["handle"] as? String) ?? ""
        self.authorPhoto = (json["resim"] as? String) ?? (json["photo"] as? String) ?? ""
        self.content = (json["icerik"] as? String)
            ?? (json["content"] as? String)
            ?? (json["body"] as? String)
            ?? ""
        self.likeCount = (json["like_count"] as? Int)
            ?? (json["likes"] as? Int)
            ?? 0
        self.commentCount = (json["comment_count"] as? Int)
            ?? (json["comments"] as? Int)
            ?? 0
        self.createdAt = (json["created_at"] as? String)
            ?? (json["createdAt"] as? String)
            ?? ""
    }

    // Initials for avatar fallback
    var initials: String {
        let words = authorName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

// MARK: - Message Thread

struct WatchThread: Identifiable {
    let id: Int
    let peerName: String
    let peerHandle: String
    let peerPhoto: String
    let lastMessage: String
    let unreadCount: Int
    let updatedAt: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id

        // peer can be nested under "other_user", "peer", or flat
        let peer = (json["other_user"] as? [String: Any])
            ?? (json["peer"] as? [String: Any])
            ?? json
        self.peerName = (peer["isim"] as? String) ?? (peer["name"] as? String) ?? ""
        self.peerHandle = (peer["kadi"] as? String) ?? (peer["handle"] as? String) ?? ""
        self.peerPhoto = (peer["resim"] as? String) ?? (peer["photo"] as? String) ?? ""

        // last message
        let lastMsg = (json["last_message"] as? [String: Any])
            ?? (json["latest_message"] as? [String: Any])
        self.lastMessage = (lastMsg?["body"] as? String)
            ?? (json["last_message"] as? String)
            ?? ""
        self.unreadCount = (json["unread_count"] as? Int) ?? 0
        self.updatedAt = (json["updated_at"] as? String)
            ?? (json["updatedAt"] as? String)
            ?? ""
    }

    var initials: String {
        let words = peerName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

// MARK: - Notification

struct WatchNotificationItem: Identifiable {
    let id: Int
    let type: String
    let sourceName: String
    let body: String
    let isRead: Bool
    let createdAt: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        self.type = (json["type"] as? String)
            ?? (json["notification_type"] as? String)
            ?? "general"
        let actor = (json["actor"] as? [String: Any])
            ?? (json["source"] as? [String: Any])
        self.sourceName = (actor?["isim"] as? String)
            ?? (actor?["name"] as? String)
            ?? (json["source_name"] as? String)
            ?? ""
        self.body = (json["body"] as? String)
            ?? (json["message"] as? String)
            ?? (json["content"] as? String)
            ?? ""
        self.isRead = (json["is_read"] as? Bool)
            ?? (json["read"] as? Bool)
            ?? false
        self.createdAt = (json["created_at"] as? String)
            ?? (json["createdAt"] as? String)
            ?? ""
    }

    var systemImageName: String {
        switch type {
        case "like": return "heart.fill"
        case "comment": return "bubble.left.fill"
        case "follow": return "person.fill.badge.plus"
        case "mention": return "at"
        case "message": return "bubble.right.fill"
        default: return "bell.fill"
        }
    }
}
