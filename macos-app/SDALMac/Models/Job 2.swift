import Foundation

struct Job: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let company: String?
    let description: String?
    let location: String?
    let jobType: String?
    let salaryMin: Int?
    let salaryMax: Int?
    let createdAt: String?
    let posterId: Int?
    let posterKadi: String?
    let posterIsim: String?
    let posterSoyisim: String?
    let myApplicationId: Int?
    let myApplicationStatus: String?

    var posterDisplayName: String {
        let first = posterIsim ?? ""
        let last = posterSoyisim ?? ""
        let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (posterKadi ?? "User") : full
    }

    var relativeTime: String {
        guard let createdAt else { return "" }
        return DateFormatter.relativeString(from: createdAt)
    }

    var hasApplied: Bool { myApplicationId != nil }

    var salaryRange: String? {
        if let min = salaryMin, let max = salaryMax {
            return "\(min.formatted()) - \(max.formatted())"
        } else if let min = salaryMin {
            return "\(min.formatted())+"
        } else if let max = salaryMax {
            return "Up to \(max.formatted())"
        }
        return nil
    }

    var jobTypeLabel: String {
        switch jobType {
        case "full_time": return "Full-time"
        case "part_time": return "Part-time"
        case "contract": return "Contract"
        case "internship": return "Internship"
        case "freelance": return "Freelance"
        default: return jobType ?? ""
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, company, description, location
        case jobType = "job_type"
        case salaryMin = "salary_min"
        case salaryMax = "salary_max"
        case createdAt = "created_at"
        case posterId = "poster_id"
        case posterKadi = "poster_kadi"
        case posterIsim = "poster_isim"
        case posterSoyisim = "poster_soyisim"
        case myApplicationId = "my_application_id"
        case myApplicationStatus = "my_application_status"
    }
}

struct JobsResponse: Codable {
    let items: [Job]?
    let hasMore: Bool?
}
