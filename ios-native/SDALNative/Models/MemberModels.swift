import Foundation

struct MembersEnvelope: Decodable {
    let items: [MemberSummary]?
    let rows: [MemberSummary]?
    let users: [MemberSummary]?
    let data: [MemberSummary]?

    var list: [MemberSummary] { items ?? rows ?? users ?? data ?? [] }
}

struct MemberSummary: Decodable, Identifiable {
    let id: Int
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: Bool?
    let online: Bool?
    let mezuniyetyili: String?
    let sehir: String?
    let universite: String?
    let meslek: String?
    let followedAt: String?
    let engagementScore: Double?
    let reasons: [String]?

    private enum CodingKeys: String, CodingKey {
        case id, kadi, isim, soyisim, resim, verified, online, mezuniyetyili, sehir, universite, meslek, followedAt, engagementScore, reasons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = container.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Missing member id")
        }
        self.id = id
        kadi = container.decodeLossyString(forKey: .kadi)
        isim = container.decodeLossyString(forKey: .isim)
        soyisim = container.decodeLossyString(forKey: .soyisim)
        resim = container.decodeLossyString(forKey: .resim)
        verified = container.decodeLossyBool(forKey: .verified)
        online = container.decodeLossyBool(forKey: .online)
        mezuniyetyili = container.decodeLossyString(forKey: .mezuniyetyili)
        sehir = container.decodeLossyString(forKey: .sehir)
        universite = container.decodeLossyString(forKey: .universite)
        meslek = container.decodeLossyString(forKey: .meslek)
        followedAt = container.decodeLossyString(forKey: .followedAt)
        if let val = try? container.decodeIfPresent(Double.self, forKey: .engagementScore) {
            engagementScore = val
        } else if let val = container.decodeLossyInt(forKey: .engagementScore) {
            engagementScore = Double(val)
        } else {
            engagementScore = nil
        }
        reasons = try? container.decodeIfPresent([String].self, forKey: .reasons)
    }
}

struct MemberDetailEnvelope: Decodable {
    let row: MemberDetail?
}

struct MemberDetail: Decodable {
    let id: Int?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let email: String?
    let mezuniyetyili: String?
    let sehir: String?
    let universite: String?
    let meslek: String?
    let websitesi: String?
    let imza: String?
    let resim: String?
    let online: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, kadi, isim, soyisim, email, mezuniyetyili, sehir, universite, meslek, websitesi, imza, resim, online
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeLossyInt(forKey: .id)
        kadi = c.decodeLossyString(forKey: .kadi)
        isim = c.decodeLossyString(forKey: .isim)
        soyisim = c.decodeLossyString(forKey: .soyisim)
        email = c.decodeLossyString(forKey: .email)
        mezuniyetyili = c.decodeLossyString(forKey: .mezuniyetyili)
        sehir = c.decodeLossyString(forKey: .sehir)
        universite = c.decodeLossyString(forKey: .universite)
        meslek = c.decodeLossyString(forKey: .meslek)
        websitesi = c.decodeLossyString(forKey: .websitesi)
        imza = c.decodeLossyString(forKey: .imza)
        resim = c.decodeLossyString(forKey: .resim)
        online = c.decodeLossyBool(forKey: .online)
    }
}

struct AlbumCategoryEnvelope: Decodable {
    let items: [AlbumCategory]
}

struct ActiveAlbumCategoryEnvelope: Decodable {
    let categories: [AlbumCategory]
}

struct AlbumCategory: Decodable, Identifiable {
    let id: Int
    let kategori: String?
    let aciklama: String?
    let count: Int?
    let previews: [String]?

    private enum CodingKeys: String, CodingKey { case id, kategori, aciklama, count, previews }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing album category id")
        }
        self.id = id
        kategori = c.decodeLossyString(forKey: .kategori)
        aciklama = c.decodeLossyString(forKey: .aciklama)
        count = c.decodeLossyInt(forKey: .count)
        previews = try? c.decodeIfPresent([String].self, forKey: .previews)
    }
}

struct AlbumListEnvelope: Decodable {
    let category: AlbumCategory?
    let photos: [AlbumPhoto]
    let page: Int?
    let pages: Int?
}

struct AlbumPhoto: Decodable, Identifiable {
    let id: Int
    let dosyaadi: String?
    let baslik: String?
    let tarih: String?

    private enum CodingKeys: String, CodingKey { case id, dosyaadi, baslik, tarih }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing album photo id")
        }
        self.id = id
        dosyaadi = c.decodeLossyString(forKey: .dosyaadi)
        baslik = c.decodeLossyString(forKey: .baslik)
        tarih = c.decodeLossyString(forKey: .tarih)
    }
}

