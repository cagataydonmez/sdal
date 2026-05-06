import Foundation

// MARK: - Feed Post

struct WatchPost: Identifiable {
    let id: Int
    let authorId: Int
    let authorName: String
    let authorHandle: String
    let authorPhoto: String
    let content: String
    var likeCount: Int
    let commentCount: Int
    let createdAt: String
    var liked: Bool
    let feedType: String
    let imageUrl: String   // primary post image

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        self.feedType = (json["feedType"] as? String) ?? (json["feed_type"] as? String) ?? "main"
        self.liked = boolValue(json["liked"]) ?? boolValue(json["liked_by_viewer"]) ?? false

        let author = (json["author"] as? [String: Any]) ?? json
        self.authorId = (author["id"] as? Int) ?? 0
        self.authorName = (author["isim"] as? String) ?? (author["name"] as? String) ?? ""
        self.authorHandle = (author["kadi"] as? String) ?? (author["handle"] as? String) ?? ""
        self.authorPhoto = (author["resim"] as? String) ?? (author["photo"] as? String) ?? ""

        self.content = (json["content"] as? String)
            ?? (json["icerik"] as? String)
            ?? (json["body"] as? String)
            ?? ""
        self.likeCount = (json["likeCount"] as? Int)
            ?? (json["like_count"] as? Int)
            ?? (json["likes"] as? Int)
            ?? 0
        self.commentCount = (json["commentCount"] as? Int)
            ?? (json["comment_count"] as? Int)
            ?? (json["comments"] as? Int)
            ?? 0
        self.createdAt = (json["createdAt"] as? String)
            ?? (json["created_at"] as? String)
            ?? ""

