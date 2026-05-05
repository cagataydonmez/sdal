import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    var body: some View {
        Group {
            switch viewModel.threadsState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let msg):
                ErrorRetryView(message: msg) {
                    Task {
                        await viewModel.loadThreads(
                            cookie: sessionManager.sessionCookie,
                            baseUrl: sessionManager.apiBaseUrl
                        )
                    }
                }
            case .loaded(let threads):
                if threads.isEmpty {
                    EmptyMessagesView()
                } else {
                    List(threads) { thread in
                        ThreadRow(thread: thread)
                    }
                    .listStyle(.carousel)
                }
            }
        }
        .navigationTitle("Mesajlar")
    }
}

private struct ThreadRow: View {
    let thread: WatchThread

    var body: some View {
        HStack(spacing: 8) {
            AvatarView(initials: thread.initials, photoUrl: thread.peerPhoto, size: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(thread.peerName.isEmpty ? "@\(thread.peerHandle)" : thread.peerName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    if thread.unreadCount > 0 {
                        Text("\(thread.unreadCount)")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.blue)
                            .clipShape(Capsule())
                    }
                }
                Text(thread.lastMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct EmptyMessagesView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundStyle(.secondary)
            Text("Mesaj yok")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