struct AlbumLatestEnvelope: Decodable {
    let items: [AlbumLatestItem]
    let hasMore: Bool?
}

struct AlbumLatestItem: Decodable, Identifiable {
    let id: Int
    let katid: Int?
    let dosyaadi: String?
    let tarih: String?
    let hit: Int?
    let kategori: String?

    private enum CodingKeys: String, CodingKey { case id, katid, dosyaadi, tarih, hit, kategori }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing latest album photo id")
        }
        self.id = id
        katid = c.decodeLossyInt(forKey: .katid)
        dosyaadi = c.decodeLossyString(forKey: .dosyaadi)
        tarih = c.decodeLossyString(forKey: .tarih)
        hit = c.decodeLossyInt(forKey: .hit)
        kategori = c.decodeLossyString(forKey: .kategori)
    }
}

struct QuickAccessEnvelope: Decodable {
    let users: [MemberSummary]
}

struct PhotoDetailEnvelope: Decodable {
    let row: PhotoDetail?
    let comments: [PhotoComment]?
}

struct PhotoDetail: Decodable {
    let id: Int?
    let katid: Int?
    let dosyaadi: String?
    let baslik: String?
    let aciklama: String?
    let tarih: String?

    private enum CodingKeys: String, CodingKey { case id, katid, dosyaadi, baslik, aciklama, tarih }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeLossyInt(forKey: .id)
        katid = c.decodeLossyInt(forKey: .katid)
        dosyaadi = c.decodeLossyString(forKey: .dosyaadi)
        baslik = c.decodeLossyString(forKey: .baslik)
        aciklama = c.decodeLossyString(forKey: .aciklama)
        tarih = c.decodeLossyString(forKey: .tarih)
    }
}

struct PhotoCommentsEnvelope: Decodable {
    let comments: [PhotoComment]
}

struct PhotoComment: Decodable, Identifiable {
    let id: Int
    let uyeadi: String?
    let yorum: String?
    let tarih: String?
    let kadi: String?
    let resim: String?

    private enum CodingKeys: String, CodingKey { case id, uyeadi, yorum, tarih, kadi, resim }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing photo comment id")
        }
        self.id = id
        uyeadi = c.decodeLossyString(forKey: .uyeadi)
        yorum = c.decodeLossyString(forKey: .yorum)
        tarih = c.decodeLossyString(forKey: .tarih)
        kadi = c.decodeLossyString(forKey: .kadi)
        resim = c.decodeLossyString(forKey: .resim)
    }
}

struct EventsEnvelope: Decodable {
    let items: [EventItem]

    private enum CodingKeys: String, CodingKey {
        case items, rows, events, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([EventItem].self, forKey: .items))
            ?? (try? c.decodeIfPresent([EventItem].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([EventItem].self, forKey: .events))
            ?? (try? c.decodeIfPresent([EventItem].self, forKey: .data))
            ?? []
    }
}

struct EventItem: Decodable, Identifiable {
    let id: Int
    let title: String?
    let description: String?
    let location: String?
    let startsAt: String?
    let endsAt: String?
    let image: String?
    let creatorKadi: String?
    let responseCounts: EventResponseCounts?
    let myResponse: String?
    let approved: Bool?
    let canManageResponses: Bool?
    let responseVisibility: EventResponseVisibility?

    private enum CodingKeys: String, CodingKey {
        case id, title, description, location, startsAt, endsAt, image, creatorKadi, responseCounts, myResponse, approved, canManageResponses, responseVisibility
        case starts_at, ends_at, creator_kadi, response_counts, my_response, can_manage_responses, response_visibility
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing event id")
        }
        self.id = id
        title = c.decodeLossyString(forKey: .title)
        description = c.decodeLossyString(forKey: .description)
        location = c.decodeLossyString(forKey: .location)
        startsAt = c.decodeLossyString(forKey: .startsAt) ?? c.decodeLossyString(forKey: .starts_at)
        endsAt = c.decodeLossyString(forKey: .endsAt) ?? c.decodeLossyString(forKey: .ends_at)
        image = c.decodeLossyString(forKey: .image)
        creatorKadi = c.decodeLossyString(forKey: .creatorKadi) ?? c.decodeLossyString(forKey: .creator_kadi)
        responseCounts = (try? c.decodeIfPresent(EventResponseCounts.self, forKey: .responseCounts))
            ?? (try? c.decodeIfPresent(EventResponseCounts.self, forKey: .response_counts))
        myResponse = c.decodeLossyString(forKey: .myResponse) ?? c.decodeLossyString(forKey: .my_response)
        approved = c.decodeLossyBool(forKey: .approved)
        canManageResponses = c.decodeLossyBool(forKey: .canManageResponses) ?? c.decodeLossyBool(forKey: .can_manage_responses)
        responseVisibility = (try? c.decodeIfPresent(EventResponseVisibility.self, forKey: .responseVisibility))
            ?? (try? c.decodeIfPresent(EventResponseVisibility.self, forKey: .response_visibility))
    }
}

