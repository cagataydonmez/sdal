import SwiftUI

struct MembersView: View {
    @State private var viewModel = MembersViewModel()
    @State private var selectedMember: User?

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search members", text: Binding(
                        get: { viewModel.searchQuery },
                        set: { viewModel.search($0) }
                    ))
                    .textFieldStyle(.plain)
                    if !viewModel.searchQuery.isEmpty {
                        Button { viewModel.search("") } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear search")
                    }
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(10)

                if viewModel.total > 0 {
                    HStack {
                        Text("\(viewModel.total) members").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 12).padding(.bottom, 6)
                }

                Divider()

                if viewModel.isLoading && viewModel.members.isEmpty {
                    LoadingView(message: "Loading members...")
                } else if viewModel.members.isEmpty {
                    EmptyStateView(icon: "person.slash", title: "No members found", message: "Try a different search query.")
                } else {
                    List(viewModel.members, selection: $selectedMember) { member in
                        MemberRowView(member: member).tag(member)
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 260, idealWidth: 300, maxWidth: 400)

            if let member = selectedMember {
                MemberDetailView(member: member)
            } else {
                EmptyStateView(icon: "person.crop.circle", title: "Select a member", message: "Choose a member from the list to view their profile.")
            }
        }
        .navigationTitle("Members")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await viewModel.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh member list (⌘R)")
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .task { await viewModel.loadMembers(reset: true) }
    }
}

struct MemberRowView: View {
    let member: User

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(url: member.photoURL, initials: member.initials, size: 34, isOnline: member.isOnline)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(member.displayName).font(.callout).fontWeight(.medium).lineLimit(1)
                    if member.isVerified {
                        Image(systemName: "checkmark.seal.fill").font(.caption2).foregroundStyle(.blue)
                    }
                }
                HStack(spacing: 4) {
                    if let year = member.mezuniyetyili, !year.isEmpty {
                        Text("'\(year.suffix(2))").font(.caption).foregroundStyle(.secondary)
                    }
                    if let company = member.sirket, !company.isEmpty {
                        Text("·").foregroundStyle(.quaternary)
                        Text(company).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
