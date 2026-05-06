import SwiftUI

struct NewConversationView: View {
    var preselectedContact: WatchContact? = nil

    @EnvironmentObject private var viewModel: WatchViewModel
    @EnvironmentObject private var sessionManager: WatchSessionManager
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var selectedContact: WatchContact? = nil
    @State private var messageText = ""
    @State private var isSending = false
    @State private var errorMessage: String? = nil
    @State private var navigateToThread: WatchThread? = nil

    private var cookie: String { sessionManager.sessionCookie }
    private var baseUrl: String { sessionManager.apiBaseUrl }

    private var filteredContacts: [WatchContact] {
        guard let contacts = viewModel.contactsState.value else { return [] }
        if searchQuery.isEmpty { return contacts }
        let q = searchQuery.lowercased()
        return contacts.filter {
            $0.fullName.lowercased().contains(q) || $0.handle.lowercased().contains(q)
        }
    }

    var body: some View {
        Group {
            if let contact = selectedContact {
                composeView(contact: contact)
            } else {
                contactPicker
            }
        }
        .task {
            if let pre = preselectedContact {
                selectedContact = pre
            } else {
                await viewModel.loadContacts(cookie: cookie, baseUrl: baseUrl)
            }
        }
    }

    // MARK: - Contact Picker

    private var contactPicker: some View {
        VStack(spacing: 0) {
            TextField("Kişi ara...", text: $searchQuery)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            Divider()
            contactList
        }
        .navigationTitle("Yeni Mesaj")
    }

    @ViewBuilder
    private var contactList: some View {
        switch viewModel.contactsState {
        case .idle, .loading:
            LoadingView()
        case .failed(let msg):
            ErrorRetryView(message: msg) {
                Task { await viewModel.loadContacts(cookie: cookie, baseUrl: baseUrl) }
            }
        case .loaded:
            if filteredContacts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.slash").foregroundStyle(.secondary)
                    Text("Kişi bulunamadı").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredContacts) { contact in
                    Button {
                        selectedContact = contact
                    } label: {
                        HStack(spacing: 8) {
                            AvatarView(initials: contact.initials, photoUrl: contact.photo, size: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.fullName.isEmpty ? "@\(contact.handle)" : contact.fullName)
                                    .font(.caption2).fontWeight(.semibold).lineLimit(1)
                                if !contact.handle.isEmpty {
                                    Text("@\(contact.handle)")
                                        .font(.system(size: 10)).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.carousel)
            }
        }
    }

    // MARK: - Compose

    private func composeView(contact: WatchContact) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    AvatarView(initials: contact.initials, photoUrl: contact.photo, size: 32)
                    Text(contact.fullName.isEmpty ? "@\(contact.handle)" : contact.fullName)
                        .font(.caption2).fontWeight(.semibold).lineLimit(1)
                }

                TextField("Mesajınız...", text: $messageText, axis: .vertical)
                    .font(.caption2)
                    .lineLimit(4)
                    .frame(minHeight: 50, alignment: .topLeading)

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 10)).foregroundStyle(.red).lineLimit(2)
                }

                HStack(spacing: 8) {
                    Button("İptal") {
                        if preselectedContact != nil { dismiss() }
                        else { selectedContact = nil }
                    }
                    .font(.caption2).buttonStyle(.bordered)

                    Button("Gönder") {
                        Task { await sendNewThread(contact: contact) }
                    }
                    .font(.caption2).buttonStyle(.borderedProminent)
                    .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                }
            }
            .padding()
        }
        .navigationTitle("Mesaj yaz")
    }

    private func sendNewThread(contact: WatchContact) async {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        isSending = true
        errorMessage = nil
        do {
            _ = try await viewModel.createThread(
                recipientId: contact.id,
                body: text,
                cookie: cookie,
                baseUrl: baseUrl
            )
            dismiss()
        } catch {
            errorMessage = "Gönderilemedi. Tekrar dene."
        }
        isSending = false
    }
}
