import SwiftUI

extension AdminView {
    var usersOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("user_management"))
                        .font(.headline)
                    HStack {
                        TextField(i18n.t("search_username_name_email"), text: $userQuery)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("load")) { Task { await loadUsers() } }
                            .buttonStyle(.borderedProminent)
                    }
                    HStack {
                        Picker(i18n.t("filter"), selection: $userFilter) {
                            Text(i18n.t("all")).tag("all")
                            Text(i18n.t("active")).tag("active")
                            Text(i18n.t("pending")).tag("pending")
                            Text(i18n.t("banned")).tag("banned")
                            Text(i18n.t("online")).tag("online")
                        }
                        .pickerStyle(.menu)
                        Picker(i18n.t("sort"), selection: $userSort) {
                            Text(i18n.t("engagement_desc")).tag("engagement_desc")
                            Text(i18n.t("engagement_asc")).tag("engagement_asc")
                            Text(i18n.t("recent")).tag("recent")
                            Text(i18n.t("name")).tag("name")
                        }
                        .pickerStyle(.menu)
                    }
                    Toggle(i18n.t("with_photo"), isOn: $userWithPhoto)
                    Toggle(i18n.t("verified_only"), isOn: $userVerifiedOnly)
                    Toggle(i18n.t("online_only"), isOn: $userOnlineOnly)
                    Toggle(i18n.t("admin_only"), isOn: $userAdminOnly)
                    if let meta = managedUsersMeta {
                        Text(String(format: i18n.t("total_returned_format"), meta.total ?? 0, meta.returned ?? 0))
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    }
                }
            }

            if managedUsers.isEmpty {
                GlassCard {
                    Text(i18n.t("no_users_loaded"))
                        .foregroundStyle(SDALTheme.muted)
                }
            } else {
                ForEach(managedUsers) { user in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("@\(user.kadi ?? "-")")
                                        .font(.headline)
                                    Text("\(user.isim ?? "") \(user.soyisim ?? "")")
                                        .font(.subheadline)
                                        .foregroundStyle(SDALTheme.muted)
                                }
                                Spacer()
                                Button(user.verified == true ? i18n.t("unverify") : i18n.t("verify")) {
                                    Task { await setUserVerified(user.id, verified: user.verified != true) }
                                }
                                .buttonStyle(.bordered)
                                Button(i18n.t("edit")) { Task { await openUserEditor(user.id) } }
                                    .buttonStyle(.borderedProminent)
                            }
                            HStack(spacing: 8) {
                                StatusChip(label: "A", active: (user.aktiv ?? 0) == 1, tint: SDALTheme.secondary)
                                StatusChip(label: "B", active: (user.yasak ?? 0) == 1, tint: .red)
                                StatusChip(label: "V", active: user.verified == true, tint: SDALTheme.primary)
                                StatusChip(label: "O", active: user.online == true, tint: .green)
                                StatusChip(label: "ADM", active: (user.admin ?? 0) == 1, tint: .orange)
                                Spacer()
                                Text(String(format: i18n.t("score_format"), user.engagementScore ?? 0))
                                    .font(.caption)
                                    .foregroundStyle(SDALTheme.muted)
                            }
                        }
                    }
                }
            }
        }
    }

    var followsOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("follow_inspector")).font(.headline)
                    HStack {
                        TextField(i18n.t("user_id"), text: $followUserIdText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("load")) { Task { await loadFollows() } }
                            .buttonStyle(.borderedProminent)
                    }
                    if let followTarget {
                        Text(String(format: i18n.t("user_format"), followTarget.kadi ?? "-", followTarget.id ?? 0))
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    }
                }
            }

            if followItems.isEmpty {
                GlassCard { Text(i18n.t("no_follow_rows")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(followItems) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("@\(item.kadi ?? "-")").font(.headline)
                            HStack(spacing: 8) {
                                Text(String(format: i18n.t("messages_count"), item.messageCount ?? 0))
                                Text(String(format: i18n.t("quotes_count"), item.quoteCount ?? 0))
                            }
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                        }
                    }
                }
            }
        }
    }

    var groupsOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                HStack {
                    Text(i18n.t("groups_admin")).font(.headline)
                    Spacer()
                    Button(i18n.t("refresh")) { Task { await loadGroups() } }
                        .buttonStyle(.bordered)
                }
            }
            if adminGroups.isEmpty {
                GlassCard { Text(i18n.t("no_groups")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(adminGroups) { group in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.name ?? "-").font(.headline)
                            Text(group.description ?? "")
                                .font(.subheadline)
                                .foregroundStyle(SDALTheme.muted)
                            HStack {
                                Text(String(format: i18n.t("id_format"), group.id)).font(.caption).foregroundStyle(SDALTheme.muted)
                                Spacer()
                                Button(i18n.t("delete"), role: .destructive) { Task { await deleteGroup(group.id) } }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
    }

    var filtersOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("filters")).font(.headline)
                    HStack {
                        TextField(i18n.t("new_blocked_word"), text: $newFilterWord)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("add")) { Task { await addFilter() } }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }

            if adminFilters.isEmpty {
                GlassCard { Text(i18n.t("no_filter_words")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(adminFilters) { item in
                    GlassCard {
                        HStack {
                            TextField(
                                i18n.t("word"),
                                text: Binding(
                                    get: { filterEdits[item.id] ?? item.kufur ?? "" },
                                    set: { filterEdits[item.id] = $0 }
                                )
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textFieldStyle(.roundedBorder)
                            Button(i18n.t("save")) { Task { await saveFilter(item.id) } }
                                .buttonStyle(.bordered)
                            Button(i18n.t("delete"), role: .destructive) { Task { await deleteFilter(item.id) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    var engagementOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("engagement_controls")).font(.headline)
                    HStack {
                        Button(i18n.t("recalculate_scores")) { Task { await recalculateScores() } }
                            .buttonStyle(.borderedProminent)
                        Button(i18n.t("rebalance_ab")) { Task { await rebalanceAB() } }
                            .buttonStyle(.bordered)
                    }
                }
            }

            if !abConfigs.isEmpty {
                ForEach(abConfigs) { config in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(config.variant) - \(config.name ?? "")")
                                .font(.headline)
                            HStack {
                                Text(i18n.t("traffic"))
                                Slider(
                                    value: Binding(
                                        get: { abTraffic[config.variant] ?? Double(config.trafficPct ?? 0) },
                                        set: { abTraffic[config.variant] = $0 }
                                    ),
                                    in: 0...100,
                                    step: 1
                                )
                                Text("\(Int(abTraffic[config.variant] ?? Double(config.trafficPct ?? 0)))%")
                                    .font(.caption)
                            }
                            Toggle(
                                i18n.t("enabled"),
                                isOn: Binding(
                                    get: { abEnabled[config.variant] ?? (config.enabled ?? true) },
                                    set: { abEnabled[config.variant] = $0 }
                                )
                            )
                            Button(i18n.t("apply")) { Task { await applyAbConfig(config) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("engagement_scores")).font(.headline)
                    HStack {
                        TextField(i18n.t("search_user"), text: $scoreQuery)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("load")) { Task { await loadEngagementScores() } }
                            .buttonStyle(.bordered)
                    }
                    HStack {
                        Picker(i18n.t("status"), selection: $scoreStatus) {
                            Text(i18n.t("all")).tag("all")
                            Text(i18n.t("active")).tag("active")
                            Text(i18n.t("pending")).tag("pending")
                            Text(i18n.t("banned")).tag("banned")
                        }
                        .pickerStyle(.menu)
                        TextField(i18n.t("variant"), text: $scoreVariant)
                            .textInputAutocapitalization(.characters)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            if !engagementScores.isEmpty {
                ForEach(engagementScores.prefix(30)) { row in
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("@\(row.kadi ?? "-")").font(.headline)
                                Text("\(row.isim ?? "") \(row.soyisim ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(SDALTheme.muted)
                            }
                            Spacer()
                            Text(String(format: "%.2f", row.score ?? 0))
                                .font(.headline)
                        }
                    }
                }
            }
        }
    }

    var emailOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(i18n.t("email_center")).font(.headline)
                        Spacer()
                        Button(i18n.t("refresh")) { Task { await loadEmailData() } }
                            .buttonStyle(.bordered)
                    }
                    Picker(i18n.t("send_mode"), selection: $emailSendMode) {
                        Text(i18n.t("single")).tag(AdminEmailSendMode.single)
                        Text(i18n.t("bulk")).tag(AdminEmailSendMode.bulk)
                    }
                    .pickerStyle(.segmented)
                    TextField(i18n.t("from"), text: $emailFrom)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textFieldStyle(.roundedBorder)
                    if emailSendMode == .single {
                        TextField(i18n.t("to"), text: $emailTo)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Picker(i18n.t("category"), selection: $selectedEmailCategoryId) {
                            Text(i18n.t("select_category")).tag(Int?.none)
                            ForEach(emailCategories) { item in
                                Text(item.ad ?? "-").tag(Optional(item.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    TextField(i18n.t("subject"), text: $emailSubject)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("html_body"), text: $emailBody, axis: .vertical)
                        .lineLimit(4...10)
                        .textFieldStyle(.roundedBorder)
                    Button(i18n.t("send")) { Task { await sendEmailAction() } }
                        .buttonStyle(.borderedProminent)
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(editingEmailCategoryId == nil ? i18n.t("email_categories") : "\(i18n.t("edit")) \(i18n.t("category")) #\(editingEmailCategoryId ?? 0)")
                            .font(.headline)
                        Spacer()
                        if editingEmailCategoryId != nil {
                            Button(i18n.t("cancel")) { clearCategoryDraft() }
                                .buttonStyle(.bordered)
                        }
                    }
                    TextField(i18n.t("category_name"), text: $newEmailCategoryName)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("type"), text: $newEmailCategoryType)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("value"), text: $newEmailCategoryValue)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("description"), text: $newEmailCategoryDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                    Button(editingEmailCategoryId == nil ? i18n.t("create") : i18n.t("save")) {
                        Task { await saveEmailCategoryAction() }
                    }
                    .buttonStyle(.borderedProminent)

                    if !emailCategories.isEmpty {
                        Divider()
                        ForEach(emailCategories) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.ad ?? "-").font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Button(i18n.t("edit")) { loadCategoryDraft(item) }
                                        .buttonStyle(.bordered)
                                    Button(i18n.t("delete"), role: .destructive) { Task { await deleteEmailCategory(item.id) } }
                                        .buttonStyle(.bordered)
                                }
                                Text("\(item.tur ?? "-") • \(item.deger ?? "-")")
                                    .font(.caption)
                                    .foregroundStyle(SDALTheme.muted)
                                if let aciklama = item.aciklama, !aciklama.isEmpty {
                                    Text(aciklama)
                                        .font(.caption)
                                        .foregroundStyle(SDALTheme.muted)
                                }
                                Button(i18n.t("use_for_bulk_send")) {
                                    selectedEmailCategoryId = item.id
                                    emailSendMode = .bulk
                                }
                                .buttonStyle(.plain)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SDALTheme.primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(editingEmailTemplateId == nil ? i18n.t("email_templates") : "\(i18n.t("edit")) \(i18n.t("template")) #\(editingEmailTemplateId ?? 0)")
                            .font(.headline)
                        Spacer()
                        if editingEmailTemplateId != nil {
                            Button(i18n.t("cancel")) { clearTemplateDraft() }
                                .buttonStyle(.bordered)
                        }
                    }
                    TextField(i18n.t("name"), text: $newEmailTemplateName)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("subject"), text: $newEmailTemplateSubject)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("html_body"), text: $newEmailTemplateBody, axis: .vertical)
                        .lineLimit(4...10)
                        .textFieldStyle(.roundedBorder)
                    Button(editingEmailTemplateId == nil ? i18n.t("create") : i18n.t("save")) {
                        Task { await saveEmailTemplateAction() }
                    }
                    .buttonStyle(.borderedProminent)

                    if !emailTemplates.isEmpty {
                        Divider()
                        ForEach(emailTemplates) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.ad ?? "-").font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Button(i18n.t("use")) { applyTemplateToComposer(item) }
                                        .buttonStyle(.bordered)
                                    Button(i18n.t("edit")) { loadTemplateDraft(item) }
                                        .buttonStyle(.bordered)
                                    Button(i18n.t("delete"), role: .destructive) { Task { await deleteEmailTemplate(item.id) } }
                                        .buttonStyle(.bordered)
                                }
                                Text(item.konu ?? "")
                                    .font(.caption)
                                    .foregroundStyle(SDALTheme.muted)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    var dbOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(i18n.t("database_tools")).font(.headline)
                        Spacer()
                        Button(i18n.t("refresh")) { Task { await loadDbData() } }
                            .buttonStyle(.bordered)
                    }
                    HStack {
                        TextField(i18n.t("backup_label"), text: $backupLabel)
                            .textFieldStyle(.roundedBorder)
                        Button(i18n.t("create_backup")) { Task { await createBackupAction() } }
                            .buttonStyle(.borderedProminent)
                        Button(i18n.t("restore")) { showRestorePicker = true }
                            .buttonStyle(.bordered)
                    }
                    if let selectedRestoreFileName, !selectedRestoreFileName.isEmpty {
                        Text("\(i18n.t("last_restored")): \(selectedRestoreFileName)")
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    }
                    if !dbTables.isEmpty {
                        Picker(i18n.t("table"), selection: Binding(
                            get: { selectedDbTableName ?? dbTables.first?.name ?? "" },
                            set: { value in
                                selectedDbTableName = value
                                Task { await loadDbTable(name: value) }
                            }
                        )) {
                            ForEach(dbTables, id: \.name) { table in
                                Text(table.name ?? "-").tag(table.name ?? "")
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    if let tableInfo = dbTables.first(where: { $0.name == selectedDbTableName }) {
                        HStack {
                            statRow(i18n.t("rows"), tableInfo.rowCount)
                        }
                    }
                }
            }

            if !dbTableColumns.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(i18n.t("columns")).font(.headline)
                        ForEach(dbTableColumns) { column in
                            Text("\(column.name ?? "-") • \(column.type ?? "-") • pk:\(column.pk ?? 0)")
                                .font(.caption)
                                .foregroundStyle(SDALTheme.muted)
                        }
                    }
                }
            }

            if !dbTableRows.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(i18n.t("rows_preview")).font(.headline)
                        ScrollView([.horizontal, .vertical]) {
                            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                                Section {
                                    ForEach(Array(dbTableRows.prefix(20).enumerated()), id: \.offset) { index, row in
                                        HStack(spacing: 0) {
                                            ForEach(dbPreviewColumns, id: \.self) { column in
                                                Text((row[column]?.description ?? "null").trimmingCharacters(in: .whitespacesAndNewlines))
                                                    .font(.caption2)
                                                    .foregroundStyle(SDALTheme.ink)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 7)
                                                    .frame(width: 160, alignment: .leading)
                                                    .overlay(alignment: .trailing) {
                                                        Rectangle()
                                                            .fill(SDALTheme.line.opacity(0.65))
                                                            .frame(width: 1)
                                                    }
                                            }
                                        }
                                        .background(index.isMultiple(of: 2) ? SDALTheme.cardAlt.opacity(0.35) : Color.clear)
                                        .overlay(alignment: .bottom) {
                                            Rectangle()
                                                .fill(SDALTheme.line.opacity(0.55))
                                                .frame(height: 1)
                                        }
                                    }
                                } header: {
                                    HStack(spacing: 0) {
                                        ForEach(dbPreviewColumns, id: \.self) { column in
                                            Text(column)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(SDALTheme.ink)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 8)
                                                .frame(width: 160, alignment: .leading)
                                                .overlay(alignment: .trailing) {
                                                    Rectangle()
                                                        .fill(SDALTheme.line.opacity(0.8))
                                                        .frame(width: 1)
                                                }
                                        }
                                    }
                                    .background(SDALTheme.softPanel)
                                }
                            }
                        }
                        .frame(minHeight: 220, maxHeight: 380)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("backups")).font(.headline)
                    if dbBackups.isEmpty {
                        Text(i18n.t("no_backups"))
                            .font(.caption)
                            .foregroundStyle(SDALTheme.muted)
                    } else {
                        ForEach(dbBackups) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "-")
                                        .font(.subheadline)
                                    Text("\(i18n.t("size")): \(formatBytes(item.size ?? 0)) • \(item.mtime ?? "-")")
                                        .font(.caption2)
                                        .foregroundStyle(SDALTheme.muted)
                                }
                                Spacer()
                                if let name = item.name, !name.isEmpty {
                                    Button(i18n.t("download")) {
                                        Task { await downloadBackup(name: name) }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    var pagesOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(selectedPageIdForEdit == nil ? i18n.t("create_page") : "\(i18n.t("edit")) \(i18n.t("pages")) #\(selectedPageIdForEdit ?? 0)")
                            .font(.headline)
                        Spacer()
                        Button(i18n.t("refresh")) { Task { await loadPages() } }
                            .buttonStyle(.bordered)
                    }
                    TextField(i18n.t("page_name"), text: $pageName)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("page_url"), text: $pageUrl)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("parent_id"), text: $pageParentId)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("image"), text: $pageImage)
                        .textFieldStyle(.roundedBorder)
                    Toggle(i18n.t("menu_visible"), isOn: $pageMenuVisible)
                    Toggle(i18n.t("redirect"), isOn: $pageRedirect)
                    Toggle(i18n.t("feature_flag"), isOn: $pageMFeature)
                    HStack {
                        Button(selectedPageIdForEdit == nil ? i18n.t("create") : i18n.t("save")) {
                            Task { await savePageAction() }
                        }
                        .buttonStyle(.borderedProminent)
                        if selectedPageIdForEdit != nil {
                            Button(i18n.t("cancel")) { clearPageDraft() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            if adminPages.isEmpty {
                GlassCard { Text(i18n.t("no_pages")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(adminPages) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.sayfaismi ?? "-").font(.headline)
                            Text(item.sayfaurl ?? "-")
                                .font(.caption)
                                .foregroundStyle(SDALTheme.muted)
                            HStack {
                                Text(String(format: i18n.t("id_parent_format"), item.id, item.babaid ?? 0))
                                    .font(.caption2)
                                    .foregroundStyle(SDALTheme.muted)
                                Spacer()
                                Button(i18n.t("edit")) { loadPageDraft(item) }
                                    .buttonStyle(.bordered)
                                Button(i18n.t("delete"), role: .destructive) {
                                    Task { await deletePageAction(item.id) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
    }

    var logsOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("logs")).font(.headline)
                    HStack {
                        Picker(i18n.t("type"), selection: $logType) {
                            Text(i18n.t("error")).tag("error")
                            Text(i18n.t("page")).tag("page")
                            Text(i18n.t("member")).tag("member")
                            Text(i18n.t("app")).tag("app")
                        }
                        .pickerStyle(.menu)
                        Button(i18n.t("load_files")) { Task { await loadLogs() } }
                            .buttonStyle(.bordered)
                    }
                    HStack {
                        TextField(i18n.t("from_date"), text: $logFrom)
                            .textFieldStyle(.roundedBorder)
                        TextField(i18n.t("to_date"), text: $logTo)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        TextField(i18n.t("search"), text: $logQuery)
                            .textFieldStyle(.roundedBorder)
                        TextField(i18n.t("activity"), text: $logActivity)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        TextField(i18n.t("user_id"), text: $logUserId)
                            .textFieldStyle(.roundedBorder)
                        TextField(i18n.t("limit"), text: $logLimit)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    if let selectedLogFile {
                        HStack {
                            Text("\(i18n.t("file")): \(selectedLogFile)")
                                .font(.caption)
                                .foregroundStyle(SDALTheme.muted)
                            Spacer()
                            Text(String(format: i18n.t("matched_format"), logMatched, logTotal))
                                .font(.caption2)
                                .foregroundStyle(SDALTheme.muted)
                        }
                        HStack {
                            Button(i18n.t("apply_filters")) { Task { await openLogFile(selectedLogFile, offset: 0) } }
                                .buttonStyle(.bordered)
                            Button(i18n.t("prev")) { Task { await paginateLog(direction: -1) } }
                                .buttonStyle(.bordered)
                                .disabled(logOffset <= 0)
                            Button(i18n.t("next")) { Task { await paginateLog(direction: 1) } }
                                .buttonStyle(.bordered)
                                .disabled(logOffset + (Int(logLimit) ?? 500) >= logMatched)
                        }
                    }
                }
            }
            if !logFiles.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(i18n.t("files")).font(.headline)
                        ForEach(logFiles) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "-")
                                        .font(.subheadline)
                                    Text("\(i18n.t("size")): \(formatBytes(item.size ?? 0)) • \(item.mtime ?? "-")")
                                        .font(.caption2)
                                        .foregroundStyle(SDALTheme.muted)
                                }
                                Spacer()
                                if let name = item.name, !name.isEmpty {
                                    Button(i18n.t("open")) { Task { await openLogFile(name, offset: 0) } }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }
            }
            if !logContent.isEmpty {
                GlassCard {
                    ScrollView {
                        Text(logContent)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 220)
                }
            }
        }
    }

    var albumOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(selectedAlbumCategoryIdForEdit == nil ? i18n.t("create_album_category") : "\(i18n.t("edit")) \(i18n.t("category")) #\(selectedAlbumCategoryIdForEdit ?? 0)")
                            .font(.headline)
                        Spacer()
                        Button(i18n.t("refresh")) { Task { await loadAlbumAdmin() } }
                            .buttonStyle(.bordered)
                    }
                    TextField(i18n.t("category"), text: $albumCategoryName)
                        .textFieldStyle(.roundedBorder)
                    TextField(i18n.t("description"), text: $albumCategoryDescription)
                        .textFieldStyle(.roundedBorder)
                    Toggle(i18n.t("active"), isOn: $albumCategoryActive)
                    HStack {
                        Button(selectedAlbumCategoryIdForEdit == nil ? i18n.t("create") : i18n.t("save")) {
                            Task { await saveAlbumCategoryAction() }
                        }
                        .buttonStyle(.borderedProminent)
                        if selectedAlbumCategoryIdForEdit != nil {
                            Button(i18n.t("cancel")) { clearAlbumCategoryDraft() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            if !albumCategories.isEmpty {
                ForEach(albumCategories) { item in
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.kategori ?? "-").font(.headline)
                                let count = albumCategoryCounts[String(item.id)]
                                Text(String(format: i18n.t("active_pending_format"), count?.activeCount ?? 0, count?.inactiveCount ?? 0))
                                    .font(.caption)
                                    .foregroundStyle(SDALTheme.muted)
                            }
                            Spacer()
                            Button(i18n.t("edit")) { loadAlbumCategoryDraft(item) }
                                .buttonStyle(.bordered)
                            Button(i18n.t("delete"), role: .destructive) { Task { await deleteAlbumCategoryAction(item.id) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(i18n.t("album_photos")).font(.headline)
                    HStack {
                        Picker(i18n.t("filter"), selection: $albumPhotoFilter) {
                            Text(i18n.t("all")).tag("")
                            Text(i18n.t("pending")).tag("onaybekleyen")
                            Text(i18n.t("by_category")).tag("kategori")
                        }
                        .pickerStyle(.menu)
                        TextField(i18n.t("category_id"), text: $albumPhotoCategoryFilter)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Picker(i18n.t("sort"), selection: $albumPhotoSort) {
                            Text(i18n.t("active_desc")).tag("aktifazalan")
                            Text(i18n.t("date_desc")).tag("tarihazalan")
                            Text(i18n.t("title_asc")).tag("baslikartan")
                            Text(i18n.t("hits_desc")).tag("hitazalan")
                        }
                        .pickerStyle(.menu)
                        Button(i18n.t("load")) { Task { await loadAlbumPhotos() } }
                            .buttonStyle(.bordered)
                    }
                    HStack {
                        Button(i18n.t("bulk_active")) { Task { await bulkAlbumPhotos(action: "aktif") } }
                            .buttonStyle(.bordered)
                            .disabled(selectedAlbumPhotoIds.isEmpty)
                        Button(i18n.t("bulk_inactive")) { Task { await bulkAlbumPhotos(action: "deaktiv") } }
                            .buttonStyle(.bordered)
                            .disabled(selectedAlbumPhotoIds.isEmpty)
                        Button(i18n.t("bulk_delete"), role: .destructive) { Task { await bulkAlbumPhotos(action: "sil") } }
                            .buttonStyle(.bordered)
                            .disabled(selectedAlbumPhotoIds.isEmpty)
                    }
                }
            }
            if !albumPhotos.isEmpty {
                ForEach(albumPhotos) { item in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { selectedAlbumPhotoIds.contains(item.id) },
                                        set: { selected in
                                            if selected {
                                                selectedAlbumPhotoIds.insert(item.id)
                                            } else {
                                                selectedAlbumPhotoIds.remove(item.id)
                                            }
                                        }
                                    )
                                )
                                .labelsHidden()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.baslik ?? "(no title)")
                                        .font(.headline)
                                    Text(String(format: i18n.t("by_comments_format"), albumUserMap[String(item.ekleyenid ?? 0)] ?? "#\(item.ekleyenid ?? 0)", albumCommentCounts[String(item.id)] ?? 0))
                                        .font(.caption2)
                                        .foregroundStyle(SDALTheme.muted)
                                }
                                Spacer()
                                Button(i18n.t("comments")) { Task { await showAlbumPhotoComments(item) } }
                                    .buttonStyle(.bordered)
                                Button(i18n.t("delete"), role: .destructive) { Task { await deleteAlbumPhoto(item.id) } }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
    }

    var tournamentOpsPanel: some View {
        VStack(spacing: 12) {
            GlassCard {
                HStack {
                    Text(i18n.t("tournament_teams")).font(.headline)
                    Spacer()
                    Button(i18n.t("refresh")) { Task { await loadTournamentTeams() } }
                        .buttonStyle(.bordered)
                }
            }
            if tournamentTeams.isEmpty {
                GlassCard { Text(i18n.t("no_teams")).foregroundStyle(SDALTheme.muted) }
            } else {
                ForEach(tournamentTeams) { team in
                    GlassCard {
                        HStack {
                            Text(team.tisim ?? team.takimadi ?? team.isim ?? "\(i18n.t("team")) #\(team.id)")
                            Spacer()
                            Button(i18n.t("delete"), role: .destructive) { Task { await deleteTournamentTeam(team.id) } }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    func statRow(_ title: String, _ value: Int?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value.map(String.init) ?? "-")
                .foregroundStyle(SDALTheme.muted)
        }
        .font(.subheadline)
    }

    var dbPreviewColumns: [String] {
        let explicit = dbTableColumns.compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !explicit.isEmpty { return explicit }
        guard let first = dbTableRows.first else { return [] }
        return first.keys.sorted()
    }

    func formatBytes(_ value: Int) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var size = Double(max(value, 0))
        var idx = 0
        while size >= 1024, idx < units.count - 1 {
            size /= 1024
            idx += 1
        }
        return String(format: "%.1f %@", size, units[idx])
    }
}
