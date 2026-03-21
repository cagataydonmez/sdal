import SwiftUI

struct AnnouncementsView: View {
    @State private var viewModel = AnnouncementsViewModel()
    @State private var showCreate = false

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.announcements.isEmpty {
                    LoadingView(message: "Loading announcements...")
                } else if viewModel.announcements.isEmpty {
                    EmptyStateView(icon: "megaphone", title: "No announcements", message: "Announcements from the community will appear here.")
                } else {
                    List(viewModel.announcements, selection: $viewModel.selectedAnnouncement) { item in
                        AnnouncementRowView(announcement: item).tag(item)
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)

            if let announcement = viewModel.selectedAnnouncement {
                AnnouncementDetailPanel(announcement: announcement)
            } else {
                EmptyStateView(icon: "megaphone", title: "Select an announcement", message: "Choose an announcement to read.")
            }
        }
        .navigationTitle("Announcements")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showCreate = true } label: {
                    Label("New Announcement", systemImage: "plus")
                }
                .help("Create a new announcement")

                Button { Task { await viewModel.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh announcements")
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateAnnouncementSheet { title, content in
                Task { await viewModel.createAnnouncement(title: title, body: content) }
            }
        }
        .task { await viewModel.loadAnnouncements() }
    }
}

struct AnnouncementRowView: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(announcement.title ?? "Announcement").font(.callout).fontWeight(.medium).lineLimit(2)
            HStack(spacing: 4) {
                if let author = announcement.creatorKadi {
                    Text(author).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(announcement.relativeTime).font(.caption2).foregroundStyle(.tertiary)
            }
            if announcement.approved?.boolValue != true {
                Text("Pending approval").font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct AnnouncementDetailPanel: View {
    let announcement: Announcement

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageURL = announcement.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                                .frame(maxHeight: 240).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 24).padding(.top, 16)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(announcement.title ?? "Announcement").font(.title2).fontWeight(.bold)
                    HStack {
                        if let author = announcement.creatorKadi {
                            Text("by \(author)").font(.caption).foregroundStyle(.secondary)
                        }
                        Text("· \(announcement.relativeTime)").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 24)

                Divider().padding(.horizontal, 24)

                if let text = announcement.body, !text.isEmpty {
                    Text(HTMLHelper.strip(text)).font(.body).lineSpacing(4).textSelection(.enabled)
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 24)
            }
        }
    }
}

struct CreateAnnouncementSheet: View {
    var onSubmit: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Text("New Announcement").font(.headline)
                Spacer()
                Button("Submit") {
                    onSubmit(title, content)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || content.isEmpty)
            }
            .padding()
            Divider()

            Form {
                TextField("Title", text: $title)
                Section("Content") {
                    TextEditor(text: $content).frame(minHeight: 150)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 380)
    }
}
