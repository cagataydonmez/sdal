import SwiftUI
import UniformTypeIdentifiers

struct BackupExportDocument: FileDocument {
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

enum AdminPanel: String, CaseIterable, Identifiable {
    case overview
    case moderation
    case verification
    case operations

    var id: String { rawValue }
}

enum ModerationQueue: String, CaseIterable, Identifiable {
    case posts
    case stories
    case messages
    case chat

    var id: String { rawValue }
}

enum AdminOpsTab: String, CaseIterable, Identifiable {
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

enum AdminEmailSendMode: String, CaseIterable, Identifiable {
    case single
    case bulk

    var id: String { rawValue }
}

struct AdminView: View {
    @EnvironmentObject var i18n: LocalizationManager
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State var adminUser: AdminUser?
    @State var password = ""
    @State var isLoading = false
    @State var errorMessage: String?

    @State var panel: AdminPanel = .overview
    @State var queue: ModerationQueue = .posts
    @State var opsTab: AdminOpsTab = .users

    @State var stats: AdminStats?
    @State var live: AdminLiveSnapshot?
    @State var moderationItems: [AdminModerationItem] = []
    @State var verificationRequests: [VerificationRequestItem] = []

    @State var managedUsers: [AdminManagedUser] = []
    @State var managedUsersMeta: AdminUsersMeta?
    @State var userFilter = "all"
    @State var userSort = "engagement_desc"
    @State var userQuery = ""
    @State var userWithPhoto = false
    @State var userVerifiedOnly = false
    @State var userOnlineOnly = false
    @State var userAdminOnly = false
    @State var editingUser: AdminManagedUser?

    @State var followUserIdText = ""
    @State var followTarget: AdminFollowUser?
    @State var followItems: [AdminFollowItem] = []

    @State var adminGroups: [AdminGroupItem] = []

    @State var adminFilters: [AdminFilterItem] = []
    @State var newFilterWord = ""
    @State var filterEdits: [Int: String] = [:]

    @State var abConfigs: [EngagementAbConfig] = []
    @State var abPerformance: [EngagementAbPerformance] = []
    @State var abRecommendations: [EngagementAbRecommendation] = []
    @State var abTraffic: [String: Double] = [:]
    @State var abEnabled: [String: Bool] = [:]
    @State var engagementScores: [EngagementScoreItem] = []
    @State var scoreQuery = ""
    @State var scoreStatus = "all"
    @State var scoreVariant = ""

    @State var emailCategories: [AdminEmailCategory] = []
    @State var emailTemplates: [AdminEmailTemplate] = []
    @State var selectedEmailCategoryId: Int?
    @State var emailFrom = ""
    @State var emailTo = ""
    @State var emailSubject = ""
    @State var emailBody = ""
    @State var emailSendMode: AdminEmailSendMode = .single
    @State var newEmailCategoryName = ""
    @State var newEmailCategoryType = "all"
    @State var newEmailCategoryValue = ""
    @State var newEmailCategoryDescription = ""
    @State var newEmailTemplateName = ""
    @State var newEmailTemplateSubject = ""
    @State var newEmailTemplateBody = ""
    @State var editingEmailCategoryId: Int?
    @State var editingEmailTemplateId: Int?
    @State var dbTables: [AdminDbTableInfo] = []
    @State var selectedDbTableName: String?
    @State var dbTableColumns: [AdminDbColumn] = []
    @State var dbTableRows: [[String: JSONValue]] = []
    @State var dbBackups: [AdminDbBackupItem] = []
    @State var backupLabel = "manual"
    @State var showRestorePicker = false
    @State var selectedRestoreFileName: String?
    @State var backupExportDocument = BackupExportDocument()
    @State var backupExportFileName = "backup.db"
    @State var showBackupExporter = false
    @State var adminPages: [AdminPageItem] = []
    @State var pageName = ""
    @State var pageUrl = ""
    @State var pageParentId = "0"
    @State var pageMenuVisible = true
    @State var pageRedirect = false
    @State var pageMFeature = false
    @State var pageImage = "yok"
    @State var selectedPageIdForEdit: Int?
    @State var logType = "error"
    @State var logFiles: [AdminLogFile] = []
    @State var selectedLogFile: String?
    @State var logContent = ""
    @State var logFrom = ""
    @State var logTo = ""
    @State var logQuery = ""
    @State var logActivity = ""
    @State var logUserId = ""
    @State var logLimit = "500"
    @State var logOffset = 0
    @State var logTotal = 0
    @State var logMatched = 0
    @State var albumCategories: [AdminAlbumCategory] = []
    @State var albumCategoryCounts: [String: AdminAlbumCategoryCount] = [:]
    @State var albumCategoryName = ""
    @State var albumCategoryDescription = ""
    @State var albumCategoryActive = true
    @State var selectedAlbumCategoryIdForEdit: Int?
    @State var albumPhotos: [AdminAlbumPhoto] = []
    @State var albumUserMap: [String: String] = [:]
    @State var albumCommentCounts: [String: Int] = [:]
    @State var albumPhotoFilter = ""
    @State var albumPhotoCategoryFilter = ""
    @State var albumPhotoSort = "aktifazalan"
    @State var selectedAlbumPhotoIds: Set<Int> = []
    @State var selectedPhotoForComments: AdminAlbumPhoto?
    @State var selectedPhotoComments: [AdminAlbumPhotoComment] = []
    @State var tournamentTeams: [AdminTournamentTeam] = []
    @State var showNavDrawer = false

    let api = APIClient.shared

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
}
