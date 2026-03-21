import SwiftUI

struct AdminView: View {
    @State private var viewModel = AdminViewModel()
    @State private var adminPassword = ""
    @State private var loginError: String?

    var body: some View {
        if viewModel.isAuthenticated {
            adminContent
        } else {
            adminLogin
        }
    }

    private var adminLogin: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("Admin Panel").font(.title2).fontWeight(.semibold)
            Text("Enter admin password to continue.").font(.callout).foregroundStyle(.secondary)

            VStack(spacing: 12) {
                SecureField("Admin Password", text: $adminPassword)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)
                    .onSubmit { loginAdmin() }

                if let error = loginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }

                Button("Sign In") { loginAdmin() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(adminPassword.isEmpty)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await viewModel.checkAdminSession() }
    }

    private func loginAdmin() {
        loginError = nil
        Task {
            do {
                try await viewModel.adminLogin(password: adminPassword)
            } catch {
                loginError = "Invalid password"
            }
        }
    }

    private var adminContent: some View {
        HSplitView {
            // Sidebar
            List(AdminViewModel.AdminSection.allCases, selection: Binding(
                get: { viewModel.activeSection },
                set: { viewModel.activeSection = $0 }
            )) { section in
                Label(section.rawValue, systemImage: section.icon).tag(section)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160, idealWidth: 180, maxWidth: 220)

            // Content
            adminSectionContent
        }
        .navigationTitle("Admin")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await refreshCurrentSection() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh current section")
            }
        }
    }

    @ViewBuilder
    private var adminSectionContent: some View {
        switch viewModel.activeSection {
        case .users:
            AdminUsersSection(viewModel: viewModel)
        case .posts:
            AdminContentSection(viewModel: viewModel, type: .posts, items: viewModel.moderationPosts)
        case .comments:
            AdminContentSection(viewModel: viewModel, type: .comments, items: viewModel.moderationComments)
        case .stories:
            AdminContentSection(viewModel: viewModel, type: .stories, items: viewModel.moderationStories)
        case .siteControls:
            AdminSiteControlsSection(viewModel: viewModel)
        case .groups:
            AdminContentSection(viewModel: viewModel, type: .groups, items: [])
        case .events:
            AdminContentSection(viewModel: viewModel, type: .events, items: [])
        case .announcements:
            AdminContentSection(viewModel: viewModel, type: .announcements, items: [])
        }
    }

    private func refreshCurrentSection() async {
        switch viewModel.activeSection {
        case .users: await viewModel.loadUsers(reset: true)
        case .posts, .comments, .stories: await viewModel.loadContentItems(type: viewModel.activeSection)
        case .siteControls: await viewModel.loadSiteControls()
        default: break
        }
    }
}

// MARK: - Users Section

struct AdminUsersSection: View {
    @Bindable var viewModel: AdminViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search users", text: Binding(
                    get: { viewModel.userSearchQuery },
                    set: { viewModel.searchUsers($0) }
                ))
                .textFieldStyle(.plain)

                Picker("Filter", selection: $viewModel.userFilter) {
                    Text("All").tag("all")
                    Text("Active").tag("active")
                    Text("Banned").tag("banned")
                    Text("Unverified").tag("unverified")
                }
                .frame(width: 120)
                .onChange(of: viewModel.userFilter) { _, _ in
                    Task { await viewModel.loadUsers(reset: true) }
                }
            }
            .padding(10)

            Divider()

            if viewModel.isLoadingUsers && viewModel.users.isEmpty {
                LoadingView(message: "Loading users...")
            } else if viewModel.users.isEmpty {
                EmptyStateView(icon: "person.slash", title: "No users found")
            } else {
                Table(viewModel.users) {
                    TableColumn("ID") { user in Text("\(user.id)").font(.caption).monospacedDigit() }
                        .width(50)
                    TableColumn("Username") { user in
                        HStack(spacing: 6) {
                            AvatarView(url: user.photoURL, initials: user.initials, size: 22)
                            Text(user.kadi ?? "—").font(.callout)
                        }
                    }
                    .width(min: 120, ideal: 160)
                    TableColumn("Name") { user in Text(user.displayName).font(.callout) }
                        .width(min: 120, ideal: 160)
                    TableColumn("Role") { user in
                        Text(user.role ?? "user").font(.caption)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(roleColor(user.role).opacity(0.15), in: Capsule())
                    }
                    .width(60)
                    TableColumn("Verified") { user in
                        Image(systemName: user.isVerified ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(user.isVerified ? Color.green : Color.secondary)
                    }
                    .width(60)
                    TableColumn("Actions") { user in
                        HStack(spacing: 4) {
                            Button {
                                Task { await viewModel.verifyUser(user.id, verified: !user.isVerified) }
                            } label: {
                                Image(systemName: user.isVerified ? "xmark.seal" : "checkmark.seal")
                            }
                            .buttonStyle(.plain)
                            .help(user.isVerified ? "Remove verification" : "Verify user")

                            Button {
                                Task { await viewModel.deleteUser(user.id) }
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete user")
                        }
                    }
                    .width(70)
                }
            }

            if let meta = viewModel.usersMeta {
                HStack {
                    Text("Page \(meta.page ?? 1) of \(meta.pages ?? 1) · \(meta.total ?? 0) total")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.bar)
            }
        }
        .task { await viewModel.loadUsers(reset: true) }
    }

    private func roleColor(_ role: String?) -> Color {
        switch role {
        case "admin", "root": return .red
        case "mod": return .orange
        default: return .gray
        }
    }
}

// MARK: - Content Moderation Section

struct AdminContentSection: View {
    @Bindable var viewModel: AdminViewModel
    let type: AdminViewModel.AdminSection
    let items: [AdminContentItem]

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingContent && items.isEmpty {
                LoadingView(message: "Loading...")
            } else if items.isEmpty {
                EmptyStateView(icon: type.icon, title: "No \(type.rawValue.lowercased()) to moderate")
            } else {
                List {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.authorName).font(.caption).fontWeight(.semibold)
                                Text(item.displayContent).font(.callout).lineLimit(3).textSelection(.enabled)
                                if let date = item.createdAt {
                                    Text(DateFormatter.relativeString(from: date)).font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Button {
                                Task { await viewModel.deleteContentItem(type: type, id: item.id) }
                            } label: {
                                Image(systemName: "trash").foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete this \(type.rawValue.lowercased().dropLast())")
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .task { await viewModel.loadContentItems(type: type) }
    }
}

// MARK: - Site Controls Section

struct AdminSiteControlsSection: View {
    @Bindable var viewModel: AdminViewModel

    var body: some View {
        Form {
            if viewModel.isLoadingSiteControls {
                Section { LoadingView(message: "Loading...") }
            } else {
                Section("Site Status") {
                    Toggle("Site Open", isOn: $viewModel.siteOpen)
                    TextField("Maintenance Message", text: $viewModel.maintenanceMessage)
                }

                Section("Modules") {
                    ForEach(Array(viewModel.modules.keys.sorted()), id: \.self) { key in
                        Toggle(key, isOn: Binding(
                            get: { viewModel.modules[key] ?? true },
                            set: { viewModel.modules[key] = $0 }
                        ))
                    }
                }

                Section {
                    Button("Save Changes") {
                        Task { await viewModel.saveSiteControls() }
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Save site control changes")
                }
            }
        }
        .formStyle(.grouped)
        .task { await viewModel.loadSiteControls() }
    }
}
