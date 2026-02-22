import Foundation

struct FeedEnvelope: Decodable {
    let items: [FeedPost]

    private enum CodingKeys: String, CodingKey {
        case items, posts, rows, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([FeedPost].self, forKey: .items))
            ?? (try? c.decodeIfPresent([FeedPost].self, forKey: .posts))
            ?? (try? c.decodeIfPresent([FeedPost].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([FeedPost].self, forKey: .data))
            ?? []
    }
}

struct FeedPost: Decodable, Identifiable {
    let id: Int
    let content: String?
    let createdAt: String?
    let image: String?
    let likeCount: Int?
    let commentCount: Int?
    let liked: Bool?
    let groupId: Int?
    let author: PostAuthor?

    private enum CodingKeys: String, CodingKey {
        case id
        case content
        case createdAt
        case image
        case likeCount
        case commentCount
        case liked
        case groupId
        case author
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = container.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Missing feed post id")
        }
        self.id = id
        self.content = container.decodeLossyString(forKey: .content)
        self.createdAt = container.decodeLossyString(forKey: .createdAt)
        self.image = container.decodeLossyString(forKey: .image)
        self.likeCount = container.decodeLossyInt(forKey: .likeCount)
        self.commentCount = container.decodeLossyInt(forKey: .commentCount)
        self.liked = container.decodeLossyBool(forKey: .liked)
        self.groupId = container.decodeLossyInt(forKey: .groupId)
        self.author = try? container.decodeIfPresent(PostAuthor.self, forKey: .author)
    }
}

struct PostComment: Decodable, Identifiable {
    let id: Int
    let comment: String?
    let createdAt: String?
    let userId: Int?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?

    private enum CodingKeys: String, CodingKey {
        case id, comment, message, yorum, content, createdAt, created_at, userId, user_id, kadi, isim, soyisim, resim
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = container.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Missing post comment id")
        }
        self.id = id
        self.comment = container.decodeLossyString(forKey: .comment)
            ?? container.decodeLossyString(forKey: .message)
            ?? container.decodeLossyString(forKey: .yorum)
            ?? container.decodeLossyString(forKey: .content)
        self.createdAt = container.decodeLossyString(forKey: .createdAt)
            ?? container.decodeLossyString(forKey: .created_at)
        self.userId = container.decodeLossyInt(forKey: .userId)
            ?? container.decodeLossyInt(forKey: .user_id)
        self.kadi = container.decodeLossyString(forKey: .kadi)
        self.isim = container.decodeLossyString(forKey: .isim)
        self.soyisim = container.decodeLossyString(forKey: .soyisim)
        self.resim = container.decodeLossyString(forKey: .resim)
    }
}

struct PostCommentsEnvelope: Decodable {
    let items: [PostComment]

    private enum CodingKeys: String, CodingKey {
        case items, comments, rows, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([PostComment].self, forKey: .items))
            ?? (try? c.decodeIfPresent([PostComment].self, forKey: .comments))
            ?? (try? c.decodeIfPresent([PostComment].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([PostComment].self, forKey: .data))
            ?? []
    }
}

struct PostAuthor: Decodable {
    let id: Int?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case kadi
        case isim
        case soyisim
        case resim
        case verified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeLossyInt(forKey: .id)
        kadi = container.decodeLossyString(forKey: .kadi)
        isim = container.decodeLossyString(forKey: .isim)
        soyisim = container.decodeLossyString(forKey: .soyisim)
        resim = container.decodeLossyString(forKey: .resim)
        verified = container.decodeLossyBool(forKey: .verified)
    }
}
