import SwiftUI

private enum MessagesMode: String, CaseIterable, Identifiable {
    case inbox
    case outbox
    case chat

    var id: String { rawValue }
}

struct MessagesView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var mode: MessagesMode = .inbox
    @State private var messages: [MessageSummary] = []
    @State private var chatMessages: [ChatMessage] = []
    @State private var onlineMembers: [MemberSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var path: [Int] = []
    @State private var showComposer = false
    @State private var selectedMessageId: Int?
    @State private var chatDraft = ""
    @State private var editingChatId: Int?
    @State private var editingChatText = ""
    @State private var translatedChat: [Int: String] = [:]
    @State private var translatingChatIds: Set<Int> = []

    private let api = APIClient.shared

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if isLoading && messages.isEmpty && chatMessages.isEmpty {
                    ProgressView(i18n.t("loading_messages"))
                } else if let errorMessage, messages.isEmpty && chatMessages.isEmpty {
                    ScreenErrorView(message: errorMessage) { Task { await loadCurrent() } }
                } else {
                    VStack(spacing: 8) {
                        Picker(i18n.t("mailbox"), selection: $mode) {
                            Text(i18n.t("inbox")).tag(MessagesMode.inbox)
                            Text(i18n.t("outbox")).tag(MessagesMode.outbox)
                            Text(i18n.t("chat")).tag(MessagesMode.chat)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .onChange(of: mode) { _, _ in
                            Task { await loadCurrent() }
                        }

                        if mode == .chat {
                            chatPanel
                        } else {
                            mailboxPanel
                        }
                    }
                }
            }
            .task { if messages.isEmpty && chatMessages.isEmpty { await loadCurrent() } }
            .task(id: mode) {
                guard mode == .chat else { return }
                await runChatAutoRefresh()
            }
            .onChange(of: router.openMessageId) { _, id in
                guard let id else { return }
                mode = .inbox
                if isCompactMailbox {
                    if !path.contains(id) { path.append(id) }
                } else {
                    selectedMessageId = id
                }
                router.openMessageId = nil
            }
            .onChange(of: router.openMessagesDestination) { _, destination in
                guard let destination else { return }
                if destination == .chat {
                    mode = .chat
                }
                router.openMessagesDestination = nil
            }
            .navigationDestination(for: Int.self) { messageId in
                MessageDetailView(messageId: messageId)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if mode != .chat {
                        Button(i18n.t("compose")) { showComposer = true }
                    }
                }
            }
            .sheet(isPresented: $showComposer) {
                MessageComposeView(onSent: {
                    showComposer = false
                    Task { await loadCurrent() }
                })
            }
            .alert(i18n.t("edit_chat_message"), isPresented: Binding(
                get: { editingChatId != nil },
                set: { if !$0 { editingChatId = nil } }
            )) {
                TextField(i18n.t("message"), text: $editingChatText)
                Button(i18n.t("save")) { Task { await saveChatEdit() } }
                Button(i18n.t("cancel"), role: .cancel) { editingChatId = nil }
            }
            .navigationTitle(i18n.t("messages"))
            .background(SDALTheme.appBackground.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var mailboxPanel: some View {
        if isCompactMailbox {
                List(messages) { message in
                    NavigationLink(value: message.id) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(message.konu?.isEmpty == false ? message.konu! : i18n.t("no_subject"))
                                .font(.headline)
                            Text(mode == .inbox
                                 ? "\(i18n.t("from")): @\(message.kimdenKadi ?? "unknown")"
                                 : "\(i18n.t("to")): @\(message.kimeKadi ?? "unknown")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(message.mesaj ?? "")
                                .font(.body)
                                .lineLimit(2)
                            Text(message.tarih ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                    }
                    .swipeActions {
                        Button(i18n.t("delete"), role: .destructive) {
                            Task { await remove(message.id) }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable { await loadCurrent() }
        } else {
            HStack(spacing: 10) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Button(i18n.t("compose")) { showComposer = true }
                                .buttonStyle(.borderedProminent)
                            if mode == .inbox {
                                Button(i18n.t("inbox")) {
                                    mode = .inbox
                                    Task { await loadCurrent() }
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button(i18n.t("inbox")) {
                                    mode = .inbox
                                    Task { await loadCurrent() }
                                }
                                .buttonStyle(.bordered)
                            }
                            if mode == .outbox {
                                Button(i18n.t("outbox")) {
                                    mode = .outbox
                                    Task { await loadCurrent() }
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button(i18n.t("outbox")) {
                                    mode = .outbox
                                    Task { await loadCurrent() }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .frame(width: 150)

                    GlassCard {
                        List(messages) { message in
                            Button {
                                selectedMessageId = message.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(message.konu?.isEmpty == false ? message.konu! : i18n.t("no_subject"))
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                        Text(mode == .inbox
                                             ? "@\(message.kimdenKadi ?? "unknown")"
                                             : "@\(message.kimeKadi ?? "unknown")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text((message.mesaj ?? "").replacingOccurrences(of: "\n", with: " "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text(message.tarih ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(selectedMessageId == message.id ? SDALTheme.accent.opacity(0.10) : Color.clear)
                            .swipeActions {
                                Button(i18n.t("delete"), role: .destructive) {
                                    Task { await remove(message.id) }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                    .frame(minWidth: 320, maxWidth: 420)

                    GlassCard {
                        if let selected = messages.first(where: { $0.id == selectedMessageId }) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text(selected.konu?.isEmpty == false ? selected.konu! : i18n.t("no_subject"))
                                        .font(.headline)
                                    Spacer()
                                    Button(i18n.t("open")) {
                                        if !path.contains(selected.id) { path.append(selected.id) }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                Text(mode == .inbox
                                     ? "\(i18n.t("from")): @\(selected.kimdenKadi ?? "unknown")"
                                     : "\(i18n.t("to")): @\(selected.kimeKadi ?? "unknown")")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(selected.tarih ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Divider()
                                ScrollView {
                                    Text(selected.mesaj ?? "")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                Spacer(minLength: 0)
                                HStack {
                                    Button(i18n.t("reply")) {
                                        if !path.contains(selected.id) { path.append(selected.id) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    Button(i18n.t("delete"), role: .destructive) {
                                        Task { await remove(selected.id) }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        } else {
                            Text(i18n.t("select_message"))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                    }
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
        }
    }

    private var chatPanel: some View {
        VStack(spacing: 8) {
            if !onlineMembers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(onlineMembers.prefix(12)) { member in
                            HStack(spacing: 6) {
                                AsyncAvatarView(imageName: member.resim, size: 24)
                                Text("@\(member.kadi ?? "user")")
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(SDALTheme.softPanel)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            List(chatMessages) { chat in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        AsyncAvatarView(imageName: chat.resim, size: 28)
                        Text("@\(chat.kadi ?? "user")")
                            .font(.caption.bold())
                        if chat.verified == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        Spacer()
                        Text(chat.createdAt ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(chat.message ?? "")
                        .font(.subheadline)
                    if let translated = translatedChat[chat.id], !translated.isEmpty {
                        Text(translated)
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing) {
                    if canManageChat(chat) {
                        Button(i18n.t("edit")) {
                            editingChatId = chat.id
                            editingChatText = chat.message ?? ""
                        }
                        .tint(.orange)
                        Button(i18n.t("delete"), role: .destructive) {
                            Task { await deleteChat(chat.id) }
                        }
                    }
                }
                .contextMenu {
                    Button(translatingChatIds.contains(chat.id) ? i18n.t("translating") : i18n.t("translate")) {
                        Task { await translateChat(chat) }
                    }
                    .disabled(translatingChatIds.contains(chat.id) || (chat.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await loadCurrent() }

            HStack(spacing: 8) {
                TextField(i18n.t("write_to_chat"), text: $chatDraft, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                Button(i18n.t("send")) {
                    Task { await sendChat() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    private func canManageChat(_ chat: ChatMessage) -> Bool {
        chat.userId == appState.session?.id
    }

    private func runChatAutoRefresh() async {
        while !Task.isCancelled, mode == .chat {
            do {
                try await loadChat(sinceOnly: true)
            } catch {
                errorMessage = error.localizedDescription
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    private func loadCurrent() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            switch mode {
            case .inbox:
                messages = try await api.fetchInbox()
            case .outbox:
                messages = try await api.fetchOutbox()
            case .chat:
                try await loadChat(sinceOnly: false)
            }
            if mode != .chat {
                if let selectedMessageId, messages.contains(where: { $0.id == selectedMessageId }) {
                    // Keep current selection.
                } else {
                    selectedMessageId = messages.first?.id
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadChat(sinceOnly: Bool) async throws {
        if sinceOnly, let lastId = chatMessages.last?.id {
            let incoming = try await api.fetchChatMessages(sinceId: lastId, limit: 80)
            if !incoming.isEmpty { mergeChat(incoming) }
        } else {
            let rows = try await api.fetchChatMessages(limit: 120)
            chatMessages = rows
        }
        onlineMembers = (try? await api.fetchOnlineMembers(limit: 12)) ?? onlineMembers
    }

    private func mergeChat(_ incoming: [ChatMessage]) {
        var map = Dictionary(uniqueKeysWithValues: chatMessages.map { ($0.id, $0) })
        for item in incoming { map[item.id] = item }
        chatMessages = map.values.sorted { $0.id < $1.id }
    }

    private func sendChat() async {
        let text = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let item = try await api.sendChatMessage(message: text)
            chatDraft = ""
            if let item {
                mergeChat([item])
            } else {
                try await loadChat(sinceOnly: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveChatEdit() async {
        guard let editingChatId else { return }
        let text = editingChatText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            let item = try await api.editChatMessage(id: editingChatId, message: text)
            self.editingChatId = nil
            if let item {
                mergeChat([item])
            } else {
                try await loadChat(sinceOnly: false)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteChat(_ id: Int) async {
        do {
            try await api.deleteChatMessage(id: id)
            chatMessages.removeAll { $0.id == id }
            translatedChat[id] = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func translateChat(_ chat: ChatMessage) async {
        let raw = (chat.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        translatingChatIds.insert(chat.id)
        defer { translatingChatIds.remove(chat.id) }
        do {
            let translated = try await api.translateText(raw, target: i18n.language.rawValue)
            translatedChat[chat.id] = translated
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ id: Int) async {
        do {
            try await api.deleteMessage(id: id)
            messages.removeAll { $0.id == id }
            if selectedMessageId == id {
                selectedMessageId = messages.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var isCompactMailbox: Bool {
        horizontalSizeClass == .compact
    }
}

private struct MessageDetailView: View {
    @EnvironmentObject private var i18n: LocalizationManager

    let messageId: Int
    @State private var detail: MessageDetailEnvelope?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        Group {
            if isLoading && detail == nil {
                ProgressView(i18n.t("loading"))
            } else if let errorMessage, detail == nil {
                ScreenErrorView(message: errorMessage) { Task { await load() } }
            } else if let row = detail?.row {
                ScrollView {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(row.konu?.isEmpty == false ? row.konu! : i18n.t("no_subject"))
                                .font(.headline)
                            Text("\(i18n.t("from")): @\(detail?.sender?.kadi ?? row.kimdenKadi ?? "unknown")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(row.mesaj ?? "")
                                .font(.body)
                            Text(row.tarih ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task { if detail == nil { await load() } }
        .navigationTitle(i18n.t("message"))
        .background(SDALTheme.appBackground.ignoresSafeArea())
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            detail = try await api.fetchMessage(id: messageId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct MessageComposeView: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let onSent: () -> Void

    @State private var query = ""
    @State private var recipients: [MessageRecipient] = []
    @State private var selectedRecipient: MessageRecipient?
    @State private var subject = ""
    @State private var messageBody = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Section(i18n.t("recipient")) {
                    TextField(i18n.t("recipient"), text: $query)
                        .onChange(of: query) { _, value in
                            Task { await search(value) }
                        }

                    ForEach(recipients) { r in
                        Button {
                            selectedRecipient = r
                        } label: {
                            HStack {
                                AsyncAvatarView(imageName: r.resim, size: 32)
                                Text("@\(r.kadi ?? "user")")
                                Spacer()
                                if selectedRecipient?.id == r.id {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                        }
                    }
                }

                Section(i18n.t("subject")) {
                    TextField(i18n.t("subject"), text: $subject)
                }

                Section(i18n.t("message")) {
                    TextField(i18n.t("message"), text: $messageBody, axis: .vertical)
                        .lineLimit(4...8)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(i18n.t("new_message"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(i18n.t("close")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("send")) {
                        Task { await send() }
                    }
                    .disabled(isSending || selectedRecipient == nil || messageBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func search(_ term: String) async {
        guard term.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            recipients = []
            return
        }
        do {
            recipients = try await api.searchRecipients(query: term)
        } catch {
            // Keep quiet while typing.
        }
    }

    private func send() async {
        guard let selectedRecipient else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            try await api.sendMessage(
                recipientId: selectedRecipient.id,
                subject: subject.isEmpty ? i18n.t("no_subject") : subject,
                body: messageBody
            )
            onSent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
