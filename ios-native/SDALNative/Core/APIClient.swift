import Foundation

enum APIError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server."
        case let .httpError(code, message):
            return "Server error (\(code)): \(message)"
        }
    }
}

struct EmptyResponse: Decodable {}

struct DownloadedFile {
    let fileName: String
    let data: Data
    let mimeType: String?
}
struct FollowToggleResponse: Decodable {
    let ok: Bool?
    let following: Bool?

    private enum CodingKeys: String, CodingKey {
        case ok, following, followed, isFollowing, status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.decodeLossyBool(forKey: .ok)
        if let value = c.decodeLossyBool(forKey: .following)
            ?? c.decodeLossyBool(forKey: .followed)
            ?? c.decodeLossyBool(forKey: .isFollowing) {
            following = value
        } else if let status = c.decodeLossyString(forKey: .status)?.lowercased() {
            switch status {
            case "following", "followed", "on", "true", "1":
                following = true
            case "unfollowed", "off", "false", "0":
                following = false
            default:
                following = nil
            }
        } else {
            following = nil
        }
    }
}
struct TranslationResponse: Decodable {
    let translatedText: String?
    let sourceLanguage: String?

    private enum CodingKeys: String, CodingKey {
        case translatedText, sourceLanguage, translated, translation, ceviri, data
    }

    private struct TranslationData: Decodable {
        let translatedText: String?
        let sourceLanguage: String?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let nested = try? c.decodeIfPresent(TranslationData.self, forKey: .data)
        translatedText = c.decodeLossyString(forKey: .translatedText)
            ?? c.decodeLossyString(forKey: .translated)
            ?? c.decodeLossyString(forKey: .translation)
            ?? c.decodeLossyString(forKey: .ceviri)
            ?? nested?.translatedText
        sourceLanguage = c.decodeLossyString(forKey: .sourceLanguage)
            ?? nested?.sourceLanguage
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func login(username: String, password: String) async throws {
        struct LoginBody: Encodable {
            let kadi: String
            let sifre: String
        }

        _ = try await request("/auth/login", method: "POST", body: LoginBody(kadi: username, sifre: password), as: EmptyResponse.self)
    }

    func fetchHealth() async throws -> HealthResponse {
        try await request("/health", as: HealthResponse.self)
    }

    func register(
        username: String,
        password: String,
        passwordRepeat: String,
        email: String,
        firstName: String,
        lastName: String,
        graduationYear: String,
        captchaCode: String
    ) async throws {
        struct Body: Encodable {
            let kadi: String
            let sifre: String
            let sifre2: String
            let email: String
            let isim: String
            let soyisim: String
            let mezuniyetyili: String
            let gkodu: String
        }

        _ = try await request(
            "/register",
            method: "POST",
            body: Body(
                kadi: username,
                sifre: password,
                sifre2: passwordRepeat,
                email: email,
                isim: firstName,
                soyisim: lastName,
                mezuniyetyili: graduationYear,
                gkodu: captchaCode
            ),
            as: APIWriteResponse.self
        )
    }

    func previewRegister(
        username: String,
        password: String,
        passwordRepeat: String,
        email: String,
        firstName: String,
        lastName: String,
        graduationYear: String,
        captchaCode: String
    ) async throws -> RegisterPreviewResponse {
        struct Body: Encodable {
            let kadi: String
            let sifre: String
            let sifre2: String
            let email: String
            let isim: String
            let soyisim: String
            let mezuniyetyili: String
            let gkodu: String
        }
        return try await request(
            "/register/preview",
            method: "POST",
            body: Body(
                kadi: username,
                sifre: password,
                sifre2: passwordRepeat,
                email: email,
                isim: firstName,
                soyisim: lastName,
                mezuniyetyili: graduationYear,
                gkodu: captchaCode
            ),
            as: RegisterPreviewResponse.self
        )
    }

    func resendActivation(memberId: String, email: String) async throws {
        struct Body: Encodable {
            let id: String
            let email: String
        }
        _ = try await request("/activation/resend", method: "POST", body: Body(id: memberId, email: email), as: APIWriteResponse.self)
    }

    func requestPasswordReset(username: String, email: String) async throws {
        struct Body: Encodable {
            let kadi: String
            let email: String
        }
        _ = try await request("/password-reset", method: "POST", body: Body(kadi: username, email: email), as: APIWriteResponse.self)
    }

    func activateAccount(id: String, code: String) async throws -> ActivationResponse {
        let safeId = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        let safeCode = code.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? code
        return try await request("/activate?id=\(safeId)&akt=\(safeCode)", as: ActivationResponse.self)
    }

    func fetchSession() async throws -> SessionUser {
        let res = try await request("/session", as: SessionEnvelope.self)
        guard let user = res.user else {
            throw APIError.invalidResponse
        }
        return user
    }

    func logout() async throws {
        _ = try await request("/auth/logout", method: "POST", as: EmptyResponse.self)
    }

    func fetchFeed(limit: Int = 20, offset: Int = 0, scope: String = "all") async throws -> [FeedPost] {
        let path = "/new/feed?limit=\(limit)&offset=\(offset)&scope=\(scope)"
        let payload = try await request(path, as: FeedEnvelope.self)
        return payload.items
    }

    func fetchExploreSuggestions(limit: Int = 24, offset: Int = 0) async throws -> [MemberSummary] {
        let path = "/new/explore/suggestions?limit=\(limit)&offset=\(offset)"
        let payload = try await request(path, as: MembersEnvelope.self)
        return payload.list
    }

    func fetchMembers(
        term: String = "",
        gradYear: Int? = nil,
        verifiedOnly: Bool = false,
        withPhoto: Bool = false,
        onlineOnly: Bool = false,
        relation: String = "",
        sort: String = "recommended",
        page: Int = 1,
        pageSize: Int = 24
    ) async throws -> [MemberSummary] {
        var query = "page=\(page)&pageSize=\(pageSize)&excludeSelf=1&sort=\(sort)"
        if !term.isEmpty {
            let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            query += "&term=\(encoded)"
        }
        if let gradYear, gradYear > 0 { query += "&gradYear=\(gradYear)" }
        if verifiedOnly { query += "&verified=1" }
        if withPhoto { query += "&withPhoto=1" }
        if onlineOnly { query += "&online=1" }
        if !relation.isEmpty { query += "&relation=\(relation)" }
        let payload = try await request("/members?\(query)", as: MembersEnvelope.self)
        return payload.list
    }

    func fetchFollowing(limit: Int = 30, offset: Int = 0) async throws -> [MemberSummary] {
        let payload = try await request("/new/follows?limit=\(limit)&offset=\(offset)&sort=engagement", as: MembersEnvelope.self)
        return payload.list
    }

    func toggleFollow(memberId: Int) async throws -> Bool {
        let payload = try await request("/new/follow/\(memberId)", method: "POST", as: FollowToggleResponse.self)
        return payload.following ?? false
    }

