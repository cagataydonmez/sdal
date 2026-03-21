import Foundation

struct SessionEnvelope: Decodable {
    let user: SessionUser?
    let role: String?
    let admin: Bool?
    let needsProfile: Bool?

    private enum CodingKeys: String, CodingKey {
        case user, member, currentUser, role, admin, needsProfile, needs_profile
    }

    var resolvedUser: SessionUser? {
        guard let user else { return nil }
        return user.merging(role: role, admin: admin, needsProfile: needsProfile)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        user = (try? c.decodeIfPresent(SessionUser.self, forKey: .user))
            ?? (try? c.decodeIfPresent(SessionUser.self, forKey: .member))
            ?? (try? c.decodeIfPresent(SessionUser.self, forKey: .currentUser))
        role = c.decodeLossyString(forKey: .role)
        admin = c.decodeLossyBool(forKey: .admin)
        needsProfile = c.decodeLossyBool(forKey: .needsProfile)
            ?? c.decodeLossyBool(forKey: .needs_profile)
    }
}

struct LoginResponse: Decodable {
    let ok: Bool?
    let user: SessionUser?
    let role: String?
    let admin: Bool?
    let needsProfile: Bool?

    private enum CodingKeys: String, CodingKey {
        case ok, user, role, admin, needsProfile, needs_profile
    }

    var resolvedUser: SessionUser? {
        guard let user else { return nil }
        return user.merging(role: role, admin: admin, needsProfile: needsProfile)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.decodeLossyBool(forKey: .ok)
        user = try? c.decodeIfPresent(SessionUser.self, forKey: .user)
        role = c.decodeLossyString(forKey: .role)
        admin = c.decodeLossyBool(forKey: .admin)
        needsProfile = c.decodeLossyBool(forKey: .needsProfile)
            ?? c.decodeLossyBool(forKey: .needs_profile)
    }
}

struct SiteAccessResponse: Decodable {
    let isOpen: Bool
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case ok, open, isOpen, siteOpen, closed, accessClosed, message, note, reason
        case is_open, site_open, access_closed
    }

    init(isOpen: Bool, message: String?) {
        self.isOpen = isOpen
        self.message = message
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let openValue = c.decodeLossyBool(forKey: .open)
            ?? c.decodeLossyBool(forKey: .isOpen)
            ?? c.decodeLossyBool(forKey: .siteOpen)
            ?? c.decodeLossyBool(forKey: .is_open)
            ?? c.decodeLossyBool(forKey: .site_open)
            ?? c.decodeLossyBool(forKey: .ok)
        let closedValue = c.decodeLossyBool(forKey: .closed)
            ?? c.decodeLossyBool(forKey: .accessClosed)
            ?? c.decodeLossyBool(forKey: .access_closed)
        if let openValue {
            isOpen = openValue
        } else if let closedValue {
            isOpen = !closedValue
        } else {
            isOpen = true
        }
        message = c.decodeLossyString(forKey: .message)
            ?? c.decodeLossyString(forKey: .note)
            ?? c.decodeLossyString(forKey: .reason)
    }
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
    let role: String?
    let admin: Bool?
    let needsProfile: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, kadi, username, isim, firstName, soyisim, lastName, email, photo, resim, role, admin, needsProfile, needs_profile
    }

    init(
        id: Int?,
        kadi: String?,
        isim: String?,
        soyisim: String?,
        email: String?,
        photo: String?,
        role: String?,
        admin: Bool?,
        needsProfile: Bool?
    ) {
        self.id = id
        self.kadi = kadi
        self.isim = isim
        self.soyisim = soyisim
        self.email = email
        self.photo = photo
        self.role = role
        self.admin = admin
        self.needsProfile = needsProfile
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decodeLossyInt(forKey: .id)
        kadi = c.decodeLossyString(forKey: .kadi) ?? c.decodeLossyString(forKey: .username)
        isim = c.decodeLossyString(forKey: .isim) ?? c.decodeLossyString(forKey: .firstName)
        soyisim = c.decodeLossyString(forKey: .soyisim) ?? c.decodeLossyString(forKey: .lastName)
        email = c.decodeLossyString(forKey: .email)
        photo = c.decodeLossyString(forKey: .photo) ?? c.decodeLossyString(forKey: .resim)
        role = c.decodeLossyString(forKey: .role)
        admin = c.decodeLossyBool(forKey: .admin)
        needsProfile = c.decodeLossyBool(forKey: .needsProfile)
            ?? c.decodeLossyBool(forKey: .needs_profile)
    }

    func merging(role: String?, admin: Bool?, needsProfile: Bool?) -> SessionUser {
        SessionUser(
            id: id,
            kadi: kadi,
            isim: isim,
            soyisim: soyisim,
            email: email,
            photo: photo,
            role: role ?? self.role,
            admin: admin ?? self.admin,
            needsProfile: needsProfile ?? self.needsProfile
        )
    }

    var canAccessAdmin: Bool {
        if admin == true { return true }
        switch (role ?? "").lowercased() {
        case "admin", "root":
            return true
        default:
            return false
        }
    }
}
