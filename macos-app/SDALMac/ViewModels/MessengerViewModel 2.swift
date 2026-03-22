import Foundation

@MainActor
@Observable
final class MessengerViewModel {
    var threads: [MessengerThread] = []
    var messages: [ChatMessage] = []
    var selectedThread: MessengerThread?
    var isLoadingThreads = false
    var isLoadingMessages = false
    var error: String?
    var searchQuery = ""
    var messageText = ""
    var contacts: [MessengerContact] = []
    var showNewConversation = false
    var contactSearchQuery = ""
    private var pollingTask: Task<Void, Never>?

    var filteredThreads: [MessengerThread] {
        if searchQuery.isEmpty { return threads }
        return threads.filter { thread in
            thread.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            thread.lastMessagePreview.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var totalUnread: Int {
        threads.reduce(0) { $0 + ($1.unreadCount ?? 0) }
    }

    func loadThreads() async {
        isLoadingThreads = true
        error = nil
        do {
            var query: [String: String] = ["limit": "40"]
            if !searchQuery.isEmpty { query["q"] = searchQuery }
            let response: ThreadsResponse = try await APIClient.shared.get("/api/sdal-messenger/threads", query: query)
            threads = response.items ?? []
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingThreads = false
    }

    func selectThread(_ thread: MessengerThread) async {
        selectedThread = thread
        await loadMessages(for: thread)
        do {
            try await APIClient.shared.postVoid("/api/sdal-messenger/threads/\(thread.id)/read")
        } catch { }
    }

    func loadMessages(for thread: MessengerThread) async {
        isLoadingMessages = true
        do {
            let response: MessagesResponse = try await APIClient.shared.get(
                "/api/sdal-messenger/threads/\(thread.id)/messages",
                query: ["limit": "100"]
            )
            messages = response.items ?? []
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingMessages = false
    }

    func sendMessage() async {
        guard let thread = selectedThread else { return }
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""

        do {
            struct SendBody: Encodable { let body: String }
            let _: SendMessageResponse = try await APIClient.shared.post(
                "/api/sdal-messenger/threads/\(thread.id)/messages",
                body: SendBody(body: text)
            )
            await loadMessages(for: thread)
            await loadThreads()
        } catch {
            messageText = text
            self.error = error.localizedDescription
        }
    }

    func searchContacts(_ query: String) async {
        contactSearchQuery = query
        guard !query.isEmpty else { contacts = []; return }
        do {
            let response: ContactsResponse = try await APIClient.shared.get(
                "/api/sdal-messenger/contacts",
                query: ["q": query, "limit": "20"]
            )
            contacts = response.items ?? []
        } catch { }
    }

    func startNewConversation(with userId: Int) async {
        do {
            struct CreateThread: Encodable { let userId: Int }
            let response: CreateThreadResponse = try await APIClient.shared.post(
                "/api/sdal-messenger/threads",
                body: CreateThread(userId: userId)
            )
            await loadThreads()
            if let threadId = response.threadId,
               let thread = threads.first(where: { $0.id == threadId }) {
                await selectThread(thread)
            }
            showNewConversation = false
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startPolling() {
        stopPolling()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else { break }
                await loadThreads()
                if let thread = selectedThread {
                    await loadMessages(for: thread)
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