    func fetchMemberDetail(id: Int) async throws -> MemberDetail {
        let payload = try await request("/members/\(id)", as: MemberDetailEnvelope.self)
        guard let row = payload.row else { throw APIError.invalidResponse }
        return row
    }

    func fetchInbox(page: Int = 1, pageSize: Int = 20) async throws -> [MessageSummary] {
        let path = "/messages?box=inbox&page=\(page)&pageSize=\(pageSize)"
        let payload = try await request(path, as: MessagesEnvelope.self)
        return payload.rows
    }

    func fetchOutbox(page: Int = 1, pageSize: Int = 20) async throws -> [MessageSummary] {
        let path = "/messages?box=outbox&page=\(page)&pageSize=\(pageSize)"
        let payload = try await request(path, as: MessagesEnvelope.self)
        return payload.rows
    }

    func fetchMessage(id: Int) async throws -> MessageDetailEnvelope {
        try await request("/messages/\(id)", as: MessageDetailEnvelope.self)
    }

    func sendMessage(recipientId: Int, subject: String, body: String) async throws {
        struct Body: Encodable {
            let kime: Int
            let konu: String
            let mesaj: String
        }
        _ = try await request(
            "/messages",
            method: "POST",
            body: Body(kime: recipientId, konu: subject, mesaj: body),
            as: APIWriteResponse.self
        )
    }

