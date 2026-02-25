import SwiftUI
import WebKit

private enum AuthSheet: String, Identifiable {
    case register
    case activate
    case resend
    case reset

    var id: String { rawValue }
}

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var i18n: LocalizationManager

    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var sheet: AuthSheet?
    @State private var oauthProviders: [OAuthProvider] = []
    @State private var oauthURL: URL?
    @State private var loadingOAuth = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                SDALTheme.appBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("SDAL")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(SDALTheme.secondary)
                        Text(i18n.t("app_tagline"))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    GlassCard {
                        VStack(spacing: 14) {
                            TextField(i18n.t("username"), text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)

                            SecureField(i18n.t("password"), text: $password)
                                .textFieldStyle(.roundedBorder)

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }

                            Button {
                                Task { await doLogin() }
                            } label: {
                                HStack {
                                    if isLoading { ProgressView().tint(.white) }
                                    Text(isLoading ? i18n.t("signing_in") : i18n.t("sign_in"))
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isLoading || username.isEmpty || password.isEmpty)

                            if !oauthProviders.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)

                                VStack(spacing: 8) {
                                    ForEach(oauthProviders) { provider in
                                        Button {
                                            startOAuth(provider)
                                        } label: {
                                            HStack {
                                                Text("\(provider.provider == "google" ? "Google" : "X") ile devam et")
                                                Spacer()
                                                if loadingOAuth {
                                                    ProgressView()
                                                }
                                            }
                                            .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(loadingOAuth)
                                    }
                                }
                            }

                            HStack {
                                Button(i18n.t("register")) { sheet = .register }
                                Spacer()
                                Button(i18n.t("activate")) { sheet = .activate }
                            }
                            .font(.footnote)

                            HStack {
                                Button(i18n.t("resend_activation")) { sheet = .resend }
                                Spacer()
                                Button(i18n.t("forgot_password")) { sheet = .reset }
                            }
                            .font(.footnote)
                        }
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationBarHidden(true)
            .sheet(item: $sheet) { target in
                switch target {
                case .register: RegisterSheet()
                case .activate: ActivationSheet()
                case .resend: ActivationResendSheet()
                case .reset: PasswordResetSheet()
                }
            }
            .sheet(isPresented: Binding(
                get: { oauthURL != nil },
                set: { presented in if !presented { oauthURL = nil } }
            )) {
                OAuthWebSheet(startURL: oauthURL ?? AppConfig.baseURL) { completed in
                    oauthURL = nil
                    loadingOAuth = false
                    if completed {
                        Task { await appState.refreshSession() }
                    }
                }
            }
            .task {
                await loadOAuthProviders()
            }
        }
    }

    private func doLogin() async {
        isLoading = true
        errorMessage = nil
        do {
            try await appState.login(username: username, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadOAuthProviders() async {
        do {
            let providers = try await api.fetchOAuthProviders()
            oauthProviders = providers.filter { $0.provider == "google" || $0.provider == "x" }
        } catch {
            oauthProviders = []
        }
    }

    private func startOAuth(_ provider: OAuthProvider) {
        let base = AppConfig.baseURL.absoluteString
        let path = provider.startUrl ?? "/api/auth/oauth/\(provider.provider)/start"
        guard let url = URL(string: path.hasPrefix("http") ? path : (base + path)) else {
            return
        }
        loadingOAuth = true
        oauthURL = url
    }
}

private struct OAuthWebSheet: View {
    @Environment(\.dismiss) private var dismiss
    let startURL: URL
    let onComplete: (Bool) -> Void

    var body: some View {
        NavigationStack {
            OAuthWebView(startURL: startURL) { success in
                onComplete(success)
                dismiss()
            }
            .navigationTitle("Sosyal Giris")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") {
                        onComplete(false)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct OAuthWebView: UIViewRepresentable {
    let startURL: URL
    let onComplete: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        webView.load(URLRequest(url: startURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        let onComplete: (Bool) -> Void
        var completed = false

        init(onComplete: @escaping (Bool) -> Void) {
            self.onComplete = onComplete
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            syncCookies(from: webView)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            let path = url.path.lowercased()
            let query = url.query?.lowercased() ?? ""
            if !completed && (path == "/new" || (path == "/new/login" && !query.contains("oauth="))) {
                completed = true
                syncCookies(from: webView)
                onComplete(true)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        private func syncCookies(from webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                let storage = HTTPCookieStorage.shared
                for cookie in cookies {
                    storage.setCookie(cookie)
                }
            }
        }
    }
}

private struct RegisterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var i18n: LocalizationManager

    @State private var username = ""
    @State private var password = ""
    @State private var passwordRepeat = ""
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var graduationYear = ""
    @State private var captchaCode = ""
    @State private var captchaReloadKey = UUID().uuidString
    @State private var message: String?
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField(i18n.t("username"), text: $username)
                SecureField(i18n.t("password"), text: $password)
                SecureField(i18n.t("repeat_password"), text: $passwordRepeat)
                TextField(i18n.t("email"), text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField(i18n.t("first_name"), text: $firstName)
                TextField(i18n.t("last_name"), text: $lastName)
                TextField(i18n.t("graduation_year"), text: $graduationYear)
                VStack(alignment: .leading, spacing: 8) {
                    if let url = URL(string: AppConfig.baseURL.absoluteString + "/api/captcha?key=\(captchaReloadKey)") {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: 56)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            case .failure(_):
                                Text(i18n.t("captcha_load_failed"))
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            default:
                                ProgressView()
                            }
                        }
                    }
                    Button(i18n.t("refresh_captcha")) { captchaReloadKey = UUID().uuidString }
                        .buttonStyle(.bordered)
                }
                TextField(i18n.t("security_code"), text: $captchaCode)
                if let message { Text(message).foregroundStyle(.green) }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(i18n.t("register"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("submit")) { Task { await submit() } }
                        .disabled(username.isEmpty || password.isEmpty || email.isEmpty || captchaCode.isEmpty)
                }
            }
        }
    }

    private func submit() async {
        error = nil
        do {
            _ = try await api.previewRegister(
                username: username,
                password: password,
                passwordRepeat: passwordRepeat,
                email: email,
                firstName: firstName,
                lastName: lastName,
                graduationYear: graduationYear,
                captchaCode: captchaCode
            )
            try await api.register(
                username: username,
                password: password,
                passwordRepeat: passwordRepeat,
                email: email,
                firstName: firstName,
                lastName: lastName,
                graduationYear: graduationYear,
                captchaCode: captchaCode
            )
            message = i18n.t("registration_completed")
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct ActivationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var i18n: LocalizationManager

    @State private var id = ""
    @State private var code = ""
    @State private var message: String?
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField(i18n.t("member_id"), text: $id)
                TextField(i18n.t("activation_code"), text: $code)
                if let message { Text(message).foregroundStyle(.green) }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(i18n.t("activate"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("verify")) { Task { await submit() } }
                        .disabled(id.isEmpty || code.isEmpty)
                }
            }
        }
    }

    private func submit() async {
        error = nil
        do {
            let payload = try await api.activateAccount(id: id, code: code)
            message = String(format: i18n.t("activated_for"), payload.kadi ?? "user")
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct ActivationResendSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var i18n: LocalizationManager

    @State private var id = ""
    @State private var email = ""
    @State private var message: String?
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField(i18n.t("member_id"), text: $id)
                TextField(i18n.t("email"), text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let message { Text(message).foregroundStyle(.green) }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(i18n.t("resend_activation"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("send")) { Task { await submit() } }
                        .disabled(id.isEmpty || email.isEmpty)
                }
            }
        }
    }

    private func submit() async {
        error = nil
        do {
            try await api.resendActivation(memberId: id, email: email)
            message = i18n.t("activation_email_sent")
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct PasswordResetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var i18n: LocalizationManager

    @State private var username = ""
    @State private var email = ""
    @State private var message: String?
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField(i18n.t("username"), text: $username)
                TextField(i18n.t("email"), text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if let message { Text(message).foregroundStyle(.green) }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(i18n.t("password_reset"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("send")) { Task { await submit() } }
                        .disabled(username.isEmpty || email.isEmpty)
                }
            }
        }
    }

    private func submit() async {
        error = nil
        do {
            try await api.requestPasswordReset(username: username, email: email)
            message = i18n.t("password_reset_sent")
        } catch {
            self.error = error.localizedDescription
        }
    }
}
