import Foundation

struct ProfileEnvelope: Decodable {
    let user: Profile?
}

struct Profile: Decodable {
    let id: Int?
    let kadi: String?
    let isim: String?
    let soyisim: String?
    let email: String?
    let mezuniyetyili: String?
    let sehir: String?
    let meslek: String?
    let websitesi: String?
    let universite: String?
    let imza: String?
    let mailkapali: Bool?
    let photo: String?

    private enum CodingKeys: String, CodingKey {
        case id, kadi, isim, soyisim, email, mezuniyetyili, sehir, meslek, websitesi, universite, imza, mailkapali, resim
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeLossyInt(forKey: .id)
        kadi = c.decodeLossyString(forKey: .kadi)
        isim = c.decodeLossyString(forKey: .isim)
        soyisim = c.decodeLossyString(forKey: .soyisim)
        email = c.decodeLossyString(forKey: .email)
        mezuniyetyili = c.decodeLossyString(forKey: .mezuniyetyili)
        sehir = c.decodeLossyString(forKey: .sehir)
        meslek = c.decodeLossyString(forKey: .meslek)
        websitesi = c.decodeLossyString(forKey: .websitesi)
        universite = c.decodeLossyString(forKey: .universite)
        imza = c.decodeLossyString(forKey: .imza)
        mailkapali = c.decodeLossyBool(forKey: .mailkapali)
        photo = c.decodeLossyString(forKey: .resim)
    }
}

struct ProfileUpdateBody: Encodable {
    let isim: String
    let soyisim: String
    let sehir: String
    let meslek: String
    let websitesi: String
    let universite: String
    let dogumgun: String
    let dogumay: String
    let dogumyil: String
    let mailkapali: Int
    let imza: String
    let ilkbd: Int
}

struct MenuEnvelope: Decodable {
    let items: [MenuItem]?
}

struct MenuItem: Decodable, Identifiable {
    var id: String { legacyUrl ?? url ?? UUID().uuidString }
    let label: String?
    let url: String?
    let legacyUrl: String?
}

struct SidebarEnvelope: Decodable {
    let onlineUsers: [MemberSummary]?
    let newMembers: [MemberSummary]?
    let newPhotos: [SidebarPhotoItem]?
    let topSnake: [SidebarGameScore]?
    let topTetris: [SidebarGameScore]?
    let newMessagesCount: Int?
}

struct SidebarPhotoItem: Decodable, Identifiable {
    let id: Int
    let katid: Int?
    let dosyaadi: String?
    let kategori: String?
}

struct SidebarGameScore: Decodable, Identifiable {
    var id: String { "\(isim ?? "oyuncu")-\(skor ?? puan ?? 0)-\(tarih ?? "")" }
    let isim: String?
    let skor: Int?
    let puan: Int?
    let tarih: String?
}

struct PanolarEnvelope: Decodable {
    let categoryId: Int?
    let categoryName: String?
    let messages: [PanoMessage]?
    let total: Int?
    let page: Int?
    let pages: Int?
    let pageSize: Int?
    let canDelete: Bool?
}

struct PanoMessage: Decodable, Identifiable {
    let id: Int
    let mesajHtml: String?
    let tarih: String?
    let user: PanoUser?
    let diffSeconds: Int?
    let isNew: Bool?
}

struct PanoUser: Decodable {
    let id: Int?
    let kadi: String?
    let resim: String?
}

struct TournamentRegisterBody: Encodable {
    var tisim: String
    var tktelefon: String
    var boyismi: String
    var boymezuniyet: String
    var ioyismi: String
    var ioymezuniyet: String
    var uoyismi: String
    var uoymezuniyet: String
    var doyismi: String
    var doymezuniyet: String
}
