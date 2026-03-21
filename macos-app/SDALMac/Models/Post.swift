import Foundation

struct PostAuthor: Codable, Hashable {
    let id: Int?
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

    var initials: String {
        let first = isim?.prefix(1) ?? ""
        let last = soyisim?.prefix(1) ?? ""
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? "?" : result
    }
}

struct PostVariants: Codable, Hashable {
    let thumbUrl: String?
    let feedUrl: String?
    let fullUrl: String?
}

struct Post: Codable, Identifiable, Hashable {
    let id: Int
    let content: String?
    let image: String?
    let createdAt: String?
    let author: PostAuthor?
    let groupId: Int?
    let likeCount: Int?
    let commentCount: Int?
    let liked: Bool?
    let variants: PostVariants?

    var authorDisplayName: String {
        author?.displayName ?? "User"
    }

    var authorPhotoURL: URL? {
        author?.photoURL
    }

    var imageURL: URL? {
        if let feedUrl = variants?.feedUrl, !feedUrl.isEmpty {
            if feedUrl.hasPrefix("http") { return URL(string: feedUrl) }
            return URL(string: "\(APIConfig.baseURL)\(feedUrl)")
        }
        guard let image, !image.isEmpty else { return nil }
        if image.hasPrefix("http") { return URL(string: image) }
        return URL(string: "\(APIConfig.baseURL)/\(image)")
    }

    var relativeTime: String {
        guard let createdAt else { return "" }
        return DateFormatter.relativeString(from: createdAt)
    }
}

struct PostComment: Codable, Identifiable, Hashable {
    let id: Int
    let postId: Int?
    let userId: Int?
    let comment: String?
    let createdAt: String?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?

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
        case id, comment, kadi, isim, soyisim, resim
        case postId = "post_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct FeedResponse: Codable {
    let items: [Post]?
    let hasMore: Bool?
}

struct CommentsResponse: Codable {
    let items: [PostComment]?
}

struct CreatePostResponse: Codable {
    let ok: Bool?
    let id: Int?
}

struct LikeResponse: Codable {
    let ok: Bool?
    let liked: Bool?
}
