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
                                        Text("SDAL Messenger")
                                            .font(.headline)
                                        Text("WhatsApp benzeri anlik mesajlasma")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    NavigationLink(i18n.t("open")) {
                                        SDALMessengerView()
                                    }
                                    .buttonStyle(.borderedProminent)
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
