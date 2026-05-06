import SwiftUI

struct ConversationView: View {
    let thread: WatchThread

    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    @State private var messages: [WatchMessage] = []
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var messageText = ""
    @State private var isSending = false
    @State private var sendError: String? = nil

    private var cookie:  String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    private func isMine(_ message: WatchMessage) -> Bool {
        if sessionManager.myUserId > 0 {
            return message.senderId == sessionManager.myUserId
        }
        return message.senderId != thread.peerUserId
    }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                LoadingView()
            } else if let err = loadError {
                ErrorRetryView(message: err) { Task { await load() } }
            } else {
                messageList
            }

            Divider()
            inputBar
        }
        .navigationTitle(thread.peerName.isEmpty ? "@\(thread.peerHandle)" : thread.peerName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        // Poll for incoming messages every 10 seconds
        .task(id: thread.id) {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled else { return }
                let fresh = try? await viewModel.loadMessages(
                    threadId: thread.id, cookie: cookie, baseUrl: baseUrl
                )
                if let fresh, !fresh.isEmpty { messages = fresh }
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(messages) { msg in
                        MessageBubble(message: msg, isMine: isMine(msg))
                            .id(msg.id)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onAppear {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                TextField("Mesaj...", text: $messageText)
                    .font(.caption2)
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: isSending ? "arrow.up.circle" : "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(
                            messageText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .accentColor
                        )
                }
                .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            if let err = sendError {
                Text(err)
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
                    .padding(.bottom, 4)
            }
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            messages = try await viewModel.loadMessages(
                threadId: thread.id, cookie: cookie, baseUrl: baseUrl
            )
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func send() async {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true
        sendError = nil
        messageText = ""
        do {
            try await viewModel.sendMessage(
                threadId: thread.id, body: text, cookie: cookie, baseUrl: baseUrl
            )
            // Brief delay so server indexes the message before reload
            try? await Task.sleep(nanoseconds: 300_000_000)
            let fresh = try? await viewModel.loadMessages(
                threadId: thread.id, cookie: cookie, baseUrl: baseUrl
            )
            if let fresh { messages = fresh }
        } catch {
            messageText = text   // restore so user can retry
            sendError = "Gönderilemedi. Tekrar dene."
        }
        isSending = false
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: WatchMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 20) }
            Text(message.body)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isMine ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundStyle(isMine ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if !isMine { Spacer(minLength: 20) }
        }
    }
}
