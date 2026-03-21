import SwiftUI

struct GroupsView: View {
    @State private var viewModel = GroupsViewModel()
    @State private var searchQuery = ""

    var filteredGroups: [SDALGroup] {
        if searchQuery.isEmpty { return viewModel.groups }
        return viewModel.groups.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchQuery) ||
            ($0.description ?? "").localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search groups", text: $searchQuery).textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(10)

                Divider()

                if viewModel.isLoading && viewModel.groups.isEmpty {
                    LoadingView(message: "Loading groups...")
                } else if filteredGroups.isEmpty {
                    EmptyStateView(icon: "person.3", title: "No groups found")
                } else {
                    List(filteredGroups, selection: Binding(
                        get: { viewModel.selectedGroup },
                        set: { group in
                            if let group {
                                Task { await viewModel.selectGroup(group) }
                            }
                        }
                    )) { group in
                        GroupRowView(group: group).tag(group)
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)

            if let group = viewModel.selectedGroup {
                GroupDetailPanel(
                    group: group,
                    detail: viewModel.groupDetail,
                    isLoading: viewModel.isLoadingDetail,
                    onJoin: { Task { await viewModel.joinGroup(group.id) } }
                )
            } else {
                EmptyStateView(icon: "person.3", title: "Select a group", message: "Choose a group to view its content.")
            }
        }
        .navigationTitle("Groups")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await viewModel.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh groups")
            }
        }
        .task { await viewModel.loadGroups() }
    }
}

struct GroupRowView: View {
    let group: SDALGroup

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: group.isPublic ? "person.3" : "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name ?? "Group").font(.callout).fontWeight(.medium).lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(group.memberCount) members").font(.caption).foregroundStyle(.secondary)
                    if group.isMember {
                        Text("· Joined").font(.caption).foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

struct GroupDetailPanel: View {
    let group: SDALGroup
    let detail: GroupDetailData?
    let isLoading: Bool
    var onJoin: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    if let coverURL = group.coverURL {
                        AsyncImage(url: coverURL) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                                    .frame(height: 160).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.name ?? "Group").font(.title2).fontWeight(.bold)
                            HStack(spacing: 8) {
                                Label(group.isPublic ? "Public" : "Private", systemImage: group.isPublic ? "globe" : "lock")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("· \(group.memberCount) members").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if !group.isMember {
                            Button("Join", action: onJoin)
                                .buttonStyle(.borderedProminent)
                                .help("Join this group")
                        }
                    }

                    if let desc = group.description, !desc.isEmpty {
                        Text(desc).font(.body).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 16)

                Divider().padding(.horizontal, 20)

                if isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else if let detail {
                    if let posts = detail.posts, !posts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Posts").font(.headline).padding(.horizontal, 20)
                            ForEach(posts) { post in
                                PostCardView(post: post)
                            }
                        }
                    }
                }

                Spacer(minLength: 24)
            }
        }
    }
}
