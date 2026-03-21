import Foundation

// MARK: - Flexible JSON Decoding Helpers

enum IntOrBool: Codable, Hashable {
    case int(Int)
    case bool(Bool)

    var boolValue: Bool {
        switch self {
        case .int(let v): return v != 0
        case .bool(let v): return v
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else {
            self = .bool(false)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        }
    }
}

enum StringOrInt: Codable, Hashable {
    case string(String)
    case int(Int)

    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        }
    }

    var intValue: Int? {
        switch self {
        case .string(let s): return Int(s)
        case .int(let i): return i
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode(Int.self) {
            self = .int(v)
        } else {
            self = .string("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        }
    }
}

// MARK: - User Model

struct User: Codable, Identifiable, Hashable {
    let id: Int
    let kadi: String?
    let email: String?
    let isim: String?
    let soyisim: String?
    let resim: String?
    let photo: String?
    let mezuniyetyili: String?
    let sehir: String?
    let sirket: String?
    let unvan: String?
    let uzmanlik: String?
    let universite: String?
    let universiteBolum: String?
    let linkedinUrl: String?
    let meslek: String?
    let websitesi: String?
    let imza: String?
    let role: String?
    let admin: IntOrBool?
    let verified: IntOrBool?
    let state: String?
    let oauthProvider: String?
    let mentorOptIn: IntOrBool?
    let mentorKonulari: String?
    let online: IntOrBool?
    let aktiv: IntOrBool?
    let yasak: IntOrBool?
    let mailkapali: IntOrBool?
    let dogumgun: Int?
    let dogumay: Int?
    let dogumyil: Int?
    let ilktarih: String?
    let sontarih: String?
    let aktivasyon: String?
    let verificationStatus: String?
    let engagementScore: Double?
    let trustBadges: [String]?

    var displayName: String {
        let first = isim ?? ""
        let last = soyisim ?? ""
        let full = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? (kadi ?? "User") : full
    }

    var initials: String {
        let first = isim?.prefix(1) ?? ""
        let last = soyisim?.prefix(1) ?? ""
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? "?" : result
    }

    var photoURL: URL? {
        let img = photo ?? resim
        guard let img, !img.isEmpty else { return nil }
        if img.hasPrefix("http") { return URL(string: img) }
        return URL(string: "\(APIConfig.baseURL)/\(img)")
    }

    var isAdmin: Bool { admin?.boolValue == true || role == "admin" || role == "root" }
    var isMod: Bool { role == "mod" || isAdmin }
    var isOnline: Bool { online?.boolValue == true }
    var isVerified: Bool { verified?.boolValue == true }
    var isMentor: Bool { mentorOptIn?.boolValue == true }

    enum CodingKeys: String, CodingKey {
        case id, kadi, email, isim, soyisim, resim, photo, mezuniyetyili
        case sehir, sirket, unvan, uzmanlik, universite, role, admin
        case verified, state, online, meslek, websitesi, imza
        case aktiv, yasak, mailkapali, dogumgun, dogumay, dogumyil
        case ilktarih, sontarih, aktivasyon
        case universiteBolum = "universite_bolum"
        case linkedinUrl = "linkedin_url"
        case oauthProvider = "oauth_provider"
        case mentorOptIn = "mentor_opt_in"
        case mentorKonulari = "mentor_konulari"
        case verificationStatus = "verification_status"
        case engagementScore = "engagement_score"
        case trustBadges = "trust_badges"
    }
}

// MARK: - Session

struct SessionResponse: Codable {
    let user: User?
}

// MARK: - Auth

struct LoginRequest: Codable {
    let kadi: String
    let sifre: String
}

struct LoginResponse: Codable {
    let user: User?
    let needsProfile: Bool?
    let error: String?
    let message: String?
}

// MARK: - Member List

struct MemberListResponse: Codable {
    let rows: [User]?
    let page: Int?
    let pages: Int?
    let total: Int?
    let pageSize: Int?
    let term: String?
}

struct MemberDetailResponse: Codable {
    let row: User?
}

// MARK: - Profile

struct ProfileResponse: Codable {
    let user: User?
}

struct ProfileUpdateResponse: Codable {
    let ok: Bool?
    let user: User?
}

struct ProfileUpdateRequest: Codable {
    let isim: String
    let soyisim: String
    let sehir: String
    let meslek: String
    let websitesi: String
    let universite: String
    let sirket: String
    let unvan: String
    let uzmanlik: String
    let linkedin_url: String
    let universite_bolum: String
    let mentor_opt_in: Bool
    let mentor_konulari: String
    let imza: String
    let mailkapali: Int
    let dogumgun: Int
    let dogumay: Int
    let dogumyil: Int
}

// MARK: - Online Members

struct OnlineMembersResponse: Codable {
    let items: [User]?
    let count: Int?
}
