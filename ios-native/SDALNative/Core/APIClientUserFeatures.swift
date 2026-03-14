import Foundation

extension APIClient {
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

    func fetchMessengerThreads(query: String = "", limit: Int = 40, offset: Int = 0) async throws -> [MessengerThread] {
        var parts = ["limit=\(limit)", "offset=\(offset)"]
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            parts.append("q=\(encoded)")
        }
        let payload = try await request("/sdal-messenger/threads?\(parts.joined(separator: "&"))", as: MessengerThreadsEnvelope.self)
        return payload.items
    }

    func searchMessengerContacts(query: String, limit: Int = 20) async throws -> [MessageRecipient] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let payload = try await request("/sdal-messenger/contacts?q=\(encoded)&limit=\(limit)", as: MessengerContactsEnvelope.self)
        return payload.items
    }

    func createMessengerThread(userId: Int) async throws -> Int {
        struct Body: Encodable { let userId: Int }
        let payload = try await request("/sdal-messenger/threads", method: "POST", body: Body(userId: userId), as: MessengerThreadCreateEnvelope.self)
        guard let id = payload.threadId else { throw APIError.invalidResponse }
        return id
    }

    func fetchMessengerMessages(threadId: Int, beforeId: Int? = nil, limit: Int = 60) async throws -> [MessengerMessage] {
        var parts = ["limit=\(limit)"]
        if let beforeId, beforeId > 0 { parts.append("beforeId=\(beforeId)") }
        let payload = try await request("/sdal-messenger/threads/\(threadId)/messages?\(parts.joined(separator: "&"))", as: MessengerMessagesEnvelope.self)
        return payload.items
    }

    func sendMessengerMessage(threadId: Int, text: String) async throws -> MessengerMessage? {
        struct Body: Encodable {
            let text: String
            let clientWrittenAt: String
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let payload = try await request(
            "/sdal-messenger/threads/\(threadId)/messages",
            method: "POST",
            body: Body(text: text, clientWrittenAt: now),
            as: MessengerMessageCreateEnvelope.self
        )
        return payload.item
    }

    func markMessengerThreadRead(threadId: Int) async throws {
        _ = try await request("/sdal-messenger/threads/\(threadId)/read", method: "POST", as: APIWriteResponse.self)
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
}
