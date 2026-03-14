import SwiftUI

struct StatusChip: View {
    let label: String
    let active: Bool
    let tint: Color

    var body: some View {
        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(active ? tint.opacity(0.18) : SDALTheme.softPanel)
            .foregroundStyle(active ? tint : SDALTheme.muted)
            .clipShape(Capsule())
    }
}

struct AdminUserEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var i18n: LocalizationManager

    let user: AdminManagedUser
    let onSaved: () -> Void

    @State private var draft: AdminUserDraft
    @State private var saving = false
    @State private var error: String?

    private let api = APIClient.shared

    init(user: AdminManagedUser, onSaved: @escaping () -> Void) {
        self.user = user
        self.onSaved = onSaved
        _draft = State(initialValue: AdminUserDraft(user: user))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(i18n.t("identity")) {
                    TextField(i18n.t("username"), text: $draft.kadi)
                        .disabled(true)
                    TextField(i18n.t("first_name"), text: $draft.isim)
                    TextField(i18n.t("last_name"), text: $draft.soyisim)
                    TextField(i18n.t("email"), text: $draft.email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    TextField(i18n.t("activation_code"), text: $draft.aktivasyon)
                    TextField(i18n.t("photo_file"), text: $draft.resim)
                        .textInputAutocapitalization(.never)
                }

                Section(i18n.t("status")) {
                    Toggle(i18n.t("active"), isOn: $draft.aktif)
                    Toggle(i18n.t("banned"), isOn: $draft.yasakli)
                    Toggle(i18n.t("first_login_done"), isOn: $draft.ilkBilgiTamam)
                    Toggle(i18n.t("mail_hidden"), isOn: $draft.mailKapali)
                    Toggle(i18n.t("admin"), isOn: $draft.admin)
                    TextField(i18n.t("hit"), value: $draft.hit, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                }

                Section(i18n.t("profile")) {
                    TextField(i18n.t("city"), text: $draft.sehir)
                    TextField(i18n.t("job"), text: $draft.meslek)
                    TextField(i18n.t("university"), text: $draft.universite)
                    TextField(i18n.t("graduation_year"), text: $draft.mezuniyetyili)
                    TextField(i18n.t("website"), text: $draft.websitesi)
                        .textInputAutocapitalization(.never)
                    TextField(i18n.t("signature"), text: $draft.imza, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section(i18n.t("birth_date")) {
                    TextField(i18n.t("day"), text: $draft.dogumgun)
                        .keyboardType(.numberPad)
                    TextField(i18n.t("month"), text: $draft.dogumay)
                        .keyboardType(.numberPad)
                    TextField(i18n.t("year"), text: $draft.dogumyil)
                        .keyboardType(.numberPad)
                }

                Section(i18n.t("password")) {
                    SecureField(i18n.t("admin_edit_password_hint"), text: $draft.sifre)
                }

                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .navigationTitle("\(i18n.t("edit")) @\(user.kadi ?? "")")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(i18n.t("close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(saving ? i18n.t("saving") : i18n.t("save")) {
                        Task { await save() }
                    }
                    .disabled(saving)
                }
            }
        }
    }

    private func save() async {
        saving = true
        error = nil
        defer { saving = false }
        do {
            try await api.updateAdminUser(id: user.id, body: draft.toUpdateBody())
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct AdminUserDraft {
    var kadi: String
    var isim: String
    var soyisim: String
    var email: String
    var aktivasyon: String
    var resim: String
    var aktif: Bool
    var yasakli: Bool
    var ilkBilgiTamam: Bool
    var mailKapali: Bool
    var admin: Bool
    var hit: Int
    var sehir: String
    var meslek: String
    var universite: String
    var mezuniyetyili: String
    var websitesi: String
    var imza: String
    var dogumgun: String
    var dogumay: String
    var dogumyil: String
    var sifre: String

    init(user: AdminManagedUser) {
        kadi = user.kadi ?? ""
        isim = user.isim ?? ""
        soyisim = user.soyisim ?? ""
        email = user.email ?? ""
        aktivasyon = user.aktivasyon ?? ""
        resim = user.resim ?? "yok"
        aktif = (user.aktiv ?? 0) == 1
        yasakli = (user.yasak ?? 0) == 1
        ilkBilgiTamam = (user.ilkbd ?? 0) == 1
        mailKapali = (user.mailkapali ?? 0) == 1
        admin = (user.admin ?? 0) == 1
        hit = user.hit ?? 0
        sehir = user.sehir ?? ""
        meslek = user.meslek ?? ""
        universite = user.universite ?? ""
        mezuniyetyili = user.mezuniyetyili ?? ""
        websitesi = user.websitesi ?? ""
        imza = user.imza ?? ""
        dogumgun = user.dogumgun ?? ""
        dogumay = user.dogumay ?? ""
        dogumyil = user.dogumyil ?? ""
        sifre = user.sifre ?? ""
    }

    func toUpdateBody() -> AdminManagedUserUpdateBody {
        AdminManagedUserUpdateBody(
            isim: isim.trimmingCharacters(in: .whitespacesAndNewlines),
            soyisim: soyisim.trimmingCharacters(in: .whitespacesAndNewlines),
            aktivasyon: aktivasyon.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            aktiv: aktif ? 1 : 0,
            yasak: yasakli ? 1 : 0,
            ilkbd: ilkBilgiTamam ? 1 : 0,
            websitesi: websitesi.trimmingCharacters(in: .whitespacesAndNewlines),
            imza: imza,
            meslek: meslek.trimmingCharacters(in: .whitespacesAndNewlines),
            sehir: sehir.trimmingCharacters(in: .whitespacesAndNewlines),
            mailkapali: mailKapali ? 1 : 0,
            hit: hit,
            mezuniyetyili: mezuniyetyili.trimmingCharacters(in: .whitespacesAndNewlines),
            universite: universite.trimmingCharacters(in: .whitespacesAndNewlines),
            dogumgun: dogumgun.trimmingCharacters(in: .whitespacesAndNewlines),
            dogumay: dogumay.trimmingCharacters(in: .whitespacesAndNewlines),
            dogumyil: dogumyil.trimmingCharacters(in: .whitespacesAndNewlines),
            admin: admin ? 1 : 0,
            resim: resim.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "yok" : resim.trimmingCharacters(in: .whitespacesAndNewlines),
            sifre: sifre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sifre
        )
    }
}
