import Foundation

struct EventResponseCounts: Codable, Hashable {
    let attend: Int?
    let decline: Int?
    let maybe: Int?
}

struct Event: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let description: String?
    let location: String?
    let image: String?
    let createdBy: Int?
    let creatorKadi: String?
    let startsAt: String?
    let endsAt: String?
    let approved: IntOrBool?
    let responseCounts: EventResponseCounts?
    let myResponse: String?
    let createdAt: String?

    var imageURL: URL? {
        guard let image, !image.isEmpty else { return nil }
        if image.hasPrefix("http") { return URL(string: image) }
        return URL(string: "\(APIConfig.baseURL)/\(image)")
    }

    var formattedDate: String {
        guard let startsAt else { return "" }
        return DateFormatter.relativeString(from: startsAt)
    }

    var attendeeCount: Int {
        responseCounts?.attend ?? 0
    }

    var isUpcoming: Bool {
        guard let startsAt else { return false }
        let formatters: [ISO8601DateFormatter] = {
            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            return [f1, f2]
        }()
        for fmt in formatters {
            if let date = fmt.date(from: startsAt) { return date > Date() }
        }
        return true
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, location, image, approved
        case createdBy = "created_by"
        case creatorKadi = "creator_kadi"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case responseCounts = "response_counts"
        case myResponse = "my_response"
        case createdAt = "created_at"
    }
}

struct EventsResponse: Codable {
    let items: [Event]?
    let hasMore: Bool?
}

struct EventRespondResponse: Codable {
    let ok: Bool?
    let myResponse: String?
    let counts: EventResponseCounts?
}
