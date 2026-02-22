import SwiftUI
import UniformTypeIdentifiers

private struct BackupExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum AdminPanel: String, CaseIterable, Identifiable {
    case overview
    case moderation
    case verification
    case operations

    var id: String { rawValue }
}

private enum ModerationQueue: String, CaseIterable, Identifiable {
    case posts
    case stories
    case messages
    case chat

    var id: String { rawValue }
}

private enum AdminOpsTab: String, CaseIterable, Identifiable {
    case users
    case follows
    case groups
    case filters
    case engagement
    case email
    case db
    case pages
    case logs
    case album
    case tournament

    var id: String { rawValue }
}

private enum AdminEmailSendMode: String, CaseIterable, Identifiable {
    case single
    case bulk

    var id: String { rawValue }
}

struct AdminView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var adminUser: AdminUser?
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var panel: AdminPanel = .overview
    @State private var queue: ModerationQueue = .posts
    @State private var opsTab: AdminOpsTab = .users

    @State private var stats: AdminStats?
    @State private var live: AdminLiveSnapshot?
    @State private var moderationItems: [AdminModerationItem] = []
    @State private var verificationRequests: [VerificationRequestItem] = []

    @State private var managedUsers: [AdminManagedUser] = []
    @State private var managedUsersMeta: AdminUsersMeta?
    @State private var userFilter = "all"
    @State private var userSort = "engagement_desc"
    @State private var userQuery = ""
    @State private var userWithPhoto = false
    @State private var userVerifiedOnly = false
    @State private var userOnlineOnly = false
    @State private var userAdminOnly = false
    @State private var editingUser: AdminManagedUser?

    @State private var followUserIdText = ""
    @State private var followTarget: AdminFollowUser?
    @State private var followItems: [AdminFollowItem] = []

    @State private var adminGroups: [AdminGroupItem] = []

    @State private var adminFilters: [AdminFilterItem] = []
    @State private var newFilterWord = ""
    @State private var filterEdits: [Int: String] = [:]

    @State private var abConfigs: [EngagementAbConfig] = []
    @State private var abPerformance: [EngagementAbPerformance] = []
    @State private var abRecommendations: [EngagementAbRecommendation] = []
    @State private var abTraffic: [String: Double] = [:]
    @State private var abEnabled: [String: Bool] = [:]
    @State private var engagementScores: [EngagementScoreItem] = []
    @State private var scoreQuery = ""
    @State private var scoreStatus = "all"
    @State private var scoreVariant = ""

    @State private var emailCategories: [AdminEmailCategory] = []
    @State private var emailTemplates: [AdminEmailTemplate] = []
    @State private var selectedEmailCategoryId: Int?
    @State private var emailFrom = ""
    @State private var emailTo = ""
    @State private var emailSubject = ""
    @State private var emailBody = ""
    @State private var emailSendMode: AdminEmailSendMode = .single
    @State private var newEmailCategoryName = ""
    @State private var newEmailCategoryType = "all"
    @State private var newEmailCategoryValue = ""
    @State private var newEmailCategoryDescription = ""
    @State private var newEmailTemplateName = ""
    @State private var newEmailTemplateSubject = ""
    @State private var newEmailTemplateBody = ""
    @State private var editingEmailCategoryId: Int?
    @State private var editingEmailTemplateId: Int?
    @State private var dbTables: [AdminDbTableInfo] = []
    @State private var selectedDbTableName: String?
    @State private var dbTableColumns: [AdminDbColumn] = []
    @State private var dbTableRows: [[String: JSONValue]] = []
    @State private var dbBackups: [AdminDbBackupItem] = []
    @State private var backupLabel = "manual"
    @State private var showRestorePicker = false
    @State private var selectedRestoreFileName: String?
    @State private var backupExportDocument = BackupExportDocument()
    @State private var backupExportFileName = "backup.db"
    @State private var showBackupExporter = false
    @State private var adminPages: [AdminPageItem] = []
    @State private var pageName = ""
    @State private var pageUrl = ""
    @State private var pageParentId = "0"
    @State private var pageMenuVisible = true
    @State private var pageRedirect = false
    @State private var pageMFeature = false
    @State private var pageImage = "yok"
    @State private var selectedPageIdForEdit: Int?
    @State private var logType = "error"
    @State private var logFiles: [AdminLogFile] = []
    @State private var selectedLogFile: String?
    @State private var logContent = ""
    @State private var logFrom = ""
    @State private var logTo = ""
    @State private var logQuery = ""
    @State private var logActivity = ""
    @State private var logUserId = ""
    @State private var logLimit = "500"
    @State private var logOffset = 0
    @State private var logTotal = 0
    @State private var logMatched = 0
    @State private var albumCategories: [AdminAlbumCategory] = []
    @State private var albumCategoryCounts: [String: AdminAlbumCategoryCount] = [:]
    @State private var albumCategoryName = ""
    @State private var albumCategoryDescription = ""
    @State private var albumCategoryActive = true
    @State private var selectedAlbumCategoryIdForEdit: Int?
    @State private var albumPhotos: [AdminAlbumPhoto] = []
    @State private var albumUserMap: [String: String] = [:]
    @State private var albumCommentCounts: [String: Int] = [:]
    @State private var albumPhotoFilter = ""
    @State private var albumPhotoCategoryFilter = ""
    @State private var albumPhotoSort = "aktifazalan"
    @State private var selectedAlbumPhotoIds: Set<Int> = []
    @State private var selectedPhotoForComments: AdminAlbumPhoto?
    @State private var selectedPhotoComments: [AdminAlbumPhotoComment] = []
    @State private var tournamentTeams: [AdminTournamentTeam] = []
    @State private var showNavDrawer = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if adminUser == nil {
                    adminLoginForm
                } else {
                    adminWorkspace
                }
            }
            .navigationTitle(i18n.t("admin"))
            .sheet(item: $editingUser) { user in
                AdminUserEditSheet(
                    user: user,
                    onSaved: {
                        Task {
                            await loadUsers()
                            editingUser = nil
                        }
                    }
                )
            }
            .sheet(item: $selectedPhotoForComments) { photo in
                NavigationStack {
                    List {
                        if selectedPhotoComments.isEmpty {
                            Text(i18n.t("no_comments"))
                                .foregroundStyle(SDALTheme.muted)
                        } else {
                            ForEach(selectedPhotoComments) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.yorum ?? "-")
                                        .font(.subheadline)
                                    Text(item.tarih ?? "")
                                        .font(.caption)
                                        .foregroundStyle(SDALTheme.muted)
                                    Button(i18n.t("delete"), role: .destructive) {
                                        Task { await deleteAlbumPhotoComment(photoId: photo.id, commentId: item.id) }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    .navigationTitle(i18n.t("photo_comments"))
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(i18n.t("close")) { selectedPhotoForComments = nil }
                        }
                    }
                    .background(SDALTheme.appBackground.ignoresSafeArea())
                }
            }
            .fileImporter(
                isPresented: $showRestorePicker,
                allowedContentTypes: [.data, .item],
                allowsMultipleSelection: false
            ) { result in
                Task { await handleRestoreFileSelection(result) }
            }
            .fileExporter(
                isPresented: $showBackupExporter,
                document: backupExportDocument,
                contentType: .data,
                defaultFilename: backupExportFileName
            ) { result in
                if case let .failure(error) = result {
                    errorMessage = error.localizedDescription
                }
            }
            .sheet(isPresented: $showNavDrawer) {
                NavigationStack {
                    ScrollView {
                        adminNavigationRail
                            .padding(16)
                    }
                    .navigationTitle(i18n.t("admin_menu"))
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(i18n.t("close")) { showNavDrawer = false }
                        }
                    }
                    .background(SDALTheme.appBackground.ignoresSafeArea())
                }
                .presentationDetents([.medium, .large])
            }
            .background(SDALTheme.appBackground.ignoresSafeArea())
        }
    }

    private var adminLoginForm: some View {
        ScrollView {
            VStack(spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(i18n.t("admin_sign_in"))
                            .font(.headline)
                        Text(i18n.t("admin_sign_in_hint"))
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                        SecureField(i18n.t("password"), text: $password)
                            .textFieldStyle(.roundedBorder)
                        Button(isLoading ? i18n.t("loading") : i18n.t("sign_in")) {
                            Task { await login() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading || password.isEmpty)
                    }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }

    private var adminWorkspace: some View {
        GeometryReader { proxy in
            let compactLayout = horizontalSizeClass == .compact || proxy.size.width < 1120
            Group {
                if compactLayout {
                    ScrollView {
                        VStack(spacing: 14) {
                            headerCard(showMenuButton: true)
                            panelPicker
                            panelBody
                            if let errorMessage {
                                Text(errorMessage)
                                    .foregroundStyle(.red)
                                    .font(.footnote)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(16)
                    }
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        adminNavigationRail
                            .frame(width: 286)
                        ScrollView {
                            VStack(spacing: 14) {
                                headerCard(showMenuButton: false)
                                panelBody
                                if let errorMessage {
                                    Text(errorMessage)
                                        .foregroundStyle(.red)
                                        .font(.footnote)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .frame(maxWidth: 1240)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .refreshable { await refreshCurrentPanel() }
    }

    private func headerCard(showMenuButton: Bool) -> some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("@\(adminUser?.kadi ?? "admin")")
                        .font(.headline)
                    Text(adminUser?.role ?? "admin")
                        .font(.caption)
                        .foregroundStyle(SDALTheme.muted)
                }
                Spacer()
                if showMenuButton {
                    Button {
                        showNavDrawer = true
                    } label: {
                        Label(i18n.t("menu"), systemImage: "line.3.horizontal")
                    }
                    .buttonStyle(.bordered)
                }
                Button(i18n.t("logout")) {
                    Task { await logout() }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var panelPicker: some View {
        GlassCard {
            Picker(i18n.t("panel"), selection: $panel) {
                Text(i18n.t("overview")).tag(AdminPanel.overview)
                Text(i18n.t("moderation")).tag(AdminPanel.moderation)
                Text(i18n.t("verification")).tag(AdminPanel.verification)
                Text(i18n.t("operations")).tag(AdminPanel.operations)
            }
            .pickerStyle(.segmented)
            .onChange(of: panel) { _, _ in Task { await refreshCurrentPanel() } }
        }
    }

    private var adminNavigationRail: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(i18n.t("admin_navigation"))
                        .font(.headline)
                    Text("@\(adminUser?.kadi ?? "admin")")
                        .font(.caption)
                        .foregroundStyle(SDALTheme.muted)
                    Divider()
                    adminNavButton(
                        title: i18n.t("overview"),
                        icon: "chart.bar.xaxis",
                        selected: panel == .overview
                    ) {
                        panel = .overview
                        Task { await refreshCurrentPanel() }
                    }
                    adminNavButton(
                        title: i18n.t("moderation"),
                        icon: "shield.lefthalf.filled",
                        selected: panel == .moderation
                    ) {
                        panel = .moderation
                        Task { await refreshCurrentPanel() }
                    }
                    if panel == .moderation {
                        VStack(spacing: 6) {
                            adminSubNavButton(title: i18n.t("posts"), selected: queue == .posts) {
                                queue = .posts
                                Task { await loadModeration() }
                            }
                            adminSubNavButton(title: i18n.t("stories"), selected: queue == .stories) {
                                queue = .stories
                                Task { await loadModeration() }
                            }
                            adminSubNavButton(title: i18n.t("messages"), selected: queue == .messages) {
                                queue = .messages
                                Task { await loadModeration() }
                            }
                            adminSubNavButton(title: i18n.t("chat"), selected: queue == .chat) {
                                queue = .chat
                                Task { await loadModeration() }
                            }
                        }
                        .padding(.leading, 4)
                    }
                    adminNavButton(
                        title: i18n.t("verification"),
                        icon: "checkmark.seal",
                        selected: panel == .verification
                    ) {
                        panel = .verification
                        Task { await refreshCurrentPanel() }
                    }
                    adminNavButton(
                        title: i18n.t("operations"),
                        icon: "slider.horizontal.3",
                        selected: panel == .operations
                    ) {
                        panel = .operations
                        Task { await refreshCurrentPanel() }
                    }
                    if panel == .operations {
                        Divider()
                        VStack(spacing: 6) {
                            adminSubNavButton(title: i18n.t("users"), selected: opsTab == .users) { selectOps(.users) }
                            adminSubNavButton(title: i18n.t("follows"), selected: opsTab == .follows) { selectOps(.follows) }
                            adminSubNavButton(title: i18n.t("groups"), selected: opsTab == .groups) { selectOps(.groups) }
                            adminSubNavButton(title: i18n.t("filters"), selected: opsTab == .filters) { selectOps(.filters) }
                            adminSubNavButton(title: i18n.t("engagement"), selected: opsTab == .engagement) { selectOps(.engagement) }
                            adminSubNavButton(title: i18n.t("email"), selected: opsTab == .email) { selectOps(.email) }
                            adminSubNavButton(title: i18n.t("db"), selected: opsTab == .db) { selectOps(.db) }
                            adminSubNavButton(title: i18n.t("pages"), selected: opsTab == .pages) { selectOps(.pages) }
                            adminSubNavButton(title: i18n.t("logs"), selected: opsTab == .logs) { selectOps(.logs) }
                            adminSubNavButton(title: i18n.t("album"), selected: opsTab == .album) { selectOps(.album) }
                            adminSubNavButton(title: i18n.t("tournament"), selected: opsTab == .tournament) { selectOps(.tournament) }
                        }
                    }
                }
            }
        }
    }

    private func adminNavButton(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .fontWeight(.semibold)
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(selected ? SDALTheme.ink : SDALTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? SDALTheme.primary.opacity(0.18) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func adminSubNavButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(selected ? SDALTheme.primary : SDALTheme.line)
                    .frame(width: 7, height: 7)
                Text(title)
                    .font(.caption.weight(selected ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(selected ? SDALTheme.ink : SDALTheme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? SDALTheme.cardAlt : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func selectOps(_ tab: AdminOpsTab) {
        panel = .operations
        opsTab = tab
        Task { await loadOperations() }
    }

    @ViewBuilder
    private var panelBody: some View {
        switch panel {
        case .overview:
            overviewPanel
        case .moderation:
            moderationPanel
        case .verification:
            verificationPanel
        case .operations:
            operationsPanel
        }
    }

    private var overviewPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(i18n.t("stats"))
                        .font(.headline)
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 160), spacing: 10)
                    ], spacing: 10) {
                        kpiCard(title: i18n.t("users"), value: stats?.totalUsers, tint: SDALTheme.secondary)
                        kpiCard(title: i18n.t("active_users"), value: stats?.activeUsers, tint: .green)
                        kpiCard(title: i18n.t("posts"), value: stats?.totalPosts, tint: SDALTheme.primary)
                        kpiCard(title: i18n.t("stories"), value: stats?.totalStories, tint: .orange)
                        kpiCard(title: i18n.t("pending_verification"), value: stats?.pendingVerifications, tint: .yellow)
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(i18n.t("live"))
                        .font(.headline)
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 160), spacing: 10)
                    ], spacing: 10) {
                        kpiCard(title: i18n.t("online_members"), value: live?.onlineMembers, tint: .mint)
                        kpiCard(title: i18n.t("unread_messages"), value: live?.unreadMessages, tint: .indigo)
                        kpiCard(title: i18n.t("pending_invites"), value: live?.pendingGroupInvites, tint: .pink)
                        kpiCard(title: i18n.t("active_rooms"), value: live?.activeRooms, tint: .cyan)
                    }
                }
            }
        }
        .task { if stats == nil || live == nil { await loadOverview() } }
    }

    private func kpiCard(title: String, value: Int?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(SDALTheme.muted)
            Text(value.map(String.init) ?? "-")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SDALTheme.ink)
            RoundedRectangle(cornerRadius: 99, style: .continuous)
                .fill(tint.opacity(0.26))
                .frame(height: 5)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SDALTheme.cardAlt.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SDALTheme.line, lineWidth: 1)
        )
    }

    private var moderationPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                Picker(i18n.t("queue"), selection: $queue) {
                    Text(i18n.t("posts")).tag(ModerationQueue.posts)
                    Text(i18n.t("stories")).tag(ModerationQueue.stories)
                    Text(i18n.t("messages")).tag(ModerationQueue.messages)
                    Text(i18n.t("chat")).tag(ModerationQueue.chat)
                }
                .pickerStyle(.segmented)
                .onChange(of: queue) { _, _ in Task { await loadModeration() } }
            }

            if moderationItems.isEmpty {
                GlassCard {
                    Text(i18n.t("no_items_in_queue"))
                        .foregroundStyle(SDALTheme.muted)
                }
            } else {
                ForEach(moderationItems) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("#\(item.id)")
                                    .font(.caption.bold())
                                Spacer()
                                Button(i18n.t("delete"), role: .destructive) { Task { await deleteModerationItem(item.id) } }
                                    .buttonStyle(.bordered)
                            }
                            Text(item.content ?? item.message ?? "-")
                                .font(.subheadline)
                            HStack(spacing: 8) {
                                Text(item.authorKadi ?? item.senderKadi ?? item.kadi ?? "-")
                                Text("•")
                                Text(item.createdAt ?? "")
                            }
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                        }
                    }
                }
            }
        }
        .task { if moderationItems.isEmpty { await loadModeration() } }
    }

    private var verificationPanel: some View {
        VStack(spacing: 12) {
            if verificationRequests.isEmpty {
                GlassCard {
                    Text(i18n.t("no_pending_verification_requests"))
                        .foregroundStyle(SDALTheme.muted)
                }
            } else {
                ForEach(verificationRequests) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("@\(item.kadi ?? i18n.t("user"))")
                                .font(.headline)
                            Text("\(item.isim ?? "") \(item.soyisim ?? "")")
                                .font(.subheadline)
                                .foregroundStyle(SDALTheme.muted)
                            Text(item.email ?? "-")
                                .font(.caption)
                                .foregroundStyle(SDALTheme.muted)
                            HStack(spacing: 8) {
                                Button(i18n.t("approve")) { Task { await decideVerification(item.id, approve: true) } }
                                    .buttonStyle(.borderedProminent)
                                Button(i18n.t("reject"), role: .destructive) { Task { await decideVerification(item.id, approve: false) } }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .task { if verificationRequests.isEmpty { await loadVerification() } }
    }

    private var operationsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                Picker(i18n.t("operations"), selection: $opsTab) {
                    Text(i18n.t("users")).tag(AdminOpsTab.users)
                    Text(i18n.t("follows")).tag(AdminOpsTab.follows)
                    Text(i18n.t("groups")).tag(AdminOpsTab.groups)
                    Text(i18n.t("filters")).tag(AdminOpsTab.filters)
                    Text(i18n.t("engagement")).tag(AdminOpsTab.engagement)
                    Text(i18n.t("email")).tag(AdminOpsTab.email)
                    Text(i18n.t("db")).tag(AdminOpsTab.db)
                    Text(i18n.t("pages")).tag(AdminOpsTab.pages)
                    Text(i18n.t("logs")).tag(AdminOpsTab.logs)
                    Text(i18n.t("album")).tag(AdminOpsTab.album)
                    Text(i18n.t("tournament")).tag(AdminOpsTab.tournament)
                }
                .pickerStyle(.menu)
                .onChange(of: opsTab) { _, _ in Task { await loadOperations() } }
            }

            switch opsTab {
            case .users:
                usersOpsPanel
            case .follows:
                followsOpsPanel
            case .groups:
                groupsOpsPanel
            case .filters:
                filtersOpsPanel
            case .engagement:
                engagementOpsPanel
            case .email:
                emailOpsPanel
            case .db:
                dbOpsPanel
            case .pages:
                pagesOpsPanel
            case .logs:
                logsOpsPanel
            case .album:
                albumOpsPanel
            case .tournament:
                tournamentOpsPanel
            }
        }
        .task { await loadOperations() }
    }

    private var usersOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("user_management"))
                        .font(.headline)
                    HStack {
                        TextField(i18n.t("search_username_name_email"), text: $userQuery)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("load")) { Task { await loadUsers() } }
                            .buttonStyle(.borderedProminent)
                    }
                    HStack {
                        Picker(i18n.t("filter"), selection: $userFilter) {
                            Text(i18n.t("all")).tag("all")
                            Text(i18n.t("active")).tag("active")
                            Text(i18n.t("pending")).tag("pending")
                            Text(i18n.t("banned")).tag("banned")
                            Text(i18n.t("online")).tag("online")
                        }
                        .pickerStyle(.menu)
                        Picker(i18n.t("sort"), selection: $userSort) {
                            Text(i18n.t("engagement_desc")).tag("engagement_desc")
                            Text(i18n.t("engagement_asc")).tag("engagement_asc")
                            Text(i18n.t("recent")).tag("recent")
                            Text(i18n.t("name")).tag("name")
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle(i18n.t("with_photo"), isOn: $userWithPhoto)
                    Toggle(i18n.t("verified_only"), isOn: $userVerifiedOnly)
                    Toggle(i18n.t("online_only"), isOn: $userOnlineOnly)
                    Toggle(i18n.t("admin_only"), isOn: $userAdminOnly)
                    if let meta = managedUsersMeta {
                        Text(String(format: i18n.t("total_returned_format"), meta.total ?? 0, meta.returned ?? 0))
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    }
                }
            }

            if managedUsers.isEmpty {
                GlassCard {
                    Text(i18n.t("no_users_loaded"))
                        .foregroundStyle(SDALTheme.muted)
                }
            } else {
                ForEach(managedUsers) { user in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("@\(user.kadi ?? "-")")
                                        .font(.headline)
                                    Text("\(user.isim ?? "") \(user.soyisim ?? "")")
                                        .font(.subheadline)
                                        .foregroundStyle(SDALTheme.muted)
                                }
                                Spacer()
                                Button(user.verified == true ? i18n.t("unverify") : i18n.t("verify")) {
                                    Task { await setUserVerified(user.id, verified: user.verified != true) }
                                }
                                .buttonStyle(.bordered)
                                Button(i18n.t("edit")) { Task { await openUserEditor(user.id) } }
                                    .buttonStyle(.borderedProminent)
                            }
                            HStack(spacing: 8) {
                                StatusChip(label: "A", active: (user.aktiv ?? 0) == 1, tint: SDALTheme.secondary)
                                StatusChip(label: "B", active: (user.yasak ?? 0) == 1, tint: .red)
                                StatusChip(label: "V", active: user.verified == true, tint: SDALTheme.primary)
                                StatusChip(label: "O", active: user.online == true, tint: .green)
                                StatusChip(label: "ADM", active: (user.admin ?? 0) == 1, tint: .orange)
                                Spacer()
                                Text(String(format: i18n.t("score_format"), user.engagementScore ?? 0))
                                    .font(.caption)
                                    .foregroundStyle(SDALTheme.muted)
                            }
                        }
                    }
                }
            }
        }
    }

    private var followsOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("follow_inspector")).font(.headline)
                    HStack {
                        TextField(i18n.t("user_id"), text: $followUserIdText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("load")) { Task { await loadFollows() } }
                            .buttonStyle(.borderedProminent)
                    }
                    if let followTarget {
                        Text(String(format: i18n.t("user_format"), followTarget.kadi ?? "-", followTarget.id ?? 0))
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    }
                }
            }

            if followItems.isEmpty {
                GlassCard { Text(i18n.t("no_follow_rows")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(followItems) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("@\(item.kadi ?? "-")").font(.headline)
                            HStack(spacing: 8) {
                                Text(String(format: i18n.t("messages_count"), item.messageCount ?? 0))
                                Text(String(format: i18n.t("quotes_count"), item.quoteCount ?? 0))
                            }
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                        }
                    }
                }
            }
        }
    }

    private var groupsOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                HStack {
                    Text(i18n.t("groups_admin")).font(.headline)
                    Spacer()
                    Button(i18n.t("refresh")) { Task { await loadGroups() } }
                        .buttonStyle(.bordered)
                }
            }
            if adminGroups.isEmpty {
                GlassCard { Text(i18n.t("no_groups")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(adminGroups) { group in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.name ?? "-").font(.headline)
                            Text(group.description ?? "")
                                .font(.subheadline)
                                .foregroundStyle(SDALTheme.muted)
                            HStack {
                                Text(String(format: i18n.t("id_format"), group.id)).font(.caption).foregroundStyle(SDALTheme.muted)
                                Spacer()
                                Button(i18n.t("delete"), role: .destructive) { Task { await deleteGroup(group.id) } }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
    }

    private var filtersOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("filters")).font(.headline)
                    HStack {
                        TextField(i18n.t("new_blocked_word"), text: $newFilterWord)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("add")) { Task { await addFilter() } }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }

            if adminFilters.isEmpty {
                GlassCard { Text(i18n.t("no_filter_words")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(adminFilters) { item in
                    GlassCard {
                        HStack {
                            TextField(
                                i18n.t("word"),
                                text: Binding(
                                    get: { filterEdits[item.id] ?? item.kufur ?? "" },
                                    set: { filterEdits[item.id] = $0 }
                                )
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textFieldStyle(.roundedBorder)
                            Button(i18n.t("save")) { Task { await saveFilter(item.id) } }
                                .buttonStyle(.bordered)
                            Button(i18n.t("delete"), role: .destructive) { Task { await deleteFilter(item.id) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private var engagementOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("engagement_controls")).font(.headline)
                    HStack {
                        Button(i18n.t("recalculate_scores")) { Task { await recalculateScores() } }
                            .buttonStyle(.borderedProminent)
                        Button(i18n.t("rebalance_ab")) { Task { await rebalanceAB() } }
                            .buttonStyle(.bordered)
                    }
                }
            }

            if !abConfigs.isEmpty {
                ForEach(abConfigs) { config in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(config.variant) - \(config.name ?? "")")
                                .font(.headline)
                            HStack {
                                Text(i18n.t("traffic"))
                                Slider(
                                    value: Binding(
                                        get: { abTraffic[config.variant] ?? Double(config.trafficPct ?? 0) },
                                        set: { abTraffic[config.variant] = $0 }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                                Text("\(Int(abTraffic[config.variant] ?? Double(config.trafficPct ?? 0)))%")
                                    .font(.caption)
                            }
                            Toggle(
                                i18n.t("enabled"),
                                isOn: Binding(
                                    get: { abEnabled[config.variant] ?? (config.enabled ?? true) },
                                    set: { abEnabled[config.variant] = $0 }
                                )
                            )
                            Button(i18n.t("apply")) { Task { await applyAbConfig(config) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("engagement_scores")).font(.headline)
                    HStack {
                        TextField(i18n.t("search_user"), text: $scoreQuery)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("load")) { Task { await loadEngagementScores() } }
                            .buttonStyle(.bordered)
                    }
                    HStack {
                        Picker(i18n.t("status"), selection: $scoreStatus) {
                            Text(i18n.t("all")).tag("all")
                            Text(i18n.t("active")).tag("active")
                            Text(i18n.t("pending")).tag("pending")
                            Text(i18n.t("banned")).tag("banned")
                        }
                        .pickerStyle(.menu)
                        TextField(i18n.t("variant"), text: $scoreVariant)
                            .textInputAutocapitalization(.characters)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            if !engagementScores.isEmpty {
                ForEach(engagementScores.prefix(30)) { row in
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("@\(row.kadi ?? "-")").font(.headline)
                                Text("\(row.isim ?? "") \(row.soyisim ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(SDALTheme.muted)
                            }
                            Spacer()
                            Text(String(format: "%.2f", row.score ?? 0))
                                .font(.headline)
                        }
                    }
                }
            }
        }
    }

    private var emailOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(i18n.t("email_center")).font(.headline)
                        Spacer()
                        Button(i18n.t("refresh")) { Task { await loadEmailData() } }
                            .buttonStyle(.bordered)
                    }
                    Picker(i18n.t("send_mode"), selection: $emailSendMode) {
                        Text(i18n.t("single")).tag(AdminEmailSendMode.single)
                        Text(i18n.t("bulk")).tag(AdminEmailSendMode.bulk)
                    }
                    .pickerStyle(.segmented)
                    TextField(i18n.t("from"), text: $emailFrom)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textFieldStyle(.roundedBorder)
                    if emailSendMode == .single {
                        TextField(i18n.t("to"), text: $emailTo)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Picker(i18n.t("category"), selection: $selectedEmailCategoryId) {
                            Text(i18n.t("select_category")).tag(Int?.none)
                            ForEach(emailCategories) { item in
                                Text("\(item.ad ?? "-") [\(item.tur ?? "-")]").tag(Int?.some(item.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    TextField(i18n.t("subject"), text: $emailSubject)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("html_body"), text: $emailBody, axis: .vertical)
                        .lineLimit(4...10)
                        .textFieldStyle(.roundedBorder)
                    Button(emailSendMode == .single ? i18n.t("send_email") : i18n.t("send_bulk")) {
                        Task { await sendEmailAction() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(emailFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || emailSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || emailBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(editingEmailCategoryId == nil ? i18n.t("create_category") : "\(i18n.t("edit")) \(i18n.t("category")) #\(editingEmailCategoryId ?? 0)")
                        .font(.headline)
                    TextField(i18n.t("name"), text: $newEmailCategoryName)
                        .textFieldStyle(.roundedBorder)
                    Picker(i18n.t("type"), selection: $newEmailCategoryType) {
                        Text(i18n.t("all")).tag("all")
                        Text(i18n.t("active")).tag("active")
                        Text(i18n.t("pending")).tag("pending")
                        Text(i18n.t("banned")).tag("banned")
                        Text(i18n.t("year")).tag("year")
                        Text(i18n.t("custom")).tag("custom")
                    }
                    .pickerStyle(.menu)
                    TextField(i18n.t("value"), text: $newEmailCategoryValue)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("description"), text: $newEmailCategoryDescription)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button(editingEmailCategoryId == nil ? i18n.t("create") : i18n.t("save")) {
                            Task { await saveEmailCategoryAction() }
                        }
                        .buttonStyle(.borderedProminent)
                        if editingEmailCategoryId != nil {
                            Button(i18n.t("cancel")) { clearCategoryDraft() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if emailCategories.isEmpty {
                GlassCard { Text(i18n.t("no_email_categories")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(emailCategories) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.ad ?? "-").font(.headline)
                            Text("\(i18n.t("type")): \(item.tur ?? "-") • \(i18n.t("value")): \(item.deger ?? "-")")
                                .font(.caption)
                                .foregroundStyle(SDALTheme.muted)
                            if let aciklama = item.aciklama, !aciklama.isEmpty {
                                Text(aciklama)
                                    .font(.caption)
                                    .foregroundStyle(SDALTheme.muted)
                            }
                            HStack {
                                Button(i18n.t("edit")) { loadCategoryDraft(item) }
                                    .buttonStyle(.bordered)
                                Button(i18n.t("delete"), role: .destructive) {
                                    Task { await deleteEmailCategory(item.id) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(editingEmailTemplateId == nil ? i18n.t("create_template") : "\(i18n.t("edit")) \(i18n.t("template")) #\(editingEmailTemplateId ?? 0)")
                        .font(.headline)
                    TextField(i18n.t("template_name"), text: $newEmailTemplateName)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("subject"), text: $newEmailTemplateSubject)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("html"), text: $newEmailTemplateBody, axis: .vertical)
                        .lineLimit(4...10)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button(editingEmailTemplateId == nil ? i18n.t("create") : i18n.t("save")) {
                            Task { await saveEmailTemplateAction() }
                        }
                        .buttonStyle(.borderedProminent)
                        if editingEmailTemplateId != nil {
                            Button(i18n.t("cancel")) { clearTemplateDraft() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if emailTemplates.isEmpty {
                GlassCard { Text(i18n.t("no_email_templates")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(emailTemplates) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.ad ?? "-").font(.headline)
                            Text(item.konu ?? "-")
                                .font(.subheadline)
                                .foregroundStyle(SDALTheme.muted)
                            HStack {
                                Button(i18n.t("use")) { applyTemplateToComposer(item) }
                                    .buttonStyle(.bordered)
                                Button(i18n.t("edit")) { loadTemplateDraft(item) }
                                    .buttonStyle(.bordered)
                                Button(i18n.t("delete"), role: .destructive) {
                                    Task { await deleteEmailTemplate(item.id) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
    }

    private var dbOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(i18n.t("database_tools")).font(.headline)
                        Spacer()
                        Button(i18n.t("refresh")) { Task { await loadDbData() } }
                            .buttonStyle(.bordered)
                    }
                    HStack {
                        TextField(i18n.t("backup_label"), text: $backupLabel)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("create_backup")) {
                            Task { await createBackupAction() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    HStack {
                        Button(i18n.t("restore_from_file"), role: .destructive) {
                            showRestorePicker = true
                        }
                        .buttonStyle(.bordered)
                        if let selectedRestoreFileName {
                            Text("\(i18n.t("last_restore")): \(selectedRestoreFileName)")
                                .font(.caption)
                                .foregroundStyle(SDALTheme.muted)
                        }
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("tables")).font(.headline)
                    if dbTables.isEmpty {
                        Text(i18n.t("no_tables_loaded"))
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    } else {
                        Picker(i18n.t("table"), selection: $selectedDbTableName) {
                            Text(i18n.t("select_table")).tag(String?.none)
                            ForEach(dbTables) { table in
                                Text("\(table.name ?? "-") (\(table.rowCount ?? 0))").tag(String?.some(table.name ?? ""))
                            }
                        }
                        .pickerStyle(.menu)
                        if let selectedDbTableName {
                            Button("\(i18n.t("load")) \(selectedDbTableName)") {
                                Task { await loadDbTable(name: selectedDbTableName) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if !dbTableColumns.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(i18n.t("columns")).font(.headline)
                        ForEach(dbTableColumns) { column in
                            Text("\(column.name ?? "-") • \(column.type ?? "-") • pk:\(column.pk ?? 0)")
                                .font(.caption)
                                .foregroundStyle(SDALTheme.muted)
                        }
                    }
                }
            }

            if !dbTableRows.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(i18n.t("rows_preview")).font(.headline)
                        ScrollView([.horizontal, .vertical]) {
                            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                                Section {
                                    ForEach(Array(dbTableRows.prefix(20).enumerated()), id: \.offset) { index, row in
                                        HStack(spacing: 0) {
                                            ForEach(dbPreviewColumns, id: \.self) { column in
                                                Text((row[column]?.description ?? "null").trimmingCharacters(in: .whitespacesAndNewlines))
                                                    .font(.caption2)
                                                    .foregroundStyle(SDALTheme.ink)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 7)
                                                    .frame(width: 160, alignment: .leading)
                                                    .overlay(alignment: .trailing) {
                                                        Rectangle()
                                                            .fill(SDALTheme.line.opacity(0.65))
                                                            .frame(width: 1)
                                                    }
                                            }
                                        }
                                        .background(index.isMultiple(of: 2) ? SDALTheme.cardAlt.opacity(0.35) : Color.clear)
                                        .overlay(alignment: .bottom) {
                                            Rectangle()
                                                .fill(SDALTheme.line.opacity(0.55))
                                                .frame(height: 1)
                                        }
                                    }
                                } header: {
                                    HStack(spacing: 0) {
                                        ForEach(dbPreviewColumns, id: \.self) { column in
                                            Text(column)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(SDALTheme.ink)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 8)
                                                .frame(width: 160, alignment: .leading)
                                                .overlay(alignment: .trailing) {
                                                    Rectangle()
                                                        .fill(SDALTheme.line.opacity(0.8))
                                                        .frame(width: 1)
                                                }
                                        }
                                    }
                                    .background(SDALTheme.softPanel)
                                }
                            }
                        }
                        .frame(minHeight: 220, maxHeight: 380)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("backups")).font(.headline)
                    if dbBackups.isEmpty {
                        Text(i18n.t("no_backups"))
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    } else {
                        ForEach(dbBackups) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "-")
                                        .font(.subheadline)
                                    Text("\(i18n.t("size")): \(formatBytes(item.size ?? 0)) • \(item.mtime ?? "-")")
                                        .font(.caption2)
                                        .foregroundStyle(SDALTheme.muted)
                                }
                                Spacer()
                                if let name = item.name, !name.isEmpty {
                                    Button(i18n.t("download")) {
                                        Task { await downloadBackup(name: name) }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var pagesOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(selectedPageIdForEdit == nil ? i18n.t("create_page") : "\(i18n.t("edit")) \(i18n.t("pages")) #\(selectedPageIdForEdit ?? 0)")
                            .font(.headline)
                        Spacer()
                        Button(i18n.t("refresh")) { Task { await loadPages() } }
                            .buttonStyle(.bordered)
                    }
                    TextField(i18n.t("page_name"), text: $pageName)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("page_url"), text: $pageUrl)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("parent_id"), text: $pageParentId)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("image"), text: $pageImage)
                        .textFieldStyle(.roundedBorder)
                    Toggle(i18n.t("menu_visible"), isOn: $pageMenuVisible)
                    Toggle(i18n.t("redirect"), isOn: $pageRedirect)
                    Toggle(i18n.t("feature_flag"), isOn: $pageMFeature)
                    HStack {
                        Button(selectedPageIdForEdit == nil ? i18n.t("create") : i18n.t("save")) {
                            Task { await savePageAction() }
                        }
                        .buttonStyle(.borderedProminent)
                        if selectedPageIdForEdit != nil {
                            Button(i18n.t("cancel")) { clearPageDraft() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            if adminPages.isEmpty {
                GlassCard { Text(i18n.t("no_pages")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(adminPages) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.sayfaismi ?? "-").font(.headline)
                            Text(item.sayfaurl ?? "-")
                                .font(.caption)
                                .foregroundStyle(SDALTheme.muted)
                            HStack {
                                Text(String(format: i18n.t("id_parent_format"), item.id, item.babaid ?? 0))
                                    .font(.caption2)
                                    .foregroundStyle(SDALTheme.muted)
                                Spacer()
                                Button(i18n.t("edit")) { loadPageDraft(item) }
                                    .buttonStyle(.bordered)
                                Button(i18n.t("delete"), role: .destructive) {
                                    Task { await deletePageAction(item.id) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
    }

    private var logsOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("logs")).font(.headline)
                    HStack {
                        Picker(i18n.t("type"), selection: $logType) {
                            Text(i18n.t("error")).tag("error")
                            Text(i18n.t("page")).tag("page")
                            Text(i18n.t("member")).tag("member")
                            Text(i18n.t("app")).tag("app")
                        }
                        .pickerStyle(.menu)
                        Button(i18n.t("load_files")) { Task { await loadLogs() } }
                            .buttonStyle(.bordered)
                    }
                    HStack {
                        TextField(i18n.t("from_date"), text: $logFrom)
                            .textFieldStyle(.roundedBorder)
                        TextField(i18n.t("to_date"), text: $logTo)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        TextField(i18n.t("search"), text: $logQuery)
                            .textFieldStyle(.roundedBorder)
                        TextField(i18n.t("activity"), text: $logActivity)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        TextField(i18n.t("user_id"), text: $logUserId)
                            .textFieldStyle(.roundedBorder)
                        TextField(i18n.t("limit"), text: $logLimit)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    if let selectedLogFile {
                        HStack {
                            Text("\(i18n.t("file")): \(selectedLogFile)")
                                .font(.caption)
                                .foregroundStyle(SDALTheme.muted)
                            Spacer()
                            Text(String(format: i18n.t("matched_format"), logMatched, logTotal))
                                .font(.caption2)
                                .foregroundStyle(SDALTheme.muted)
                        }
                        HStack {
                            Button(i18n.t("apply_filters")) { Task { await openLogFile(selectedLogFile, offset: 0) } }
                                .buttonStyle(.bordered)
                            Button(i18n.t("prev")) { Task { await paginateLog(direction: -1) } }
                                .buttonStyle(.bordered)
                                .disabled(logOffset <= 0)
                            Button(i18n.t("next")) { Task { await paginateLog(direction: 1) } }
                                .buttonStyle(.bordered)
                                .disabled(logOffset + (Int(logLimit) ?? 500) >= logMatched)
                        }
                    }
                }
            }
            if !logFiles.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(i18n.t("files")).font(.headline)
                        ForEach(logFiles) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "-")
                                        .font(.subheadline)
                                    Text("\(i18n.t("size")): \(formatBytes(item.size ?? 0)) • \(item.mtime ?? "-")")
                                        .font(.caption2)
                                        .foregroundStyle(SDALTheme.muted)
                                }
                                Spacer()
                                if let name = item.name, !name.isEmpty {
                                    Button(i18n.t("open")) { Task { await openLogFile(name, offset: 0) } }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
            if !logContent.isEmpty {
                GlassCard {
                    ScrollView {
                        Text(logContent)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 220)
                }
            }
        }
    }

    private var albumOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(selectedAlbumCategoryIdForEdit == nil ? i18n.t("create_album_category") : "\(i18n.t("edit")) \(i18n.t("category")) #\(selectedAlbumCategoryIdForEdit ?? 0)")
                            .font(.headline)
                        Spacer()
                        Button(i18n.t("refresh")) { Task { await loadAlbumAdmin() } }
                            .buttonStyle(.bordered)
                    }
                    TextField(i18n.t("category"), text: $albumCategoryName)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("description"), text: $albumCategoryDescription)
                        .textFieldStyle(.roundedBorder)
                    Toggle(i18n.t("active"), isOn: $albumCategoryActive)
                    HStack {
                        Button(selectedAlbumCategoryIdForEdit == nil ? i18n.t("create") : i18n.t("save")) {
                            Task { await saveAlbumCategoryAction() }
                        }
                        .buttonStyle(.borderedProminent)
                        if selectedAlbumCategoryIdForEdit != nil {
                            Button(i18n.t("cancel")) { clearAlbumCategoryDraft() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            if !albumCategories.isEmpty {
                ForEach(albumCategories) { item in
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.kategori ?? "-").font(.headline)
                                let count = albumCategoryCounts[String(item.id)]
                                Text(String(format: i18n.t("active_pending_format"), count?.activeCount ?? 0, count?.inactiveCount ?? 0))
                                    .font(.caption)
                                    .foregroundStyle(SDALTheme.muted)
                            }
                            Spacer()
                            Button(i18n.t("edit")) { loadAlbumCategoryDraft(item) }
                                .buttonStyle(.bordered)
                            Button(i18n.t("delete"), role: .destructive) { Task { await deleteAlbumCategoryAction(item.id) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("album_photos")).font(.headline)
                    HStack {
                        Picker(i18n.t("filter"), selection: $albumPhotoFilter) {
                            Text(i18n.t("all")).tag("")
                            Text(i18n.t("pending")).tag("onaybekleyen")
                            Text(i18n.t("by_category")).tag("kategori")
                        }
                        .pickerStyle(.menu)
                        TextField(i18n.t("category_id"), text: $albumPhotoCategoryFilter)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Picker(i18n.t("sort"), selection: $albumPhotoSort) {
                            Text(i18n.t("active_desc")).tag("aktifazalan")
                            Text(i18n.t("date_desc")).tag("tarihazalan")
                            Text(i18n.t("title_asc")).tag("baslikartan")
                            Text(i18n.t("hits_desc")).tag("hitazalan")
                        }
                        .pickerStyle(.menu)
                        Button(i18n.t("load")) { Task { await loadAlbumPhotos() } }
                            .buttonStyle(.bordered)
                    }
                    HStack {
                        Button(i18n.t("bulk_active")) { Task { await bulkAlbumPhotos(action: "aktif") } }
                            .buttonStyle(.bordered)
                            .disabled(selectedAlbumPhotoIds.isEmpty)
                        Button(i18n.t("bulk_inactive")) { Task { await bulkAlbumPhotos(action: "deaktiv") } }
                            .buttonStyle(.bordered)
                            .disabled(selectedAlbumPhotoIds.isEmpty)
                        Button(i18n.t("bulk_delete"), role: .destructive) { Task { await bulkAlbumPhotos(action: "sil") } }
                            .buttonStyle(.bordered)
                            .disabled(selectedAlbumPhotoIds.isEmpty)
                    }
                }
            }
            if !albumPhotos.isEmpty {
                ForEach(albumPhotos) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { selectedAlbumPhotoIds.contains(item.id) },
                                        set: { selected in
                                            if selected {
                                                selectedAlbumPhotoIds.insert(item.id)
                                            } else {
                                                selectedAlbumPhotoIds.remove(item.id)
                                            }
                                        }
                                    )
                                )
                                .labelsHidden()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.baslik ?? "(no title)")
                                        .font(.headline)
                                    Text(String(format: i18n.t("by_comments_format"), albumUserMap[String(item.ekleyenid ?? 0)] ?? "#\(item.ekleyenid ?? 0)", albumCommentCounts[String(item.id)] ?? 0))
                                        .font(.caption2)
                                        .foregroundStyle(SDALTheme.muted)
                                }
                                Spacer()
                                Button(i18n.t("comments")) { Task { await showAlbumPhotoComments(item) } }
                                    .buttonStyle(.bordered)
                                Button(i18n.t("delete"), role: .destructive) { Task { await deleteAlbumPhoto(item.id) } }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
    }

    private var tournamentOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                HStack {
                    Text(i18n.t("tournament_teams")).font(.headline)
                    Spacer()
                    Button(i18n.t("refresh")) { Task { await loadTournamentTeams() } }
                        .buttonStyle(.bordered)
                }
            }
            if tournamentTeams.isEmpty {
                GlassCard { Text(i18n.t("no_teams")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(tournamentTeams) { team in
                    GlassCard {
                        HStack {
                            Text(team.tisim ?? team.takimadi ?? team.isim ?? "\(i18n.t("team")) #\(team.id)")
                            Spacer()
                            Button(i18n.t("delete"), role: .destructive) { Task { await deleteTournamentTeam(team.id) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private func statRow(_ title: String, _ value: Int?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.map(String.init) ?? "-")
                .foregroundStyle(SDALTheme.muted)
        }
        .font(.subheadline)
    }

    private var dbPreviewColumns: [String] {
        let explicit = dbTableColumns.compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !explicit.isEmpty { return explicit }
        guard let first = dbTableRows.first else { return [] }
        return first.keys.sorted()
    }

    private func login() async {
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

    private func logout() async {
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

    private func refreshCurrentPanel() async {
        switch panel {
        case .overview: await loadOverview()
        case .moderation: await loadModeration()
        case .verification: await loadVerification()
        case .operations: await loadOperations()
        }
    }

    private func loadOverview() async {
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

    private func loadModeration() async {
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

    private func deleteModerationItem(_ id: Int) async {
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

    private func loadVerification() async {
        errorMessage = nil
        do {
            verificationRequests = try await api.fetchVerificationRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func decideVerification(_ id: Int, approve: Bool) async {
        errorMessage = nil
        do {
            try await api.resolveVerificationRequest(id: id, approve: approve)
            verificationRequests.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadOperations() async {
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

    private func loadUsers() async {
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

    private func openUserEditor(_ userId: Int) async {
        errorMessage = nil
        do {
            editingUser = try await api.fetchAdminUserDetail(id: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setUserVerified(_ userId: Int, verified: Bool) async {
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

    private func loadFollows() async {
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

    private func loadGroups() async {
        errorMessage = nil
        do { adminGroups = try await api.fetchAdminGroups() } catch { errorMessage = error.localizedDescription }
    }

    private func deleteGroup(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.adminDeleteGroup(id: id)
            adminGroups.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadFilters() async {
        errorMessage = nil
        do {
            adminFilters = try await api.fetchAdminFilters()
            for item in adminFilters { filterEdits[item.id] = item.kufur ?? "" }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addFilter() async {
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

    private func saveFilter(_ id: Int) async {
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

    private func deleteFilter(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminFilter(id: id)
            adminFilters.removeAll { $0.id == id }
            filterEdits[id] = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadEngagement() async {
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

    private func applyAbConfig(_ config: EngagementAbConfig) async {
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

    private func rebalanceAB() async {
        errorMessage = nil
        do {
            try await api.rebalanceEngagementAB(keepAssignments: false)
            await loadEngagement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadEngagementScores() async {
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

    private func recalculateScores() async {
        errorMessage = nil
        do {
            try await api.recalculateEngagementScores()
            await loadEngagement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadEmailData() async {
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

    private func sendEmailAction() async {
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

    private func saveEmailCategoryAction() async {
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

    private func deleteEmailCategory(_ id: Int) async {
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

    private func loadCategoryDraft(_ category: AdminEmailCategory) {
        editingEmailCategoryId = category.id
        newEmailCategoryName = category.ad ?? ""
        newEmailCategoryType = category.tur ?? "all"
        newEmailCategoryValue = category.deger ?? ""
        newEmailCategoryDescription = category.aciklama ?? ""
    }

    private func clearCategoryDraft() {
        editingEmailCategoryId = nil
        newEmailCategoryName = ""
        newEmailCategoryType = "all"
        newEmailCategoryValue = ""
        newEmailCategoryDescription = ""
    }

    private func saveEmailTemplateAction() async {
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

    private func deleteEmailTemplate(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminEmailTemplate(id: id)
            await loadEmailData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadTemplateDraft(_ template: AdminEmailTemplate) {
        editingEmailTemplateId = template.id
        newEmailTemplateName = template.ad ?? ""
        newEmailTemplateSubject = template.konu ?? ""
        newEmailTemplateBody = template.icerik ?? ""
    }

    private func clearTemplateDraft() {
        editingEmailTemplateId = nil
        newEmailTemplateName = ""
        newEmailTemplateSubject = ""
        newEmailTemplateBody = ""
    }

    private func applyTemplateToComposer(_ template: AdminEmailTemplate) {
        emailSubject = template.konu ?? emailSubject
        emailBody = template.icerik ?? emailBody
    }

    private func loadDbData() async {
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

    private func loadDbTable(name: String) async {
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

    private func createBackupAction() async {
        errorMessage = nil
        let label = backupLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await api.createAdminDbBackup(label: label.isEmpty ? "manual" : label)
            await loadDbData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func downloadBackup(name: String) async {
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

    private func loadPages() async {
        errorMessage = nil
        do {
            adminPages = try await api.fetchAdminPages()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func savePageAction() async {
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

    private func loadPageDraft(_ item: AdminPageItem) {
        selectedPageIdForEdit = item.id
        pageName = item.sayfaismi ?? ""
        pageUrl = item.sayfaurl ?? ""
        pageParentId = String(item.babaid ?? 0)
        pageMenuVisible = (item.menugorun ?? 0) == 1
        pageRedirect = (item.yonlendir ?? 0) == 1
        pageMFeature = (item.mozellik ?? 0) == 1
        pageImage = item.resim ?? "yok"
    }

    private func clearPageDraft() {
        selectedPageIdForEdit = nil
        pageName = ""
        pageUrl = ""
        pageParentId = "0"
        pageMenuVisible = true
        pageRedirect = false
        pageMFeature = false
        pageImage = "yok"
    }

    private func deletePageAction(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminPage(id: id)
            adminPages.removeAll { $0.id == id }
            if selectedPageIdForEdit == id { clearPageDraft() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadLogs() async {
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

    private func openLogFile(_ fileName: String, offset: Int) async {
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

    private func paginateLog(direction: Int) async {
        guard let selectedLogFile else { return }
        let step = max(Int(logLimit) ?? 500, 1)
        let nextOffset = max(logOffset + (direction * step), 0)
        await openLogFile(selectedLogFile, offset: nextOffset)
    }

    private func loadAlbumAdmin() async {
        await loadAlbumCategories()
        await loadAlbumPhotos()
    }

    private func loadAlbumCategories() async {
        errorMessage = nil
        do {
            let payload = try await api.fetchAdminAlbumCategories()
            albumCategories = payload.categories ?? []
            albumCategoryCounts = payload.counts ?? [:]
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveAlbumCategoryAction() async {
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

    private func loadAlbumCategoryDraft(_ item: AdminAlbumCategory) {
        selectedAlbumCategoryIdForEdit = item.id
        albumCategoryName = item.kategori ?? ""
        albumCategoryDescription = item.aciklama ?? ""
        albumCategoryActive = (item.aktif ?? 0) == 1
    }

    private func clearAlbumCategoryDraft() {
        selectedAlbumCategoryIdForEdit = nil
        albumCategoryName = ""
        albumCategoryDescription = ""
        albumCategoryActive = true
    }

    private func deleteAlbumCategoryAction(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminAlbumCategory(id: id)
            albumCategories.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadAlbumPhotos() async {
        errorMessage = nil
        do {
            let payload = try await api.fetchAdminAlbumPhotos(krt: albumPhotoFilter, kid: albumPhotoCategoryFilter, diz: albumPhotoSort)
            albumPhotos = payload.photos ?? []
            albumUserMap = payload.userMap ?? [:]
            albumCommentCounts = payload.commentCounts ?? [:]
            selectedAlbumPhotoIds = selectedAlbumPhotoIds.intersection(Set(albumPhotos.map(\.id)))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func bulkAlbumPhotos(action: String) async {
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

    private func deleteAlbumPhoto(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminAlbumPhoto(id: id)
            albumPhotos.removeAll { $0.id == id }
            selectedAlbumPhotoIds.remove(id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showAlbumPhotoComments(_ photo: AdminAlbumPhoto) async {
        errorMessage = nil
        do {
            selectedPhotoComments = try await api.fetchAdminAlbumPhotoComments(photoId: photo.id)
            selectedPhotoForComments = photo
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteAlbumPhotoComment(photoId: Int, commentId: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminAlbumPhotoComment(photoId: photoId, commentId: commentId)
            selectedPhotoComments.removeAll { $0.id == commentId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadTournamentTeams() async {
        errorMessage = nil
        do {
            tournamentTeams = try await api.fetchAdminTournamentTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteTournamentTeam(_ id: Int) async {
        errorMessage = nil
        do {
            try await api.deleteAdminTournamentTeam(id: id)
            tournamentTeams.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleRestoreFileSelection(_ result: Result<[URL], Error>) async {
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

    private func formatBytes(_ value: Int) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var size = Double(max(value, 0))
        var idx = 0
        while size >= 1024, idx < units.count - 1 {
            size /= 1024
            idx += 1
        }
        return String(format: "%.1f %@", size, units[idx])
    }
}

private struct StatusChip: View {
    let label: String
    let active: Bool
    let tint: Color

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? tint.opacity(0.18) : SDALTheme.softPanel)
            .foregroundStyle(active ? tint : SDALTheme.muted)
            .clipShape(Capsule())
    }
}

private struct AdminUserEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var i18n: LocalizationManager

    let user: AdminManagedUser
    let onSaved: () -> Void

    @State private var draft: AdminUserDraft
    @State private var saving = false
    @State private var error: String?

    private let api = APIClient.shared

    init(user: AdminManagedUser, onSaved: @escaping () -> Void) {
        self.user = user
        self.onSaved = onSaved
        _draft = State(initialValue: AdminUserDraft(user: user))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(i18n.t("identity")) {
                    TextField(i18n.t("username"), text: $draft.kadi)
                        .disabled(true)
                    TextField(i18n.t("first_name"), text: $draft.isim)
                    TextField(i18n.t("last_name"), text: $draft.soyisim)
                    TextField(i18n.t("email"), text: $draft.email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField(i18n.t("activation_code"), text: $draft.aktivasyon)
                    TextField(i18n.t("photo_file"), text: $draft.resim)
                        .textInputAutocapitalization(.never)
                }

                Section(i18n.t("status")) {
                    Toggle(i18n.t("active"), isOn: $draft.aktif)
                    Toggle(i18n.t("banned"), isOn: $draft.yasakli)
                    Toggle(i18n.t("first_login_done"), isOn: $draft.ilkBilgiTamam)
                    Toggle(i18n.t("mail_hidden"), isOn: $draft.mailKapali)
                    Toggle(i18n.t("admin"), isOn: $draft.admin)
                    TextField(i18n.t("hit"), value: $draft.hit, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                }

                Section(i18n.t("profile")) {
                    TextField(i18n.t("city"), text: $draft.sehir)
                    TextField(i18n.t("job"), text: $draft.meslek)
                    TextField(i18n.t("university"), text: $draft.universite)
                    TextField(i18n.t("graduation_year"), text: $draft.mezuniyetyili)
                    TextField(i18n.t("website"), text: $draft.websitesi)
                        .textInputAutocapitalization(.never)
                    TextField(i18n.t("signature"), text: $draft.imza, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section(i18n.t("birth_date")) {
                    TextField(i18n.t("day"), text: $draft.dogumgun)
                        .keyboardType(.numberPad)
                    TextField(i18n.t("month"), text: $draft.dogumay)
                        .keyboardType(.numberPad)
                    TextField(i18n.t("year"), text: $draft.dogumyil)
                        .keyboardType(.numberPad)
                }

                Section(i18n.t("password")) {
                    SecureField(i18n.t("admin_edit_password_hint"), text: $draft.sifre)
                }

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("\(i18n.t("edit")) @\(user.kadi ?? "")")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(i18n.t("close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(saving ? i18n.t("saving") : i18n.t("save")) {
                        Task { await save() }
                    }
                    .disabled(saving)
                }
            }
        }
    }

    private func save() async {
        saving = true
        error = nil
        defer { saving = false }
        do {
            try await api.updateAdminUser(id: user.id, body: draft.toUpdateBody())
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct AdminUserDraft {
    var kadi: String
    var isim: String
    var soyisim: String
    var email: String
    var aktivasyon: String
    var resim: String
    var aktif: Bool
    var yasakli: Bool
    var ilkBilgiTamam: Bool
    var mailKapali: Bool
    var admin: Bool
    var hit: Int
    var sehir: String
    var meslek: String
    var universite: String
    var mezuniyetyili: String
    var websitesi: String
    var imza: String
    var dogumgun: String
    var dogumay: String
    var dogumyil: String
    var sifre: String

    init(user: AdminManagedUser) {
        kadi = user.kadi ?? ""
        isim = user.isim ?? ""
        soyisim = user.soyisim ?? ""
        email = user.email ?? ""
        aktivasyon = user.aktivasyon ?? ""
        resim = user.resim ?? "yok"
        aktif = (user.aktiv ?? 0) == 1
        yasakli = (user.yasak ?? 0) == 1
        ilkBilgiTamam = (user.ilkbd ?? 0) == 1
        mailKapali = (user.mailkapali ?? 0) == 1
        admin = (user.admin ?? 0) == 1
        hit = user.hit ?? 0
        sehir = user.sehir ?? ""
        meslek = user.meslek ?? ""
        universite = user.universite ?? ""
        mezuniyetyili = user.mezuniyetyili ?? ""
        websitesi = user.websitesi ?? ""
        imza = user.imza ?? ""
        dogumgun = user.dogumgun ?? ""
        dogumay = user.dogumay ?? ""
        dogumyil = user.dogumyil ?? ""
        sifre = user.sifre ?? ""
    }

    func toUpdateBody() -> AdminManagedUserUpdateBody {
        AdminManagedUserUpdateBody(
            isim: isim.trimmingCharacters(in: .whitespacesAndNewlines),
            soyisim: soyisim.trimmingCharacters(in: .whitespacesAndNewlines),
            aktivasyon: aktivasyon.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            aktiv: aktif ? 1 : 0,
            yasak: yasakli ? 1 : 0,
            ilkbd: ilkBilgiTamam ? 1 : 0,
            websitesi: websitesi.trimmingCharacters(in: .whitespacesAndNewlines),
            imza: imza,
            meslek: meslek.trimmingCharacters(in: .whitespacesAndNewlines),
            sehir: sehir.trimmingCharacters(in: .whitespacesAndNewlines),
            mailkapali: mailKapali ? 1 : 0,
            hit: hit,
            mezuniyetyili: mezuniyetyili.trimmingCharacters(in: .whitespacesAndNewlines),
            universite: universite.trimmingCharacters(in: .whitespacesAndNewlines),
            dogumgun: dogumgun.trimmingCharacters(in: .whitespacesAndNewlines),
            dogumay: dogumay.trimmingCharacters(in: .whitespacesAndNewlines),
            dogumyil: dogumyil.trimmingCharacters(in: .whitespacesAndNewlines),
            admin: admin ? 1 : 0,
            resim: resim.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "yok" : resim.trimmingCharacters(in: .whitespacesAndNewlines),
            sifre: sifre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sifre
        )
    }
}
