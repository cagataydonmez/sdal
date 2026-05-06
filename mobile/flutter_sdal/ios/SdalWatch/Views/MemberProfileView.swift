import SwiftUI

struct MemberProfileView: View {
    let memberId: Int

    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    @State private var member: WatchMember? = nil
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var isFollowing = false
    @State private var followInProgress = false
    @State private var navigateToNewConversation = false

    private var cookie: String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    var body: some View {
        Group {
            if isLoading {
                LoadingView()
            } else if let err = loadError {
                ErrorRetryView(message: err) { Task { await load() } }
            } else if let m = member {
                profileContent(m)
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func profileContent(_ m: WatchMember) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                AvatarView(initials: m.initials, photoUrl: m.photo, size: 48)

                VStack(spacing: 3) {
                    Text(m.fullName.isEmpty ? "@\(m.handle)" : m.fullName)
                        .font(.headline).lineLimit(2).multilineTextAlignment(.center)
                    if !m.handle.isEmpty {
                        Text("@\(m.handle)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                // Info chips
                VStack(alignment: .leading, spacing: 4) {
                    if !m.profession.isEmpty {
                        infoRow(icon: "briefcase", text: m.profession)
                    }
                    if !m.city.isEmpty {
                        infoRow(icon: "mappin", text: m.city)
                    }
                    if !m.graduationYear.isEmpty {
                        infoRow(icon: "graduationcap", text: "\(m.graduationYear) mezunu")
                    }
                }

                HStack(spacing: 8) {
                    Button(isFollowing ? "Takip ediliyor" : "Takip et") {
                        Task { await toggleFollow(m) }
                    }
                    .font(.caption2)
                    .buttonStyle(.borderedProminent)
                    .disabled(followInProgress)
                    .tint(isFollowing ? .gray : .accentColor)

                    NavigationLink(destination: newConvDestination(m)) {
                        Label("Mesaj at", systemImage: "bubble.right")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func newConvDestination(_ m: WatchMember) -> some View {
        NewConversationView(preselectedContact: WatchContact(
            prebuilt: m.id,
            firstName: m.firstName,
            lastName: m.lastName,
            handle: m.handle,
            photo: m.photo
        ))
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            let m = try await viewModel.fetchMember(id: memberId, cookie: cookie, baseUrl: baseUrl)
            member = m
            isFollowing = m.following
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleFollow(_ m: WatchMember) async {
        followInProgress = true
        do {
            try await viewModel.toggleFollow(memberId: m.id, cookie: cookie, baseUrl: baseUrl)
            isFollowing.toggle()
            member?.following = isFollowing
        } catch {}
        followInProgress = false
    }
}

// Convenience init for WatchContact built from member fields
extension WatchContact {
    init(prebuilt id: Int, firstName: String, lastName: String, handle: String, photo: String) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.handle = handle
        self.photo = photo
    }
}
