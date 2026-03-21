import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var session: SessionUser?
    @Published var isBootstrapping = true
    @Published private(set) var siteAccess = SiteAccessResponse(isOpen: true, message: nil)
    @Published private(set) var chatConnectionState: WebSocketConnectionState = .disconnected
    @Published private(set) var messengerConnectionState: WebSocketConnectionState = .disconnected

    private let api = APIClient.shared
    private var unauthorizedObserver: NSObjectProtocol?
    private var realtimeStateTasks: [Task<Void, Never>] = []

    init() {
        observeRealtimeState()
        unauthorizedObserver = NotificationCenter.default.addObserver(
            forName: .sdalUnauthorizedResponse,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleUnauthorized()
            }
        }
    }

    deinit {
        if let unauthorizedObserver {
            NotificationCenter.default.removeObserver(unauthorizedObserver)
        }
        realtimeStateTasks.forEach { $0.cancel() }
    }

    func bootstrapSession() async {
        defer { isBootstrapping = false }
        do {
            siteAccess = try await api.fetchSiteAccess()
        } catch {
            siteAccess = SiteAccessResponse(isOpen: true, message: nil)
        }
        do {
            session = try await api.fetchSession()
        } catch {
            session = nil
        }
        await syncRealtimeConnections()
        await PushNotificationService.shared.syncRegistrationForCurrentSession(isAuthenticated: session != nil)
    }

    func login(username: String, password: String) async throws {
        let payload = try await api.login(username: username, password: password)
        if let user = payload.resolvedUser {
            session = user
        } else {
            session = try await api.fetchSession()
        }
        await syncRealtimeConnections()
        await PushNotificationService.shared.syncRegistrationForCurrentSession(isAuthenticated: true)
    }

    func refreshSession() async {
        do {
            session = try await api.fetchSession()
        } catch {
            session = nil
        }
        await syncRealtimeConnections()
        await PushNotificationService.shared.syncRegistrationForCurrentSession(isAuthenticated: session != nil)
    }

    func logout() async {
        do {
            try await api.logout()
        } catch {
            // Ignore logout failures and clear local state anyway.
        }
        session = nil
        await WebSocketManager.shared.disconnectAll()
        await PushNotificationService.shared.syncRegistrationForCurrentSession(isAuthenticated: false)
    }

    func ensureRealtimeConnected() async {
        await syncRealtimeConnections()
    }

    var isProfileCompletionRequired: Bool {
        session?.needsProfile == true
    }

    private func handleUnauthorized() async {
        session = nil
        await WebSocketManager.shared.disconnectAll()
        await PushNotificationService.shared.syncRegistrationForCurrentSession(isAuthenticated: false)
    }

    private func syncRealtimeConnections() async {
        guard let userId = session?.id else {
            await WebSocketManager.shared.disconnectAll()
            return
        }
        await WebSocketManager.shared.connect(channel: .chat, userId: userId)
        await WebSocketManager.shared.connect(channel: .messenger, userId: userId)
    }

    private func observeRealtimeState() {
        realtimeStateTasks.append(Task { @MainActor [weak self] in
            let stream = await WebSocketManager.shared.stateStream(for: .chat)
            for await state in stream {
                self?.chatConnectionState = state
            }
        })
        realtimeStateTasks.append(Task { @MainActor [weak self] in
            let stream = await WebSocketManager.shared.stateStream(for: .messenger)
            for await state in stream {
                self?.messengerConnectionState = state
            }
        })
    }
}

extension Notification.Name {
    static let sdalUnauthorizedResponse = Notification.Name("sdalUnauthorizedResponse")
}

enum WebSocketChannel: String, CaseIterable, Sendable {
    case chat
    case messenger

    var path: String {
        switch self {
        case .chat:
            return "/ws/chat"
        case .messenger:
            return "/ws/messenger"
        }
    }
}

enum WebSocketConnectionState: String, Sendable {
    case disconnected
    case connecting
    case connected
}

struct WebSocketEvent: Sendable {
    let channel: WebSocketChannel
    let text: String
}

