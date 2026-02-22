import SwiftUI
import PhotosUI
import UIKit

struct StoryGroup: Identifiable {
    let id: Int
    let author: PostAuthor?
    let items: [Story]
    let viewed: Bool
    let latestAt: String
}

struct StoryViewerContext: Identifiable {
    let id = UUID()
    let groups: [StoryGroup]
    let groupIndex: Int
    let storyIndex: Int
}

@MainActor
struct StoryBarView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @State private var stories: [Story] = []
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var uploadError: String?
    @State private var captionDraft = ""
    @State private var pendingImageData: Data?
    @State private var viewerContext: StoryViewerContext?
    @State private var viewedStoryIds: Set<Int> = []
    @State private var myStories: [MyStoryItem] = []
    @State private var manageOpen = false

    private let api = APIClient.shared

    private var groupedStories: [StoryGroup] {
        var map: [Int: (author: PostAuthor?, items: [Story])] = [:]
        for story in stories {
            let authorId = story.author?.id ?? 0
            guard authorId > 0 else { continue }
            if map[authorId] == nil {
                map[authorId] = (story.author, [])
            }
            map[authorId]?.items.append(story)
        }
        var groups = map.map { key, value in
            let sortedItems = value.items.sorted { ($0.createdAt ?? "") > ($1.createdAt ?? "") }
            return StoryGroup(
                id: key,
                author: value.author,
                items: sortedItems,
                viewed: sortedItems.allSatisfy { isStoryViewed($0) },
                latestAt: sortedItems.first?.createdAt ?? ""
            )
        }
        groups.sort { lhs, rhs in
            if lhs.viewed != rhs.viewed {
                return lhs.viewed == false
            }
            return lhs.latestAt > rhs.latestAt
        }
        return groups
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(i18n.t("stories"))
                    .font(.headline)
                Spacer()
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    Label(i18n.t("add_story"), systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label(i18n.t("camera"), systemImage: "camera")
                    }
                    .buttonStyle(.bordered)
                }
                Button(i18n.t("manage")) { manageOpen = true }
                    .buttonStyle(.bordered)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(groupedStories.enumerated()), id: \.element.id) { idx, group in
                        VStack(spacing: 6) {
                            AsyncAvatarView(imageName: group.author?.resim, size: 56)
                                .overlay(Circle().stroke(group.viewed ? Color.gray.opacity(0.4) : SDALTheme.accent, lineWidth: 3))
                            Text("@\(group.author?.kadi ?? "user")")
                                .font(.caption2)
                                .lineLimit(1)
                                .frame(width: 62)
                        }
                        .onTapGesture {
                            let start = firstUnviewedIndex(group.items)
                            viewerContext = StoryViewerContext(groups: groupedStories, groupIndex: idx, storyIndex: start)
                        }
                    }
                    if groupedStories.isEmpty {
                        Text(i18n.t("stories_empty"))
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    }
                }
            }

            if let uploadError {
                Text(uploadError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .task {
            await loadStories()
        }
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            Task {
                pendingImageData = try? await newValue.loadTransferable(type: Data.self)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCapturePicker { data in
                if let data {
                    pendingImageData = data
                }
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $viewerContext) { context in
            StorySequenceViewerSheet(
                groups: context.groups,
                startGroupIndex: context.groupIndex,
                startStoryIndex: context.storyIndex,
                onMarkViewed: { id in
                    setStoryViewed(id: id)
                    Task { await markViewedById(id) }
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { pendingImageData != nil },
            set: { if !$0 { pendingImageData = nil } }
        )) {
            StoryUploadSheet(
                caption: $captionDraft,
                onCancel: {
                    captionDraft = ""
                    pendingImageData = nil
                },
                onUpload: {
                    Task { await uploadStory() }
                }
            )
            .presentationDetents([.height(230)])
        }
        .sheet(isPresented: $manageOpen) {
            StoryManageSheet(
                stories: $myStories,
                onReload: {
                    Task { await loadMyStories() }
                }
            )
        }
    }

    private func loadStories() async {
        do {
            stories = try await api.fetchStories()
            viewedStoryIds = Set(stories.compactMap { $0.viewed == true ? $0.id : nil })
        } catch {
            uploadError = error.localizedDescription
        }
    }

    private func uploadStory() async {
        guard let pendingImageData else { return }
        do {
            _ = try await api.uploadStory(
                imageData: pendingImageData,
                fileName: "story.jpg",
                mimeType: "image/jpeg",
                caption: captionDraft
            )
            captionDraft = ""
            self.pendingImageData = nil
            uploadError = nil
            await loadStories()
        } catch {
            uploadError = error.localizedDescription
        }
    }

    private func markViewedById(_ id: Int) async {
        do {
            try await api.markStoryViewed(id: id)
        } catch {
            // Ignore view mark errors.
        }
    }

    private func setStoryViewed(id: Int) {
        viewedStoryIds.insert(id)
    }

    private func firstUnviewedIndex(_ items: [Story]) -> Int {
        if let idx = items.firstIndex(where: { !isStoryViewed($0) }) {
            return idx
        }
        return 0
    }

    private func isStoryViewed(_ story: Story) -> Bool {
        viewedStoryIds.contains(story.id) || story.viewed == true
    }

    private func loadMyStories() async {
        do {
            myStories = try await api.fetchMyStories()
        } catch {
            uploadError = error.localizedDescription
        }
    }
}

private struct StoryManageSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @Binding var stories: [MyStoryItem]
    let onReload: () -> Void

    @State private var editCaption = ""
    @State private var editingId: Int?
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            List(stories) { s in
                VStack(alignment: .leading, spacing: 6) {
                    if let url = AppConfig.absoluteURL(path: s.image) {
                        CachedRemoteImage(url: url, targetSize: CGSize(width: 300, height: 180)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            SDALTheme.softPanel
                        }
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    Text(String(format: i18n.t("story_title_format"), s.id))
                    Text(s.caption ?? "")
                        .foregroundStyle(.secondary)
                    Text(String(format: i18n.t("views_label_format"), s.viewCount ?? 0))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button(i18n.t("edit")) {
                            editingId = s.id
                            editCaption = s.caption ?? ""
                        }
                        .buttonStyle(.bordered)
                        Button(i18n.t("delete"), role: .destructive) {
                            Task { await remove(s.id) }
                        }
                        .buttonStyle(.bordered)
                        if s.isExpired == true {
                            Button(i18n.t("repost")) { Task { await repost(s.id) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle(i18n.t("my_stories"))
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } } }
            .task { onReload() }
            .alert(i18n.t("edit"), isPresented: Binding(
                get: { editingId != nil },
                set: { if !$0 { editingId = nil } }
            )) {
                TextField(i18n.t("caption"), text: $editCaption)
                Button(i18n.t("save")) { Task { await saveEdit() } }
                Button(i18n.t("close"), role: .cancel) { editingId = nil }
            } message: {
                Text(i18n.t("update_story_caption"))
            }
            .overlay(alignment: .bottom) {
                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private func saveEdit() async {
        guard let editingId else { return }
        do {
            try await api.editStoryCaption(id: editingId, caption: editCaption)
            self.editingId = nil
            onReload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func remove(_ id: Int) async {
        do {
            try await api.deleteStory(id: id)
            stories.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func repost(_ id: Int) async {
        do {
            try await api.repostStory(id: id)
            onReload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct StoryUploadSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Binding var caption: String
    let onCancel: () -> Void
    let onUpload: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                TextField(i18n.t("caption_optional"), text: $caption, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                Button(i18n.t("add_story"), action: onUpload)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer()
            }
            .padding(16)
            .navigationTitle(i18n.t("new_story"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(i18n.t("close"), action: onCancel)
                }
            }
        }
    }
}

struct StorySequenceViewerSheet: View {
    let groups: [StoryGroup]
    let startGroupIndex: Int
    let startStoryIndex: Int
    let onMarkViewed: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var i18n: LocalizationManager
    @State private var groupIndex = 0
    @State private var storyIndex = 0
    @State private var progress: Double = 0
    @State private var dragOffset: CGFloat = 0
    @State private var markedIds: Set<Int> = []
    @State private var preloadedImages: [Int: UIImage] = [:]
    @State private var preloadingIds: Set<Int> = []

    private let duration: Double = 5.0
    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var activeGroup: StoryGroup? {
        guard groups.indices.contains(groupIndex) else { return nil }
        return groups[groupIndex]
    }

    private var activeStory: Story? {
        guard let activeGroup, activeGroup.items.indices.contains(storyIndex) else { return nil }
        return activeGroup.items[storyIndex]
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            if let story = activeStory {
                storyImage(story)
                    .id(story.id)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.20), value: story.id)
                    .overlay(alignment: .bottomLeading) {
                        if let caption = story.caption, !caption.isEmpty {
                            Text(caption)
                                .foregroundStyle(.white)
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 16)
                                .padding(.bottom, 22)
                        }
                    }
            } else {
                ProgressView().tint(.white)
            }

            VStack(spacing: 12) {
                progressBars
                header
            }
            .padding(.top, 10)
            .padding(.horizontal, 10)
        }
        .overlay {
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { previous() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { next() }
            }
        }
        .offset(x: dragOffset)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let width = value.translation.width
                    let height = value.translation.height
                    dragOffset = 0
                    if height > 140 {
                        dismiss()
                    } else if width < -90 {
                        nextGroup()
                    } else if width > 90 {
                        previousGroup()
                    }
                }
        )
        .onAppear {
            guard !groups.isEmpty else {
                dismiss()
                return
            }
            groupIndex = clamp(startGroupIndex, in: 0...(groups.count - 1))
            let maxStoryIndex = max(0, groups[groupIndex].items.count - 1)
            storyIndex = clamp(startStoryIndex, in: 0...maxStoryIndex)
            progress = 0
            markCurrentAsViewed()
            prefetchCurrentNeighborhood()
        }
        .onReceive(tick) { _ in
            guard activeStory != nil else { return }
            progress += 0.05 / duration
            if progress >= 1 {
                next()
            }
        }
        .onChange(of: groupIndex) { _, _ in
            progress = 0
            markCurrentAsViewed()
            prefetchCurrentNeighborhood()
        }
        .onChange(of: storyIndex) { _, _ in
            progress = 0
            markCurrentAsViewed()
            prefetchCurrentNeighborhood()
        }
        .statusBarHidden(true)
    }

    @ViewBuilder
    private func storyImage(_ story: Story) -> some View {
        if let cached = preloadedImages[story.id] {
            Image(uiImage: cached)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else if let url = imageURL(for: story.image) {
            CachedRemoteImage(url: url, targetSize: UIScreen.main.bounds.size) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .task {
                        await preloadImage(story)
                    }
            } placeholder: {
                ProgressView().tint(.white)
            }
        } else {
            Text(i18n.t("image_unavailable")).foregroundStyle(.white)
        }
    }

    private var progressBars: some View {
        HStack(spacing: 5) {
            ForEach(Array((activeGroup?.items ?? []).enumerated()), id: \.element.id) { idx, _ in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.25))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: proxy.size.width * barFill(for: idx))
                    }
                }
                .frame(height: 3)
            }
        }
        .frame(height: 3)
    }

    private var header: some View {
        HStack(spacing: 10) {
            AsyncAvatarView(imageName: activeGroup?.author?.resim, size: 34)
            Text("@\(activeGroup?.author?.kadi ?? "user")")
                .foregroundStyle(.white)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.35), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 2)
    }

    private func barFill(for idx: Int) -> CGFloat {
        if idx < storyIndex { return 1 }
        if idx == storyIndex { return CGFloat(min(max(progress, 0), 1)) }
        return 0
    }

    private func markCurrentAsViewed() {
        guard let id = activeStory?.id else { return }
        if markedIds.contains(id) { return }
        markedIds.insert(id)
        onMarkViewed(id)
    }

    private func next() {
        guard let activeGroup else { return }
        if storyIndex + 1 < activeGroup.items.count {
            storyIndex += 1
            return
        }
        nextGroup()
    }

    private func previous() {
        if storyIndex > 0 {
            storyIndex -= 1
            return
        }
        if groupIndex > 0 {
            groupIndex -= 1
            storyIndex = max(0, groups[groupIndex].items.count - 1)
            return
        }
        dismiss()
    }

    private func nextGroup() {
        guard !groups.isEmpty else {
            dismiss()
            return
        }
        if groupIndex + 1 < groups.count {
            groupIndex += 1
            storyIndex = 0
        } else {
            dismiss()
        }
    }

    private func previousGroup() {
        if groupIndex > 0 {
            groupIndex -= 1
            storyIndex = max(0, groups[groupIndex].items.count - 1)
        } else {
            dismiss()
        }
    }

    private func imageURL(for value: String?) -> URL? {
        AppConfig.absoluteURL(path: value)
    }

    private func clamp(_ value: Int, in range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func prefetchCurrentNeighborhood() {
        Task {
            let targets = preloadTargetStories()
            for story in targets {
                await preloadImage(story)
            }
        }
    }

    private func preloadTargetStories() -> [Story] {
        guard !groups.isEmpty,
              groups.indices.contains(groupIndex),
              groups[groupIndex].items.indices.contains(storyIndex)
        else { return [] }

        var result: [Story] = []
        let currentGroup = groups[groupIndex]

        result.append(currentGroup.items[storyIndex])
        if currentGroup.items.indices.contains(storyIndex + 1) {
            result.append(currentGroup.items[storyIndex + 1])
        }
        if currentGroup.items.indices.contains(storyIndex - 1) {
            result.append(currentGroup.items[storyIndex - 1])
        }
        if groups.indices.contains(groupIndex + 1), let first = groups[groupIndex + 1].items.first {
            result.append(first)
        }

        var seen: Set<Int> = []
        return result.filter { seen.insert($0.id).inserted }
    }

    private func preloadImage(_ story: Story) async {
        guard preloadedImages[story.id] == nil,
              !preloadingIds.contains(story.id),
              let url = imageURL(for: story.image)
        else { return }

        _ = await MainActor.run { preloadingIds.insert(story.id) }
        defer { Task { @MainActor in preloadingIds.remove(story.id) } }

        if let image = await RemoteImagePipeline.shared.image(for: url, targetSize: UIScreen.main.bounds.size) {
            await MainActor.run {
                preloadedImages[story.id] = image
            }
        }
    }
}
