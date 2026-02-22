import SwiftUI
import UserNotifications
import PhotosUI

@MainActor
struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var pushService: PushNotificationService
    @EnvironmentObject private var i18n: LocalizationManager
    @EnvironmentObject private var theme: ThemeManager

    @State private var profile: Profile?
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var city = ""
    @State private var job = ""
    @State private var website = ""
    @State private var university = ""
    @State private var signature = ""
    @State private var mailPrivate = false

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var showCamera = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && profile == nil {
                    ProgressView(i18n.t("loading"))
                } else if let errorMessage, profile == nil {
                    ScreenErrorView(message: errorMessage) { Task { await load() } }
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            GlassCard {
                                VStack(spacing: 12) {
                                    AsyncAvatarView(imageName: profile?.photo, size: 88)
                                    Text("@\(profile?.kadi ?? "user")")
                                        .font(.title3.bold())
                                    Text("\(profile?.isim ?? "") \(profile?.soyisim ?? "")")
                                        .foregroundStyle(.secondary)

                                    HStack {
                                        PhotosPicker(selection: $photoPickerItem, matching: .images, photoLibrary: .shared()) {
                                            Label(i18n.t("change_photo"), systemImage: "photo")
                                        }
                                        .buttonStyle(.bordered)
                                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                            Button {
                                                showCamera = true
                                            } label: {
                                                Label(i18n.t("camera"), systemImage: "camera")
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }

                                    if photoData != nil {
                                        Button(i18n.t("upload")) {
                                            Task { await uploadPhoto() }
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }

                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(i18n.t("language"))
                                        .font(.headline)
                                    Picker(i18n.t("language"), selection: $i18n.language) {
                                        ForEach(AppLanguage.allCases) { lang in
                                            Text(lang.label).tag(lang)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }

                            GlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(i18n.t("appearance"))
                                        .font(.headline)
                                    Picker(i18n.t("appearance"), selection: $theme.mode) {
                                        ForEach(AppThemeMode.allCases) { mode in
                                            Text(mode.label).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }

                            GlassCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(i18n.t("profile"))
                                        .font(.headline)

                                    TextField(i18n.t("first_name"), text: $firstName)
                                        .textFieldStyle(.roundedBorder)
                                    TextField(i18n.t("last_name"), text: $lastName)
                                        .textFieldStyle(.roundedBorder)
                                    TextField(i18n.t("city"), text: $city)
                                        .textFieldStyle(.roundedBorder)
                                    TextField(i18n.t("job"), text: $job)
                                        .textFieldStyle(.roundedBorder)
                                    TextField(i18n.t("university"), text: $university)
                                        .textFieldStyle(.roundedBorder)
                                    TextField(i18n.t("website"), text: $website)
                                        .textFieldStyle(.roundedBorder)
                                    TextField(i18n.t("signature"), text: $signature, axis: .vertical)
                                        .lineLimit(2...4)
                                        .textFieldStyle(.roundedBorder)
                                    Toggle(i18n.t("email_private"), isOn: $mailPrivate)

                                    Button(isSaving ? i18n.t("saving") : i18n.t("save")) {
                                        Task { await saveProfile() }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(isSaving)

                                    Button(i18n.t("request_verification")) {
                                        Task { await requestVerification() }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            GlassCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(i18n.t("push_notifications"))
                                        .font(.headline)
                                    Text(pushStatusText(pushService.authorizationStatus))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Button(i18n.t("enable_push")) {
                                        Task { await pushService.requestAuthorizationAndRegister() }
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }

                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(i18n.t("admin_tools"))
                                            .font(.headline)
                                        Text(i18n.t("moderation_tools"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    NavigationLink(i18n.t("open")) {
                                        AdminView()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }

                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(i18n.t("password"))
                                            .font(.headline)
                                        Text(i18n.t("change_password_desc"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    NavigationLink(i18n.t("open")) {
                                        ChangePasswordView()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(i18n.t("boards"))
                                            .font(.headline)
                                        Text(i18n.t("boards_desc"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    NavigationLink(i18n.t("open")) {
                                        PanolarView()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(i18n.t("tournament"))
                                            .font(.headline)
                                        Text(i18n.t("tournament_desc"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    NavigationLink(i18n.t("open")) {
                                        TournamentRegisterView()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(i18n.t("menu_sidebar"))
                                            .font(.headline)
                                        Text(i18n.t("menu_sidebar_desc"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    NavigationLink(i18n.t("open")) {
                                        MenuSidebarView()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(i18n.t("help"))
                                            .font(.headline)
                                        Text(i18n.t("help_desc"))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    NavigationLink(i18n.t("open")) {
                                        HelpView()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }

                            if let infoMessage {
                                Text(infoMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.green)
                            }
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }

                            Button(role: .destructive) {
                                Task { await appState.logout() }
                            } label: {
                                Text(i18n.t("sign_out"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(16)
                    }
                    .refreshable { await load() }
                }
            }
            .task { if profile == nil { await load() } }
            .onChange(of: photoPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    photoData = try? await newItem.loadTransferable(type: Data.self)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraCapturePicker { data in
                    if let data {
                        photoData = data
                    }
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            .navigationTitle(i18n.t("profile"))
            .background(SDALTheme.appBackground.ignoresSafeArea())
        }
    }

    private func syncForm(with profile: Profile) {
        firstName = profile.isim ?? ""
        lastName = profile.soyisim ?? ""
        city = profile.sehir ?? ""
        job = profile.meslek ?? ""
        website = profile.websitesi ?? ""
        university = profile.universite ?? ""
        signature = profile.imza ?? ""
        mailPrivate = profile.mailkapali ?? false
    }

    private func pushStatusText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return i18n.t("push_enabled")
        case .denied:
            return i18n.t("push_denied")
        case .notDetermined:
            return i18n.t("push_not_determined")
        @unknown default:
            return i18n.t("push_unknown")
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched = try await api.fetchProfile()
            profile = fetched
            syncForm(with: fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveProfile() async {
        isSaving = true
        errorMessage = nil
        infoMessage = nil
        defer { isSaving = false }

        do {
            try await api.updateProfile(
                ProfileUpdateBody(
                    isim: firstName,
                    soyisim: lastName,
                    sehir: city,
                    meslek: job,
                    websitesi: website,
                    universite: university,
                    dogumgun: "0",
                    dogumay: "0",
                    dogumyil: "0",
                    mailkapali: mailPrivate ? 1 : 0,
                    imza: signature,
                    ilkbd: 0
                )
            )
            infoMessage = i18n.t("profile_updated")
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadPhoto() async {
        guard let photoData else { return }
        errorMessage = nil
        infoMessage = nil
        do {
            try await api.uploadProfilePhoto(imageData: photoData)
            self.photoData = nil
            infoMessage = i18n.t("profile_photo_updated")
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestVerification() async {
        errorMessage = nil
        infoMessage = nil
        do {
            try await api.requestVerification()
            infoMessage = i18n.t("verification_request_sent")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ChangePasswordView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var newPasswordRepeat = ""
    @State private var info: String?
    @State private var error: String?
    private let api = APIClient.shared

    var body: some View {
        Form {
            SecureField(i18n.t("old_password"), text: $oldPassword)
            SecureField(i18n.t("new_password"), text: $newPassword)
            SecureField(i18n.t("repeat_new_password"), text: $newPasswordRepeat)
            Button(i18n.t("change_password")) { Task { await submit() } }
                .disabled(oldPassword.isEmpty || newPassword.isEmpty || newPasswordRepeat.isEmpty)
            if let info { Text(info).foregroundStyle(.green) }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle(i18n.t("password"))
    }

    private func submit() async {
        info = nil
        error = nil
        do {
            try await api.changeProfilePassword(oldPassword: oldPassword, newPassword: newPassword, newPasswordRepeat: newPasswordRepeat)
            oldPassword = ""
            newPassword = ""
            newPasswordRepeat = ""
            info = i18n.t("password_updated")
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct MenuSidebarView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @State private var menuItems: [MenuItem] = []
    @State private var sidebar: SidebarEnvelope?
    @State private var error: String?
    private let api = APIClient.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(i18n.t("menu")).font(.headline)
                            Spacer()
                            Button(i18n.t("refresh")) { Task { await load() } }
                                .buttonStyle(.bordered)
                        }
                        if menuItems.isEmpty {
                            Text(i18n.t("no_menu_items")).foregroundStyle(.secondary)
                        } else {
                            ForEach(menuItems) { item in
                                Text("• \(item.label ?? "-")  (\(item.url ?? item.legacyUrl ?? "-"))")
                                    .font(.caption)
                            }
                        }
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(i18n.t("sidebar")).font(.headline)
                        Text(String(format: i18n.t("new_messages_count"), sidebar?.newMessagesCount ?? 0))
                            .font(.subheadline)
                        Text(String(format: i18n.t("online_users_count"), sidebar?.onlineUsers?.count ?? 0))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: i18n.t("new_members_count"), sidebar?.newMembers?.count ?? 0))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: i18n.t("new_photos_count"), sidebar?.newPhotos?.count ?? 0))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if let error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }
            .padding(16)
        }
        .navigationTitle(i18n.t("menu_sidebar"))
        .task { await load() }
        .background(SDALTheme.appBackground.ignoresSafeArea())
    }

    private func load() async {
        error = nil
        do {
            async let menuReq = api.fetchMenu()
            async let sideReq = api.fetchSidebar()
            menuItems = try await menuReq
            sidebar = try await sideReq
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct PanolarView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @State private var categoryId = 0
    @State private var page = 1
    @State private var payload: PanolarEnvelope?
    @State private var messageText = ""
    @State private var error: String?
    private let api = APIClient.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(i18n.t("boards")).font(.headline)
                            Spacer()
                            Button(i18n.t("refresh")) { Task { await load() } }
                                .buttonStyle(.bordered)
                        }
                        TextField(i18n.t("category_id"), value: $categoryId, format: .number)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button(i18n.t("prev")) {
                                page = max(page - 1, 1)
                                Task { await load() }
                            }
                            .buttonStyle(.bordered)
                            .disabled((payload?.page ?? 1) <= 1)
                            Button(i18n.t("next")) {
                                page += 1
                                Task { await load() }
                            }
                            .buttonStyle(.bordered)
                            .disabled((payload?.page ?? 1) >= (payload?.pages ?? 1))
                            Spacer()
                            Text(String(format: i18n.t("page_count_format"), payload?.page ?? 1, payload?.pages ?? 1))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        TextField(i18n.t("write_message"), text: $messageText, axis: .vertical)
                            .lineLimit(2...5)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("post")) { Task { await post() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                ForEach(payload?.messages ?? []) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("@\(item.user?.kadi ?? "uye")")
                                .font(.caption.bold())
                            Text((item.mesajHtml ?? "").replacingOccurrences(of: "<br>", with: "\n").replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                                .font(.subheadline)
                            HStack {
                                Text(item.tarih ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if payload?.canDelete == true {
                                    Button(i18n.t("delete"), role: .destructive) { Task { await delete(item.id) } }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
                if let error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }
            .padding(16)
        }
        .navigationTitle(i18n.t("boards"))
        .task { await load() }
        .background(SDALTheme.appBackground.ignoresSafeArea())
    }

    private func load() async {
        error = nil
        do {
            payload = try await api.fetchPanolar(categoryId: categoryId, page: page)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func post() async {
        error = nil
        do {
            try await api.createPanoMessage(message: messageText, categoryId: categoryId)
            messageText = ""
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ id: Int) async {
        error = nil
        do {
            try await api.deletePanoMessage(id: id)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct TournamentRegisterView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @State private var form = TournamentRegisterBody(
        tisim: "",
        tktelefon: "",
        boyismi: "",
        boymezuniyet: "",
        ioyismi: "",
        ioymezuniyet: "",
        uoyismi: "",
        uoymezuniyet: "",
        doyismi: "",
        doymezuniyet: ""
    )
    @State private var info: String?
    @State private var error: String?
    private let api = APIClient.shared

    var body: some View {
        Form {
            TextField(i18n.t("team_name"), text: $form.tisim)
            TextField(i18n.t("captain_phone"), text: $form.tktelefon)
            TextField(i18n.t("player_1"), text: $form.boyismi)
            TextField(i18n.t("player_1_graduation"), text: $form.boymezuniyet)
            TextField(i18n.t("player_2"), text: $form.ioyismi)
            TextField(i18n.t("player_2_graduation"), text: $form.ioymezuniyet)
            TextField(i18n.t("player_3"), text: $form.uoyismi)
            TextField(i18n.t("player_3_graduation"), text: $form.uoymezuniyet)
            TextField(i18n.t("player_4"), text: $form.doyismi)
            TextField(i18n.t("player_4_graduation"), text: $form.doymezuniyet)
            Button(i18n.t("register_team")) { Task { await submit() } }
                .buttonStyle(.borderedProminent)
            if let info { Text(info).foregroundStyle(.green) }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle(i18n.t("tournament"))
    }

    private func submit() async {
        info = nil
        error = nil
        do {
            try await api.registerTournament(form)
            info = i18n.t("team_registration_submitted")
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct HelpView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @State private var health: HealthResponse?
    @State private var mailTestTo = ""
    @State private var statusText: String?
    @State private var errorText: String?
    private let api = APIClient.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(i18n.t("system_health"))
                                .font(.headline)
                            Spacer()
                            Button(i18n.t("check")) { Task { await checkHealth() } }
                                .buttonStyle(.bordered)
                        }
                        Text("\(i18n.t("ok")): \(health?.ok == true ? i18n.t("yes") : i18n.t("no"))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let dbPath = health?.dbPath {
                            Text("\(i18n.t("db")): \(dbPath)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(i18n.t("sdal_new_help"))
                            .font(.headline)
                        Text(i18n.t("help_overview"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(i18n.t("quick_troubleshooting"))
                            .font(.headline)
                        Text(i18n.t("troubleshoot_1"))
                        Text(i18n.t("troubleshoot_2"))
                        Text(i18n.t("troubleshoot_3"))
                        Text(i18n.t("troubleshoot_4"))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(i18n.t("mail_test"))
                            .font(.headline)
                        TextField("test@example.com", text: $mailTestTo)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        Button(i18n.t("send_test_mail")) { Task { await sendMailTest() } }
                            .buttonStyle(.bordered)
                            .disabled(mailTestTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if let statusText {
                            Text(statusText)
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                        if let errorText {
                            Text(errorText)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(i18n.t("help"))
        .task { await checkHealth() }
        .background(SDALTheme.appBackground.ignoresSafeArea())
    }

    private func checkHealth() async {
        errorText = nil
        do {
            health = try await api.fetchHealth()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func sendMailTest() async {
        statusText = nil
        errorText = nil
        do {
            try await api.sendMailTest(to: mailTestTo.trimmingCharacters(in: .whitespacesAndNewlines))
            statusText = i18n.t("test_mail_sent")
        } catch {
            errorText = error.localizedDescription
        }
    }
}
