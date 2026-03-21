import SwiftUI
import PhotosUI
import UIKit

struct EventsHubView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let initialEventId: Int?
    @State private var items: [EventItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var createOpen = false
    @State private var selectedEvent: EventItem?
    @State private var didOpenInitialEvent = false

    private let api = APIClient.shared

    init(initialEventId: Int? = nil) {
        self.initialEventId = initialEventId
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
                            GlassCard {
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.title2.weight(.semibold))
                                        .symbolRenderingMode(.hierarchical)
                                        .symbolEffect(.pulse, options: .repeating.speed(0.8))
                                        .foregroundStyle(SDALTheme.primary)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(i18n.t("events"))
                                            .font(.title2.weight(.bold))
                                            .fontDesign(.rounded)
                                        Text("Live alumni events with approval, attendance, reminders, and comments.")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            ForEach(items) { e in
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(e.title ?? "-")
                                            .font(.title3.weight(.bold))
                                            .fontDesign(.rounded)
                                        if let desc = e.description, !desc.isEmpty {
                                            Text(desc)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                        }
                                        HStack(spacing: 8) {
                                            Label(e.startsAt ?? "", systemImage: "clock")
                                                .symbolRenderingMode(.hierarchical)
                                            Text("•")
                                            Label(e.location ?? "-", systemImage: "mappin.and.ellipse")
                                                .symbolRenderingMode(.hierarchical)
                                        }
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        HStack(spacing: 6) {
                                            if (e.approved == false) {
                                                Text(i18n.t("pending_approval"))
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.orange.opacity(0.18))
                                                    .clipShape(Capsule())
                                            }
                                            if let counts = e.responseCounts {
                                                Text("\(i18n.t("attend")) \(counts.attend ?? 0)")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(SDALTheme.softPanel)
                                                    .clipShape(Capsule())
                                                Text("\(i18n.t("decline")) \(counts.decline ?? 0)")
                                                    .font(.caption2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(SDALTheme.softPanel)
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        HStack(spacing: 8) {
                                            Button(i18n.t("attend")) {
                                                SDALHaptics.tap(.light)
                                                Task { await respond(e.id, "attend") }
                                            }
                                            .buttonStyle(PolishedGlassButtonStyle())
                                            Button(i18n.t("decline")) {
                                                SDALHaptics.tap(.light)
                                                Task { await respond(e.id, "decline") }
                                            }
                                            .buttonStyle(PolishedGlassButtonStyle())
                                            Button(i18n.t("notify")) {
                                                SDALHaptics.tap(.light)
                                                Task { await notify(e.id) }
                                            }
                                            .buttonStyle(PolishedGlassButtonStyle())
                                            Button(i18n.t("comments")) {
                                                SDALHaptics.tap(.light)
                                                selectedEvent = e
                                            }
                                            .buttonStyle(PolishedGlassButtonStyle(emphasized: true))
                                        }

                                        if e.canManageResponses == true {
                                            HStack(spacing: 8) {
                                                Button("\(i18n.t("counts")): \(e.responseVisibility?.showCounts == true ? i18n.t("on") : i18n.t("off"))") {
                                                    Task {
                                                        let v = e.responseVisibility
                                                        await setVisibility(
                                                            e.id,
                                                            showCounts: !(v?.showCounts ?? false),
                                                            showAttendeeNames: v?.showAttendeeNames ?? false,
                                                            showDeclinerNames: v?.showDeclinerNames ?? false
                                                        )
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                                Button("\(i18n.t("attendees")): \(e.responseVisibility?.showAttendeeNames == true ? i18n.t("on") : i18n.t("off"))") {
                                                    Task {
                                                        let v = e.responseVisibility
                                                        await setVisibility(
                                                            e.id,
                                                            showCounts: v?.showCounts ?? false,
                                                            showAttendeeNames: !(v?.showAttendeeNames ?? false),
                                                            showDeclinerNames: v?.showDeclinerNames ?? false
                                                        )
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                            }
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(i18n.t("delete"), role: .destructive) { Task { await deleteEvent(e.id) } }
                                    Button(e.approved == true ? i18n.t("unapprove") : i18n.t("approve")) {
                                        Task { await approveEvent(e.id, approved: e.approved != true) }
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle(i18n.t("events"))
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
                        createOpen = true
                    }
                }
            }
            .task { if items.isEmpty { await load() } }
            .sheet(isPresented: $createOpen) {
                EventCreateSheet(onDone: {
                    createOpen = false
                    Task { await load() }
                })
            }
            .sheet(item: $selectedEvent) { event in
                EventCommentsSheet(event: event) {
                    Task { await load() }
                }
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            items = try await api.fetchEvents(limit: initialEventId == nil ? 20 : 60)
            presentInitialEventIfNeeded()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func presentInitialEventIfNeeded() {
        guard !didOpenInitialEvent, let initialEventId else { return }
        guard let match = items.first(where: { $0.id == initialEventId }) else { return }
        didOpenInitialEvent = true
        selectedEvent = match
    }

    private func respond(_ id: Int, _ value: String) async {
        do {
            try await api.respondEvent(id: id, response: value)
            SDALHaptics.success()
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func notify(_ id: Int) async {
        do {
            try await api.notifyEventFollowers(id: id)
            SDALHaptics.success()
        } catch { self.error = error.localizedDescription }
    }

    private func setVisibility(_ id: Int, showCounts: Bool, showAttendeeNames: Bool, showDeclinerNames: Bool) async {
        do {
            try await api.setEventResponseVisibility(id: id, showCounts: showCounts, showAttendeeNames: showAttendeeNames, showDeclinerNames: showDeclinerNames)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func approveEvent(_ id: Int, approved: Bool) async {
        do {
            try await api.approveEvent(id: id, approved: approved)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteEvent(_ id: Int) async {
        do {
            try await api.deleteEvent(id: id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct EventCreateSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let onDone: () -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var location = ""
    @State private var startsAt = ""
    @State private var endsAt = ""
    @State private var item: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showCamera = false
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        let photoLabel = imageData == nil ? i18n.t("add_photo") : i18n.t("change_photo")
        NavigationStack {
            Form {
                TextField(i18n.t("title"), text: $title)
                TextField(i18n.t("description"), text: $description, axis: .vertical)
                TextField(i18n.t("location"), text: $location)
                TextField(i18n.t("starts_at_iso"), text: $startsAt)
                TextField(i18n.t("ends_at_iso"), text: $endsAt)
                PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                    Label(photoLabel, systemImage: "photo")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        SDALHaptics.tap(.light)
                        showCamera = true
                    } label: {
                        Label(i18n.t("camera"), systemImage: "camera")
                    }
                }
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
                        .disabled(title.isEmpty || description.isEmpty)
                }
            }
            .onChange(of: item) { _, newValue in
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

    private func save() async {
        do {
            if let imageData {
                try await api.createEventWithImage(
                    title: title,
                    description: description,
                    location: location,
                    startsAt: startsAt,
                    endsAt: endsAt,
                    imageData: imageData
                )
            } else {
                try await api.createEvent(title: title, description: description, location: location, startsAt: startsAt, endsAt: endsAt)
            }
            SDALHaptics.success()
            onDone()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct EventCommentsSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let eventId: Int
    let eventTitle: String?
    let onChanged: (() -> Void)?
    @State private var event: EventItem?
    @State private var comments: [EventComment] = []
    @State private var text = ""
    @State private var error: String?
    @State private var isSubmitting = false

    private let api = APIClient.shared

    init(event: EventItem, onChanged: (() -> Void)? = nil) {
        self.eventId = event.id
        self.eventTitle = event.title
        self.onChanged = onChanged
        _event = State(initialValue: event)
    }

    init(eventId: Int, eventTitle: String? = nil, onChanged: (() -> Void)? = nil) {
        self.eventId = eventId
        self.eventTitle = eventTitle
        self.onChanged = onChanged
        _event = State(initialValue: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let event {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(event.title ?? eventTitle ?? i18n.t("event"))
                                    .font(.title2.weight(.bold))
                                    .fontDesign(.rounded)
                                if let description = event.description, !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
                                }
                                HStack(spacing: 10) {
                                    Label(event.startsAt ?? "-", systemImage: "clock")
                                        .symbolRenderingMode(.hierarchical)
                                    Label(event.location ?? "-", systemImage: "mappin.and.ellipse")
                                        .symbolRenderingMode(.hierarchical)
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    if let response = event.myResponse, !response.isEmpty {
                                        SDALPill(text: response.capitalized, tint: SDALTheme.primary.opacity(0.16), foreground: SDALTheme.ink)
                                    }
                                    if let counts = event.responseCounts {
                                        SDALPill(text: "\(i18n.t("attend")) \(counts.attend ?? 0)", tint: SDALTheme.cardAlt, foreground: SDALTheme.ink)
                                        SDALPill(text: "\(i18n.t("decline")) \(counts.decline ?? 0)", tint: SDALTheme.cardAlt, foreground: SDALTheme.ink)
                                    }
                                }
                                HStack(spacing: 8) {
                                    Button(i18n.t("attend")) {
                                        SDALHaptics.tap(.light)
                                        Task { await respond("attend") }
                                    }
                                    .buttonStyle(PolishedGlassButtonStyle())
                                    Button(i18n.t("decline")) {
                                        SDALHaptics.tap(.light)
                                        Task { await respond("decline") }
                                    }
                                    .buttonStyle(PolishedGlassButtonStyle())
                                    if event.canManageResponses == true {
                                        Button(i18n.t("notify")) {
                                            SDALHaptics.tap(.medium)
                                            Task { await notifyFollowers() }
                                        }
                                        .buttonStyle(PolishedGlassButtonStyle(emphasized: true))
                                    }
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(i18n.t("comments"))
                                .font(.headline)
                                .fontDesign(.rounded)
                            if comments.isEmpty {
                                Text(i18n.t("no_comments"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                LazyVStack(alignment: .leading, spacing: 10) {
                                    ForEach(comments) { comment in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("@\(comment.kadi ?? "user")")
                                                .font(.caption.weight(.semibold))
                                            Text(comment.comment ?? "")
                                                .font(.subheadline)
                                            if let createdAt = comment.createdAt {
                                                Text(createdAt)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(SDALTheme.softPanel)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        TextField(i18n.t("comment"), text: $text, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("send")) {
                            SDALHaptics.tap(.light)
                            Task { await add() }
                        }
                        .buttonStyle(PolishedGlassButtonStyle(emphasized: true))
                        .disabled(isSubmitting || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if let error {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
                .padding(16)
            }
            .navigationTitle(eventTitle ?? i18n.t("event"))
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } } }
            .task { await load() }
            .background(SDALTheme.appBackground.ignoresSafeArea())
        }
    }

    private func load() async {
        error = nil
        do {
            async let commentsRequest = api.fetchEventComments(id: eventId)
            comments = try await commentsRequest
            if event == nil {
                let events = try await api.fetchEvents(limit: 60)
                event = events.first(where: { $0.id == eventId })
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func refreshEvent() async {
        do {
            let events = try await api.fetchEvents(limit: 60)
            if let refreshed = events.first(where: { $0.id == eventId }) {
                event = refreshed
            }
        } catch {
            // Keep event detail usable even if refresh fails.
        }
    }

    private func respond(_ response: String) async {
        do {
            try await api.respondEvent(id: eventId, response: response)
            SDALHaptics.success()
            await refreshEvent()
            onChanged?()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func notifyFollowers() async {
        do {
            try await api.notifyEventFollowers(id: eventId)
            SDALHaptics.success()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func add() async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await api.addEventComment(id: eventId, comment: trimmed)
            text = ""
            comments = try await api.fetchEventComments(id: eventId)
            SDALHaptics.success()
            onChanged?()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct AnnouncementsHubView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [AnnouncementItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showCreate = false

    private let api = APIClient.shared

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
                            GlassCard {
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: "megaphone.fill")
                                        .font(.title2.weight(.semibold))
                                        .symbolRenderingMode(.hierarchical)
                                        .symbolEffect(.pulse, options: .repeating.speed(0.8))
                                        .foregroundStyle(SDALTheme.primary)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(i18n.t("announcements"))
                                            .font(.title2.weight(.bold))
                                            .fontDesign(.rounded)
                                        Text("Broadcast updates for alumni, moderators, and community organizers.")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            ForEach(items) { a in
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(a.title ?? "-")
                                            .font(.title3.weight(.bold))
                                            .fontDesign(.rounded)
                                        Text(a.body ?? "")
                                            .font(.subheadline)
                                        HStack(spacing: 8) {
                                            Text(a.createdAt ?? "")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if a.approved == false {
                                                Text("Pending approval")
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.orange.opacity(0.18))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) {
                                        SDALHaptics.tap(.light)
                                        Task { await deleteAnnouncement(a.id) }
                                    }
                                    Button(a.approved == true ? "Unapprove" : "Approve") {
                                        SDALHaptics.tap(.light)
                                        Task { await approveAnnouncement(a.id, approved: a.approved != true) }
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle(i18n.t("announcements"))
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
            .sheet(isPresented: $showCreate) {
                AnnouncementCreateSheet(onDone: {
                    showCreate = false
                    Task { await load() }
                })
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do { items = try await api.fetchAnnouncements() } catch { self.error = error.localizedDescription }
    }

    private func approveAnnouncement(_ id: Int, approved: Bool) async {
        do {
            try await api.approveAnnouncement(id: id, approved: approved)
            SDALHaptics.success()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteAnnouncement(_ id: Int) async {
        do {
            try await api.deleteAnnouncement(id: id)
            SDALHaptics.success()
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct AnnouncementCreateSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let onDone: () -> Void

    @State private var title = ""
    @State private var announcementText = ""
    @State private var item: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showCamera = false
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        let photoLabel = imageData == nil ? i18n.t("add_photo") : i18n.t("change_photo")
        NavigationStack {
            Form {
                TextField(i18n.t("title"), text: $title)
                TextField(i18n.t("body"), text: $announcementText, axis: .vertical)
                    .lineLimit(4...8)
                PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                    Label(photoLabel, systemImage: "photo")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        SDALHaptics.tap(.light)
                        showCamera = true
                    } label: {
                        Label(i18n.t("camera"), systemImage: "camera")
                    }
                }
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
                        .disabled(title.isEmpty || announcementText.isEmpty)
                }
            }
            .onChange(of: item) { _, newValue in
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

    private func save() async {
        do {
            if let imageData {
                try await api.createAnnouncementWithImage(title: title, body: announcementText, imageData: imageData)
            } else {
                try await api.createAnnouncement(title: title, body: announcementText)
            }
            SDALHaptics.success()
            onDone()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
