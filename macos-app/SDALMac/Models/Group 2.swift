import Foundation

struct SDALGroup: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let description: String?
    let coverImage: String?
    let ownerId: Int?
    let visibility: String?
    let members: Int?
    let joined: Bool?
    let pending: Bool?
    let invited: Bool?
    let myRole: String?
    let membershipStatus: String?
    let createdAt: String?
    let showContactHint: IntOrBool?

    var coverURL: URL? {
        guard let coverImage, !coverImage.isEmpty else { return nil }
        if coverImage.hasPrefix("http") { return URL(string: coverImage) }
        return URL(string: "\(APIConfig.baseURL)/\(coverImage)")
    }

    var isPublic: Bool { visibility == "public" }
    var memberCount: Int { members ?? 0 }
    var isMember: Bool { joined == true || membershipStatus == "member" }

    enum CodingKeys: String, CodingKey {
        case id, name, description, visibility, joined, pending, invited, members
        case coverImage = "cover_image"
        case ownerId = "owner_id"
        case myRole = "myRole"
        case membershipStatus = "membershipStatus"
        case createdAt = "created_at"
        case showContactHint = "show_contact_hint"
    }
}

struct GroupDetailResponse: Codable {
    let group: GroupDetailData?
}

struct GroupDetailData: Codable {
    let id: Int?
    let name: String?
    let description: String?
    let coverImage: String?
    let ownerId: Int?
    let visibility: String?
    let members: Int?
    let joined: Bool?
    let pending: Bool?
    let invited: Bool?
    let myRole: String?
    let posts: [Post]?
    let onlineMembers: [User]?

    enum CodingKeys: String, CodingKey {
        case id, name, description, visibility, joined, pending, invited, members, posts
        case coverImage = "cover_image"
        case ownerId = "owner_id"
        case myRole = "myRole"
        case onlineMembers = "onlineMembers"
    }
}

struct GroupsResponse: Codable {
    let items: [SDALGroup]?
    let hasMore: Bool?
}

struct GroupJoinResponse: Codable {
    let ok: Bool?
    let status: String?
}

struct Announcement: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let body: String?
    let image: String?
    let createdBy: Int?
    let creatorKadi: String?
    let approved: IntOrBool?
    let createdAt: String?

    var imageURL: URL? {
        guard let image, !image.isEmpty else { return nil }
        if image.hasPrefix("http") { return URL(string: image) }
        return URL(string: "\(APIConfig.baseURL)/\(image)")
    }

    var relativeTime: String {
        guard let createdAt else { return "" }
        return DateFormatter.relativeString(from: createdAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, body, image, approved
        case createdBy = "created_by"
        case creatorKadi = "creator_kadi"
        case createdAt = "created_at"
    }
}

struct AnnouncementsResponse: Codable {
    let items: [Announcement]?
    let hasMore: Bool?
}
