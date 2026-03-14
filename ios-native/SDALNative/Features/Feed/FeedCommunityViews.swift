import SwiftUI
import PhotosUI
import UIKit

struct EventsHubView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [EventItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var createOpen = false
    @State private var selectedEvent: EventItem?

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
                            ForEach(items) { e in
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(e.title ?? "-")
                                            .font(.headline)
                                        if let desc = e.description, !desc.isEmpty { Text(desc).font(.subheadline) }
                                        HStack(spacing: 8) {
                                            Text(e.startsAt ?? "")
                                            Text("•")
                                            Text(e.location ?? "-")
                                        }
                                        .font(.caption)
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
                                            Button(i18n.t("attend")) { Task { await respond(e.id, "attend") } }
                                                .buttonStyle(.bordered)
                                            Button(i18n.t("decline")) { Task { await respond(e.id, "decline") } }
                                                .buttonStyle(.bordered)
                                            Button(i18n.t("notify")) { Task { await notify(e.id) } }
                                                .buttonStyle(.bordered)
                                            Button(i18n.t("comments")) { selectedEvent = e }
                                                .buttonStyle(.borderedProminent)
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
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button(i18n.t("create")) { createOpen = true } }
            }
            .task { if items.isEmpty { await load() } }
            .sheet(isPresented: $createOpen) {
                EventCreateSheet(onDone: {
                    createOpen = false
                    Task { await load() }
                })
            }
            .sheet(item: $selectedEvent) { event in
                EventCommentsSheet(event: event)
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do { items = try await api.fetchEvents() } catch { self.error = error.localizedDescription }
    }

    private func respond(_ id: Int, _ value: String) async {
        do { try await api.respondEvent(id: id, response: value); await load() } catch { self.error = error.localizedDescription }
    }

    private func notify(_ id: Int) async {
        do { try await api.notifyEventFollowers(id: id) } catch { self.error = error.localizedDescription }
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
        NavigationStack {
            Form {
                TextField(i18n.t("title"), text: $title)
                TextField(i18n.t("description"), text: $description, axis: .vertical)
                TextField(i18n.t("location"), text: $location)
                TextField(i18n.t("starts_at_iso"), text: $startsAt)
                TextField(i18n.t("ends_at_iso"), text: $endsAt)
                PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                    Label(imageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label(i18n.t("camera"), systemImage: "camera")
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("create")) { Task { await save() } }
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

    let event: EventItem
    @State private var comments: [EventComment] = []
    @State private var text = ""
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                List(comments) { c in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("@\(c.kadi ?? "user")").font(.caption.bold())
                        Text(c.comment ?? "")
                    }
                }
                HStack {
                    TextField(i18n.t("comment"), text: $text)
                        .textFieldStyle(.roundedBorder)
                    Button(i18n.t("send")) { Task { await add() } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle(event.title ?? i18n.t("event"))
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        do { comments = try await api.fetchEventComments(id: event.id) } catch { self.error = error.localizedDescription }
    }

    private func add() async {
        do {
            try await api.addEventComment(id: event.id, comment: text)
            text = ""
            comments = try await api.fetchEventComments(id: event.id)
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
                            ForEach(items) { a in
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(a.title ?? "-")
                                            .font(.headline)
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
                                    Button("Delete", role: .destructive) { Task { await deleteAnnouncement(a.id) } }
                                    Button(a.approved == true ? "Unapprove" : "Approve") {
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
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { Button(i18n.t("create")) { showCreate = true } }
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
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteAnnouncement(_ id: Int) async {
        do {
            try await api.deleteAnnouncement(id: id)
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
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Body", text: $announcementText, axis: .vertical)
                    .lineLimit(4...8)
                PhotosPicker(selection: $item, matching: .images, photoLibrary: .shared()) {
                    Label(imageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label(i18n.t("camera"), systemImage: "camera")
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { Task { await save() } }
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
            onDone()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