    func deleteMessage(id: Int) async throws {
        _ = try await request("/messages/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func searchRecipients(query: String, limit: Int = 12) async throws -> [MessageRecipient] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let path = "/messages/recipients?q=\(encoded)&limit=\(limit)"
        let payload = try await request(path, as: RecipientsEnvelope.self)
        return payload.items
    }

    func fetchNotifications(limit: Int = 30, offset: Int = 0) async throws -> [AppNotification] {
        let path = "/new/notifications?limit=\(limit)&offset=\(offset)"
        let payload = try await request(path, as: NotificationsEnvelope.self)
        return payload.items
    }

    func fetchUnreadMessagesCount() async throws -> Int {
        let payload = try await request("/new/messages/unread", as: CountEnvelope.self)
        return payload.count ?? 0
    }

    func fetchOnlineMembers(limit: Int = 12) async throws -> [MemberSummary] {
        let payload = try await request("/new/online-members?limit=\(limit)&excludeSelf=1", as: MembersEnvelope.self)
        return payload.list
    }

    func fetchChatMessages(sinceId: Int? = nil, beforeId: Int? = nil, limit: Int = 40) async throws -> [ChatMessage] {
        var parts = ["limit=\(limit)"]
        if let sinceId, sinceId > 0 { parts.append("sinceId=\(sinceId)") }
        if let beforeId, beforeId > 0 { parts.append("beforeId=\(beforeId)") }
        let payload = try await request("/new/chat/messages?\(parts.joined(separator: "&"))", as: ChatMessagesEnvelope.self)
        return payload.items
    }

    func translateText(_ text: String, target: String, source: String = "auto") async throws -> String {
        struct Body: Encodable {
            let text: String
            let target: String
            let source: String
        }
        let payload = try await request("/new/translate", method: "POST", body: Body(text: text, target: target, source: source), as: TranslationResponse.self)
        return payload.translatedText ?? ""
    }

    func sendChatMessage(message: String) async throws -> ChatMessage? {
        struct BodyMessage: Encodable { let message: String }
        struct BodyMesaj: Encodable { let mesaj: String }
        do {
            let payload = try await request("/new/chat/send", method: "POST", body: BodyMessage(message: message), as: ChatSendEnvelope.self)
            return payload.item
        } catch let APIError.httpError(code, _) where code == 400 || code == 404 || code == 405 || code == 422 {
            let payload = try await request("/new/chat/send", method: "POST", body: BodyMesaj(mesaj: message), as: ChatSendEnvelope.self)
            return payload.item
        }
    }

    func editChatMessage(id: Int, message: String) async throws -> ChatMessage? {
        struct Body: Encodable { let message: String }
        do {
            let payload = try await request("/new/chat/messages/\(id)", method: "PATCH", body: Body(message: message), as: ChatUpdateEnvelope.self)
            return payload.item
        } catch let APIError.httpError(code, _) where code == 404 || code == 405 {
            let payload = try await request("/new/chat/messages/\(id)/edit", method: "POST", body: Body(message: message), as: ChatUpdateEnvelope.self)
            return payload.item
        }
    }

    func deleteChatMessage(id: Int) async throws {
        do {
            _ = try await request("/new/chat/messages/\(id)", method: "DELETE", as: APIWriteResponse.self)
        } catch let APIError.httpError(code, _) where code == 404 || code == 405 {
            _ = try await request("/new/chat/messages/\(id)/delete", method: "POST", as: APIWriteResponse.self)
        }
    }

    func markNotificationsRead() async throws {
        _ = try await request("/new/notifications/read", method: "POST", as: APIWriteResponse.self)
    }

    func fetchProfile() async throws -> Profile {
        let payload = try await request("/profile", as: ProfileEnvelope.self)
        guard let profile = payload.user else {
            throw APIError.invalidResponse
        }
        return profile
    }

    func updateProfile(_ body: ProfileUpdateBody) async throws {
        _ = try await request("/profile", method: "PUT", body: body, as: APIWriteResponse.self)
    }

    func uploadProfilePhoto(imageData: Data, fileName: String = "profile.jpg", mimeType: String = "image/jpeg") async throws {
        let parts = [MultipartPart(name: "file", fileName: fileName, mimeType: mimeType, data: imageData)]
        _ = try await requestMultipart("/profile/photo", method: "POST", parts: parts, as: APIWriteResponse.self)
    }

    func requestVerification() async throws {
        _ = try await request("/new/verified/request", method: "POST", as: APIWriteResponse.self)
    }

    func changeProfilePassword(oldPassword: String, newPassword: String, newPasswordRepeat: String) async throws {
        struct Body: Encodable {
            let eskisifre: String
            let yenisifre: String
            let yenisifretekrar: String
        }
        _ = try await request("/profile/password", method: "POST", body: Body(eskisifre: oldPassword, yenisifre: newPassword, yenisifretekrar: newPasswordRepeat), as: APIWriteResponse.self)
    }

    func sendMailTest(to: String) async throws {
        struct Body: Encodable { let to: String }
        _ = try await request("/mail/test", method: "POST", body: Body(to: to), as: APIWriteResponse.self)
    }

    func fetchMenu() async throws -> [MenuItem] {
        let payload = try await request("/menu", as: MenuEnvelope.self)
        return payload.items ?? []
    }

    func fetchSidebar() async throws -> SidebarEnvelope {
        try await request("/sidebar", as: SidebarEnvelope.self)
    }

    func fetchAlbumCategories() async throws -> [AlbumCategory] {
        let payload = try await request("/albums", as: AlbumCategoryEnvelope.self)
        return payload.items
    }

    func fetchActiveAlbumCategories() async throws -> [AlbumCategory] {
        let payload = try await request("/album/categories/active", as: ActiveAlbumCategoryEnvelope.self)
        return payload.categories
    }

    func fetchAlbum(id: Int, page: Int = 1, pageSize: Int = 24) async throws -> AlbumListEnvelope {
        try await request("/albums/\(id)?page=\(page)&pageSize=\(pageSize)", as: AlbumListEnvelope.self)
    }

    func fetchLatestAlbumPhotos(limit: Int = 24, offset: Int = 0) async throws -> AlbumLatestEnvelope {
        try await request("/album/latest?limit=\(limit)&offset=\(offset)", as: AlbumLatestEnvelope.self)
    }

    func fetchLatestMembers(limit: Int = 24) async throws -> [MemberSummary] {
        let payload = try await request("/members/latest?limit=\(limit)", as: MembersEnvelope.self)
        return payload.list
    }

    func fetchQuickAccessUsers() async throws -> [MemberSummary] {
        let payload = try await request("/quick-access", as: QuickAccessEnvelope.self)
        return payload.users
    }

    func addQuickAccessUser(id: Int) async throws {
        struct Body: Encodable { let id: Int }
        _ = try await request("/quick-access/add", method: "POST", body: Body(id: id), as: APIWriteResponse.self)
    }

    func removeQuickAccessUser(id: Int) async throws {
        struct Body: Encodable { let id: Int }
        _ = try await request("/quick-access/remove", method: "POST", body: Body(id: id), as: APIWriteResponse.self)
    }

    func fetchPanolar(categoryId: Int = 0, page: Int = 1) async throws -> PanolarEnvelope {
        try await request("/panolar?mkatid=\(categoryId)&page=\(page)", as: PanolarEnvelope.self)
    }

    func createPanoMessage(message: String, categoryId: Int = 0) async throws {
        struct Body: Encodable {
            let mesaj: String
            let katid: Int
        }
        _ = try await request("/panolar", method: "POST", body: Body(mesaj: message, katid: categoryId), as: APIWriteResponse.self)
    }

    func deletePanoMessage(id: Int) async throws {
        _ = try await request("/panolar/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func registerTournament(_ body: TournamentRegisterBody) async throws {
        _ = try await request("/tournament/register", method: "POST", body: body, as: APIWriteResponse.self)
    }

    func fetchPhoto(id: Int) async throws -> PhotoDetailEnvelope {
        try await request("/photos/\(id)", as: PhotoDetailEnvelope.self)
    }

    func fetchPhotoComments(id: Int) async throws -> [PhotoComment] {
        let payload = try await request("/photos/\(id)/comments", as: PhotoCommentsEnvelope.self)
        return payload.comments
    }

    func addPhotoComment(photoId: Int, comment: String) async throws {
        struct Body: Encodable { let yorum: String }
        _ = try await request("/photos/\(photoId)/comments", method: "POST", body: Body(yorum: comment), as: APIWriteResponse.self)
    }

    func uploadAlbumPhoto(categoryId: Int, title: String, description: String, imageData: Data, fileName: String = "album.jpg", mimeType: String = "image/jpeg") async throws {
        let parts = [
            MultipartPart(name: "kat", fileName: nil, mimeType: nil, data: Data(String(categoryId).utf8)),
            MultipartPart(name: "baslik", fileName: nil, mimeType: nil, data: Data(title.utf8)),
            MultipartPart(name: "aciklama", fileName: nil, mimeType: nil, data: Data(description.utf8)),
            MultipartPart(name: "file", fileName: fileName, mimeType: mimeType, data: imageData)
        ]
        _ = try await requestMultipart("/album/upload", method: "POST", parts: parts, as: APIWriteResponse.self)
    }

    func fetchEvents(limit: Int = 20, offset: Int = 0) async throws -> [EventItem] {
        let payload = try await request("/new/events?limit=\(limit)&offset=\(offset)", as: EventsEnvelope.self)
        return payload.items
    }

    func createEvent(title: String, description: String, location: String, startsAt: String, endsAt: String) async throws {
        struct Body: Encodable {
            let title: String
            let description: String
            let location: String
            let starts_at: String
            let ends_at: String
        }
        _ = try await request(
            "/new/events",
            method: "POST",
            body: Body(title: title, description: description, location: location, starts_at: startsAt, ends_at: endsAt),
            as: APIWriteResponse.self
        )
    }

    func createEventWithImage(
        title: String,
        description: String,
        location: String,
        startsAt: String,
        endsAt: String,
        imageData: Data,
        fileName: String = "event.jpg",
        mimeType: String = "image/jpeg"
    ) async throws {
        let parts = [
            MultipartPart(name: "title", fileName: nil, mimeType: nil, data: Data(title.utf8)),
            MultipartPart(name: "body", fileName: nil, mimeType: nil, data: Data(description.utf8)),
            MultipartPart(name: "description", fileName: nil, mimeType: nil, data: Data(description.utf8)),
            MultipartPart(name: "location", fileName: nil, mimeType: nil, data: Data(location.utf8)),
            MultipartPart(name: "starts_at", fileName: nil, mimeType: nil, data: Data(startsAt.utf8)),
            MultipartPart(name: "ends_at", fileName: nil, mimeType: nil, data: Data(endsAt.utf8)),
            MultipartPart(name: "image", fileName: fileName, mimeType: mimeType, data: imageData)
        ]
        _ = try await requestMultipart("/new/events/upload", method: "POST", parts: parts, as: APIWriteResponse.self)
    }

    func respondEvent(id: Int, response: String) async throws {
        struct Body: Encodable { let response: String }
        _ = try await request("/new/events/\(id)/respond", method: "POST", body: Body(response: response), as: APIWriteResponse.self)
    }

    func setEventResponseVisibility(id: Int, showCounts: Bool, showAttendeeNames: Bool, showDeclinerNames: Bool) async throws {
        struct Body: Encodable {
            let showCounts: Bool
            let showAttendeeNames: Bool
            let showDeclinerNames: Bool
        }
        _ = try await request(
            "/new/events/\(id)/response-visibility",
            method: "POST",
            body: Body(showCounts: showCounts, showAttendeeNames: showAttendeeNames, showDeclinerNames: showDeclinerNames),
            as: APIWriteResponse.self
        )
    }

    func approveEvent(id: Int, approved: Bool) async throws {
        struct Body: Encodable { let approved: Int }
        _ = try await request("/new/events/\(id)/approve", method: "POST", body: Body(approved: approved ? 1 : 0), as: APIWriteResponse.self)
    }

    func deleteEvent(id: Int) async throws {
        _ = try await request("/new/events/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func fetchEventComments(id: Int) async throws -> [EventComment] {
        let payload = try await request("/new/events/\(id)/comments", as: EventCommentsEnvelope.self)
        return payload.items
    }

    func addEventComment(id: Int, comment: String) async throws {
        struct BodyComment: Encodable { let comment: String }
        struct BodyYorum: Encodable { let yorum: String }
        do {
            _ = try await request("/new/events/\(id)/comments", method: "POST", body: BodyComment(comment: comment), as: APIWriteResponse.self)
        } catch let APIError.httpError(code, _) where code == 400 || code == 404 || code == 405 || code == 422 {
            _ = try await request("/new/events/\(id)/comments", method: "POST", body: BodyYorum(yorum: comment), as: APIWriteResponse.self)
        }
    }

    func notifyEventFollowers(id: Int) async throws {
        _ = try await request("/new/events/\(id)/notify", method: "POST", as: APIWriteResponse.self)
    }

    func fetchAnnouncements(limit: Int = 20, offset: Int = 0) async throws -> [AnnouncementItem] {
        let payload = try await request("/new/announcements?limit=\(limit)&offset=\(offset)", as: AnnouncementsEnvelope.self)
        return payload.items
    }

    func createAnnouncement(title: String, body: String) async throws {
        struct Body: Encodable { let title: String; let body: String }
        _ = try await request("/new/announcements", method: "POST", body: Body(title: title, body: body), as: APIWriteResponse.self)
    }

    func createAnnouncementWithImage(title: String, body: String, imageData: Data, fileName: String = "announcement.jpg", mimeType: String = "image/jpeg") async throws {
        let parts = [
            MultipartPart(name: "title", fileName: nil, mimeType: nil, data: Data(title.utf8)),
            MultipartPart(name: "body", fileName: nil, mimeType: nil, data: Data(body.utf8)),
            MultipartPart(name: "image", fileName: fileName, mimeType: mimeType, data: imageData)
        ]
        _ = try await requestMultipart("/new/announcements/upload", method: "POST", parts: parts, as: APIWriteResponse.self)
    }

    func approveAnnouncement(id: Int, approved: Bool) async throws {
        struct Body: Encodable { let approved: Int }
        _ = try await request("/new/announcements/\(id)/approve", method: "POST", body: Body(approved: approved ? 1 : 0), as: APIWriteResponse.self)
    }

    func deleteAnnouncement(id: Int) async throws {
        _ = try await request("/new/announcements/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func fetchGroups(limit: Int = 30, offset: Int = 0) async throws -> [GroupItem] {
        let payload = try await request("/new/groups?limit=\(limit)&offset=\(offset)", as: GroupsEnvelope.self)
        return payload.items
    }

    func createGroup(name: String, description: String) async throws {
        struct Body: Encodable { let name: String; let description: String }
        _ = try await request("/new/groups", method: "POST", body: Body(name: name, description: description), as: APIWriteResponse.self)
    }

    func joinOrLeaveGroup(id: Int) async throws {
        _ = try await request("/new/groups/\(id)/join", method: "POST", as: APIWriteResponse.self)
    }

    func fetchGroupDetail(id: Int) async throws -> GroupDetailEnvelope {
        try await request("/new/groups/\(id)", as: GroupDetailEnvelope.self)
    }

    func createGroupPost(groupId: Int, content: String) async throws {
        struct Body: Encodable { let content: String }
        _ = try await request("/new/groups/\(groupId)/posts", method: "POST", body: Body(content: content), as: APIWriteResponse.self)
    }

    func createGroupPostWithImage(groupId: Int, content: String, imageData: Data, fileName: String = "grouppost.jpg", mimeType: String = "image/jpeg") async throws {
        let parts = [
            MultipartPart(name: "content", fileName: nil, mimeType: nil, data: Data(content.utf8)),
            MultipartPart(name: "image", fileName: fileName, mimeType: mimeType, data: imageData)
        ]
        _ = try await requestMultipart("/new/groups/\(groupId)/posts/upload", method: "POST", parts: parts, as: APIWriteResponse.self)
    }

    func createGroupEvent(groupId: Int, title: String, description: String, location: String, startsAt: String, endsAt: String) async throws {
        struct Body: Encodable {
            let title: String
            let description: String
            let location: String
            let starts_at: String
            let ends_at: String
        }
        _ = try await request(
            "/new/groups/\(groupId)/events",
            method: "POST",
            body: Body(title: title, description: description, location: location, starts_at: startsAt, ends_at: endsAt),
            as: APIWriteResponse.self
        )
    }

    func fetchGroupEvents(groupId: Int) async throws -> [EventItem] {
        let payload = try await request("/new/groups/\(groupId)/events", as: GroupEventsEnvelope.self)
        return payload.items
    }

    func deleteGroupEvent(groupId: Int, eventId: Int) async throws {
        _ = try await request("/new/groups/\(groupId)/events/\(eventId)", method: "DELETE", as: APIWriteResponse.self)
    }

    func fetchGroupAnnouncements(groupId: Int) async throws -> [AnnouncementItem] {
        let payload = try await request("/new/groups/\(groupId)/announcements", as: GroupAnnouncementsEnvelope.self)
        return payload.items
    }

    func createGroupAnnouncement(groupId: Int, title: String, body: String) async throws {
        struct Body: Encodable { let title: String; let body: String }
        _ = try await request("/new/groups/\(groupId)/announcements", method: "POST", body: Body(title: title, body: body), as: APIWriteResponse.self)
    }

    func deleteGroupAnnouncement(groupId: Int, announcementId: Int) async throws {
        _ = try await request("/new/groups/\(groupId)/announcements/\(announcementId)", method: "DELETE", as: APIWriteResponse.self)
    }

    func respondGroupInvite(groupId: Int, action: String) async throws {
        struct Body: Encodable { let action: String }
        _ = try await request("/new/groups/\(groupId)/invitations/respond", method: "POST", body: Body(action: action), as: APIWriteResponse.self)
    }

    func fetchGroupJoinRequests(groupId: Int) async throws -> [GroupJoinRequestItem] {
        let payload = try await request("/new/groups/\(groupId)/requests", as: GroupJoinRequestsEnvelope.self)
        return payload.items
    }

    func decideGroupJoinRequest(groupId: Int, requestId: Int, action: String) async throws {
        struct Body: Encodable { let action: String }
        _ = try await request("/new/groups/\(groupId)/requests/\(requestId)", method: "POST", body: Body(action: action), as: APIWriteResponse.self)
    }

    func fetchGroupInvitations(groupId: Int) async throws -> [GroupInviteItem] {
        let payload = try await request("/new/groups/\(groupId)/invitations", as: GroupInvitesEnvelope.self)
        return payload.items
    }

    func sendGroupInvitations(groupId: Int, userIds: [Int]) async throws {
        struct Body: Encodable { let userIds: [Int] }
        _ = try await request("/new/groups/\(groupId)/invitations", method: "POST", body: Body(userIds: userIds), as: APIWriteResponse.self)
    }

    func updateGroupSettings(groupId: Int, visibility: String, showContactHint: Bool) async throws {
        struct Body: Encodable {
            let visibility: String
            let showContactHint: Bool
        }
        _ = try await request(
            "/new/groups/\(groupId)/settings",
            method: "POST",
            body: Body(visibility: visibility, showContactHint: showContactHint),
            as: APIWriteResponse.self
        )
    }

    func uploadGroupCover(groupId: Int, imageData: Data, fileName: String = "groupcover.jpg", mimeType: String = "image/jpeg") async throws {
        let parts = [MultipartPart(name: "image", fileName: fileName, mimeType: mimeType, data: imageData)]
        _ = try await requestMultipart("/new/groups/\(groupId)/cover", method: "POST", parts: parts, as: APIWriteResponse.self)
    }

    func setGroupRole(groupId: Int, userId: Int, role: String) async throws {
        struct Body: Encodable {
            let userId: Int
            let role: String
        }
        _ = try await request("/new/groups/\(groupId)/role", method: "POST", body: Body(userId: userId, role: role), as: APIWriteResponse.self)
    }

    func fetchGamesLeaderboard(gameKey: String, arcade: Bool = false) async throws -> [LeaderboardRow] {
        let path = arcade ? "/games/arcade/\(gameKey)/leaderboard" : "/games/\(gameKey)/leaderboard"
        let payload = try await request(path, as: LeaderboardEnvelope.self)
        return payload.rows
    }

    func submitGameScore(gameKey: String, score: Int, arcade: Bool = false) async throws {
        struct Body: Encodable { let score: Int }
        let path = arcade ? "/games/arcade/\(gameKey)/score" : "/games/\(gameKey)/score"
        _ = try await request(path, method: "POST", body: Body(score: score), as: APIWriteResponse.self)
    }

    func fetchStories() async throws -> [Story] {
        let payload = try await request("/new/stories", as: StoriesEnvelope.self)
        return payload.items
    }

    func fetchMyStories() async throws -> [MyStoryItem] {
        let payload = try await request("/new/stories/mine", as: MyStoriesEnvelope.self)
        return payload.items
    }

    func fetchStoriesByUser(userId: Int, includeExpired: Bool = false) async throws -> [Story] {
        let include = includeExpired ? 1 : 0
        let payload = try await request("/new/stories/user/\(userId)?includeExpired=\(include)", as: StoriesEnvelope.self)
        return payload.items
    }

    func createPost(content: String) async throws -> APIWriteResponse {
        struct Body: Encodable { let content: String }
        return try await request("/new/posts", method: "POST", body: Body(content: content), as: APIWriteResponse.self)
    }

    func editPost(id: Int, content: String) async throws {
        struct Body: Encodable { let content: String }
        do {
            _ = try await request("/new/posts/\(id)", method: "PATCH", body: Body(content: content), as: APIWriteResponse.self)
        } catch let APIError.httpError(code, _) where code == 404 || code == 405 {
            _ = try await request("/new/posts/\(id)/edit", method: "POST", body: Body(content: content), as: APIWriteResponse.self)
        }
    }

    func deletePost(id: Int) async throws {
        do {
            _ = try await request("/new/posts/\(id)", method: "DELETE", as: APIWriteResponse.self)
        } catch let APIError.httpError(code, _) where code == 404 || code == 405 {
            _ = try await request("/new/posts/\(id)/delete", method: "POST", as: APIWriteResponse.self)
        }
    }

    func togglePostLike(id: Int) async throws -> Bool {
        struct LikeResponse: Decodable { let liked: Bool? }
        let payload = try await request("/new/posts/\(id)/like", method: "POST", as: LikeResponse.self)
        return payload.liked ?? false
    }

    func fetchPostComments(id: Int) async throws -> [PostComment] {
        let payload = try await request("/new/posts/\(id)/comments", as: PostCommentsEnvelope.self)
        return payload.items
    }

    func addPostComment(id: Int, comment: String) async throws {
        struct BodyComment: Encodable { let comment: String }
        struct BodyYorum: Encodable { let yorum: String }
        do {
            _ = try await request("/new/posts/\(id)/comments", method: "POST", body: BodyComment(comment: comment), as: APIWriteResponse.self)
        } catch let APIError.httpError(code, _) where code == 400 || code == 404 || code == 405 || code == 422 {
            _ = try await request("/new/posts/\(id)/comments", method: "POST", body: BodyYorum(yorum: comment), as: APIWriteResponse.self)
        }
    }

    func createPostWithImage(
        content: String,
        imageData: Data,
        fileName: String,
        mimeType: String,
        filter: String
    ) async throws -> APIWriteResponse {
        let parts = [
            MultipartPart(name: "content", fileName: nil, mimeType: nil, data: Data(content.utf8)),
            MultipartPart(name: "filter", fileName: nil, mimeType: nil, data: Data(filter.utf8)),
            MultipartPart(name: "image", fileName: fileName, mimeType: mimeType, data: imageData)
        ]
        return try await requestMultipart("/new/posts/upload", method: "POST", parts: parts, as: APIWriteResponse.self)
    }

    func uploadStory(
        imageData: Data,
        fileName: String,
        mimeType: String,
        caption: String
    ) async throws -> APIWriteResponse {
        let parts = [
            MultipartPart(name: "caption", fileName: nil, mimeType: nil, data: Data(caption.utf8)),
            MultipartPart(name: "image", fileName: fileName, mimeType: mimeType, data: imageData)
        ]
        return try await requestMultipart("/new/stories/upload", method: "POST", parts: parts, as: APIWriteResponse.self)
    }

    func markStoryViewed(id: Int) async throws {
        do {
            _ = try await request("/new/stories/\(id)/view", method: "POST", as: APIWriteResponse.self)
        } catch let APIError.httpError(code, _) where code == 404 || code == 405 {
            _ = try await request("/new/stories/\(id)", method: "POST", as: APIWriteResponse.self)
        }
    }

    func editStoryCaption(id: Int, caption: String) async throws {
        struct Body: Encodable { let caption: String }
        do {
            _ = try await request("/new/stories/\(id)", method: "PATCH", body: Body(caption: caption), as: APIWriteResponse.self)
        } catch let APIError.httpError(code, _) where code == 404 || code == 405 {
            _ = try await request("/new/stories/\(id)/edit", method: "POST", body: Body(caption: caption), as: APIWriteResponse.self)
        }
    }

    func deleteStory(id: Int) async throws {
        do {
            _ = try await request("/new/stories/\(id)", method: "DELETE", as: APIWriteResponse.self)
        } catch let APIError.httpError(code, _) where code == 404 || code == 405 {
            do {
                _ = try await request("/new/stories/\(id)/delete", method: "POST", as: APIWriteResponse.self)
            } catch let APIError.httpError(secondaryCode, _) where secondaryCode == 404 || secondaryCode == 405 {
                _ = try await request("/new/stories/\(id)/remove", method: "POST", as: APIWriteResponse.self)
            }
        }
    }

    func repostStory(id: Int) async throws {
        _ = try await request("/new/stories/\(id)/repost", method: "POST", as: APIWriteResponse.self)
    }

    func fetchAdminSession() async throws -> AdminUser? {
        let payload = try await request("/admin/session", as: AdminSessionEnvelope.self)
        return payload.resolvedUser
    }

    func adminLogin(password: String) async throws {
        struct Body: Encodable {
            let password: String
        }
        _ = try await request("/admin/login", method: "POST", body: Body(password: password), as: APIWriteResponse.self)
    }

    func adminLogout() async throws {
        _ = try await request("/admin/logout", method: "POST", as: APIWriteResponse.self)
    }

    func fetchAdminStats() async throws -> AdminStats? {
        let payload = try await request("/new/admin/stats", as: AdminStatsEnvelope.self)
        return payload.payload
    }

    func fetchAdminLive() async throws -> AdminLiveSnapshot? {
        let payload = try await request("/new/admin/live", as: AdminLiveEnvelope.self)
        return payload.payload
    }

    func fetchAdminPosts(limit: Int = 40, offset: Int = 0) async throws -> [AdminModerationItem] {
        let payload = try await request("/new/admin/posts?limit=\(limit)&offset=\(offset)", as: AdminListEnvelope<AdminModerationItem>.self)
        return payload.list
    }

    func fetchAdminStories(limit: Int = 40, offset: Int = 0) async throws -> [AdminModerationItem] {
        let payload = try await request("/new/admin/stories?limit=\(limit)&offset=\(offset)", as: AdminListEnvelope<AdminModerationItem>.self)
        return payload.list
    }

    func fetchAdminMessages(limit: Int = 40, offset: Int = 0) async throws -> [AdminModerationItem] {
        let payload = try await request("/new/admin/messages?limit=\(limit)&offset=\(offset)", as: AdminListEnvelope<AdminModerationItem>.self)
        return payload.list
    }

    func fetchAdminChatMessages(limit: Int = 40, offset: Int = 0) async throws -> [AdminModerationItem] {
        let payload = try await request("/new/admin/chat/messages?limit=\(limit)&offset=\(offset)", as: AdminListEnvelope<AdminModerationItem>.self)
        return payload.list
    }

    func adminDeletePost(id: Int) async throws {
        _ = try await request("/new/admin/posts/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func adminDeleteStory(id: Int) async throws {
        _ = try await request("/new/admin/stories/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func adminDeleteMessage(id: Int) async throws {
        _ = try await request("/new/admin/messages/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func adminDeleteChatMessage(id: Int) async throws {
        _ = try await request("/new/admin/chat/messages/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func fetchVerificationRequests() async throws -> [VerificationRequestItem] {
        let payload = try await request("/new/admin/verification-requests", as: AdminListEnvelope<VerificationRequestItem>.self)
        return payload.list
    }

    func resolveVerificationRequest(id: Int, approve: Bool) async throws {
        struct Body: Encodable { let status: String }
        _ = try await request(
            "/new/admin/verification-requests/\(id)",
            method: "POST",
            body: Body(status: approve ? "approved" : "rejected"),
            as: APIWriteResponse.self
        )
    }

    func adminSetUserVerified(userId: Int, verified: Bool) async throws {
        struct Body: Encodable {
            let userId: Int
            let verified: Int
        }
        _ = try await request(
            "/new/admin/verify",
            method: "POST",
            body: Body(userId: userId, verified: verified ? 1 : 0),
            as: APIWriteResponse.self
        )
    }

    func fetchAdminFollows(userId: Int, limit: Int = 40, offset: Int = 0) async throws -> AdminFollowsEnvelope {
        try await request("/new/admin/follows/\(userId)?limit=\(limit)&offset=\(offset)", as: AdminFollowsEnvelope.self)
    }

    func fetchAdminGroups() async throws -> [AdminGroupItem] {
        let payload = try await request("/new/admin/groups", as: AdminListEnvelope<AdminGroupItem>.self)
        return payload.list
    }

    func adminDeleteGroup(id: Int) async throws {
        _ = try await request("/new/admin/groups/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func fetchAdminFilters() async throws -> [AdminFilterItem] {
        let payload = try await request("/new/admin/filters", as: AdminListEnvelope<AdminFilterItem>.self)
        return payload.list
    }

    func createAdminFilter(word: String) async throws {
        struct Body: Encodable { let kufur: String }
        _ = try await request("/new/admin/filters", method: "POST", body: Body(kufur: word), as: APIWriteResponse.self)
    }

    func updateAdminFilter(id: Int, word: String) async throws {
        struct Body: Encodable { let kufur: String }
        _ = try await request("/new/admin/filters/\(id)", method: "PUT", body: Body(kufur: word), as: APIWriteResponse.self)
    }

    func deleteAdminFilter(id: Int) async throws {
        _ = try await request("/new/admin/filters/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func fetchEngagementAB() async throws -> EngagementAbEnvelope {
        try await request("/new/admin/engagement-ab", as: EngagementAbEnvelope.self)
    }

    func updateEngagementABVariant(
        variant: String,
        trafficPct: Int,
        enabled: Bool,
        params: [String: Double]
    ) async throws {
        struct Body: Encodable {
            let trafficPct: Int
            let enabled: Int
            let params: [String: Double]
        }
        _ = try await request(
            "/new/admin/engagement-ab/\(variant)",
            method: "PUT",
            body: Body(trafficPct: trafficPct, enabled: enabled ? 1 : 0, params: params),
            as: APIWriteResponse.self
        )
    }

    func rebalanceEngagementAB(keepAssignments: Bool) async throws {
        struct Body: Encodable { let keepAssignments: Int }
        _ = try await request(
            "/new/admin/engagement-ab/rebalance",
            method: "POST",
            body: Body(keepAssignments: keepAssignments ? 1 : 0),
            as: APIWriteResponse.self
        )
    }

    func fetchEngagementScores(
        query: String = "",
        status: String = "all",
        variant: String = "",
        sort: String = "score_desc",
        page: Int = 1,
        limit: Int = 40
    ) async throws -> EngagementScoresEnvelope {
        var parts = ["sort=\(sort)", "status=\(status)", "page=\(page)", "limit=\(limit)"]
        if !query.isEmpty {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            parts.append("q=\(encoded)")
        }
        if !variant.isEmpty {
            let encoded = variant.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            parts.append("variant=\(encoded)")
        }
        return try await request("/new/admin/engagement-scores?\(parts.joined(separator: "&"))", as: EngagementScoresEnvelope.self)
    }

    func recalculateEngagementScores() async throws {
        _ = try await request("/new/admin/engagement-scores/recalculate", method: "POST", as: APIWriteResponse.self)
    }

    func fetchAdminEmailCategories() async throws -> [AdminEmailCategory] {
        let payload = try await request("/admin/email/categories", as: AdminEmailCategoriesEnvelope.self)
        return payload.categories ?? []
    }

    func createAdminEmailCategory(ad: String, tur: String, deger: String, aciklama: String) async throws {
        struct Body: Encodable { let ad: String; let tur: String; let deger: String; let aciklama: String }
        _ = try await request("/admin/email/categories", method: "POST", body: Body(ad: ad, tur: tur, deger: deger, aciklama: aciklama), as: APIWriteResponse.self)
    }

    func updateAdminEmailCategory(id: Int, ad: String, tur: String, deger: String, aciklama: String) async throws {
        struct Body: Encodable { let ad: String; let tur: String; let deger: String; let aciklama: String }
        _ = try await request("/admin/email/categories/\(id)", method: "PUT", body: Body(ad: ad, tur: tur, deger: deger, aciklama: aciklama), as: APIWriteResponse.self)
    }

    func deleteAdminEmailCategory(id: Int) async throws {
        _ = try await request("/admin/email/categories/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func fetchAdminEmailTemplates() async throws -> [AdminEmailTemplate] {
        let payload = try await request("/admin/email/templates", as: AdminEmailTemplatesEnvelope.self)
        return payload.templates ?? []
    }

    func createAdminEmailTemplate(ad: String, konu: String, icerik: String) async throws {
        struct Body: Encodable { let ad: String; let konu: String; let icerik: String }
        _ = try await request("/admin/email/templates", method: "POST", body: Body(ad: ad, konu: konu, icerik: icerik), as: APIWriteResponse.self)
    }

    func updateAdminEmailTemplate(id: Int, ad: String, konu: String, icerik: String) async throws {
        struct Body: Encodable { let ad: String; let konu: String; let icerik: String }
        _ = try await request("/admin/email/templates/\(id)", method: "PUT", body: Body(ad: ad, konu: konu, icerik: icerik), as: APIWriteResponse.self)
    }

    func deleteAdminEmailTemplate(id: Int) async throws {
        _ = try await request("/admin/email/templates/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func sendAdminEmail(to: String, from: String, subject: String, html: String) async throws {
        struct Body: Encodable { let to: String; let from: String; let subject: String; let html: String }
        _ = try await request("/admin/email/send", method: "POST", body: Body(to: to, from: from, subject: subject, html: html), as: APIWriteResponse.self)
    }

    func sendAdminBulkEmail(categoryId: Int, from: String, subject: String, html: String) async throws {
        struct Body: Encodable { let categoryId: Int; let from: String; let subject: String; let html: String }
        _ = try await request("/admin/email/bulk", method: "POST", body: Body(categoryId: categoryId, from: from, subject: subject, html: html), as: APIWriteResponse.self)
    }

    func fetchAdminDbTables() async throws -> [AdminDbTableInfo] {
        let payload = try await request("/new/admin/db/tables", as: AdminDbTablesEnvelope.self)
        return payload.items ?? []
    }

    func fetchAdminDbTable(name: String, page: Int = 1, limit: Int = 30) async throws -> AdminDbTableEnvelope {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try await request("/new/admin/db/table/\(encoded)?page=\(page)&limit=\(limit)", as: AdminDbTableEnvelope.self)
    }

    func fetchAdminDbBackups() async throws -> AdminDbBackupsEnvelope {
        try await request("/new/admin/db/backups", as: AdminDbBackupsEnvelope.self)
    }

    func createAdminDbBackup(label: String) async throws {
        struct Body: Encodable { let label: String }
        _ = try await request("/new/admin/db/backups", method: "POST", body: Body(label: label), as: APIWriteResponse.self)
    }

    func restoreAdminDbBackup(fileData: Data, fileName: String = "backup.db", mimeType: String = "application/octet-stream") async throws {
        let parts = [MultipartPart(name: "backup", fileName: fileName, mimeType: mimeType, data: fileData)]
        _ = try await requestMultipart("/new/admin/db/restore", method: "POST", parts: parts, as: APIWriteResponse.self)
    }

    func downloadAdminDbBackup(name: String) async throws -> DownloadedFile {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let (data, response) = try await requestRaw("/new/admin/db/backups/\(encoded)/download", accept: "application/octet-stream")
        let fallback = name.hasSuffix(".db") ? name : "\(name).db"
        let fileName = extractFilename(from: response) ?? fallback
        return DownloadedFile(fileName: fileName, data: data, mimeType: response.value(forHTTPHeaderField: "Content-Type"))
    }

    func fetchAdminUsers(
        filter: String = "all",
        query: String = "",
        withPhoto: Bool = false,
        verifiedOnly: Bool = false,
        onlineOnly: Bool = false,
        adminOnly: Bool = false,
        sort: String = "engagement_desc",
        limit: Int = 500
    ) async throws -> AdminUsersListEnvelope {
        var parts: [String] = [
            "filter=\(filter)",
            "sort=\(sort)",
            "limit=\(limit)"
        ]
        if !query.isEmpty {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            parts.append("q=\(encoded)")
        }
        if withPhoto { parts.append("photo=1") }
        if verifiedOnly { parts.append("verified=1") }
        if onlineOnly { parts.append("online=1") }
        if adminOnly { parts.append("admin=1") }
        return try await request("/admin/users/lists?\(parts.joined(separator: "&"))", as: AdminUsersListEnvelope.self)
    }

    func fetchAdminUserDetail(id: Int) async throws -> AdminManagedUser {
        let payload = try await request("/admin/users/\(id)", as: AdminManagedUserEnvelope.self)
        guard let user = payload.user else { throw APIError.invalidResponse }
        return user
    }

    func updateAdminUser(id: Int, body: AdminManagedUserUpdateBody) async throws {
        _ = try await request("/admin/users/\(id)", method: "PUT", body: body, as: APIWriteResponse.self)
    }

    func searchAdminUsers(query: String, onlyWithPhoto: Bool = false, sort: String = "engagement_desc", limit: Int = 800) async throws -> AdminUsersListEnvelope {
        var parts: [String] = [
            "q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
            "sort=\(sort)",
            "limit=\(limit)"
        ]
        if onlyWithPhoto { parts.append("res=1") }
        return try await request("/admin/users/search?\(parts.joined(separator: "&"))", as: AdminUsersListEnvelope.self)
    }

    func fetchAdminPages() async throws -> [AdminPageItem] {
        let payload = try await request("/admin/pages", as: AdminPagesEnvelope.self)
        return payload.pages ?? []
    }

    func createAdminPage(body: AdminPageWriteBody) async throws {
        _ = try await request("/admin/pages", method: "POST", body: body, as: APIWriteResponse.self)
    }

    func updateAdminPage(id: Int, body: AdminPageWriteBody) async throws {
        _ = try await request("/admin/pages/\(id)", method: "PUT", body: body, as: APIWriteResponse.self)
    }

    func deleteAdminPage(id: Int) async throws {
        _ = try await request("/admin/pages/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func fetchAdminLogs(
        type: String,
        file: String? = nil,
        query: String = "",
        activity: String = "",
        userId: String = "",
        from: String = "",
        to: String = "",
        limit: Int = 500,
        offset: Int = 0
    ) async throws -> AdminLogsEnvelope {
        var parts = ["type=\(type)"]
        if let file, !file.isEmpty {
            parts.append("file=\(file.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
            if !query.isEmpty { parts.append("q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") }
            if !activity.isEmpty { parts.append("activity=\(activity.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") }
            if !userId.isEmpty { parts.append("userId=\(userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") }
            if !from.isEmpty { parts.append("from=\(from)") }
            if !to.isEmpty { parts.append("to=\(to)") }
            parts.append("limit=\(limit)")
            parts.append("offset=\(offset)")
        } else {
            if !from.isEmpty { parts.append("from=\(from)") }
            if !to.isEmpty { parts.append("to=\(to)") }
        }
        return try await request("/admin/logs?\(parts.joined(separator: "&"))", as: AdminLogsEnvelope.self)
    }

    func fetchAdminAlbumCategories() async throws -> AdminAlbumCategoriesEnvelope {
        try await request("/admin/album/categories", as: AdminAlbumCategoriesEnvelope.self)
    }

    func createAdminAlbumCategory(body: AdminAlbumCategoryWriteBody) async throws {
        _ = try await request("/admin/album/categories", method: "POST", body: body, as: APIWriteResponse.self)
    }

    func updateAdminAlbumCategory(id: Int, body: AdminAlbumCategoryWriteBody) async throws {
        _ = try await request("/admin/album/categories/\(id)", method: "PUT", body: body, as: APIWriteResponse.self)
    }

    func deleteAdminAlbumCategory(id: Int) async throws {
        _ = try await request("/admin/album/categories/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func fetchAdminAlbumPhotos(krt: String = "", kid: String = "", diz: String = "") async throws -> AdminAlbumPhotosEnvelope {
        var parts: [String] = []
        if !krt.isEmpty { parts.append("krt=\(krt)") }
        if !kid.isEmpty { parts.append("kid=\(kid)") }
        if !diz.isEmpty { parts.append("diz=\(diz)") }
        let suffix = parts.isEmpty ? "" : "?\(parts.joined(separator: "&"))"
        return try await request("/admin/album/photos\(suffix)", as: AdminAlbumPhotosEnvelope.self)
    }

    func bulkAdminAlbumPhotos(ids: [Int], action: String) async throws {
        _ = try await request("/admin/album/photos/bulk", method: "POST", body: AdminAlbumPhotoBulkBody(ids: ids, action: action), as: APIWriteResponse.self)
    }

    func updateAdminAlbumPhoto(id: Int, body: AdminAlbumPhotoWriteBody) async throws {
        _ = try await request("/admin/album/photos/\(id)", method: "PUT", body: body, as: APIWriteResponse.self)
    }

    func deleteAdminAlbumPhoto(id: Int) async throws {
        _ = try await request("/admin/album/photos/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func fetchAdminAlbumPhotoComments(photoId: Int) async throws -> [AdminAlbumPhotoComment] {
        let payload = try await request("/admin/album/photos/\(photoId)/comments", as: AdminAlbumPhotoCommentsEnvelope.self)
        return payload.comments ?? []
    }

    func deleteAdminAlbumPhotoComment(photoId: Int, commentId: Int) async throws {
        _ = try await request("/admin/album/photos/\(photoId)/comments/\(commentId)", method: "DELETE", as: APIWriteResponse.self)
    }

    func fetchAdminTournamentTeams() async throws -> [AdminTournamentTeam] {
        let payload = try await request("/admin/tournament", as: AdminTournamentEnvelope.self)
        return payload.teams ?? []
    }

    func deleteAdminTournamentTeam(id: Int) async throws {
        _ = try await request("/admin/tournament/\(id)", method: "DELETE", as: APIWriteResponse.self)
    }

    func registerPushToken(_ token: String) async throws {
        struct Body: Encodable {
            let token: String
            let platform: String
        }
        do {
            _ = try await request("/new/push/register", method: "POST", body: Body(token: token, platform: "ios"), as: APIWriteResponse.self)
        } catch let APIError.httpError(code, _) where code == 404 || code == 405 {
            // Backend may not expose push token registration yet.
        }
    }

    private func request<T: Decodable>(_ path: String, method: String = "GET", as type: T.Type) async throws -> T {
        try await request(path, method: method, body: Optional<String>.none, as: type)
    }

    private func request<T: Decodable, B: Encodable>(_ path: String, method: String = "GET", body: B?, as type: T.Type) async throws -> T {
        guard let url = URL(string: AppConfig.baseURL.absoluteString + AppConfig.apiPrefix + path) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(currentLanguageCode(), forHTTPHeaderField: "Accept-Language")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.httpError(http.statusCode, message)
        }

        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }

        return try decoder.decode(T.self, from: data)
    }

    private func requestMultipart<T: Decodable>(_ path: String, method: String, parts: [MultipartPart], as type: T.Type) async throws -> T {
        guard let url = URL(string: AppConfig.baseURL.absoluteString + AppConfig.apiPrefix + path) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(currentLanguageCode(), forHTTPHeaderField: "Accept-Language")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = MultipartFormData.build(parts: parts, boundary: boundary)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.httpError(http.statusCode, message)
        }
        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }
        return try decoder.decode(T.self, from: data)
    }

    private func requestRaw(_ path: String, method: String = "GET", accept: String = "*/*") async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: AppConfig.baseURL.absoluteString + AppConfig.apiPrefix + path) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(currentLanguageCode(), forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw APIError.httpError(http.statusCode, message)
        }
        return (data, http)
    }

    private func extractFilename(from response: HTTPURLResponse) -> String? {
        guard let disposition = response.value(forHTTPHeaderField: "Content-Disposition"), !disposition.isEmpty else {
            return nil
        }

        let parts = disposition.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let extended = parts.first(where: { $0.lowercased().hasPrefix("filename*=") }) {
            var value = String(extended.dropFirst("filename*=".count))
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            let encoded = value.replacingOccurrences(of: "UTF-8''", with: "", options: [.caseInsensitive])
            if let decoded = encoded.removingPercentEncoding, !decoded.isEmpty {
                return decoded
            }
        }
        if let plain = parts.first(where: { $0.lowercased().hasPrefix("filename=") }) {
            var value = String(plain.dropFirst("filename=".count))
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func currentLanguageCode() -> String {
        UserDefaults.standard.string(forKey: "sdal_native_lang") ?? "tr"
    }
}

extension KeyedDecodingContainer {
    func decodeLossyInt(forKey key: Key) -> Int? {
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return v }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Int(s) }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return Int(d) }
        return nil
    }

    func decodeLossyBool(forKey key: Key) -> Bool? {
        if let v = try? decodeIfPresent(Bool.self, forKey: key) { return v }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return i != 0 }
        if let s = try? decodeIfPresent(String.self, forKey: key) {
            let value = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "yes"].contains(value) { return true }
            if ["0", "false", "no"].contains(value) { return false }
        }
        return nil
    }

    func decodeLossyString(forKey key: Key) -> String? {
        if let v = try? decodeIfPresent(String.self, forKey: key) { return v }
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return String(i) }
        if let d = try? decodeIfPresent(Double.self, forKey: key) { return String(d) }
        if let b = try? decodeIfPresent(Bool.self, forKey: key) { return String(b) }
        return nil
    }
}
