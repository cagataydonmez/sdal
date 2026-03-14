import SwiftUI

extension AdminView {
    @ViewBuilder
    var panelBody: some View {
        switch panel {
        case .overview:
            overviewPanel
        case .moderation:
            moderationPanel
        case .verification:
            verificationPanel
        case .operations:
            operationsPanel
        }
    }

    var overviewPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(i18n.t("stats"))
                        .font(.headline)
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 160), spacing: 10)
                    ], spacing: 10) {
                        kpiCard(title: i18n.t("users"), value: stats?.totalUsers, tint: SDALTheme.secondary)
                        kpiCard(title: i18n.t("active_users"), value: stats?.activeUsers, tint: .green)
                        kpiCard(title: i18n.t("posts"), value: stats?.totalPosts, tint: SDALTheme.primary)
                        kpiCard(title: i18n.t("stories"), value: stats?.totalStories, tint: .orange)
                        kpiCard(title: i18n.t("pending_verification"), value: stats?.pendingVerifications, tint: .yellow)
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(i18n.t("live"))
                        .font(.headline)
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 160), spacing: 10)
                    ], spacing: 10) {
                        kpiCard(title: i18n.t("online_members"), value: live?.onlineMembers, tint: .mint)
                        kpiCard(title: i18n.t("unread_messages"), value: live?.unreadMessages, tint: .indigo)
                        kpiCard(title: i18n.t("pending_invites"), value: live?.pendingGroupInvites, tint: .pink)
                        kpiCard(title: i18n.t("active_rooms"), value: live?.activeRooms, tint: .cyan)
                    }
                }
            }
        }
        .task { if stats == nil || live == nil { await loadOverview() } }
    }

    func kpiCard(title: String, value: Int?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(SDALTheme.muted)
            Text(value.map(String.init) ?? "-")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SDALTheme.ink)
            RoundedRectangle(cornerRadius: 99, style: .continuous)
                .fill(tint.opacity(0.26))
                .frame(height: 5)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SDALTheme.cardAlt.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SDALTheme.line, lineWidth: 1)
        )
    }

    var moderationPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                Picker(i18n.t("queue"), selection: $queue) {
                    Text(i18n.t("posts")).tag(ModerationQueue.posts)
                    Text(i18n.t("stories")).tag(ModerationQueue.stories)
                    Text(i18n.t("messages")).tag(ModerationQueue.messages)
                    Text(i18n.t("chat")).tag(ModerationQueue.chat)
                }
                .pickerStyle(.segmented)
                .onChange(of: queue) { _, _ in Task { await loadModeration() } }
            }

            if moderationItems.isEmpty {
                GlassCard {
                    Text(i18n.t("no_items_in_queue"))
                        .foregroundStyle(SDALTheme.muted)
                }
            } else {
                ForEach(moderationItems) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("#\(item.id)")
                                    .font(.caption.bold())
                                Spacer()
                                Button(i18n.t("delete"), role: .destructive) {
                                    Task { await deleteModerationItem(item.id) }
                                }
                                .buttonStyle(.bordered)
                            }
                            Text(item.content ?? item.message ?? "-")
                                .font(.subheadline)
                            HStack(spacing: 8) {
                                Text(item.authorKadi ?? item.senderKadi ?? item.kadi ?? "-")
                                Text("•")
                                Text(item.createdAt ?? "")
                            }
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                        }
                    }
                }
            }
        }
        .task { if moderationItems.isEmpty { await loadModeration() } }
    }

    var verificationPanel: some View {
        VStack(spacing: 12) {
            if verificationRequests.isEmpty {
                GlassCard {
                    Text(i18n.t("no_pending_verification_requests"))
                        .foregroundStyle(SDALTheme.muted)
                }
            } else {
                ForEach(verificationRequests) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("@\(item.kadi ?? i18n.t("user"))")
                                .font(.headline)
                            Text("\(item.isim ?? "") \(item.soyisim ?? "")")
                                .font(.subheadline)
                                .foregroundStyle(SDALTheme.muted)
                            Text(item.email ?? "-")
                                .font(.caption)
                                .foregroundStyle(SDALTheme.muted)
                            HStack(spacing: 8) {
                                Button(i18n.t("approve")) {
                                    Task { await decideVerification(item.id, approve: true) }
                                }
                                .buttonStyle(.borderedProminent)
                                Button(i18n.t("reject"), role: .destructive) {
                                    Task { await decideVerification(item.id, approve: false) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
        .task { if verificationRequests.isEmpty { await loadVerification() } }
    }

    var operationsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                Picker(i18n.t("operations"), selection: $opsTab) {
                    Text(i18n.t("users")).tag(AdminOpsTab.users)
                    Text(i18n.t("follows")).tag(AdminOpsTab.follows)
                    Text(i18n.t("groups")).tag(AdminOpsTab.groups)
                    Text(i18n.t("filters")).tag(AdminOpsTab.filters)
                    Text(i18n.t("engagement")).tag(AdminOpsTab.engagement)
                    Text(i18n.t("email")).tag(AdminOpsTab.email)
                    Text(i18n.t("db")).tag(AdminOpsTab.db)
                    Text(i18n.t("pages")).tag(AdminOpsTab.pages)
                    Text(i18n.t("logs")).tag(AdminOpsTab.logs)
                    Text(i18n.t("album")).tag(AdminOpsTab.album)
                    Text(i18n.t("tournament")).tag(AdminOpsTab.tournament)
                }
                .pickerStyle(.menu)
                .onChange(of: opsTab) { _, _ in Task { await loadOperations() } }
            }

            switch opsTab {
            case .users:
                usersOpsPanel
            case .follows:
                followsOpsPanel
            case .groups:
                groupsOpsPanel
            case .filters:
                filtersOpsPanel
            case .engagement:
                engagementOpsPanel
            case .email:
                emailOpsPanel
            case .db:
                dbOpsPanel
            case .pages:
                pagesOpsPanel
            case .logs:
                logsOpsPanel
            case .album:
                albumOpsPanel
            case .tournament:
                tournamentOpsPanel
            }
        }
        .task { await loadOperations() }
    }
}
