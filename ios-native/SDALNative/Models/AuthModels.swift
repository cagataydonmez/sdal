import Foundation

struct SessionEnvelope: Decodable {
    let user: SessionUser?
}

struct HealthResponse: Decodable {
    let ok: Bool?
    let dbPath: String?
}

struct ActivationResponse: Decodable {
    let ok: Bool?
    let kadi: String?
}

struct RegisterPreviewResponse: Decodable {
    let ok: Bool?
    let fields: RegisterPreviewFields?
}

struct RegisterPreviewFields: Decodable {
    let kadi: String?
    let email: String?
    let mezuniyetyili: String?
    let isim: String?
    let soyisim: String?
}

struct SessionUser: Decodable {
    let id: Int?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let email: String?
    let photo: String?
}
