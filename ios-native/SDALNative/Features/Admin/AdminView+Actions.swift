import Foundation

extension AdminView {
    func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await api.adminLogin(password: password)
            adminUser = try await api.fetchAdminSession()
            if adminUser == nil { throw APIError.invalidResponse }
            await loadOverview()
        } catch let APIError.httpError(code, _) where code == 401 {
            errorMessage = i18n.t("login_as_normal_user_first")
        } catch let APIError.httpError(code, _) where code == 403 {
            errorMessage = i18n.t("admin_login_required_not_admin")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        isLoading = true
        defer { isLoading = false }
        do { try await api.adminLogout() } catch {}
        adminUser = nil
        stats = nil
        live = nil
        moderationItems = []
        verificationRequests = []
        managedUsers = []
        managedUsersMeta = nil
        followTarget = nil
        followItems = []
        adminGroups = []
        adminFilters = []
        abConfigs = []
        abPerformance = []
        abRecommendations = []
        engagementScores = []
        adminPages = []
        logFiles = []
        logContent = ""
        selectedLogFile = nil
        albumCategories = []
        albumPhotos = []
        tournamentTeams = []
    }

    func refreshCurrentPanel() async {
        switch panel {
        case .overview: await loadOverview()
        case .moderation: await loadModeration()
        case .verification: await loadVerification()
        case .operations: await loadOperations()
        }
    }

    func loadOverview() async {
        errorMessage = nil
        do {
            async let statsReq = api.fetchAdminStats()
            async let liveReq = api.fetchAdminLive()
            stats = try await statsReq
            live = try await liveReq
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadModeration() async {
        errorMessage = nil
        do {
            switch queue {
            case .posts: moderationItems = try await api.fetchAdminPosts()
            case .stories: moderationItems = try await api.fetchAdminStories()
            case .messages: moderationItems = try await api.fetchAdminMessages()
            case .chat: moderationItems = try await api.fetchAdminChatMessages()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteModerationItem(_ id: Int) async {
        errorMessage = nil
        do {
            switch queue {
            case .posts: try await api.adminDeletePost(id: id)
            case .stories: try await api.adminDeleteStory(id: id)
            case .messages: try await api.adminDeleteMessage(id: id)
            case .chat: try await api.adminDeleteChatMessage(id: id)
            }
            moderationItems.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadVerification() async {
        errorMessage = nil
        do {
            verificationRequests = try await api.fetchVerificationRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func decideVerification(_ id: Int, approve: Bool) async {
        errorMessage = nil
        do {
            try await api.resolveVerificationRequest(id: id, approve: approve)
            verificationRequests.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadOperations() async {
        switch opsTab {
        case .users:
            if managedUsers.isEmpty { await loadUsers() }
        case .follows:
            if followItems.isEmpty, !followUserIdText.isEmpty { await loadFollows() }
        case .groups:
            await loadGroups()
        case .filters:
            await loadFilters()
        case .engagement:
            await loadEngagement()
        case .email:
            await loadEmailData()
        case .db:
            await loadDbData()
        case .pages:
            await loadPages()
        case .logs:
            await loadLogs()
        case .album:
            await loadAlbumAdmin()
        case .tournament:
            await loadTournamentTeams()
        }
    }

    func loadUsers() async {
        errorMessage = nil
        do {
            let trimmedQuery = userQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let payload: AdminUsersListEnvelope
            if !trimmedQuery.isEmpty, !userVerifiedOnly, !userOnlineOnly, !userAdminOnly {
                payload = try await api.searchAdminUsers(query: trimmedQuery, onlyWithPhoto: userWithPhoto, sort: userSort)
            } else {
                payload = try await api.fetchAdminUsers(
                    filter: userFilter,
                    query: trimmedQuery,
                    withPhoto: userWithPhoto,
                    verifiedOnly: userVerifiedOnly,
                    onlineOnly: userOnlineOnly,
                    adminOnly: userAdminOnly,
                    sort: userSort
                )
            }
            managedUsers = payload.users ?? []
            managedUsersMeta = payload.meta
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openUserEditor(_ userId: Int) async {
        errorMessage = nil
        do {
            editingUser = try await api.fetchAdminUserDetail(id: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setUserVerified(_ userId: Int, verified: Bool) async {
        errorMessage = nil
        do {
            try await api.adminSetUserVerified(userId: userId, verified: verified)
            if let idx = managedUsers.firstIndex(where: { $0.id == userId }) {
                let refreshed = try await api.fetchAdminUserDetail(id: userId)
                managedUsers[idx] = refreshed
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadFollows() async {
        errorMessage = nil
        guard let userId = Int(followUserIdText), userId > 0 else {
            errorMessage = i18n.t("enter_valid_user_id")
            return
        }
        do {
            let payload = try await api.fetchAdminFollows(userId: userId)
            followTarget = payload.user
            followItems = payload.items ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadGroups() async {
        errorMessage = nil
        do { adminGroups = try await api.fetchAdminGroups() } catch { errorMessage = error.localizedDescription }
    }

    func deleteGroup(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.adminDeleteGroup(id: id)
            adminGroups.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadFilters() async {
        errorMessage = nil
        do {
            adminFilters = try await api.fetchAdminFilters()
            for item in adminFilters { filterEdits[item.id] = item.kufur ?? "" }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addFilter() async {
        errorMessage = nil
        let word = newFilterWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        do {
            try await api.createAdminFilter(word: word)
            newFilterWord = ""
            await loadFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveFilter(_ id: Int) async {
        errorMessage = nil
        let word = (filterEdits[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        do {
            try await api.updateAdminFilter(id: id, word: word)
            await loadFilters()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFilter(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminFilter(id: id)
            adminFilters.removeAll { $0.id == id }
            filterEdits[id] = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadEngagement() async {
        errorMessage = nil
        do {
            let ab = try await api.fetchEngagementAB()
            abConfigs = ab.configs ?? []
            abPerformance = ab.performance ?? []
            abRecommendations = ab.recommendations ?? []
            for config in abConfigs {
                if abTraffic[config.variant] == nil { abTraffic[config.variant] = Double(config.trafficPct ?? 0) }
                if abEnabled[config.variant] == nil { abEnabled[config.variant] = config.enabled ?? true }
            }
            if engagementScores.isEmpty { await loadEngagementScores() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyAbConfig(_ config: EngagementAbConfig) async {
        errorMessage = nil
        do {
            try await api.updateEngagementABVariant(
                variant: config.variant,
                trafficPct: Int(abTraffic[config.variant] ?? Double(config.trafficPct ?? 0)),
                enabled: abEnabled[config.variant] ?? (config.enabled ?? true),
                params: config.params ?? [:]
            )
            await loadEngagement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rebalanceAB() async {
        errorMessage = nil
        do {
            try await api.rebalanceEngagementAB(keepAssignments: false)
            await loadEngagement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadEngagementScores() async {
        errorMessage = nil
        do {
            let payload = try await api.fetchEngagementScores(
                query: scoreQuery,
                status: scoreStatus,
                variant: scoreVariant,
                sort: "score_desc",
                page: 1,
                limit: 80
            )
            engagementScores = payload.items ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func recalculateScores() async {
        errorMessage = nil
        do {
            try await api.recalculateEngagementScores()
            await loadEngagement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadEmailData() async {
        errorMessage = nil
        do {
            async let categoriesReq = api.fetchAdminEmailCategories()
            async let templatesReq = api.fetchAdminEmailTemplates()
            emailCategories = try await categoriesReq
            emailTemplates = try await templatesReq
            if selectedEmailCategoryId == nil {
                selectedEmailCategoryId = emailCategories.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendEmailAction() async {
        errorMessage = nil
        let trimmedFrom = emailFrom.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTo = emailTo.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubject = emailSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = emailBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFrom.isEmpty, !trimmedSubject.isEmpty, !trimmedBody.isEmpty else { return }
        do {
            if emailSendMode == .single {
                guard !trimmedTo.isEmpty else {
                    errorMessage = i18n.t("recipient_required_single_send")
                    return
                }
                try await api.sendAdminEmail(to: trimmedTo, from: trimmedFrom, subject: trimmedSubject, html: trimmedBody)
            } else {
                guard let categoryId = selectedEmailCategoryId else {
                    errorMessage = i18n.t("select_email_category_bulk_send")
                    return
                }
                try await api.sendAdminBulkEmail(categoryId: categoryId, from: trimmedFrom, subject: trimmedSubject, html: trimmedBody)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveEmailCategoryAction() async {
        errorMessage = nil
        let ad = newEmailCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let tur = newEmailCategoryType.trimmingCharacters(in: .whitespacesAndNewlines)
        let deger = newEmailCategoryValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let aciklama = newEmailCategoryDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ad.isEmpty, !tur.isEmpty else { return }
        do {
            if let editingEmailCategoryId {
                try await api.updateAdminEmailCategory(id: editingEmailCategoryId, ad: ad, tur: tur, deger: deger, aciklama: aciklama)
            } else {
                try await api.createAdminEmailCategory(ad: ad, tur: tur, deger: deger, aciklama: aciklama)
            }
            clearCategoryDraft()
            await loadEmailData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEmailCategory(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminEmailCategory(id: id)
            if selectedEmailCategoryId == id {
                selectedEmailCategoryId = nil
            }
            await loadEmailData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCategoryDraft(_ category: AdminEmailCategory) {
        editingEmailCategoryId = category.id
        newEmailCategoryName = category.ad ?? ""
        newEmailCategoryType = category.tur ?? "all"
        newEmailCategoryValue = category.deger ?? ""
        newEmailCategoryDescription = category.aciklama ?? ""
    }

    func clearCategoryDraft() {
        editingEmailCategoryId = nil
        newEmailCategoryName = ""
        newEmailCategoryType = "all"
        newEmailCategoryValue = ""
        newEmailCategoryDescription = ""
    }

    func saveEmailTemplateAction() async {
        errorMessage = nil
        let ad = newEmailTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
        let konu = newEmailTemplateSubject.trimmingCharacters(in: .whitespacesAndNewlines)
        let icerik = newEmailTemplateBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ad.isEmpty, !konu.isEmpty, !icerik.isEmpty else { return }
        do {
            if let editingEmailTemplateId {
                try await api.updateAdminEmailTemplate(id: editingEmailTemplateId, ad: ad, konu: konu, icerik: icerik)
            } else {
                try await api.createAdminEmailTemplate(ad: ad, konu: konu, icerik: icerik)
            }
            clearTemplateDraft()
            await loadEmailData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEmailTemplate(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminEmailTemplate(id: id)
            await loadEmailData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadTemplateDraft(_ template: AdminEmailTemplate) {
        editingEmailTemplateId = template.id
        newEmailTemplateName = template.ad ?? ""
        newEmailTemplateSubject = template.konu ?? ""
        newEmailTemplateBody = template.icerik ?? ""
    }

    func clearTemplateDraft() {
        editingEmailTemplateId = nil
        newEmailTemplateName = ""
        newEmailTemplateSubject = ""
        newEmailTemplateBody = ""
    }

    func applyTemplateToComposer(_ template: AdminEmailTemplate) {
        emailSubject = template.konu ?? emailSubject
        emailBody = template.icerik ?? emailBody
    }

    func loadDbData() async {
        errorMessage = nil
        do {
            async let tablesReq = api.fetchAdminDbTables()
            async let backupsReq = api.fetchAdminDbBackups()
            dbTables = try await tablesReq
            let backupsEnvelope = try await backupsReq
            dbBackups = backupsEnvelope.items ?? []
            if selectedDbTableName == nil {
                selectedDbTableName = dbTables.first?.name
            }
            if let selectedDbTableName, dbTableRows.isEmpty {
                await loadDbTable(name: selectedDbTableName)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadDbTable(name: String) async {
        errorMessage = nil
        do {
            let payload = try await api.fetchAdminDbTable(name: name, page: 1, limit: 40)
            dbTableColumns = payload.columns ?? []
            dbTableRows = payload.rows ?? []
            selectedDbTableName = payload.table ?? name
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createBackupAction() async {
        errorMessage = nil
        let label = backupLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await api.createAdminDbBackup(label: label.isEmpty ? "manual" : label)
            await loadDbData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func downloadBackup(name: String) async {
        errorMessage = nil
        do {
            let file = try await api.downloadAdminDbBackup(name: name)
            backupExportDocument = BackupExportDocument(data: file.data)
            backupExportFileName = file.fileName
            showBackupExporter = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPages() async {
        errorMessage = nil
        do {
            adminPages = try await api.fetchAdminPages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePageAction() async {
        errorMessage = nil
        let name = pageName.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = pageUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let image = pageImage.trimmingCharacters(in: .whitespacesAndNewlines)
        let parentId = Int(pageParentId) ?? 0
        guard !name.isEmpty, !url.isEmpty, !image.isEmpty else {
            errorMessage = i18n.t("page_name_url_image_required")
            return
        }
        let body = AdminPageWriteBody(
            sayfaismi: name,
            sayfaurl: url,
            babaid: parentId,
            menugorun: pageMenuVisible ? 1 : 0,
            yonlendir: pageRedirect ? 1 : 0,
            mozellik: pageMFeature ? 1 : 0,
            resim: image
        )
        do {
            if let id = selectedPageIdForEdit {
                try await api.updateAdminPage(id: id, body: body)
            } else {
                try await api.createAdminPage(body: body)
            }
            clearPageDraft()
            await loadPages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadPageDraft(_ item: AdminPageItem) {
        selectedPageIdForEdit = item.id
        pageName = item.sayfaismi ?? ""
        pageUrl = item.sayfaurl ?? ""
        pageParentId = String(item.babaid ?? 0)
        pageMenuVisible = (item.menugorun ?? 0) == 1
        pageRedirect = (item.yonlendir ?? 0) == 1
        pageMFeature = (item.mozellik ?? 0) == 1
        pageImage = item.resim ?? "yok"
    }

    func clearPageDraft() {
        selectedPageIdForEdit = nil
        pageName = ""
        pageUrl = ""
        pageParentId = "0"
        pageMenuVisible = true
        pageRedirect = false
        pageMFeature = false
        pageImage = "yok"
    }

    func deletePageAction(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminPage(id: id)
            adminPages.removeAll { $0.id == id }
            if selectedPageIdForEdit == id { clearPageDraft() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadLogs() async {
        errorMessage = nil
        do {
            let payload = try await api.fetchAdminLogs(type: logType, from: logFrom, to: logTo)
            logFiles = payload.files ?? []
            selectedLogFile = nil
            logContent = ""
            logOffset = 0
            logTotal = 0
            logMatched = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openLogFile(_ fileName: String, offset: Int) async {
        errorMessage = nil
        do {
            let payload = try await api.fetchAdminLogs(
                type: logType,
                file: fileName,
                query: logQuery,
                activity: logActivity,
                userId: logUserId,
                from: logFrom,
                to: logTo,
                limit: Int(logLimit) ?? 500,
                offset: max(offset, 0)
            )
            selectedLogFile = fileName
            logContent = payload.content ?? ""
            logOffset = payload.offset ?? max(offset, 0)
            logTotal = payload.total ?? 0
            logMatched = payload.matched ?? 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func paginateLog(direction: Int) async {
        guard let selectedLogFile else { return }
        let step = max(Int(logLimit) ?? 500, 1)
        let nextOffset = max(logOffset + (direction * step), 0)
        await openLogFile(selectedLogFile, offset: nextOffset)
    }

    func loadAlbumAdmin() async {
        await loadAlbumCategories()
        await loadAlbumPhotos()
    }

    func loadAlbumCategories() async {
        errorMessage = nil
        do {
            let payload = try await api.fetchAdminAlbumCategories()
            albumCategories = payload.categories ?? []
            albumCategoryCounts = payload.counts ?? [:]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveAlbumCategoryAction() async {
        errorMessage = nil
        let name = albumCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let desc = albumCategoryDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !desc.isEmpty else {
            errorMessage = i18n.t("category_description_required")
            return
        }
        let body = AdminAlbumCategoryWriteBody(kategori: name, aciklama: desc, aktif: albumCategoryActive ? 1 : 0)
        do {
            if let id = selectedAlbumCategoryIdForEdit {
                try await api.updateAdminAlbumCategory(id: id, body: body)
            } else {
                try await api.createAdminAlbumCategory(body: body)
            }
            clearAlbumCategoryDraft()
            await loadAlbumCategories()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadAlbumCategoryDraft(_ item: AdminAlbumCategory) {
        selectedAlbumCategoryIdForEdit = item.id
        albumCategoryName = item.kategori ?? ""
        albumCategoryDescription = item.aciklama ?? ""
        albumCategoryActive = (item.aktif ?? 0) == 1
    }

    func clearAlbumCategoryDraft() {
        selectedAlbumCategoryIdForEdit = nil
        albumCategoryName = ""
        albumCategoryDescription = ""
        albumCategoryActive = true
    }

    func deleteAlbumCategoryAction(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminAlbumCategory(id: id)
            albumCategories.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadAlbumPhotos() async {
        errorMessage = nil
        do {
            let payload = try await api.fetchAdminAlbumPhotos(
                krt: albumPhotoFilter,
                kid: albumPhotoCategoryFilter,
                diz: albumPhotoSort
            )
            albumPhotos = payload.photos ?? []
            albumUserMap = payload.userMap ?? [:]
            albumCommentCounts = payload.commentCounts ?? [:]
            selectedAlbumPhotoIds = selectedAlbumPhotoIds.intersection(Set(albumPhotos.map(\.id)))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func bulkAlbumPhotos(action: String) async {
        errorMessage = nil
        let ids = Array(selectedAlbumPhotoIds)
        guard !ids.isEmpty else { return }
        do {
            try await api.bulkAdminAlbumPhotos(ids: ids, action: action)
            await loadAlbumPhotos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAlbumPhoto(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminAlbumPhoto(id: id)
            albumPhotos.removeAll { $0.id == id }
            selectedAlbumPhotoIds.remove(id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func showAlbumPhotoComments(_ photo: AdminAlbumPhoto) async {
        errorMessage = nil
        do {
            selectedPhotoComments = try await api.fetchAdminAlbumPhotoComments(photoId: photo.id)
            selectedPhotoForComments = photo
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAlbumPhotoComment(photoId: Int, commentId: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminAlbumPhotoComment(photoId: photoId, commentId: commentId)
            selectedPhotoComments.removeAll { $0.id == commentId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadTournamentTeams() async {
        errorMessage = nil
        do {
            tournamentTeams = try await api.fetchAdminTournamentTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTournamentTeam(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminTournamentTeam(id: id)
            tournamentTeams.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func handleRestoreFileSelection(_ result: Result<[URL], Error>) async {
        switch result {
        case let .failure(error):
            errorMessage = error.localizedDescription
        case let .success(urls):
            guard let url = urls.first else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                let data = try Data(contentsOf: url)
                try await api.restoreAdminDbBackup(fileData: data, fileName: url.lastPathComponent)
                selectedRestoreFileName = url.lastPathComponent
                await loadDbData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