struct EventResponseCounts: Decodable {
    let attend: Int?
    let decline: Int?
}

struct EventResponseVisibility: Decodable {
    let showCounts: Bool?
    let showAttendeeNames: Bool?
    let showDeclinerNames: Bool?
}

struct EventCommentsEnvelope: Decodable {
    let items: [EventComment]

    private enum CodingKeys: String, CodingKey {
        case items, rows, comments, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([EventComment].self, forKey: .items))
            ?? (try? c.decodeIfPresent([EventComment].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([EventComment].self, forKey: .comments))
            ?? (try? c.decodeIfPresent([EventComment].self, forKey: .data))
            ?? []
    }
}

struct EventComment: Decodable, Identifiable {
    let id: Int
    let comment: String?
    let createdAt: String?
    let kadi: String?
    let resim: String?

    private enum CodingKeys: String, CodingKey { case id, comment, message, yorum, createdAt, created_at, kadi, resim }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing event comment id")
        }
        self.id = id
        comment = c.decodeLossyString(forKey: .comment)
            ?? c.decodeLossyString(forKey: .message)
            ?? c.decodeLossyString(forKey: .yorum)
        createdAt = c.decodeLossyString(forKey: .createdAt)
            ?? c.decodeLossyString(forKey: .created_at)
        kadi = c.decodeLossyString(forKey: .kadi)
        resim = c.decodeLossyString(forKey: .resim)
    }
}

struct AnnouncementsEnvelope: Decodable {
    let items: [AnnouncementItem]

    private enum CodingKeys: String, CodingKey {
        case items, rows, announcements, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([AnnouncementItem].self, forKey: .items))
            ?? (try? c.decodeIfPresent([AnnouncementItem].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([AnnouncementItem].self, forKey: .announcements))
            ?? (try? c.decodeIfPresent([AnnouncementItem].self, forKey: .data))
            ?? []
    }
}

struct AnnouncementItem: Decodable, Identifiable {
    let id: Int
    let title: String?
    let body: String?
    let image: String?
    let createdAt: String?
    let creatorKadi: String?
    let approved: Bool?

    private enum CodingKeys: String, CodingKey { case id, title, body, content, message, image, createdAt, creatorKadi, approved, created_at, creator_kadi }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing announcement id")
        }
        self.id = id
        title = c.decodeLossyString(forKey: .title)
        body = c.decodeLossyString(forKey: .body)
            ?? c.decodeLossyString(forKey: .content)
            ?? c.decodeLossyString(forKey: .message)
        image = c.decodeLossyString(forKey: .image)
        createdAt = c.decodeLossyString(forKey: .createdAt) ?? c.decodeLossyString(forKey: .created_at)
        creatorKadi = c.decodeLossyString(forKey: .creatorKadi) ?? c.decodeLossyString(forKey: .creator_kadi)
        approved = c.decodeLossyBool(forKey: .approved)
    }
}

struct GroupsEnvelope: Decodable {
    let items: [GroupItem]

    private enum CodingKeys: String, CodingKey {
        case items, rows, groups, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([GroupItem].self, forKey: .items))
            ?? (try? c.decodeIfPresent([GroupItem].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([GroupItem].self, forKey: .groups))
            ?? (try? c.decodeIfPresent([GroupItem].self, forKey: .data))
            ?? []
    }
}

struct GroupItem: Decodable, Identifiable {
    let id: Int
    let name: String?
    let description: String?
    let coverImage: String?
    let visibility: String?
    let members: Int?
    let joined: Bool?
    let pending: Bool?
    let invited: Bool?
    let myRole: String?
    let membershipStatus: String?
    let showContactHint: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, coverImage, visibility, members, joined, pending, invited, myRole, membershipStatus, showContactHint
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing group id")
        }
        self.id = id
        name = c.decodeLossyString(forKey: .name)
        description = c.decodeLossyString(forKey: .description)
        coverImage = c.decodeLossyString(forKey: .coverImage)
        visibility = c.decodeLossyString(forKey: .visibility)
        members = c.decodeLossyInt(forKey: .members)
        joined = c.decodeLossyBool(forKey: .joined)
        pending = c.decodeLossyBool(forKey: .pending)
        invited = c.decodeLossyBool(forKey: .invited)
        myRole = c.decodeLossyString(forKey: .myRole)
        membershipStatus = c.decodeLossyString(forKey: .membershipStatus)
        showContactHint = c.decodeLossyBool(forKey: .showContactHint)
    }
}