        let variants = (json["variants"] as? [String: Any]) ?? [:]
        if let variant = (variants["feedUrl"] as? String)
            ?? (variants["feed_url"] as? String)
            ?? (variants["fullUrl"] as? String)
            ?? (variants["full_url"] as? String),
            !variant.isEmpty {
            self.imageUrl = variant
        } else if let direct = (json["imageUrl"] as? String) ?? (json["image_url"] as? String), !direct.isEmpty {
            self.imageUrl = direct
        } else if let image = json["image"] as? String, !image.isEmpty {
            self.imageUrl = image
        } else if let mediaArr = json["media"] as? [[String: Any]],
                  let first = mediaArr.first,
                  let url = first["url"] as? String {
            self.imageUrl = url
        } else if let media = json["media"] as? [String: Any],
                  let url = media["url"] as? String {
            self.imageUrl = url
        } else if let images = json["images"] as? [String], let first = images.first {
            self.imageUrl = first
        } else {
            self.imageUrl = ""
        }
    }

    var initials: String {
        let words = authorName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

// MARK: - Comment

struct WatchComment: Identifiable {
    let id: Int
    let userId: Int
    let comment: String
    let authorName: String
    let authorHandle: String
    let authorPhoto: String
    let createdAt: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        self.userId = (json["userId"] as? Int) ?? (json["user_id"] as? Int) ?? 0
        self.comment = (json["comment"] as? String) ?? (json["body"] as? String) ?? ""
        let first = (json["isim"] as? String) ?? ""
        let last = (json["soyisim"] as? String) ?? ""
        self.authorName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        self.authorHandle = (json["kadi"] as? String) ?? ""
        self.authorPhoto = (json["resim"] as? String) ?? ""
        self.createdAt = (json["createdAt"] as? String) ?? (json["created_at"] as? String) ?? ""
    }

    var initials: String {
        let words = authorName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

// MARK: - Story

struct WatchStory: Identifiable {
    let id: Int
    let caption: String
    var viewed: Bool
    let createdAt: String
    let authorId: Int
    let authorName: String
    let authorHandle: String
    let authorPhoto: String
    let feedUrl: String
    let fullUrl: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        self.caption = (json["caption"] as? String) ?? ""
        self.viewed = boolValue(json["viewed"]) ?? false
        self.createdAt = (json["createdAt"] as? String) ?? (json["created_at"] as? String) ?? ""

        let author = (json["author"] as? [String: Any]) ?? [:]
        self.authorId = (author["id"] as? Int) ?? 0
        let first = (author["isim"] as? String) ?? ""
        let last = (author["soyisim"] as? String) ?? ""
        self.authorName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        self.authorHandle = (author["kadi"] as? String) ?? ""
        self.authorPhoto = (author["resim"] as? String) ?? ""

        let variants = (json["variants"] as? [String: Any]) ?? [:]
        let feedRaw = (variants["feedUrl"] as? String)
            ?? (variants["feed_url"] as? String)
            ?? (variants["thumbUrl"] as? String)
            ?? (variants["thumb_url"] as? String)
            ?? (json["image"] as? String)
            ?? (json["imageUrl"] as? String) ?? (json["image_url"] as? String) ?? ""
        self.feedUrl = feedRaw
        self.fullUrl = ((variants["fullUrl"] as? String)
            ?? (variants["full_url"] as? String))
            .flatMap { $0.isEmpty ? nil : $0 } ?? feedRaw
    }

    var initials: String {
        let words = authorName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

// MARK: - Member

struct WatchMember: Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let handle: String
    let photo: String
    let profession: String
    let city: String
    let graduationYear: String
    var following: Bool
    var isOnline: Bool

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        self.firstName = (json["isim"] as? String) ?? ""
        self.lastName = (json["soyisim"] as? String) ?? ""
        self.handle = (json["kadi"] as? String) ?? ""
        self.photo = (json["resim"] as? String) ?? ""
        self.profession = (json["meslek"] as? String) ?? ""
        self.city = (json["sehir"] as? String) ?? ""
        let year = (json["mezuniyetyili"] as? Int).map { String($0) }
            ?? (json["mezuniyetyili"] as? String)
            ?? ""
        self.graduationYear = year
        self.following = boolValue(json["following"]) ?? false
        self.isOnline = boolValue(json["isOnline"]) ?? boolValue(json["is_online"]) ?? false
    }

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var initials: String {
        let words = fullName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

// MARK: - Message Thread

struct WatchThread: Identifiable {
    let id: Int
    let peerUserId: Int
    let peerName: String
    let peerHandle: String
    let peerPhoto: String
    let lastMessage: String
    let unreadCount: Int
    let updatedAt: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id

        let peer = (json["other_user"] as? [String: Any])
            ?? (json["peer"] as? [String: Any])
            ?? json
        self.peerUserId = (peer["id"] as? Int) ?? 0
        let first = (peer["isim"] as? String) ?? (peer["name"] as? String) ?? ""
        let last = (peer["soyisim"] as? String) ?? ""
        self.peerName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        self.peerHandle = (peer["kadi"] as? String) ?? (peer["handle"] as? String) ?? ""
        self.peerPhoto = (peer["resim"] as? String) ?? (peer["photo"] as? String) ?? ""

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

// MARK: - Message

struct WatchMessage: Identifiable {
    let id: Int
    let senderId: Int
    let body: String
    let createdAt: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        self.senderId = (json["sender_id"] as? Int) ?? (json["senderId"] as? Int) ?? 0
        self.body = (json["body"] as? String) ?? (json["content"] as? String) ?? ""
        self.createdAt = (json["created_at"] as? String) ?? (json["createdAt"] as? String) ?? ""
    }
}

// MARK: - Contact

struct WatchContact: Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let handle: String
    let photo: String

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        self.firstName = (json["isim"] as? String) ?? ""
        self.lastName = (json["soyisim"] as? String) ?? ""
        self.handle = (json["kadi"] as? String) ?? ""
        self.photo = (json["resim"] as? String) ?? ""
    }

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var initials: String {
        let words = fullName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

// MARK: - Notification

struct WatchNotificationItem: Identifiable {
    let id: Int
    let type: String
    let actorId: Int
    let actorName: String
    let actorPhoto: String
    let body: String
    var isRead: Bool
    let createdAt: String
    let targetId: Int
    let targetType: String
    let targetImageUrl: String   // image of the target content (e.g. post image)

    init?(json: [String: Any]) {
        guard let id = json["id"] as? Int else { return nil }
        self.id = id
        self.type = (json["type"] as? String)
            ?? (json["notification_type"] as? String)
            ?? "general"
        let actor = (json["actor"] as? [String: Any])
            ?? (json["source"] as? [String: Any])
        self.actorId = (actor?["id"] as? Int) ?? 0
        let first = (actor?["isim"] as? String) ?? (actor?["name"] as? String) ?? ""
        let last = (actor?["soyisim"] as? String) ?? ""
        self.actorName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        self.actorPhoto = (actor?["resim"] as? String) ?? ""
        self.body = (json["body"] as? String)
            ?? (json["message"] as? String)
            ?? (json["content"] as? String)
            ?? ""
        self.isRead = boolValue(json["is_read"])
            ?? boolValue(json["read"])
            ?? false
        self.createdAt = (json["created_at"] as? String)
            ?? (json["createdAt"] as? String)
            ?? ""
        let target = (json["target"] as? [String: Any]) ?? [:]
        self.targetId = (target["id"] as? Int) ?? 0
        self.targetType = (target["type"] as? String) ?? ""
        self.targetImageUrl = (target["imageUrl"] as? String)
            ?? (target["image_url"] as? String)
            ?? (target["image"] as? String)
            ?? ""
    }

    var sourceName: String { actorName }

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

    var accentColor: String {
        switch type {
        case "like": return "red"
        case "comment": return "blue"
        case "follow": return "green"
        case "mention": return "orange"
        case "message": return "blue"
        default: return "gray"
        }
    }

    var initials: String {
        let words = actorName.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}

private func boolValue(_ raw: Any?) -> Bool? {
    if let value = raw as? Bool { return value }
    if let value = raw as? Int { return value != 0 }
    if let value = raw as? NSNumber { return value.intValue != 0 }
    if let value = raw as? String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["1", "true", "yes", "evet"].contains(normalized) { return true }
        if ["0", "false", "no", "hayir", "hayır"].contains(normalized) { return false }
    }
    return nil
}

// MARK: - Deep Link Target

enum DeepLinkTarget: Equatable {
    case post(Int)
    case thread(Int)
    case member(Int)
    case notifications
}
