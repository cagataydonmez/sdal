import SwiftUI
import PhotosUI

private enum ExploreMode: String, CaseIterable, Identifiable {
    case suggestions
    case members
    case following

    var id: String { rawValue }
}

struct ExploreView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var mode: ExploreMode = .suggestions
    @State private var members: [MemberSummary] = []
    @State private var onlineMembers: [MemberSummary] = []
    @State private var latestMembers: [MemberSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var query = ""
    @State private var selectedMemberId: Int?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && members.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(i18n.t("loading_suggestions"))
                                .font(.headline)
                            SDALSkeletonLines(rows: 5)
                        }
                    }
                    .padding(16)
                } else if let errorMessage, members.isEmpty {
                    ScreenErrorView(message: errorMessage) { Task { await load() } }
                } else if members.isEmpty {
                    ScreenEmptyView(
                        title: i18n.t("explore"),
                        subtitle: i18n.t("no_members_for_filters"),
                        actionTitle: i18n.t("reload"),
                        action: { Task { await load() } }
                    )
                } else {
                    ScrollView {
                        GeometryReader { geo in
                            let columns = exploreColumns(for: geo.size.width)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(members) { member in
                                    memberCard(member, compact: geo.size.width < 520)
                                }
                            }
                            .padding(16)
                        }
                        .frame(minHeight: 240)
                    }
                    .refreshable { await load() }
                }
            }
            .task { if members.isEmpty { await load() } }
            .navigationTitle(i18n.t("explore"))
            .background(SDALTheme.appBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AlbumsHubView()
                    } label: {
                        Label(i18n.t("albums"), systemImage: "photo.on.rectangle")
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 10) {
                    Picker(i18n.t("mode"), selection: $mode) {
                        Text(i18n.t("suggestions")).tag(ExploreMode.suggestions)
                        Text(i18n.t("members")).tag(ExploreMode.members)
                        Text(i18n.t("following")).tag(ExploreMode.following)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: mode) { _, _ in Task { await load() } }

                    if mode == .members {
                        TextField(i18n.t("search"), text: $query)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { Task { await load() } }
                    }
                    if mode != .following, !onlineMembers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(onlineMembers) { member in
                                    HStack(spacing: 6) {
                                        AsyncAvatarView(imageName: member.resim, size: 28)
                                        Text("@\(member.kadi ?? i18n.t("user"))")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(SDALTheme.softPanel)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    if mode == .members, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !latestMembers.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(latestMembers) { member in
                                    Button {
                                        selectedMemberId = member.id
                                    } label: {
                                        HStack(spacing: 6) {
                                            AsyncAvatarView(imageName: member.resim, size: 28)
                                            Text("@\(member.kadi ?? i18n.t("user"))")
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(SDALTheme.softPanel)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(SDALTheme.appBackground)
            }
            .sheet(item: Binding(
                get: { selectedMemberId.map { MemberID(id: $0) } },
                set: { selectedMemberId = $0?.id }
            )) { payload in
                MemberDetailSheet(memberId: payload.id)
            }
        }
    }

    private func memberCard(_ member: MemberSummary, compact: Bool) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    AsyncAvatarView(imageName: member.resim, size: 52)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("@\(member.kadi ?? i18n.t("user"))")
                                .font(.headline)
                            if member.verified == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(SDALTheme.accent)
                            }
                            if member.online == true {
                                Circle().fill(.green).frame(width: 8, height: 8)
                            }
                        }
                        Text("\(member.isim ?? "") \(member.soyisim ?? "")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if let grad = member.mezuniyetyili, !grad.isEmpty {
                            memberChip(grad)
                        }
                        memberChip(member.online == true ? i18n.t("status_online") : i18n.t("status_offline"))
                        ForEach((member.reasons ?? []).prefix(3), id: \.self) { reason in
                            memberChip(reason)
                        }
                    }
                }
                if compact {
                    VStack(spacing: 8) {
                        followButton(member)
                        viewButton(member)
                    }
                } else {
                    HStack(spacing: 8) {
                        followButton(member)
                        viewButton(member)
                    }
                }
            }
        }
    }

    private func followButton(_ member: MemberSummary) -> some View {
        Group {
            if mode == .following {
                Button(i18n.t("unfollow")) {
                    Task { await unfollow(member.id) }
                }
                .buttonStyle(.bordered)
            } else {
                Button(i18n.t("follow")) {
                    Task { await follow(member.id) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func viewButton(_ member: MemberSummary) -> some View {
        Button(i18n.t("view")) {
            selectedMemberId = member.id
        }
        .buttonStyle(.bordered)
    }

    private func memberChip(_ label: String) -> some View {
        SDALPill(text: label, tint: SDALTheme.softPanel, foreground: SDALTheme.ink)
    }

    private func exploreColumns(for width: CGFloat) -> [GridItem] {
        if horizontalSizeClass == .compact || width < 760 {
            return [GridItem(.flexible(), spacing: 12)]
        }
        if width < 1367 {
            return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        }
        return [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            onlineMembers = (try? await api.fetchOnlineMembers(limit: 14)) ?? []
            latestMembers = (try? await api.fetchLatestMembers(limit: 14)) ?? []
            switch mode {
            case .suggestions:
                members = try await api.fetchExploreSuggestions()
            case .members:
                members = try await api.fetchMembers(term: query)
            case .following:
                members = try await api.fetchFollowing()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func follow(_ id: Int) async {
        do {
            _ = try await api.toggleFollow(memberId: id)
            members.removeAll { $0.id == id && mode != .following }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unfollow(_ id: Int) async {
        do {
            _ = try await api.toggleFollow(memberId: id)
            members.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MemberID: Identifiable { let id: Int }

private struct MemberDetailSheet: View {
    let memberId: Int

    @EnvironmentObject private var i18n: LocalizationManager
    @State private var member: MemberDetail?
    @State private var stories: [Story] = []
    @State private var viewerContext: StoryViewerContext?
    @State private var viewedStoryIds: Set<Int> = []
    @State private var loading = false
    @State private var error: String?
    @State private var quickAccessAdded = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if loading && member == nil {
                    ProgressView()
                } else if let error, member == nil {
                    ScreenErrorView(message: error) { Task { await load() } }
                } else if let member {
                    ScrollView {
                        VStack(spacing: 14) {
                            GlassCard {
                                VStack(spacing: 10) {
                                    AsyncAvatarView(imageName: member.resim, size: 84)
                                    Text("@\(member.kadi ?? i18n.t("user"))")
                                        .font(.title3.bold())
                                    Text("\(member.isim ?? "") \(member.soyisim ?? "")")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }

                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    row(i18n.t("email"), member.email)
                                    row(i18n.t("graduation"), member.mezuniyetyili)
                                    row(i18n.t("city"), member.sehir)
                                    row(i18n.t("university"), member.universite)
                                    row(i18n.t("job"), member.meslek)
                                    row(i18n.t("website"), member.websitesi)
                                }
                            }

                            if !stories.isEmpty {
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(i18n.t("stories"))
                                            .font(.headline)
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 10) {
                                                ForEach(Array(stories.enumerated()), id: \.element.id) { idx, story in
                                                    StoryThumb(story: story, viewed: isStoryViewed(story))
                                                        .onTapGesture {
                                                            viewerContext = StoryViewerContext(
                                                                groups: [memberStoryGroup],
                                                                groupIndex: 0,
                                                                storyIndex: idx
                                                            )
                                                        }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            GlassCard {
                                HStack {
                                    Button(quickAccessAdded ? i18n.t("added_to_quick_access") : i18n.t("add_to_quick_access")) {
                                        Task { await addQuickAccess() }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(quickAccessAdded || member.id == nil)
                                    Spacer()
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .task { if member == nil { await load() } }
            .navigationTitle(i18n.t("member"))
            .fullScreenCover(item: $viewerContext) { context in
                StorySequenceViewerSheet(
                    groups: context.groups,
                    startGroupIndex: context.groupIndex,
                    startStoryIndex: context.storyIndex,
                    onMarkViewed: { id in
                        viewedStoryIds.insert(id)
                        Task { await markStoryViewed(id) }
                    }
                )
            }
        }
    }

    private var memberStoryGroup: StoryGroup {
        let sortedStories = stories.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
        return StoryGroup(
            id: memberId,
            author: sortedStories.first?.author,
            items: sortedStories,
            viewed: sortedStories.allSatisfy { isStoryViewed($0) },
            latestAt: sortedStories.first?.createdAt ?? ""
        )
    }

    private func row(_ key: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(key).font(.caption).foregroundStyle(.secondary)
            Text((value?.isEmpty == false ? value : nil) ?? "-")
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            member = try await api.fetchMemberDetail(id: memberId)
            stories = try await api.fetchStoriesByUser(userId: memberId)
            viewedStoryIds = Set(stories.compactMap { $0.viewed == true ? $0.id : nil })
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func isStoryViewed(_ story: Story) -> Bool {
        viewedStoryIds.contains(story.id) || story.viewed == true
    }

    private func markStoryViewed(_ id: Int) async {
        do {
            try await api.markStoryViewed(id: id)
        } catch {
            // Ignore mark failures while browsing stories.
        }
    }

    private func addQuickAccess() async {
        guard let id = member?.id else { return }
        do {
            try await api.addQuickAccessUser(id: id)
            quickAccessAdded = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct StoryThumb: View {
    @EnvironmentObject private var i18n: LocalizationManager
    let story: Story
    let viewed: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let imagePath = story.image,
               let url = AppConfig.absoluteURL(path: imagePath) {
                CachedRemoteImage(url: url, targetSize: CGSize(width: 96, height: 140)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    SDALTheme.softPanel
                }
            } else {
                SDALTheme.softPanel
            }
            Text("@\(story.author?.kadi ?? i18n.t("user"))")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.35))
        }
        .frame(width: 96, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(viewed ? Color.white.opacity(0.28) : SDALTheme.accent, lineWidth: 2)
        )
    }
}

private struct AlbumsHubView: View {
    @EnvironmentObject private var i18n: LocalizationManager

    @State private var categories: [AlbumCategory] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showUpload = false
    @State private var latestPhotos: [AlbumLatestItem] = []

    private let api = APIClient.shared

    var body: some View {
        Group {
            if loading && categories.isEmpty {
                ProgressView(i18n.t("loading"))
            } else if let error, categories.isEmpty {
                ScreenErrorView(message: error) { Task { await load() } }
            } else {
                List {
                    if !latestPhotos.isEmpty {
                        Section(i18n.t("latest_photos")) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(latestPhotos) { item in
                                        if let url = AppConfig.thumbnailURL(fileName: item.dosyaadi, width: 220) {
                                            CachedRemoteImage(url: url, targetSize: CGSize(width: 84, height: 84)) { img in
                                                img.resizable().scaledToFill()
                                            } placeholder: {
                                                Color.gray.opacity(0.2)
                                            }
                                            .frame(width: 84, height: 84)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Section(i18n.t("categories")) {
                        ForEach(categories) { cat in
                            NavigationLink {
                                AlbumCategoryDetailView(category: cat)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cat.kategori ?? i18n.t("category"))
                                        .font(.headline)
                                    Text(String(format: i18n.t("photo_count"), cat.count ?? 0))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle(i18n.t("albums"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(i18n.t("upload")) { showUpload = true }
            }
        }
        .sheet(isPresented: $showUpload) {
            AlbumUploadView(onDone: {
                showUpload = false
                Task { await load() }
            })
        }
        .task { if categories.isEmpty { await load() } }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            async let categoriesReq = api.fetchAlbumCategories()
            async let latestReq = api.fetchLatestAlbumPhotos(limit: 24, offset: 0)
            categories = try await categoriesReq
            let latest = try await latestReq
            latestPhotos = latest.items
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct AlbumCategoryDetailView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var i18n: LocalizationManager
    let category: AlbumCategory

    @State private var photos: [AlbumPhoto] = []
    @State private var loading = false
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        Group {
            if loading && photos.isEmpty {
                ProgressView()
            } else if let error, photos.isEmpty {
                ScreenErrorView(message: error) { Task { await load() } }
            } else {
                GeometryReader { geo in
                    let columns = photoColumns(for: geo.size.width)
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(photos) { photo in
                                NavigationLink {
                                    AlbumPhotoDetailView(photoId: photo.id)
                                } label: {
                                    GlassCard {
                                        VStack(alignment: .leading, spacing: 6) {
                                            if let file = photo.dosyaadi {
                                                CachedRemoteImage(
                                                    url: AppConfig.thumbnailURL(fileName: file, width: 220),
                                                    targetSize: CGSize(width: 220, height: geo.size.width < 430 ? 120 : 150)
                                                ) { img in
                                                    img.resizable().scaledToFill()
                                                } placeholder: {
                                                    Color.gray.opacity(0.2)
                                                }
                                                .frame(height: geo.size.width < 430 ? 120 : 150)
                                                .frame(maxWidth: .infinity)
                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            }
                                            Text(photo.baslik ?? i18n.t("photo"))
                                                .lineLimit(1)
                                            Text(photo.tarih ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .navigationTitle(category.kategori ?? i18n.t("albums"))
        .task { if photos.isEmpty { await load() } }
    }

    private func photoColumns(for width: CGFloat) -> [GridItem] {
        if horizontalSizeClass == .compact || width < 760 {
            return [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        }
        if width < 1367 {
            return [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        }
        return [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            photos = try await api.fetchAlbum(id: category.id).photos
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct AlbumPhotoDetailView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    let photoId: Int

    @State private var detail: PhotoDetail?
    @State private var comments: [PhotoComment] = []
    @State private var commentText = ""
    @State private var loading = false
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if let file = detail?.dosyaadi {
                    CachedRemoteImage(
                        url: AppConfig.thumbnailURL(fileName: file, width: 1200),
                        targetSize: UIScreen.main.bounds.size
                    ) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        ProgressView()
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(detail?.baslik ?? "")
                                .font(.headline)
                            Spacer()
                            Text(detail?.tarih ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let aciklama = detail?.aciklama, !aciklama.isEmpty {
                            Text(aciklama)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(i18n.t("comments")).font(.headline)
                        ForEach(comments) { c in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(c.kadi ?? c.uyeadi ?? i18n.t("user"))").font(.caption.bold())
                                Text(c.yorum ?? "")
                            }
                        }
                        TextField(i18n.t("write_comment"), text: $commentText)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("add_comment")) {
                            Task { await addComment() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .padding(16)
        }
        .overlay {
            if loading && detail == nil { ProgressView() }
            if let error, detail == nil {
                ScreenErrorView(message: error) { Task { await load() } }
            }
        }
        .navigationTitle(i18n.t("photo"))
        .task { if detail == nil { await load() } }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let payload = try await api.fetchPhoto(id: photoId)
            detail = payload.row
            comments = payload.comments ?? []
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func addComment() async {
        do {
            try await api.addPhotoComment(photoId: photoId, comment: commentText)
            commentText = ""
            comments = try await api.fetchPhotoComments(id: photoId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct AlbumUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var i18n: LocalizationManager
    let onDone: () -> Void

    @State private var categories: [AlbumCategory] = []
    @State private var selectedCategoryId: Int?
    @State private var title = ""
    @State private var description = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var imageData: Data?
    @State private var errorMessage: String?
    @State private var isUploading = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Picker(i18n.t("category"), selection: $selectedCategoryId) {
                    Text(i18n.t("select")).tag(nil as Int?)
                    ForEach(categories) { c in
                        Text(c.kategori ?? i18n.t("category")).tag(Optional(c.id))
                    }
                }
                TextField(i18n.t("title"), text: $title)
                TextField(i18n.t("description"), text: $description, axis: .vertical)
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Label(imageData == nil ? i18n.t("select_photo") : i18n.t("change_photo"), systemImage: "photo")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label(i18n.t("camera"), systemImage: "camera")
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .navigationTitle(i18n.t("upload_photo"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(i18n.t("close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isUploading ? i18n.t("loading") : i18n.t("upload")) {
                        Task { await upload() }
                    }
                    .disabled(isUploading || selectedCategoryId == nil || title.isEmpty || imageData == nil)
                }
            }
            .task {
                categories = (try? await api.fetchActiveAlbumCategories()) ?? []
            }
            .onChange(of: selectedItem) { _, newValue in
                guard let newValue else { return }
                Task { imageData = try? await newValue.loadTransferable(type: Data.self) }
            }
            .sheet(isPresented: $showCamera) {
                CameraCapturePicker { data in
                    if let data {
                        imageData = data
                    }
                    showCamera = false
                }
                .ignoresSafeArea()
            }
        }
    }

    private func upload() async {
        guard let selectedCategoryId, let imageData else { return }
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }
        do {
            try await api.uploadAlbumPhoto(
                categoryId: selectedCategoryId,
                title: title,
                description: description,
                imageData: imageData
            )
            onDone()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