struct GroupDetailEnvelope: Decodable {
    let group: GroupItem?
    let members: [GroupMemberItem]?
    let managers: [GroupMemberItem]?
    let posts: [FeedPost]?
    let membershipStatus: String?
    let myRole: String?
    let groupEvents: [EventItem]?
    let groupAnnouncements: [AnnouncementItem]?
    let joinRequests: [GroupJoinRequestItem]?
    let pendingInvites: [GroupInviteItem]?
    let canReviewRequests: Bool?

    private enum CodingKeys: String, CodingKey {
        case group, row, item, members, managers, posts, membershipStatus, myRole, groupEvents, groupAnnouncements, joinRequests, pendingInvites, canReviewRequests
        case membership_status, my_role, group_events, group_announcements, join_requests, pending_invites, can_review_requests, data
    }

    private struct DetailData: Decodable {
        let group: GroupItem?
        let members: [GroupMemberItem]?
        let managers: [GroupMemberItem]?
        let posts: [FeedPost]?
        let membershipStatus: String?
        let myRole: String?
        let groupEvents: [EventItem]?
        let groupAnnouncements: [AnnouncementItem]?
        let joinRequests: [GroupJoinRequestItem]?
        let pendingInvites: [GroupInviteItem]?
        let canReviewRequests: Bool?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let nested = try? c.decodeIfPresent(DetailData.self, forKey: .data)
        group = (try? c.decodeIfPresent(GroupItem.self, forKey: .group))
            ?? (try? c.decodeIfPresent(GroupItem.self, forKey: .row))
            ?? (try? c.decodeIfPresent(GroupItem.self, forKey: .item))
            ?? nested?.group
        members = (try? c.decodeIfPresent([GroupMemberItem].self, forKey: .members)) ?? nested?.members
        managers = (try? c.decodeIfPresent([GroupMemberItem].self, forKey: .managers)) ?? nested?.managers
        posts = (try? c.decodeIfPresent([FeedPost].self, forKey: .posts)) ?? nested?.posts
        membershipStatus = c.decodeLossyString(forKey: .membershipStatus)
            ?? c.decodeLossyString(forKey: .membership_status)
            ?? nested?.membershipStatus
        myRole = c.decodeLossyString(forKey: .myRole)
            ?? c.decodeLossyString(forKey: .my_role)
            ?? nested?.myRole
        groupEvents = (try? c.decodeIfPresent([EventItem].self, forKey: .groupEvents))
            ?? (try? c.decodeIfPresent([EventItem].self, forKey: .group_events))
            ?? nested?.groupEvents
        groupAnnouncements = (try? c.decodeIfPresent([AnnouncementItem].self, forKey: .groupAnnouncements))
            ?? (try? c.decodeIfPresent([AnnouncementItem].self, forKey: .group_announcements))
            ?? nested?.groupAnnouncements
        joinRequests = (try? c.decodeIfPresent([GroupJoinRequestItem].self, forKey: .joinRequests))
            ?? (try? c.decodeIfPresent([GroupJoinRequestItem].self, forKey: .join_requests))
            ?? nested?.joinRequests
        pendingInvites = (try? c.decodeIfPresent([GroupInviteItem].self, forKey: .pendingInvites))
            ?? (try? c.decodeIfPresent([GroupInviteItem].self, forKey: .pending_invites))
            ?? nested?.pendingInvites
        canReviewRequests = c.decodeLossyBool(forKey: .canReviewRequests)
            ?? c.decodeLossyBool(forKey: .can_review_requests)
            ?? nested?.canReviewRequests
    }
}

struct GroupJoinRequestsEnvelope: Decodable {
    let items: [GroupJoinRequestItem]

    private enum CodingKeys: String, CodingKey {
        case items, rows, requests, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([GroupJoinRequestItem].self, forKey: .items))
            ?? (try? c.decodeIfPresent([GroupJoinRequestItem].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([GroupJoinRequestItem].self, forKey: .requests))
            ?? (try? c.decodeIfPresent([GroupJoinRequestItem].self, forKey: .data))
            ?? []
    }
}

struct GroupInvitesEnvelope: Decodable {
    let items: [GroupInviteItem]

