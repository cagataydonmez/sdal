import Foundation

extension APIClient {
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
        let payload = try await request("/new/admin/posts", query: [
            "limit": String(limit),
            "offset": String(offset)
        ], as: AdminListEnvelope<AdminModerationItem>.self)
        return payload.list
    }

    func fetchAdminStories(limit: Int = 40, offset: Int = 0) async throws -> [AdminModerationItem] {
        let payload = try await request("/new/admin/stories", query: [
            "limit": String(limit),
            "offset": String(offset)
        ], as: AdminListEnvelope<AdminModerationItem>.self)
        return payload.list
    }

    func fetchAdminMessages(limit: Int = 40, offset: Int = 0) async throws -> [AdminModerationItem] {
        let payload = try await request("/new/admin/messages", query: [
            "limit": String(limit),
            "offset": String(offset)
        ], as: AdminListEnvelope<AdminModerationItem>.self)
        return payload.list
    }

    func fetchAdminChatMessages(limit: Int = 40, offset: Int = 0) async throws -> [AdminModerationItem] {
        let payload = try await request("/new/admin/chat/messages", query: [
            "limit": String(limit),
            "offset": String(offset)
        ], as: AdminListEnvelope<AdminModerationItem>.self)
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
        try await request("/new/admin/follows/\(userId)", query: [
            "limit": String(limit),
            "offset": String(offset)
        ], as: AdminFollowsEnvelope.self)
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
        var params: [String: String] = [
            "sort": sort,
            "status": status,
            "page": String(page),
            "limit": String(limit)
        ]
        if !query.isEmpty { params["q"] = query }
        if !variant.isEmpty { params["variant"] = variant }
        return try await request("/new/admin/engagement-scores", query: params, as: EngagementScoresEnvelope.self)
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
        return try await request("/new/admin/db/table/\(encoded)", query: [
            "page": String(page),
            "limit": String(limit)
        ], as: AdminDbTableEnvelope.self)
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
        var params: [String: String] = [
            "filter": filter,
            "sort": sort,
            "limit": String(limit)
        ]
        if !query.isEmpty { params["q"] = query }
        if withPhoto { params["photo"] = "1" }
        if verifiedOnly { params["verified"] = "1" }
        if onlineOnly { params["online"] = "1" }
        if adminOnly { params["admin"] = "1" }
        return try await request("/admin/users/lists", query: params, as: AdminUsersListEnvelope.self)
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
        var params: [String: String] = [
            "q": query,
            "sort": sort,
            "limit": String(limit)
        ]
        if onlyWithPhoto { params["res"] = "1" }
        return try await request("/admin/users/search", query: params, as: AdminUsersListEnvelope.self)
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
        var params = ["type": type]
        if let file, !file.isEmpty {
            params["file"] = file
            if !query.isEmpty { params["q"] = query }
            if !activity.isEmpty { params["activity"] = activity }
            if !userId.isEmpty { params["userId"] = userId }
            if !from.isEmpty { params["from"] = from }
            if !to.isEmpty { params["to"] = to }
            params["limit"] = String(limit)
            params["offset"] = String(offset)
        } else {
            if !from.isEmpty { params["from"] = from }
            if !to.isEmpty { params["to"] = to }
        }
        return try await request("/admin/logs", query: params, as: AdminLogsEnvelope.self)
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
        var params: [String: String] = [:]
        if !krt.isEmpty { params["krt"] = krt }
        if !kid.isEmpty { params["kid"] = kid }
        if !diz.isEmpty { params["diz"] = diz }
        return try await request("/admin/album/photos", query: params, as: AdminAlbumPhotosEnvelope.self)
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
}
