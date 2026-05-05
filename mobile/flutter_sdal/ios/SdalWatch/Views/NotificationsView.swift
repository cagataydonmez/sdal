import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager

    var body: some View {
        Group {
            switch viewModel.notificationsState {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let msg):
                ErrorRetryView(message: msg) {
                    Task {
                        await viewModel.loadNotifications(
                            cookie: sessionManager.sessionCookie,
                            baseUrl: sessionManager.apiBaseUrl
                        )
                    }
                }
            case .loaded(let items):
                if items.isEmpty {
                    EmptyNotificationsView()
                } else {
                    List(items) { item in
                        NotificationRow(item: item)
                    }
                    .listStyle(.carousel)
                }
            }
        }
        .navigationTitle("Bildirimler")
    }
}

private struct NotificationRow: View {
    let item: WatchNotificationItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.systemImageName)
                .font(.system(size: 14))
                .foregroundStyle(item.isRead ? .secondary : .blue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                if !item.sourceName.isEmpty {
                    Text(item.sourceName)
                        .font(.caption2)
                        .fontWeight(item.isRead ? .regular : .semibold)
                        .lineLimit(1)
                }
                if !item.body.isEmpty {
                    Text(item.body)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(item.isRead ? 0.7 : 1.0)
    }
}

private struct EmptyNotificationsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .foregroundStyle(.secondary)
            Text("Bildirim yok")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