    private enum CodingKeys: String, CodingKey {
        case items, rows, invites, invitations, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([GroupInviteItem].self, forKey: .items))
            ?? (try? c.decodeIfPresent([GroupInviteItem].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([GroupInviteItem].self, forKey: .invites))
            ?? (try? c.decodeIfPresent([GroupInviteItem].self, forKey: .invitations))
            ?? (try? c.decodeIfPresent([GroupInviteItem].self, forKey: .data))
            ?? []
    }
}

struct GroupEventsEnvelope: Decodable {
    let items: [EventItem]

    private enum CodingKeys: String, CodingKey {
        case items, rows, events, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([EventItem].self, forKey: .items))
            ?? (try? c.decodeIfPresent([EventItem].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([EventItem].self, forKey: .events))
            ?? (try? c.decodeIfPresent([EventItem].self, forKey: .data))
            ?? []
    }
}

struct GroupAnnouncementsEnvelope: Decodable {
    let items: [AnnouncementItem]

    private enum CodingKeys: String, CodingKey {
        case items, rows, announcements, data
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([AnnouncementItem].self, forKey: .items))
            ?? (try? c.decodeIfPresent([AnnouncementItem].self, forKey: .rows))
            ?? (try? c.decodeIfPresent([AnnouncementItem].self, forKey: .announcements))
            ?? (try? c.decodeIfPresent([AnnouncementItem].self, forKey: .data))
            ?? []
    }
}

struct GroupMemberItem: Decodable, Identifiable {
    let id: Int
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: Bool?
    let role: String?

    private enum CodingKeys: String, CodingKey { case id, kadi, isim, soyisim, resim, verified, role }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing group member id")
        }
        self.id = id
        kadi = c.decodeLossyString(forKey: .kadi)
        isim = c.decodeLossyString(forKey: .isim)
        soyisim = c.decodeLossyString(forKey: .soyisim)
        resim = c.decodeLossyString(forKey: .resim)
        verified = c.decodeLossyBool(forKey: .verified)
        role = c.decodeLossyString(forKey: .role)
    }
}

struct GroupJoinRequestItem: Decodable, Identifiable {
    let id: Int
    let groupId: Int?
    let userId: Int?
    let status: String?
    let createdAt: String?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: Bool?

    private enum CodingKeys: String, CodingKey { case id, groupId, userId, status, createdAt, kadi, isim, soyisim, resim, verified }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing group request id")
        }
        self.id = id
        groupId = c.decodeLossyInt(forKey: .groupId)
        userId = c.decodeLossyInt(forKey: .userId)
        status = c.decodeLossyString(forKey: .status)
        createdAt = c.decodeLossyString(forKey: .createdAt)
        kadi = c.decodeLossyString(forKey: .kadi)
        isim = c.decodeLossyString(forKey: .isim)
        soyisim = c.decodeLossyString(forKey: .soyisim)
        resim = c.decodeLossyString(forKey: .resim)
        verified = c.decodeLossyBool(forKey: .verified)
    }
}

struct GroupInviteItem: Decodable, Identifiable {
    let id: Int
    let groupId: Int?
    let invitedUserId: Int?
    let invitedBy: Int?
    let status: String?
    let createdAt: String?
    let respondedAt: String?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let verified: Bool?

    private enum CodingKeys: String, CodingKey { case id, groupId, invitedUserId, invitedBy, status, createdAt, respondedAt, kadi, isim, soyisim, resim, verified }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.decodeLossyInt(forKey: .id) else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing group invite id")
        }
        self.id = id
        groupId = c.decodeLossyInt(forKey: .groupId)
        invitedUserId = c.decodeLossyInt(forKey: .invitedUserId)
        invitedBy = c.decodeLossyInt(forKey: .invitedBy)
        status = c.decodeLossyString(forKey: .status)
        createdAt = c.decodeLossyString(forKey: .createdAt)
        respondedAt = c.decodeLossyString(forKey: .respondedAt)
        kadi = c.decodeLossyString(forKey: .kadi)
        isim = c.decodeLossyString(forKey: .isim)
        soyisim = c.decodeLossyString(forKey: .soyisim)
        resim = c.decodeLossyString(forKey: .resim)
        verified = c.decodeLossyBool(forKey: .verified)
    }
}

struct LeaderboardEnvelope: Decodable {
    let rows: [LeaderboardRow]
}

struct LeaderboardRow: Decodable, Identifiable {
    let id = UUID()
    let isim: String?
    let skor: Int?
    let puan: Int?
    let tarih: String?

    private enum CodingKeys: String, CodingKey { case isim, skor, puan, tarih }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isim = c.decodeLossyString(forKey: .isim)
        skor = c.decodeLossyInt(forKey: .skor)
        puan = c.decodeLossyInt(forKey: .puan)
        tarih = c.decodeLossyString(forKey: .tarih)
    }
}
