import Foundation

struct StoryImageVariants: Decodable {
    let thumb: String?
    let feed: String?
    let full: String?

    private enum CodingKeys: String, CodingKey {
        case thumb
        case feed
        case full
        case thumbUrl
        case feedUrl
        case fullUrl
        case thumb_url
        case feed_url
        case full_url
        case imageThumb
        case imageFeed
        case imageFull
        case image_thumb
        case image_feed
        case image_full
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        thumb = c.decodeLossyString(forKey: .thumb)
            ?? c.decodeLossyString(forKey: .thumbUrl)
            ?? c.decodeLossyString(forKey: .thumb_url)
            ?? c.decodeLossyString(forKey: .imageThumb)
            ?? c.decodeLossyString(forKey: .image_thumb)
        feed = c.decodeLossyString(forKey: .feed)
            ?? c.decodeLossyString(forKey: .feedUrl)
            ?? c.decodeLossyString(forKey: .feed_url)
            ?? c.decodeLossyString(forKey: .imageFeed)
            ?? c.decodeLossyString(forKey: .image_feed)
        full = c.decodeLossyString(forKey: .full)
            ?? c.decodeLossyString(forKey: .fullUrl)
            ?? c.decodeLossyString(forKey: .full_url)
            ?? c.decodeLossyString(forKey: .imageFull)
            ?? c.decodeLossyString(forKey: .image_full)
    }
}

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
    let variants: StoryImageVariants?
    let caption: String?
    let createdAt: String?
    let expiresAt: String?
    let isExpired: Bool?
    let viewed: Bool?
    let author: PostAuthor?

    private enum CodingKeys: String, CodingKey {
        case id, image, caption, createdAt, expiresAt, isExpired, viewed, author
        case variants, images
        case thumb, feed, full
        case thumb_url, feed_url, full_url
        case image_thumb, image_feed, image_full
        case created_at, expires_at, is_expired
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing story id")
        }
        self.id = id
        image = c.decodeLossyString(forKey: .image)
        variants = Story.decodeVariants(from: c)
        caption = c.decodeLossyString(forKey: .caption)
        createdAt = c.decodeLossyString(forKey: .createdAt) ?? c.decodeLossyString(forKey: .created_at)
        expiresAt = c.decodeLossyString(forKey: .expiresAt) ?? c.decodeLossyString(forKey: .expires_at)
        isExpired = c.decodeLossyBool(forKey: .isExpired) ?? c.decodeLossyBool(forKey: .is_expired)
        viewed = c.decodeLossyBool(forKey: .viewed)
        author = try? c.decodeIfPresent(PostAuthor.self, forKey: .author)
    }

    var thumbnailPath: String? {
        variants?.thumb ?? variants?.feed ?? variants?.full ?? image
    }

    var feedPath: String? {
        variants?.feed ?? variants?.full ?? variants?.thumb ?? image
    }

    var fullScreenPath: String? {
        variants?.full ?? variants?.feed ?? variants?.thumb ?? image
    }

    private static func decodeVariants(from container: KeyedDecodingContainer<CodingKeys>) -> StoryImageVariants? {
        if let nested = try? container.decodeIfPresent(StoryImageVariants.self, forKey: .variants) {
            return nested
        }
        if let nested = try? container.decodeIfPresent(StoryImageVariants.self, forKey: .images) {
            return nested
        }
        let thumb = container.decodeLossyString(forKey: .thumb)
            ?? container.decodeLossyString(forKey: .thumb_url)
            ?? container.decodeLossyString(forKey: .image_thumb)
        let feed = container.decodeLossyString(forKey: .feed)
            ?? container.decodeLossyString(forKey: .feed_url)
            ?? container.decodeLossyString(forKey: .image_feed)
        let full = container.decodeLossyString(forKey: .full)
            ?? container.decodeLossyString(forKey: .full_url)
            ?? container.decodeLossyString(forKey: .image_full)
        guard thumb != nil || feed != nil || full != nil else {
            return nil
        }
        return StoryImageVariants(thumb: thumb, feed: feed, full: full)
    }
}

struct MyStoryItem: Decodable, Identifiable {
    let id: Int
    let image: String?
    let variants: StoryImageVariants?
    let caption: String?
    let createdAt: String?
    let expiresAt: String?
    let isExpired: Bool?
    let viewCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, image, caption, createdAt, expiresAt, isExpired, viewCount
        case variants, images
        case thumb, feed, full
        case thumb_url, feed_url, full_url
        case image_thumb, image_feed, image_full
        case created_at, expires_at, is_expired, view_count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing my story id")
        }
        self.id = id
        image = c.decodeLossyString(forKey: .image)
        variants = MyStoryItem.decodeVariants(from: c)
        caption = c.decodeLossyString(forKey: .caption)
        createdAt = c.decodeLossyString(forKey: .createdAt) ?? c.decodeLossyString(forKey: .created_at)
        expiresAt = c.decodeLossyString(forKey: .expiresAt) ?? c.decodeLossyString(forKey: .expires_at)
        isExpired = c.decodeLossyBool(forKey: .isExpired) ?? c.decodeLossyBool(forKey: .is_expired)
        viewCount = c.decodeLossyInt(forKey: .viewCount) ?? c.decodeLossyInt(forKey: .view_count)
    }

    var thumbnailPath: String? {
        variants?.thumb ?? variants?.feed ?? variants?.full ?? image
    }

    var fullScreenPath: String? {
        variants?.full ?? variants?.feed ?? variants?.thumb ?? image
    }

    private static func decodeVariants(from container: KeyedDecodingContainer<CodingKeys>) -> StoryImageVariants? {
        if let nested = try? container.decodeIfPresent(StoryImageVariants.self, forKey: .variants) {
            return nested
        }
        if let nested = try? container.decodeIfPresent(StoryImageVariants.self, forKey: .images) {
            return nested
        }
        let thumb = container.decodeLossyString(forKey: .thumb)
            ?? container.decodeLossyString(forKey: .thumb_url)
            ?? container.decodeLossyString(forKey: .image_thumb)
        let feed = container.decodeLossyString(forKey: .feed)
            ?? container.decodeLossyString(forKey: .feed_url)
            ?? container.decodeLossyString(forKey: .image_feed)
        let full = container.decodeLossyString(forKey: .full)
            ?? container.decodeLossyString(forKey: .full_url)
            ?? container.decodeLossyString(forKey: .image_full)
        guard thumb != nil || feed != nil || full != nil else {
            return nil
        }
        return StoryImageVariants(thumb: thumb, feed: feed, full: full)
    }
}

struct APIWriteResponse: Decodable {
    let ok: Bool?
    let id: Int?
    let image: String?
}

private extension StoryImageVariants {
    init(thumb: String?, feed: String?, full: String?) {
        self.thumb = thumb
        self.feed = feed
        self.full = full
    }
}
