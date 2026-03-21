import SwiftUI
import PhotosUI
import UIKit

struct GroupsHubView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let initialGroupId: Int?

    @State private var items: [GroupItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showCreate = false
    @State private var selectedGroupId: Int?

    private let api = APIClient.shared

    init(initialGroupId: Int? = nil) {
        self.initialGroupId = initialGroupId
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading && items.isEmpty {
                    ProgressView(i18n.t("loading"))
                } else if let error, items.isEmpty {
                    ScreenErrorView(message: error) { Task { await load() } }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            hubHeader
                            ForEach(items) { g in
                                NavigationLink {
                                    GroupDetailScreen(groupId: g.id)
                                } label: {
                                    GlassCard {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(g.name ?? "-")
                                                .font(.title3.weight(.bold))
                                                .fontDesign(.rounded)
                                            Text(g.description ?? "")
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                                .lineLimit(2)
                                            HStack(spacing: 6) {
                                                Text("\(g.members ?? 0) uye")
                                                    .font(.subheadline)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(SDALTheme.softPanel)
                                                    .clipShape(Capsule())
                                                Text(g.membershipStatus ?? "none")
                                                    .font(.subheadline)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(SDALTheme.softPanel)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button(g.joined == true ? i18n.t("leave") : i18n.t("join")) {
                                        SDALHaptics.tap(.light)
                                        Task { await joinLeave(g.id) }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle(i18n.t("groups"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(i18n.t("close")) {
                        SDALHaptics.tap(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("create")) {
                        SDALHaptics.tap(.medium)
                        showCreate = true
                    }
                }
            }
            .task { if items.isEmpty { await load() } }
            .task {
                if selectedGroupId == nil {
                    selectedGroupId = initialGroupId
                }
            }
            .sheet(isPresented: $showCreate) {
                GroupCreateSheet(onDone: {
                    showCreate = false
                    Task { await load() }
                })
            }
            .navigationDestination(item: $selectedGroupId) { groupId in
                GroupDetailScreen(groupId: groupId)
            }
        }
    }

    private var hubHeader: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "person.3.sequence.fill")
                    .font(.title2.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(SDALTheme.secondary)
                VStack(alignment: .leading, spacing: 6) {
                    Text(i18n.t("groups"))
                        .font(.title2.weight(.bold))
                        .fontDesign(.rounded)
                    Text("Private and public alumni circles with invites, roles, posts, and shared updates.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do { items = try await api.fetchGroups() } catch { self.error = error.localizedDescription }
    }

    private func joinLeave(_ id: Int) async {
        do {
            try await api.joinOrLeaveGroup(id: id)
            SDALHaptics.success()
            await load()
        } catch { self.error = error.localizedDescription }
    }
}

struct GroupCreateSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let onDone: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField(i18n.t("title"), text: $name)
                TextField(i18n.t("description"), text: $description, axis: .vertical)
                if let error { Text(error).foregroundStyle(.red) }
            }
            .fontDesign(.rounded)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(i18n.t("close")) {
                        SDALHaptics.tap(.light)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("create")) {
                        SDALHaptics.tap(.medium)
                        Task { await save() }
                    }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() async {
        do {
            try await api.createGroup(name: name, description: description)
            SDALHaptics.success()
            onDone()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct GroupDetailScreen: View {
    @EnvironmentObject private var i18n: LocalizationManager
    let groupId: Int

    @State private var detail: GroupDetailEnvelope?
    @State private var text = ""
    @State private var postImageItem: PhotosPickerItem?
    @State private var postImageData: Data?
    @State private var showPostCamera = false
    @State private var coverImageItem: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var showCoverCamera = false
    @State private var eventTitle = ""
    @State private var eventDescription = ""
    @State private var announcementTitle = ""
    @State private var announcementBody = ""
    @State private var visibility = "public"
    @State private var showContactHint = false
    @State private var inviteUserIds = ""
    @State private var joinRequests: [GroupJoinRequestItem] = []
    @State private var pendingInvites: [GroupInviteItem] = []
    @State private var groupEventsFallback: [EventItem] = []
    @State private var groupAnnouncementsFallback: [AnnouncementItem] = []
    @State private var error: String?

    private let api = APIClient.shared
    private var isManager: Bool {
        let role = detail?.myRole?.lowercased()
        return role == "owner" || role == "moderator" || role == "admin"
    }

    var body: some View {
        let coverPickerLabel = coverImageData == nil ? "Choose Cover" : i18n.t("change_photo")
        let postPickerLabel = postImageData == nil ? i18n.t("add_photo") : i18n.t("change_photo")
        ScrollView {
            VStack(spacing: 14) {
                if let group = detail?.group {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            if let cover = group.coverImage,
                               let url = AppConfig.absoluteURL(path: cover) {
                                ZStack(alignment: .bottomLeading) {
                                    CachedRemoteImage(
                                        url: url,
                                        targetSize: CGSize(width: UIScreen.main.bounds.width - 32, height: 150)
                                    ) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        SDALTheme.softPanel
                                    }
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    LinearGradient(
                                        colors: [Color.clear, Color.black.opacity(0.45)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                    Text(group.visibility ?? "group")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.35), in: Capsule())
                                        .padding(10)
                                }
                            }
                            Text(group.name ?? "Group")
                                .font(.title2.weight(.bold))
                                .fontDesign(.rounded)
                            Text(group.description ?? "")
                                .font(.subheadline)
                            HStack {
                                Text("Status: \(detail?.membershipStatus ?? group.membershipStatus ?? "none")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button((group.joined == true) ? "Leave" : "Join") {
                                    SDALHaptics.tap(.light)
                                    Task { await joinLeave() }
                                }
                                .buttonStyle(PolishedGlassButtonStyle(emphasized: true))
                            }
                            if group.invited == true {
                                HStack {
                                    Button("Accept Invite") {
                                        SDALHaptics.tap(.light)
                                        Task { await respondInvite("accept") }
                                    }
                                    .buttonStyle(PolishedGlassButtonStyle())
                                    Button("Reject Invite") {
                                        SDALHaptics.tap(.light)
                                        Task { await respondInvite("reject") }
                                    }
                                    .buttonStyle(PolishedGlassButtonStyle())
                                }
                            }
                            Text("Visibility: \(visibility)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if isManager {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Group Settings", systemImage: "slider.horizontal.3")
                                .font(.title3.weight(.bold))
                                .fontDesign(.rounded)
                                .symbolRenderingMode(.hierarchical)
                            Text("Visibility")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                Button("Public") {
                                    SDALHaptics.tap(.light)
                                    visibility = "public"
                                }
                                    .buttonStyle(FeedScopeChipButtonStyle(active: visibility == "public"))
                                Button("Members Only") {
                                    SDALHaptics.tap(.light)
                                    visibility = "members_only"
                                }
                                    .buttonStyle(FeedScopeChipButtonStyle(active: visibility == "members_only"))
                            }
                            Toggle("Show contact hint", isOn: $showContactHint)
                            Button("Save Settings") {
                                SDALHaptics.tap(.medium)
                                Task { await saveSettings() }
                            }
                                .buttonStyle(PolishedGlassButtonStyle(emphasized: true))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Cover Photo", systemImage: "photo.stack")
                                .font(.title3.weight(.bold))
                                .fontDesign(.rounded)
                                .symbolRenderingMode(.hierarchical)
                            PhotosPicker(selection: $coverImageItem, matching: .images, photoLibrary: .shared()) {
                                Label(coverPickerLabel, systemImage: "photo")
                            }
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    SDALHaptics.tap(.light)
                                    showCoverCamera = true
                                } label: {
                                    Label(i18n.t("camera"), systemImage: "camera")
                                }
                            }
                            Button("Upload Cover") {
                                SDALHaptics.tap(.medium)
                                Task { await uploadCover() }
                            }
                                .buttonStyle(PolishedGlassButtonStyle())
                                .disabled(coverImageData == nil)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("New Group Post", systemImage: "square.and.pencil")
                            .font(.title3.weight(.bold))
                            .fontDesign(.rounded)
                            .symbolRenderingMode(.hierarchical)
                        TextField("Write something...", text: $text, axis: .vertical)
                            .lineLimit(2...5)
                            .textFieldStyle(.roundedBorder)
                        PhotosPicker(selection: $postImageItem, matching: .images, photoLibrary: .shared()) {
                            Label(postPickerLabel, systemImage: "photo")
                        }
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                SDALHaptics.tap(.light)
                                showPostCamera = true
                            } label: {
                                Label(i18n.t("camera"), systemImage: "camera")
                            }
                        }
                        Button("Share") {
                            SDALHaptics.tap(.medium)
                            Task { await createPost() }
                        }
                            .buttonStyle(PolishedGlassButtonStyle(emphasized: true))
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && postImageData == nil)
                    }
                }

                if let posts = detail?.posts {
                    ForEach(posts) { p in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("@\(p.author?.kadi ?? "user")").font(.caption.bold())
                                Text(p.content ?? "")
                            }
                        }
                    }
                }

                if isManager {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Join Requests", systemImage: "person.badge.plus")
                                .font(.title3.weight(.bold))
                                .fontDesign(.rounded)
                                .symbolRenderingMode(.hierarchical)
                            if joinRequests.isEmpty {
                                Text("No pending requests").foregroundStyle(.secondary)
                            }
                            ForEach(joinRequests) { r in
                                HStack {
                                    Text("@\(r.kadi ?? "user")")
                                    Spacer()
                                    Button("Approve") {
                                        SDALHaptics.tap(.light)
                                        Task { await decideJoinRequest(r.id, action: "approve") }
                                    }
                                    .buttonStyle(PolishedGlassButtonStyle())
                                    Button("Reject") {
                                        SDALHaptics.tap(.light)
                                        Task { await decideJoinRequest(r.id, action: "reject") }
                                    }
                                    .buttonStyle(PolishedGlassButtonStyle())
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Invite Members", systemImage: "paperplane")
                                .font(.title3.weight(.bold))
                                .fontDesign(.rounded)
                                .symbolRenderingMode(.hierarchical)
                            TextField("User IDs (comma separated)", text: $inviteUserIds)
                                .textFieldStyle(.roundedBorder)
                            Button("Send Invites") {
                                SDALHaptics.tap(.medium)
                                Task { await sendInvites() }
                            }
                            .buttonStyle(PolishedGlassButtonStyle())
                            ForEach(pendingInvites) { invite in
                                Text("@\(invite.kadi ?? "user") - pending")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let members = detail?.members, !members.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Roles", systemImage: "person.text.rectangle")
                                    .font(.title3.weight(.bold))
                                    .fontDesign(.rounded)
                                    .symbolRenderingMode(.hierarchical)
                                ForEach(members) { m in
                                    HStack {
                                        Text("@\(m.kadi ?? "user")")
                                        Spacer()
                                        Menu(m.role ?? "member") {
                                            Button("owner") { Task { await setRole(userId: m.id, role: "owner") } }
                                            Button("moderator") { Task { await setRole(userId: m.id, role: "moderator") } }
                                            Button("member") { Task { await setRole(userId: m.id, role: "member") } }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Group Events", systemImage: "calendar")
                            .font(.title3.weight(.bold))
                            .fontDesign(.rounded)
                            .symbolRenderingMode(.hierarchical)
                        TextField("Title", text: $eventTitle).textFieldStyle(.roundedBorder)
                        TextField("Description", text: $eventDescription).textFieldStyle(.roundedBorder)
                        Button("Add Event") {
                            SDALHaptics.tap(.medium)
                            Task { await addGroupEvent() }
                        }
                            .buttonStyle(PolishedGlassButtonStyle())
                        ForEach((detail?.groupEvents?.isEmpty == false ? detail?.groupEvents : groupEventsFallback) ?? []) { e in
                            HStack {
                                Text(e.title ?? "-")
                                Spacer()
                                Button("Delete") {
                                    SDALHaptics.tap(.light)
                                    Task { await deleteGroupEvent(e.id) }
                                }
                                .buttonStyle(PolishedGlassButtonStyle())
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Group Announcements", systemImage: "megaphone")
                            .font(.title3.weight(.bold))
                            .fontDesign(.rounded)
                            .symbolRenderingMode(.hierarchical)
                        TextField("Title", text: $announcementTitle).textFieldStyle(.roundedBorder)
                        TextField("Body", text: $announcementBody).textFieldStyle(.roundedBorder)
                        Button("Add Announcement") {
                            SDALHaptics.tap(.medium)
                            Task { await addGroupAnnouncement() }
                        }
                            .buttonStyle(PolishedGlassButtonStyle())
                        ForEach((detail?.groupAnnouncements?.isEmpty == false ? detail?.groupAnnouncements : groupAnnouncementsFallback) ?? []) { a in
                            HStack {
                                Text(a.title ?? "-")
                                Spacer()
                                Button("Delete") {
                                    SDALHaptics.tap(.light)
                                    Task { await deleteGroupAnnouncement(a.id) }
                                }
                                    .buttonStyle(PolishedGlassButtonStyle())
                            }
                        }
                    }
                }

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .padding(16)
        }
        .navigationTitle("Group")
        .task { if detail == nil { await load() } }
        .onChange(of: postImageItem) { _, newValue in
            guard let newValue else { return }
            Task { postImageData = try? await newValue.loadTransferable(type: Data.self) }
        }
        .onChange(of: coverImageItem) { _, newValue in
            guard let newValue else { return }
            Task { coverImageData = try? await newValue.loadTransferable(type: Data.self) }
        }
        .sheet(isPresented: $showPostCamera) {
            CameraCapturePicker { data in
                if let data {
                    postImageData = data
                }
                showPostCamera = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showCoverCamera) {
            CameraCapturePicker { data in
                if let data {
                    coverImageData = data
                }
                showCoverCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private func load() async {
        do {
            detail = try await api.fetchGroupDetail(id: groupId)
            visibility = detail?.group?.visibility ?? "public"
            showContactHint = detail?.group?.showContactHint ?? false
            if detail?.groupEvents?.isEmpty != false {
                groupEventsFallback = (try? await api.fetchGroupEvents(groupId: groupId)) ?? []
            } else {
                groupEventsFallback = []
            }
            if detail?.groupAnnouncements?.isEmpty != false {
                groupAnnouncementsFallback = (try? await api.fetchGroupAnnouncements(groupId: groupId)) ?? []
            } else {
                groupAnnouncementsFallback = []
            }
            if detail?.canReviewRequests == true {
                joinRequests = try await api.fetchGroupJoinRequests(groupId: groupId)
                pendingInvites = try await api.fetchGroupInvitations(groupId: groupId)
            } else {
                joinRequests = []
                pendingInvites = []
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func joinLeave() async {
        do {
            try await api.joinOrLeaveGroup(id: groupId)
            SDALHaptics.success()
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func respondInvite(_ action: String) async {
        do {
            try await api.respondGroupInvite(groupId: groupId, action: action)
            SDALHaptics.success()
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func createPost() async {
        do {
            if let postImageData {
                try await api.createGroupPostWithImage(groupId: groupId, content: text, imageData: postImageData)
            } else {
                try await api.createGroupPost(groupId: groupId, content: text)
            }
            text = ""
            postImageData = nil
            SDALHaptics.success()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func addGroupEvent() async {
        do {
            try await api.createGroupEvent(groupId: groupId, title: eventTitle, description: eventDescription, location: "", startsAt: "", endsAt: "")
            eventTitle = ""
            eventDescription = ""
            SDALHaptics.success()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteGroupEvent(_ eventId: Int) async {
        do {
            try await api.deleteGroupEvent(groupId: groupId, eventId: eventId)
            SDALHaptics.success()
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func addGroupAnnouncement() async {
        do {
            try await api.createGroupAnnouncement(groupId: groupId, title: announcementTitle, body: announcementBody)
            announcementTitle = ""
            announcementBody = ""
            SDALHaptics.success()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteGroupAnnouncement(_ id: Int) async {
        do {
            try await api.deleteGroupAnnouncement(groupId: groupId, announcementId: id)
            SDALHaptics.success()
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func saveSettings() async {
        do {
            try await api.updateGroupSettings(groupId: groupId, visibility: visibility, showContactHint: showContactHint)
            SDALHaptics.success()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func uploadCover() async {
        guard let coverImageData else { return }
        do {
            try await api.uploadGroupCover(groupId: groupId, imageData: coverImageData)
            self.coverImageData = nil
            SDALHaptics.success()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func decideJoinRequest(_ requestId: Int, action: String) async {
        do {
            try await api.decideGroupJoinRequest(groupId: groupId, requestId: requestId, action: action)
            SDALHaptics.success()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func sendInvites() async {
        let ids = inviteUserIds
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 > 0 }
        guard !ids.isEmpty else {
            self.error = "Enter valid member ids."
            return
        }
        do {
            try await api.sendGroupInvitations(groupId: groupId, userIds: ids)
            inviteUserIds = ""
            SDALHaptics.success()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func setRole(userId: Int, role: String) async {
        do {
            try await api.setGroupRole(groupId: groupId, userId: userId, role: role)
            SDALHaptics.success()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct GamesHubView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    LazyVGrid(columns: gameColumns(for: geo.size.width), spacing: 12) {
                        gameCard(title: "Snake", subtitle: "Classic grid runner", key: "snake", arcade: false)
                        gameCard(title: "Tetris", subtitle: "Block stack challenge", key: "tetris", arcade: false)
                        gameCard(title: "Tap Rush", subtitle: "Arcade tap speed", key: "tap-rush", arcade: true)
                        gameCard(title: "Memory Pairs", subtitle: "Match card pairs", key: "memory-pairs", arcade: true)
                        gameCard(title: "Puzzle 2048", subtitle: "Merge to 2048", key: "puzzle-2048", arcade: true)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(i18n.t("games"))
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } } }
        }
    }

    @ViewBuilder
    private func gameCard(title: String, subtitle: String, key: String, arcade: Bool) -> some View {
        NavigationLink {
            MiniGameView(title: title, key: key, arcade: arcade)
        } label: {
            GlassCard {
                HStack(spacing: 12) {
                    Image(systemName: arcade ? "bolt.circle.fill" : "gamecontroller.fill")
                        .font(.title3)
                        .foregroundStyle(SDALTheme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func gameColumns(for width: CGFloat) -> [GridItem] {
        if horizontalSizeClass == .compact || width < 760 {
            return [GridItem(.flexible(), spacing: 12)]
        }
        return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }
}

struct MiniGameView: View {
    let title: String
    let key: String
    let arcade: Bool

    @State private var score = 0
    @State private var leaderboard: [LeaderboardRow] = []
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        VStack(spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title).font(.headline)
                    GameBoardPreview(gameKey: key)
                        .frame(height: 140)
                    Text("Score: \(score)")
                    HStack(spacing: 10) {
                        Button("+1") { score += 1 }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 42)
                        Button("+5") { score += 5 }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 42)
                        Button("+10") { score += 10 }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    HStack {
                        Button("Submit") { Task { await submit() } }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Leaderboard").font(.headline)
                    ForEach(Array(leaderboard.enumerated()), id: \.offset) { idx, row in
                        HStack {
                            Text("#\(idx + 1)")
                            Text(row.isim ?? "-")
                            Spacer()
                            Text("\(row.skor ?? row.puan ?? 0)")
                        }
                        .font(.subheadline)
                    }
                }
            }

            if let error {
                Text(error).foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(16)
        .navigationTitle(title)
        .task { await loadLeaderboard() }
    }

    private func loadLeaderboard() async {
        do { leaderboard = try await api.fetchGamesLeaderboard(gameKey: key, arcade: arcade) } catch { self.error = error.localizedDescription }
    }

    private func submit() async {
        do {
            try await api.submitGameScore(gameKey: key, score: score, arcade: arcade)
            await loadLeaderboard()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct GameBoardPreview: View {
    let gameKey: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SDALTheme.softPanel)
            switch gameKey {
            case "snake":
                snakePreview
            case "tetris":
                tetrisPreview
            case "puzzle-2048":
                puzzlePreview
            case "memory-pairs":
                memoryPreview
            default:
                tapPreview
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SDALTheme.line, lineWidth: 1)
        )
    }

    private var snakePreview: some View {
        GeometryReader { geo in
            let size = min(geo.size.width / 11, geo.size.height / 6.2)
            VStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { row in
                    HStack(spacing: 3) {
                        ForEach(0..<10, id: \.self) { col in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill((row == 2 && (3...6).contains(col)) ? .green : SDALTheme.card)
                                .frame(width: size, height: size)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var tetrisPreview: some View {
        HStack(alignment: .bottom, spacing: 4) {
            block(.orange, h: 42)
            block(.blue, h: 70)
            block(.mint, h: 56)
            block(.pink, h: 84)
            block(.yellow, h: 34)
            block(.indigo, h: 52)
        }
        .padding(12)
    }

    private var puzzlePreview: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { c in
                        let value = [2, 4, 8, 16, 32, 64, 128, 256, 512][(r * 3 + c) % 9]
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SDALTheme.card)
                            .overlay {
                                Text("\(value)")
                                    .font(.caption.bold())
                                    .foregroundStyle(SDALTheme.ink)
                            }
                    }
                }
            }
        }
        .padding(10)
    }

    private var memoryPreview: some View {
        VStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(i.isMultiple(of: 2) ? SDALTheme.cardAlt : SDALTheme.card)
                            .overlay {
                                Image(systemName: i.isMultiple(of: 2) ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundStyle(SDALTheme.primary)
                            }
                    }
                }
            }
        }
        .padding(10)
    }

    private var tapPreview: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.tap.fill")
                .font(.title2)
                .foregroundStyle(SDALTheme.primary)
            Text("Tap!")
                .font(.headline)
                .foregroundStyle(SDALTheme.ink)
        }
    }

    private func block(_ color: Color, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color.opacity(0.75))
            .frame(maxWidth: .infinity)
            .frame(height: h)
    }
}
