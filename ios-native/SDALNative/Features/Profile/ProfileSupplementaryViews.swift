import SwiftUI

struct ChangePasswordView: View {
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

struct MenuSidebarView: View {
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

struct PanolarView: View {
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

struct TournamentRegisterView: View {
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

struct HelpView: View {
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

struct SDALMessengerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var threads: [MessengerThread] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var searchText = ""
    @State private var showNewChat = false
    @State private var wsTask: URLSessionWebSocketTask?
    @State private var wsListenerTask: Task<Void, Never>?
    @State private var wsActive = false
    @State private var liveRefreshTask: Task<Void, Never>?

    private let api = APIClient.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SDALTheme.secondary.opacity(0.34), SDALTheme.cardAlt],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("SDAL Messenger")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SDALTheme.ink)
                    Spacer()
                    Button {
                        showNewChat = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(SDALTheme.ink)
                            .font(.title3.weight(.semibold))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(SDALTheme.muted)
                    TextField("Sohbet ara", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(SDALTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(SDALTheme.line, lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
                .onChange(of: searchText) { _, _ in
                    Task { await loadThreads() }
                }

                Group {
                    if isLoading && threads.isEmpty {
                        Spacer()
                        ProgressView("Yukleniyor...")
                            .tint(SDALTheme.secondary)
                            .foregroundStyle(SDALTheme.ink)
                        Spacer()
                    } else if let error, threads.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Text(error).foregroundStyle(SDALTheme.danger)
                            Button("Tekrar Dene") {
                                Task { await loadThreads() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(SDALTheme.primary)
                        }
                        Spacer()
                    } else if threads.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 42))
                                .foregroundStyle(SDALTheme.secondary.opacity(0.86))
                            Text("Henuz sohbet yok")
                                .font(.headline)
                                .foregroundStyle(SDALTheme.ink)
                            Text("Yeni sohbet baslatmak icin kalem ikonuna dokun.")
                                .font(.subheadline)
                                .foregroundStyle(SDALTheme.muted)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        Spacer()
                    } else {
                        List(threads) { thread in
                            NavigationLink(value: thread.id) {
                                messengerRow(thread)
                            }
                            .listRowInsets(EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Int.self) { threadId in
            if let selected = threads.first(where: { $0.id == threadId }) {
                SDALMessengerThreadView(thread: selected)
            } else {
                Text("Sohbet bulunamadi")
            }
        }
        .sheet(isPresented: $showNewChat) {
            SDALMessengerNewChatView { _ in
                showNewChat = false
                Task {
                    await loadThreads()
                }
            }
        }
        .task {
            wsActive = true
            connectMessengerSocket()
            await loadThreads()
            startLiveRefresh()
        }
        .onDisappear {
            wsActive = false
            disconnectMessengerSocket()
            stopLiveRefresh()
        }
    }

    private func messengerRow(_ thread: MessengerThread) -> some View {
        let peer = thread.peer
        let unread = thread.unreadCount ?? 0
        return HStack(spacing: 12) {
            AsyncAvatarView(imageName: peer?.resim, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("@\(peer?.kadi ?? "uye")")
                        .font(.system(size: 16, weight: unread > 0 ? .bold : .semibold))
                        .foregroundStyle(SDALTheme.ink)
                    Spacer()
                    Text(thread.lastMessage?.createdAt ?? "")
                        .font(.caption2)
                        .foregroundStyle(unread > 0 ? SDALTheme.secondary : SDALTheme.muted)
                }
                HStack(spacing: 8) {
                    Text(thread.lastMessage?.body ?? "Mesajlasma baslat")
                        .lineLimit(1)
                        .font(.subheadline)
                        .foregroundStyle(unread > 0 ? SDALTheme.ink : SDALTheme.muted)
                    Spacer()
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(SDALTheme.secondary, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(10)
        .background(SDALTheme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SDALTheme.line, lineWidth: 1)
        )
    }

    private func loadThreads(silent: Bool = false) async {
        if !silent {
            isLoading = true
            error = nil
        }
        defer {
            if !silent {
                isLoading = false
            }
        }
        do {
            threads = try await api.fetchMessengerThreads(query: searchText, limit: 60, offset: 0)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func connectMessengerSocket() {
        if wsTask != nil { return }
        guard let userId = appState.session?.id else { return }
        guard var comps = URLComponents(url: AppConfig.baseURL, resolvingAgainstBaseURL: false) else { return }
        comps.scheme = comps.scheme == "https" ? "wss" : "ws"
        comps.path = "/ws/messenger"
        comps.queryItems = [
            URLQueryItem(name: "userId", value: String(userId))
        ]
        guard let url = comps.url else { return }
        let task = URLSession.shared.webSocketTask(with: url)
        wsTask = task
        task.resume()
        wsListenerTask?.cancel()
        wsListenerTask = Task { await listenMessengerSocket(task) }
    }

    private func startLiveRefresh() {
        liveRefreshTask?.cancel()
        liveRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { break }
                await loadThreads(silent: true)
            }
        }
    }

    private func stopLiveRefresh() {
        liveRefreshTask?.cancel()
        liveRefreshTask = nil
    }

    private func disconnectMessengerSocket() {
        wsListenerTask?.cancel()
        wsListenerTask = nil
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
    }

    private func listenMessengerSocket(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    await handleMessengerSocketPayload(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleMessengerSocketPayload(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                break
            }
        }
        wsTask = nil
        if wsActive {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            connectMessengerSocket()
        }
    }

    private func handleMessengerSocketPayload(_ text: String) async {
        guard let data = text.data(using: .utf8) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let type = String(json["type"] as? String ?? "")
        if type == "messenger:new" || type == "messenger:read" || type == "messenger:delivered" {
            await loadThreads(silent: true)
        }
    }
}

struct SDALMessengerThreadView: View {
    @EnvironmentObject private var appState: AppState
    @State private var messages: [MessengerMessage] = []
    @State private var draft = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var error: String?
    @State private var selectedMessageMeta: MessengerMessage?
    @State private var wsTask: URLSessionWebSocketTask?
    @State private var wsListenerTask: Task<Void, Never>?
    @State private var wsActive = false
    @State private var liveRefreshTask: Task<Void, Never>?

    let thread: MessengerThread
    private let api = APIClient.shared

    var body: some View {
        ZStack {
            SDALTheme.softPanel.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(messages) { message in
                                bubble(message)
                                    .id(message.id)
                                    .onTapGesture {
                                        selectedMessageMeta = message
                                    }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last?.id {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(SDALTheme.danger)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                }
                composer
                    .padding(8)
                    .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("@\(thread.peer?.kadi ?? "uye")")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            wsActive = true
            connectMessengerSocket()
            if messages.isEmpty {
                await load()
            }
            startLiveRefresh()
        }
        .onDisappear {
            wsActive = false
            disconnectMessengerSocket()
            stopLiveRefresh()
        }
        .sheet(item: $selectedMessageMeta) { msg in
            NavigationStack {
                List {
                    Section("Zaman Bilgileri") {
                        detailRow("Yazildi (cihaz)", msg.clientWrittenAt ?? msg.createdAt)
                        detailRow("Sunucuya ulasti", msg.serverReceivedAt ?? msg.createdAt)
                        detailRow("Karsiya iletildi", msg.deliveredAt ?? "henuz iletilmedi")
                        detailRow("Okundu", msg.readAt ?? "henuz okunmadi")
                    }
                    Section("Mesaj") {
                        Text(msg.body ?? "")
                            .font(.body)
                            .foregroundStyle(SDALTheme.ink)
                    }
                }
                .navigationTitle("Mesaj Detayi")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.fraction(0.35), .medium])
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Mesaj yaz", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(SDALTheme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(SDALTheme.line, lineWidth: 1)
                )
            Button {
                Task { await send() }
            } label: {
                Image(systemName: isSending ? "hourglass" : "paperplane.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(SDALTheme.secondary, in: Circle())
            }
            .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ViewBuilder
    private func bubble(_ msg: MessengerMessage) -> some View {
        let sessionId = appState.session?.id ?? -1
        let isMine = msg.isMine ?? ((msg.senderId ?? 0) == sessionId)
        let isRead = (msg.readAt?.isEmpty == false)
        let isDelivered = isRead || (msg.deliveredAt?.isEmpty == false)
        let stateText = isRead ? "okundu" : (isDelivered ? "iletildi" : "gonderildi")
        HStack {
            if isMine { Spacer(minLength: 44) }
            VStack(alignment: .leading, spacing: 4) {
                Text(msg.body ?? "")
                    .font(.body)
                    .foregroundStyle(SDALTheme.ink)
                HStack(spacing: 4) {
                    Text(msg.createdAt ?? "")
                        .font(.caption2)
                        .foregroundStyle(SDALTheme.muted)
                    if isMine {
                        Image(systemName: isRead ? "checkmark.circle.fill" : (isDelivered ? "checkmark.circle" : "checkmark"))
                            .font(.caption2)
                            .foregroundStyle(isRead ? SDALTheme.secondary : SDALTheme.muted)
                        Text(stateText)
                            .font(.caption2)
                            .foregroundStyle(isRead ? SDALTheme.secondary : SDALTheme.muted)
                    }
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(isMine ? SDALTheme.success.opacity(0.22) : SDALTheme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SDALTheme.line, lineWidth: 1)
            )
            if !isMine { Spacer(minLength: 44) }
        }
    }

    private func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            messages = try await api.fetchMessengerMessages(threadId: thread.id, limit: 90)
            try? await api.markMessengerThreadRead(threadId: thread.id)
            messages = try await api.fetchMessengerMessages(threadId: thread.id, limit: 90)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func connectMessengerSocket() {
        if wsTask != nil { return }
        guard let userId = appState.session?.id else { return }
        guard var comps = URLComponents(url: AppConfig.baseURL, resolvingAgainstBaseURL: false) else { return }
        comps.scheme = comps.scheme == "https" ? "wss" : "ws"
        comps.path = "/ws/messenger"
        comps.queryItems = [
            URLQueryItem(name: "userId", value: String(userId)),
            URLQueryItem(name: "threadId", value: String(thread.id))
        ]
        guard let url = comps.url else { return }
        let task = URLSession.shared.webSocketTask(with: url)
        wsTask = task
        task.resume()
        wsListenerTask?.cancel()
        wsListenerTask = Task { await listenMessengerSocket(task) }
    }

    private func startLiveRefresh() {
        liveRefreshTask?.cancel()
        liveRefreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if Task.isCancelled { break }
                await load()
            }
        }
    }

    private func stopLiveRefresh() {
        liveRefreshTask?.cancel()
        liveRefreshTask = nil
    }

    private func disconnectMessengerSocket() {
        wsListenerTask?.cancel()
        wsListenerTask = nil
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
    }

    private func listenMessengerSocket(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    await handleMessengerSocketPayload(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleMessengerSocketPayload(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                break
            }
        }
        wsTask = nil
        if wsActive {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            connectMessengerSocket()
        }
    }

    private func handleMessengerSocketPayload(_ text: String) async {
        guard let data = text.data(using: .utf8) else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let type = String(json["type"] as? String ?? "")
        if type == "messenger:hello" { return }
        let eventThreadId = Int("\(json["threadId"] ?? "")") ?? 0
        if eventThreadId != thread.id { return }
        await load()
    }

    private func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return }
        isSending = true
        error = nil
        defer { isSending = false }
        do {
            if let created = try await api.sendMessengerMessage(threadId: thread.id, text: text) {
                messages.append(created)
            } else {
                await load()
            }
            draft = ""
            try? await api.markMessengerThreadRead(threadId: thread.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    @ViewBuilder
    private func detailRow(_ title: String, _ value: String?) -> some View {
        let text = (value?.isEmpty == false) ? (value ?? "-") : "-"
        HStack {
            Text(title)
            Spacer()
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

struct SDALMessengerNewChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var items: [MessageRecipient] = []
    @State private var error: String?
    @State private var loading = false
    private let api = APIClient.shared
    let onCreated: (Int) -> Void

    var body: some View {
        NavigationStack {
            List(items) { item in
                Button {
                    Task { await openThread(item.id) }
                } label: {
                    HStack(spacing: 10) {
                        AsyncAvatarView(imageName: item.resim, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(item.kadi ?? "uye")").font(.headline)
                            Text("\(item.isim ?? "") \(item.soyisim ?? "")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: "Uye ara")
            .navigationTitle("Yeni Sohbet")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                }
            }
            .overlay {
                if loading {
                    ProgressView("Yukleniyor...")
                } else if let error, items.isEmpty {
                    Text(error).foregroundStyle(.red)
                } else if items.isEmpty {
                    Text("Arama yaparak kisi sec.")
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: query) { _, _ in
                Task { await search() }
            }
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            items = []
            return
        }
        loading = true
        error = nil
        defer { loading = false }
        do {
            items = try await api.searchMessengerContacts(query: text, limit: 30)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func openThread(_ userId: Int) async {
        do {
            let threadId = try await api.createMessengerThread(userId: userId)
            onCreated(threadId)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
