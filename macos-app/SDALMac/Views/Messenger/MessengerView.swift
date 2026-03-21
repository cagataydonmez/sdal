import SwiftUI

struct MessengerView: View {
    @State private var viewModel = MessengerViewModel()

    var body: some View {
        HSplitView {
            // Thread list
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search conversations", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(10)

                Divider()

                if viewModel.isLoadingThreads && viewModel.threads.isEmpty {
                    LoadingView(message: "Loading...")
                } else if viewModel.filteredThreads.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: "No conversations",
                        message: "Start a conversation from the Members tab."
                    )
                } else {
                    List(viewModel.filteredThreads, selection: Binding(
                        get: { viewModel.selectedThread },
                        set: { thread in
                            if let thread { Task { await viewModel.selectThread(thread) } }
                        }
                    )) { thread in
                        ThreadRowView(thread: thread, isSelected: viewModel.selectedThread?.id == thread.id)
                            .tag(thread)
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

            // Chat
            if let thread = viewModel.selectedThread {
                ChatPanelView(
                    thread: thread,
                    messages: viewModel.messages,
                    isLoading: viewModel.isLoadingMessages,
                    messageText: $viewModel.messageText,
                    onSend: { Task { await viewModel.sendMessage() } }
                )
            } else {
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: "Select a conversation",
                    message: "Choose a conversation from the sidebar to start chatting."
                )
            }
        }
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { viewModel.showNewConversation = true } label: {
                    Label("New Conversation", systemImage: "square.and.pencil")
                }
                .help("Start a new conversation")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await viewModel.loadThreads() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh conversations")
            }
        }
        .sheet(isPresented: $viewModel.showNewConversation) {
            NewConversationSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadThreads()
            viewModel.startPolling()
        }
        .onDisappear { viewModel.stopPolling() }
    }
}

struct ThreadRowView: View {
    let thread: MessengerThread
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            AvatarView(url: thread.peerPhotoURL, initials: thread.peerInitials, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(thread.displayName).font(.callout).fontWeight(.medium).lineLimit(1)
                    Spacer()
                    Text(thread.relativeTime).font(.caption2).foregroundStyle(.tertiary)
                }
                HStack {
                    Text(thread.lastMessagePreview).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    if let count = thread.unreadCount, count > 0 { BadgeView(count: count) }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct ChatPanelView: View {
    let thread: MessengerThread
    let messages: [ChatMessage]
    let isLoading: Bool
    @Binding var messageText: String
    var onSend: () -> Void

    private let currentUserId = AuthService.shared.currentUser?.id

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AvatarView(url: thread.peerPhotoURL, initials: thread.peerInitials, size: 32)
                Text(thread.displayName).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.bar)

            Divider()

            if isLoading && messages.isEmpty {
                LoadingView(message: "Loading messages...")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message, isMine: message.senderId == currentUserId)
                                    .id(message.id)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            HStack(spacing: 10) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit {
                        if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { onSend() }
                    }
                Button { onSend() } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send message")
            }
            .padding(12)
        }
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 60) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                Text(message.body ?? "")
                    .font(.body)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(isMine ? Color.accentColor : Color(.controlBackgroundColor))
                    .foregroundStyle(isMine ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .textSelection(.enabled)
                Text(message.relativeTime).font(.caption2).foregroundStyle(.tertiary)
            }
            if !isMine { Spacer(minLength: 60) }
        }
    }
}

struct NewConversationSheet: View {
    @Bindable var viewModel: MessengerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Text("New Conversation").font(.headline)
                Spacer()
                Spacer().frame(width: 60)
            }
            .padding()
            Divider()

            TextField("Search contacts...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
                .onChange(of: searchText) { _, newValue in
                    Task { await viewModel.searchContacts(newValue) }
                }

            if viewModel.contacts.isEmpty && !searchText.isEmpty {
                EmptyStateView(icon: "person.slash", title: "No contacts found")
            } else {
                List(viewModel.contacts) { contact in
                    Button {
                        Task {
                            await viewModel.startNewConversation(with: contact.id)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            AvatarView(url: contact.photoURL, initials: String(contact.displayName.prefix(2)).uppercased(), size: 32)
                            Text(contact.displayName).font(.callout)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 400, height: 420)
    }
}
