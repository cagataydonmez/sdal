import SwiftUI

struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.error {
                ErrorBanner(message: error) { await viewModel.refresh() }
            }

            if viewModel.isLoading && viewModel.notifications.isEmpty {
                LoadingView(message: "Loading notifications...")
            } else if viewModel.notifications.isEmpty {
                EmptyStateView(icon: "bell.slash", title: "No notifications", message: "You're all caught up.")
            } else {
                List {
                    ForEach(viewModel.notifications) { notification in
                        NotificationRow(notification: notification)
                            .onTapGesture {
                                Task { await viewModel.markRead(notification) }
                            }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.unreadCount > 0 {
                    Button { Task { await viewModel.markAllRead() } } label: {
                        Label("Mark All Read", systemImage: "checkmark.circle")
                    }
                    .help("Mark all notifications as read")
                }

                Button { Task { await viewModel.refresh() } } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh notifications")
            }
        }
        .task {
            await viewModel.refresh()
            viewModel.startPolling()
        }
        .onDisappear { viewModel.stopPolling() }
    }
}

struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(spacing: 12) {
            if let photoURL = notification.sourcePhotoURL {
                AvatarView(url: photoURL, initials: String(notification.sourceDisplayName.prefix(1)), size: 32)
            } else {
                Image(systemName: notification.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(notification.isRead ? Color.secondary : Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(notification.isRead ? Color.gray.opacity(0.1) : Color.accentColor.opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                if !notification.sourceDisplayName.isEmpty {
                    Text(notification.sourceDisplayName).font(.caption).fontWeight(.semibold)
                }
                Text(notification.message ?? "Notification")
                    .font(.callout)
                    .fontWeight(notification.isRead ? .regular : .medium)
                    .lineLimit(2)
                Text(notification.relativeTime).font(.caption).foregroundStyle(.tertiary)
            }

            Spacer()

            if !notification.isRead {
                Circle().fill(Color.accentColor).frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .opacity(notification.isRead ? 0.7 : 1)
    }
}
