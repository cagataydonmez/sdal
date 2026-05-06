import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @State private var showNewConversation = false

    private var cookie:  String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    var body: some View {
        Group {
            switch viewModel.threadsState {
            case .idle, .loading:
                LoadingView()
            case .failed(let msg):
                ErrorRetryView(message: msg) {
                    Task { await viewModel.loadThreads(cookie: cookie, baseUrl: baseUrl) }
                }
            case .loaded(let threads):
                if threads.isEmpty {
                    emptyView
                } else {
                    threadList(threads)
                }
            }
        }
        .navigationTitle("Mesajlar")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showNewConversation = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showNewConversation) {
            NewConversationView()
        }
        // Poll for new messages every 15 seconds
        .task(id: cookie) {
            guard !cookie.isEmpty else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled else { return }
                await viewModel.loadThreads(cookie: cookie, baseUrl: baseUrl, silent: true)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Mesaj yok")
                .font(.caption2).foregroundStyle(.secondary)
            Button {
                showNewConversation = true
            } label: {
                Label("Yeni mesaj", systemImage: "square.and.pencil")
                    .font(.caption2)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func threadList(_ threads: [WatchThread]) -> some View {
        List(threads) { thread in
            NavigationLink(destination: ConversationView(thread: thread)) {
                ThreadRow(thread: thread)
            }
        }
        .listStyle(.carousel)
        .refreshable {
            await viewModel.loadThreads(cookie: cookie, baseUrl: baseUrl)
        }
    }
}

// MARK: - Thread Row

struct ThreadRow: View {
    let thread: WatchThread

    var body: some View {
        HStack(spacing: 8) {
            AvatarView(initials: thread.initials, photoUrl: thread.peerPhoto, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(thread.peerName.isEmpty ? "@\(thread.peerHandle)" : thread.peerName)
                        .font(.caption2).fontWeight(.semibold).lineLimit(1)
                    Spacer()
                    if thread.unreadCount > 0 {
                        Text("\(thread.unreadCount)")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.blue).clipShape(Capsule())
                            .foregroundStyle(.white)
                    }
                }
                if !thread.lastMessage.isEmpty {
                    Text(thread.lastMessage)
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
