import Foundation

struct Story: Codable, Identifiable, Hashable {
    let id: Int
    let userId: Int?
    let image: String?
    let imageRecordId: Int?
    let caption: String?
    let createdAt: String?
    let expiresAt: String?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: IntOrBool?
    let variants: PostVariants?
    let viewed: Bool?

    var authorDisplayName: String {
        let first = isim ?? ""
        let last = soyisim ?? ""
        let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (kadi ?? "User") : full
    }

    var authorPhotoURL: URL? {
        guard let resim, !resim.isEmpty else { return nil }
        if resim.hasPrefix("http") { return URL(string: resim) }
        return URL(string: "\(APIConfig.baseURL)/\(resim)")
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

    var initials: String {
        let first = isim?.prefix(1) ?? ""
        let last = soyisim?.prefix(1) ?? ""
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? "?" : result
    }

    enum CodingKeys: String, CodingKey {
        case id, image, caption, kadi, isim, soyisim, resim, verified, variants, viewed
        case userId = "user_id"
        case imageRecordId = "image_record_id"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

struct StoriesResponse: Codable {
    let items: [Story]?
}
