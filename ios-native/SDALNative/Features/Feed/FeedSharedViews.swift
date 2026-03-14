import SwiftUI

struct FeedSidePanelsView: View {
    @EnvironmentObject private var i18n: LocalizationManager

    @Binding var sidePanel: FeedSidePanel
    let notifications: [AppNotification]
    let unreadMessages: Int
    let onlineMembers: [MemberSummary]
    let chatMessages: [ChatMessage]
    let quickAccessUsers: [MemberSummary]
    @Binding var chatDraft: String
    let isCompact: Bool
    let onNotificationTap: (AppNotification) -> Void
    let onOpenMessages: () -> Void
    let onOpenExplore: () -> Void
    let onSendChat: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                if isCompact {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FeedSidePanel.allCases) { item in
                                if item == sidePanel {
                                    Button(panelTitle(item)) {
                                        sidePanel = item
                                    }
                                    .buttonStyle(.borderedProminent)
                                } else {
                                    Button(panelTitle(item)) {
                                        sidePanel = item
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    panelBody(sidePanel)
                } else {
                    panelBody(.notifications)
                    panelBody(.livechat)
                    panelBody(.online)
                    panelBody(.messages)
                    panelBody(.quick)
                }
            }
            .animation(.easeInOut(duration: 0.20), value: sidePanel)
        }
    }

    @ViewBuilder
    private func panelBody(_ panel: FeedSidePanel) -> some View {
        switch panel {
        case .notifications:
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("notifications")).font(.headline)
                if notifications.isEmpty {
                    Text(i18n.t("notifications_empty")).font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(notifications.prefix(3)) { n in
                        Button {
                            onNotificationTap(n)
                        } label: {
                            HStack(spacing: 8) {
                                AsyncAvatarView(imageName: n.resim, size: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(n.message ?? "")
                                        .font(.caption)
                                        .lineLimit(2)
                                    Text("@\(n.kadi ?? "user")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .livechat:
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("live_chat_title")).font(.headline)
                if chatMessages.isEmpty {
                    Text(i18n.t("loading")).font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(chatMessages.suffix(4)) { chat in
                        HStack(spacing: 8) {
                            Text("@\(chat.kadi ?? "user")")
                                .font(.caption.bold())
                            Text(chat.message ?? "")
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
                HStack(spacing: 8) {
                    TextField(i18n.t("write_to_chat"), text: $chatDraft)
                        .textFieldStyle(.roundedBorder)
                    Button(i18n.t("send"), action: onSendChat)
                        .buttonStyle(.borderedProminent)
                        .disabled(chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        case .online:
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("online_members")).font(.headline)
                if onlineMembers.isEmpty {
                    Text(i18n.t("online_members_empty")).font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(onlineMembers.prefix(8)) { u in
                        HStack(spacing: 8) {
                            AsyncAvatarView(imageName: u.resim, size: 24)
                            Text("@\(u.kadi ?? "user")")
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
            }
        case .messages:
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("new_messages")).font(.headline)
                Button {
                    onOpenMessages()
                } label: {
                    Text(unreadMessages > 0 ? "\(unreadMessages) \(i18n.t("new_messages"))" : i18n.t("no_new_messages"))
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        case .quick:
            VStack(alignment: .leading, spacing: 8) {
                Text(i18n.t("quick_access")).font(.headline)
                if quickAccessUsers.isEmpty {
                    Text(i18n.t("quick_access")).font(.caption).foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickAccessUsers.prefix(10)) { member in
                                HStack(spacing: 6) {
                                    AsyncAvatarView(imageName: member.resim, size: 20)
                                    Text("@\(member.kadi ?? "uye")").font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(SDALTheme.softPanel)
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                Button(i18n.t("feed_discover_members"), action: onOpenExplore)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func panelTitle(_ panel: FeedSidePanel) -> String {
        switch panel {
        case .notifications: return i18n.t("notifications")
        case .livechat: return i18n.t("live_chat_title")
        case .online: return i18n.t("online_members")
        case .messages: return i18n.t("messages")
        case .quick: return i18n.t("quick_access")
        }
    }
}

struct FeedScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FeedScopeChipButtonStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(active ? SDALTheme.ink : SDALTheme.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? SDALTheme.primary.opacity(0.22) : SDALTheme.softPanel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(active ? SDALTheme.primary.opacity(0.5) : SDALTheme.line, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct PressableActionButtonStyle: ButtonStyle {
    let active: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? SDALTheme.primary.opacity(0.18) : SDALTheme.softPanel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(active ? SDALTheme.primary.opacity(0.45) : SDALTheme.line, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct EditPostSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let post: FeedPost
    let onSaved: () -> Void

    @State private var content = ""
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            Form {
                TextField(i18n.t("content"), text: $content, axis: .vertical)
                    .lineLimit(3...8)
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle(i18n.t("edit_post"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("save")) { Task { await save() } }
                }
            }
            .onAppear {
                content = post.content ?? ""
            }
        }
    }

    private func save() async {
        do {
            try await api.editPost(id: post.id, content: content)
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct PostCommentsSheet: View {
    @EnvironmentObject private var i18n: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let post: FeedPost
    @State private var comments: [PostComment] = []
    @State private var text = ""
    @State private var error: String?

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                List(comments) { c in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("@\(c.kadi ?? "user")")
                            .font(.caption.bold())
                        Text(c.comment ?? "")
                        Text(c.createdAt ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    TextField(i18n.t("write_comment"), text: $text)
                        .textFieldStyle(.roundedBorder)
                    Button(i18n.t("send")) { Task { await add() } }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .navigationTitle(i18n.t("comments"))
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button(i18n.t("close")) { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        do { comments = try await api.fetchPostComments(id: post.id) } catch { self.error = error.localizedDescription }
    }

    private func add() async {
        do {
            try await api.addPostComment(id: post.id, comment: text)
            text = ""
            comments = try await api.fetchPostComments(id: post.id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
