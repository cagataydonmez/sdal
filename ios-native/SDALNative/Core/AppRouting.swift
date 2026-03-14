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

enum AppCommunityDestination: String, Identifiable {
    case events
    case announcements
    case groups
    case games

    var id: String { rawValue }
}

enum AppMessagesDestination: String {
    case chat
}

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab: AppTab = .feed
    @Published var openMessageId: Int?
    @Published var openCommunityDestination: AppCommunityDestination?
    @Published var openMessagesDestination: AppMessagesDestination?

    func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        let path = userInfo["path"] as? String
        let screen = userInfo["screen"] as? String
        let type = userInfo["type"] as? String

        if let path {
            route(path: path)
            return
        }

        if let screen {
            route(path: screen)
            return
        }

        if let type {
            switch type.lowercased() {
            case "message", "mention_message":
                selectedTab = .messages
                if let rawId = userInfo["entity_id"] {
                    openMessageId = Int("\(rawId)")
                }
            case "like", "comment", "mention_post", "post":
                selectedTab = .feed
            case "group_invite", "notification":
                selectedTab = .notifications
            default:
                break
            }
        }
    }

    private func route(path: String) {
        let normalized = path.lowercased()
        if normalized.contains("/chat") {
            selectedTab = .messages
            openMessagesDestination = .chat
            return
        }
        if normalized.contains("/new/messenger") || normalized.contains("/messenger") {
            selectedTab = .messenger
            return
        }
        if normalized.contains("/notifications") {
            selectedTab = .notifications
            return
        }
        if normalized.contains("/messages/") {
            selectedTab = .messages
            let idPart = normalized.split(separator: "/").last
            if let idPart, let id = Int(idPart) {
                openMessageId = id
            }
            return
        }
        if normalized.contains("/messages") {
            selectedTab = .messages
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
}
