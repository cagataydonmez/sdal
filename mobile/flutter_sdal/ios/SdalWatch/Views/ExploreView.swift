import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    @State private var selectedTab = 0   // 0 = Üyeler, 1 = Çevrimiçi
    @State private var searchQuery = ""
    @State private var searchTask: Task<Void, Never>? = nil

    private var cookie:  String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    var body: some View {
        VStack(spacing: 0) {
            // ── Tab selector ─────────────────────────────────────────────
            exploreTabSelector

            // ── Content ──────────────────────────────────────────────────
            if selectedTab == 0 {
                memberSearchTab
            } else {
                onlineMembersTab
            }
        }
        .navigationTitle("Keşfet")
        .task {
            // Initial load
            if viewModel.membersState.value == nil {
                await viewModel.searchMembers(query: "", cookie: cookie, baseUrl: baseUrl)
            }
            if viewModel.onlineMembersState.value == nil {
                await viewModel.loadOnlineMembers(cookie: cookie, baseUrl: baseUrl)
            }
        }
    }

    // MARK: - Tab Selector

    private var exploreTabSelector: some View {
        HStack(spacing: 0) {
            exploreTab(title: "Üyeler",     idx: 0)
            exploreTab(title: "Çevrimiçi",  idx: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 6)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private func exploreTab(title: String, idx: Int) -> some View {
        Button {
            selectedTab = idx
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(selectedTab == idx ? Color.accentColor : Color.clear)
                .foregroundStyle(selectedTab == idx ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Members Search Tab

    private var memberSearchTab: some View {
        VStack(spacing: 0) {
            TextField("Ara...", text: $searchQuery)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .onChange(of: searchQuery) { q in
                    searchTask?.cancel()
                    searchTask = Task {
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        guard !Task.isCancelled else { return }
                        await viewModel.searchMembers(query: q, cookie: cookie, baseUrl: baseUrl)
                    }
                }

            Divider()

            memberListContent(state: viewModel.membersState, onRetry: {
                Task { await viewModel.searchMembers(query: searchQuery, cookie: cookie, baseUrl: baseUrl) }
            })
        }
        .refreshable {
            await viewModel.searchMembers(query: searchQuery, cookie: cookie, baseUrl: baseUrl)
        }
    }

    // MARK: - Online Members Tab

    private var onlineMembersTab: some View {
        memberListContent(state: viewModel.onlineMembersState, emptyText: "Şu an çevrimiçi üye yok", onRetry: {
            Task { await viewModel.loadOnlineMembers(cookie: cookie, baseUrl: baseUrl) }
        })
        .refreshable {
            await viewModel.loadOnlineMembers(cookie: cookie, baseUrl: baseUrl)
        }
    }

    // MARK: - Shared member list

    @ViewBuilder
    private func memberListContent(
        state: LoadState<[WatchMember]>,
        emptyText: String = "Sonuç bulunamadı",
        onRetry: @escaping () -> Void
    ) -> some View {
        switch state {
        case .idle, .loading:
            LoadingView()
        case .failed(let msg):
            ErrorRetryView(message: msg, onRetry: onRetry)
        case .loaded(let members):
            if members.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: selectedTab == 1 ? "wifi.slash" : "person.slash")
                        .foregroundStyle(.secondary)
                    Text(emptyText)
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(members) { member in
                    NavigationLink(destination: MemberProfileView(memberId: member.id)) {
                        MemberRow(member: member, showOnlineDot: selectedTab == 1)
                    }
                }
                .listStyle(.carousel)
            }
        }
    }
}

// MARK: - Member Row

struct MemberRow: View {
    let member: WatchMember
    var showOnlineDot: Bool = false

    private var isOnline: Bool { member.isOnline || showOnlineDot }

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(initials: member.initials, photoUrl: member.photo, size: 28)
                if isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1))
                        .offset(x: 1, y: 1)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(member.fullName.isEmpty ? "@\(member.handle)" : member.fullName)
                    .font(.system(size: 12, weight: .medium)).lineLimit(1)
                if !member.profession.isEmpty {
                    Text(member.profession)
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                } else if !member.city.isEmpty {
                    Text(member.city)
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
