import Foundation
import SwiftUI

enum AppTab: Hashable {
    case feed
    case explore
    case messenger
    case messages
    case notifications
    case profile
}

enum AppCommunityDestination: String, Identifiable, Equatable {
    case events
    case announcements
    case groups
    case games

    var id: String { rawValue }
}

enum AppMessagesDestination: String, Equatable {
    case chat
}

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: AppTab = .feed
    @Published var openMessageId: Int?
    @Published var openPostId: Int?
    @Published var openEventId: Int?
    @Published var openPhotoId: Int?
    @Published var openMemberId: Int?
    @Published var openGroupId: Int?
    @Published var openMessengerThreadId: Int?
    @Published var openCommunityDestination: AppCommunityDestination?
    @Published var openMessagesDestination: AppMessagesDestination?

    func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        if let path = normalizedPath(from: userInfo) {
            route(path: path)
        }
    }

    func handleDeepLink(_ url: URL) {
        if url.scheme?.lowercased() == "sdal" {
            let host = url.host?.lowercased() ?? ""
            let path = ([host] + url.pathComponents.filter { $0 != "/" }).joined(separator: "/")
            route(path: "/" + path)
            return
        }
        route(path: url.absoluteString)
    }

    private func route(path: String) {
        let normalized = path.lowercased()
        resetTransientDestinations()
        if normalized.contains("/admin") {
            selectedTab = .profile
            return
        }
        if let postId = routeID(in: normalized, marker: "/posts/") ?? routeID(in: normalized, marker: "?post=") {
            selectedTab = .feed
            openPostId = postId
            return
        }
        if let memberId = routeID(in: normalized, marker: "/explore/member/") ?? routeID(in: normalized, marker: "/members/") {
            selectedTab = .explore
            openMemberId = memberId
            return
        }
        if let photoId = routeID(in: normalized, marker: "/photos/") ?? routeID(in: normalized, marker: "/albums/photo/") {
            selectedTab = .explore
            openPhotoId = photoId
            return
        }
        if normalized.contains("/chat") {
            selectedTab = .messages
            openMessagesDestination = .chat
            return
        }
        if normalized.contains("/new/messenger") || normalized.contains("/messenger") {
            selectedTab = .messenger
            openMessengerThreadId = routeID(in: normalized, marker: "/messenger/threads/")
            return
        }
        if normalized.contains("/notifications") {
            selectedTab = .notifications
            return
        }
        if normalized.contains("/messages/") {
            selectedTab = .messages
            openMessageId = routeID(in: normalized, marker: "/messages/")
            return
        }
        if normalized.contains("/messages") {
            selectedTab = .messages
            return
        }
        if let eventId = routeID(in: normalized, marker: "/events/") {
            selectedTab = .feed
            openEventId = eventId
            return
        }
        if normalized.contains("/events") {
            selectedTab = .feed
            openCommunityDestination = .events
            return
        }
        if normalized.contains("/announcements") {
            selectedTab = .feed
            openCommunityDestination = .announcements
            return
        }
        if let groupId = routeID(in: normalized, marker: "/groups/") {
            selectedTab = .feed
            openCommunityDestination = .groups
            openGroupId = groupId
            return
        }
        if normalized.contains("/groups") {
            selectedTab = .feed
            openCommunityDestination = .groups
            return
        }
        if normalized.contains("/games") {
            selectedTab = .feed
            openCommunityDestination = .games
            return
        }
        if normalized.contains("/explore") {
            selectedTab = .explore
            return
        }
        if normalized.contains("/profile") {
            selectedTab = .profile
            return
        }
        selectedTab = .feed
    }

    private func resetTransientDestinations() {
        openMessageId = nil
        openPostId = nil
        openEventId = nil
        openPhotoId = nil
        openMemberId = nil
        openGroupId = nil
        openMessengerThreadId = nil
        openCommunityDestination = nil
        openMessagesDestination = nil
    }

    private func routeID(in path: String, marker: String) -> Int? {
        guard let range = path.range(of: marker) else {
            return nil
        }
        let suffix = path[range.upperBound...]
        let candidate = suffix.split(separator: "/").first
        guard let candidate else {
            return nil
        }
        let digits = candidate.prefix { $0.isNumber }
        guard !digits.isEmpty else {
            return nil
        }
        return Int(digits)
    }

    private func normalizedPath(from userInfo: [AnyHashable: Any]) -> String? {
        if let path = userInfo["path"] as? String {
            return path
        }
        if let screen = userInfo["screen"] as? String {
            return screen
        }

        let type = (userInfo["type"] as? String)?.lowercased() ?? ""
        let entityId = integerValue(userInfo["entity_id"])
        let sourceUserId = integerValue(userInfo["source_user_id"]) ?? integerValue(userInfo["sourceUserId"])
        let threadId = integerValue(userInfo["thread_id"]) ?? integerValue(userInfo["threadId"])

        switch type {
        case "message", "mention_message":
            if let entityId { return "/messages/\(entityId)" }
            return "/messages"
        case "messenger:new", "messenger:read", "messenger:delivered":
            if let threadId { return "/messenger/threads/\(threadId)" }
            return "/messenger"
        case "like", "comment", "mention_post", "post":
            if let entityId { return "/posts/\(entityId)" }
            return "/feed"
        case "mention_photo", "photo_comment":
            if let entityId { return "/photos/\(entityId)" }
            return "/explore"
        case "mention_event", "event_comment", "event_invite", "event_response", "event_reminder", "event_starts_soon":
            if let entityId { return "/events/\(entityId)" }
            return "/events"
        case "mention_group", "group_join_request", "group_join_approved", "group_join_rejected", "group_invite":
            if let entityId { return "/groups/\(entityId)" }
            return "/groups"
        case "follow":
            if let targetId = sourceUserId ?? entityId {
                return "/members/\(targetId)"
            }
            return "/explore"
        case "notification":
            return "/notifications"
        default:
            return nil
        }
    }

    private func integerValue(_ value: Any?) -> Int? {
        guard let value else {
            return nil
        }
        if let value = value as? Int {
            return value
        }
        return Int("\(value)")
    }
}
