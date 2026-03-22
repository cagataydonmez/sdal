import Foundation

@MainActor
@Observable
final class AdminViewModel {
    var isAuthenticated = false
    var isLoading = false
    var error: String?

    // Users
    var users: [User] = []
    var usersMeta: AdminListMeta?
    var selectedUser: User?
    var userSearchQuery = ""
    var userFilter = "all"
    var isLoadingUsers = false

    // Content moderation
    var moderationPosts: [AdminContentItem] = []
    var moderationComments: [AdminContentItem] = []
    var moderationStories: [AdminContentItem] = []
    var moderationMeta: AdminListMeta?
    var isLoadingContent = false

    // Site controls
    var siteOpen = true
    var maintenanceMessage = ""
    var modules: [String: Bool] = [:]
    var isLoadingSiteControls = false

    // Active section
    var activeSection: AdminSection = .users

    enum AdminSection: String, CaseIterable, Identifiable {
        case users = "Users"
        case posts = "Posts"
        case comments = "Comments"
        case stories = "Stories"
        case siteControls = "Site Controls"
        case groups = "Groups"
        case events = "Events"
        case announcements = "Announcements"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .users: return "person.2"
            case .posts: return "text.bubble"
            case .comments: return "bubble.left"
            case .stories: return "camera"
            case .siteControls: return "gearshape"
            case .groups: return "person.3"
            case .events: return "calendar"
            case .announcements: return "megaphone"
            }
        }
    }

    // MARK: - Auth

    func checkAdminSession() async {
        do {
            let response: AdminSessionResponse = try await APIClient.shared.get("/api/admin/session")
            isAuthenticated = response.adminOk == true
        } catch {
            isAuthenticated = false
        }
    }

    func adminLogin(password: String) async throws {
        struct LoginBody: Encodable { let password: String }
        try await APIClient.shared.postVoid("/api/admin/login", body: LoginBody(password: password))
        isAuthenticated = true
    }

    // MARK: - Users

    func loadUsers(reset: Bool = false) async {
        isLoadingUsers = true
        error = nil
        do {
            var query: [String: String] = ["limit": "30"]
            if !userSearchQuery.isEmpty { query["q"] = userSearchQuery }
            if userFilter != "all" { query["filter"] = userFilter }
            if let page = usersMeta?.page, !reset {
                query["page"] = "\((page ?? 1) + 1)"
            }
            let response: AdminUserListResponse = try await APIClient.shared.get("/api/admin/users/lists", query: query)
            if reset {
                users = response.users ?? []
            } else {
                users.append(contentsOf: response.users ?? [])
            }
            usersMeta = response.meta
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingUsers = false
    }

    func searchUsers(_ query: String) {
        userSearchQuery = query
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            await loadUsers(reset: true)
        }
    }

    func deleteUser(_ userId: Int) async {
        do {
            try await APIClient.shared.delete("/api/admin/users/\(userId)")
            users.removeAll { $0.id == userId }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func verifyUser(_ userId: Int, verified: Bool) async {
        do {
            struct VerifyBody: Encodable { let userId: Int; let verified: String }
            try await APIClient.shared.postVoid(
                "/api/new/admin/verify",
                body: VerifyBody(userId: userId, verified: verified ? "1" : "0")
            )
            await loadUsers(reset: true)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Content Moderation

    func loadContentItems(type: AdminSection) async {
        isLoadingContent = true
        error = nil
        let path: String
        switch type {
        case .posts: path = "/api/new/admin/posts"
        case .comments: path = "/api/new/admin/comments"
        case .stories: path = "/api/new/admin/stories"
        default: isLoadingContent = false; return
        }

        do {
            let response: AdminContentListResponse = try await APIClient.shared.get(path, query: ["limit": "30"])
            let items = response.items ?? []
            switch type {
            case .posts: moderationPosts = items
            case .comments: moderationComments = items
            case .stories: moderationStories = items
            default: break
            }
            moderationMeta = response.meta
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingContent = false
    }

    func deleteContentItem(type: AdminSection, id: Int) async {
        let path: String
        switch type {
        case .posts: path = "/api/new/admin/posts/\(id)"
        case .comments: path = "/api/new/admin/comments/\(id)"
        case .stories: path = "/api/new/admin/stories/\(id)"
        default: return
        }

        do {
            try await APIClient.shared.delete(path)
            switch type {
            case .posts: moderationPosts.removeAll { $0.id == id }
            case .comments: moderationComments.removeAll { $0.id == id }
            case .stories: moderationStories.removeAll { $0.id == id }
            default: break
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Site Controls

    func loadSiteControls() async {
        isLoadingSiteControls = true
        do {
            let response: SiteControlsResponse = try await APIClient.shared.get("/api/admin/site-controls")
            siteOpen = response.siteOpen ?? true
            maintenanceMessage = response.maintenanceMessage ?? ""
            modules = response.modules ?? [:]
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingSiteControls = false
    }

    func saveSiteControls() async {
        do {
            struct UpdateBody: Encodable {
                let siteOpen: Bool
                let maintenanceMessage: String
                let modules: [String: Bool]
            }
            try await APIClient.shared.requestVoid("PUT", path: "/api/admin/site-controls", body: UpdateBody(
                siteOpen: siteOpen, maintenanceMessage: maintenanceMessage, modules: modules
            ))
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Announcements/Events admin

    func approveEvent(_ eventId: Int) async {
        do {
            try await APIClient.shared.postVoid("/api/new/events/\(eventId)/approve")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteEvent(_ eventId: Int) async {
        do {
            try await APIClient.shared.delete("/api/new/events/\(eventId)")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func approveAnnouncement(_ id: Int) async {
        do {
            try await APIClient.shared.postVoid("/api/new/announcements/\(id)/approve")
        } catch {
            self.error = error.localizedDescription
        }
    }

    func deleteAnnouncement(_ id: Int) async {
        do {
            try await APIClient.shared.delete("/api/new/announcements/\(id)")
        } catch {
            self.error = error.localizedDescription
        }
    }
}