actor WebSocketManager {
    static let shared = WebSocketManager()

    private struct ChannelContext {
        var socketTask: URLSessionWebSocketTask?
        var receiveTask: Task<Void, Never>?
        var heartbeatTask: Task<Void, Never>?
        var reconnectTask: Task<Void, Never>?
        var eventContinuations: [UUID: AsyncStream<WebSocketEvent>.Continuation] = [:]
        var stateContinuations: [UUID: AsyncStream<WebSocketConnectionState>.Continuation] = [:]
        var state: WebSocketConnectionState = .disconnected
        var reconnectDelay: UInt64 = 1_000_000_000
        var lastUserId: Int?
        var manuallyDisconnected = false
    }

    private let session: URLSession
    private var contexts: [WebSocketChannel: ChannelContext] = [:]

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpCookieAcceptPolicy = .always
        session = URLSession(configuration: configuration)
    }

    func connect(channel: WebSocketChannel, userId: Int?) {
        var context = contexts[channel] ?? ChannelContext()
        context.lastUserId = userId
        context.manuallyDisconnected = false
        if context.state == .connected || context.state == .connecting {
            contexts[channel] = context
            return
        }
        contexts[channel] = context
        openConnection(for: channel)
    }

    func disconnectAll() {
        for channel in WebSocketChannel.allCases {
            disconnect(channel: channel)
        }
    }

    func disconnect(channel: WebSocketChannel) {
        guard var context = contexts[channel] else { return }
        context.manuallyDisconnected = true
        context.reconnectTask?.cancel()
        context.receiveTask?.cancel()
        context.heartbeatTask?.cancel()
        context.socketTask?.cancel(with: .goingAway, reason: nil)
        context.socketTask = nil
        context.receiveTask = nil
        context.heartbeatTask = nil
        context.reconnectTask = nil
        context.reconnectDelay = 1_000_000_000
        updateState(.disconnected, for: channel, context: &context)
        contexts[channel] = context
    }

    func eventStream(for channel: WebSocketChannel) -> AsyncStream<WebSocketEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { self.addEventContinuation(continuation, id: id, for: channel) }
            continuation.onTermination = { _ in
                Task { await self.removeEventContinuation(id: id, for: channel) }
            }
        }
    }

    func stateStream(for channel: WebSocketChannel) -> AsyncStream<WebSocketConnectionState> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { self.addStateContinuation(continuation, id: id, for: channel) }
            continuation.onTermination = { _ in
                Task { await self.removeStateContinuation(id: id, for: channel) }
            }
        }
    }

    private func openConnection(for channel: WebSocketChannel) {
        guard var context = contexts[channel] else { return }
        let userId = context.lastUserId
        var query: [String: String] = [:]
        if channel == .messenger, let userId {
            query["userId"] = String(userId)
        }
        guard let url = AppConfig.webSocketURL(path: channel.path, query: query.isEmpty ? nil : query) else { return }
        let task = session.webSocketTask(with: url)
        context.socketTask = task
        context.receiveTask?.cancel()
        context.heartbeatTask?.cancel()
        updateState(.connecting, for: channel, context: &context)
        contexts[channel] = context
        task.resume()
        contexts[channel]?.receiveTask = Task { [weak self] in
            await self?.receiveLoop(channel: channel)
        }
        contexts[channel]?.heartbeatTask = Task { [weak self] in
            await self?.heartbeatLoop(channel: channel)
        }
    }

    private func receiveLoop(channel: WebSocketChannel) async {
        await updateState(.connected, for: channel)
        while let task = contexts[channel]?.socketTask, !Task.isCancelled {
            do {
                let message = try await task.receive()
                let text: String?
                switch message {
                case .string(let value):
                    text = value
                case .data(let data):
                    text = String(data: data, encoding: .utf8)
                @unknown default:
                    text = nil
                }
                guard let text else { continue }
                publish(WebSocketEvent(channel: channel, text: text), for: channel)
            } catch {
                break
            }
        }
        await scheduleReconnect(for: channel)
    }

    private func heartbeatLoop(channel: WebSocketChannel) async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard let task = contexts[channel]?.socketTask else { return }
            do {
                try await sendPing(on: task)
            } catch {
                return
            }
        }
    }

    private func scheduleReconnect(for channel: WebSocketChannel) async {
        guard var context = contexts[channel], !context.manuallyDisconnected else {
            return
        }
        context.socketTask = nil
        context.receiveTask = nil
        context.heartbeatTask = nil
        updateState(.disconnected, for: channel, context: &context)
        let delay = context.reconnectDelay
        context.reconnectDelay = min(context.reconnectDelay * 2, 30_000_000_000)
        context.reconnectTask?.cancel()
        context.reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            await self?.reconnect(channel: channel)
        }
        contexts[channel] = context
    }

    private func reconnect(channel: WebSocketChannel) {
        guard let context = contexts[channel], !context.manuallyDisconnected else { return }
        openConnection(for: channel)
    }

    private func sendPing(on task: URLSessionWebSocketTask) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            task.sendPing { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func publish(_ event: WebSocketEvent, for channel: WebSocketChannel) {
        let continuations = Array(contexts[channel]?.eventContinuations.values ?? Dictionary<UUID, AsyncStream<WebSocketEvent>.Continuation>().values)
        for continuation in continuations {
            continuation.yield(event)
        }
    }

    private func updateState(_ state: WebSocketConnectionState, for channel: WebSocketChannel) async {
        guard var context = contexts[channel] else { return }
        updateState(state, for: channel, context: &context)
        contexts[channel] = context
    }

    private func updateState(_ state: WebSocketConnectionState, for channel: WebSocketChannel, context: inout ChannelContext) {
        context.state = state
        for continuation in context.stateContinuations.values {
            continuation.yield(state)
        }
    }

    private func addEventContinuation(_ continuation: AsyncStream<WebSocketEvent>.Continuation, id: UUID, for channel: WebSocketChannel) {
        var context = contexts[channel] ?? ChannelContext()
        context.eventContinuations[id] = continuation
        contexts[channel] = context
    }

    private func removeEventContinuation(id: UUID, for channel: WebSocketChannel) {
        guard var context = contexts[channel] else { return }
        context.eventContinuations.removeValue(forKey: id)
        contexts[channel] = context
    }

    private func addStateContinuation(_ continuation: AsyncStream<WebSocketConnectionState>.Continuation, id: UUID, for channel: WebSocketChannel) {
        var context = contexts[channel] ?? ChannelContext()
        context.stateContinuations[id] = continuation
        continuation.yield(context.state)
        contexts[channel] = context
    }

    private func removeStateContinuation(id: UUID, for channel: WebSocketChannel) {
        guard var context = contexts[channel] else { return }
        context.stateContinuations.removeValue(forKey: id)
        contexts[channel] = context
    }
}
