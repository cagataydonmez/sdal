import Foundation

struct StoriesEnvelope: Decodable {
    let items: [Story]

    private enum CodingKeys: String, CodingKey {
        case items, rows, data, stories
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([Story].self, forKey: .items))
            ?? (try? c.decodeIfPresent([Story].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([Story].self, forKey: .data))
            ?? (try? c.decodeIfPresent([Story].self, forKey: .stories))
            ?? []
    }
}

struct MyStoriesEnvelope: Decodable {
    let items: [MyStoryItem]

    private enum CodingKeys: String, CodingKey {
        case items, rows, data, stories
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([MyStoryItem].self, forKey: .items))
            ?? (try? c.decodeIfPresent([MyStoryItem].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([MyStoryItem].self, forKey: .data))
            ?? (try? c.decodeIfPresent([MyStoryItem].self, forKey: .stories))
            ?? []
    }
}

struct Story: Decodable, Identifiable {
    let id: Int
    let image: String?
    let caption: String?
    let createdAt: String?
    let expiresAt: String?
    let isExpired: Bool?
    let viewed: Bool?
    let author: PostAuthor?

    private enum CodingKeys: String, CodingKey {
        case id, image, caption, createdAt, expiresAt, isExpired, viewed, author
        case created_at, expires_at, is_expired
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing story id")
        }
        self.id = id
        image = c.decodeLossyString(forKey: .image)
        caption = c.decodeLossyString(forKey: .caption)
        createdAt = c.decodeLossyString(forKey: .createdAt) ?? c.decodeLossyString(forKey: .created_at)
        expiresAt = c.decodeLossyString(forKey: .expiresAt) ?? c.decodeLossyString(forKey: .expires_at)
        isExpired = c.decodeLossyBool(forKey: .isExpired) ?? c.decodeLossyBool(forKey: .is_expired)
        viewed = c.decodeLossyBool(forKey: .viewed)
        author = try? c.decodeIfPresent(PostAuthor.self, forKey: .author)
    }
}

struct MyStoryItem: Decodable, Identifiable {
    let id: Int
    let image: String?
    let caption: String?
    let createdAt: String?
    let expiresAt: String?
    let isExpired: Bool?
    let viewCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, image, caption, createdAt, expiresAt, isExpired, viewCount
        case created_at, expires_at, is_expired, view_count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing my story id")
        }
        self.id = id
        image = c.decodeLossyString(forKey: .image)
        caption = c.decodeLossyString(forKey: .caption)
        createdAt = c.decodeLossyString(forKey: .createdAt) ?? c.decodeLossyString(forKey: .created_at)
        expiresAt = c.decodeLossyString(forKey: .expiresAt) ?? c.decodeLossyString(forKey: .expires_at)
        isExpired = c.decodeLossyBool(forKey: .isExpired) ?? c.decodeLossyBool(forKey: .is_expired)
        viewCount = c.decodeLossyInt(forKey: .viewCount) ?? c.decodeLossyInt(forKey: .view_count)
    }
}

struct APIWriteResponse: Decodable {
    let ok: Bool?
    let id: Int?
    let image: String?
}
