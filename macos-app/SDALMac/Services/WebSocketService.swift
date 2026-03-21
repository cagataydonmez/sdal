import Foundation

@MainActor
@Observable
final class WebSocketService {
    static let shared = WebSocketService()

    var isConnected = false

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var onMessage: ((Data) -> Void)?
    private var reconnectTask: Task<Void, Never>?

    private init() {}

    func connect(userId: Int, onMessage: @escaping (Data) -> Void) {
        self.onMessage = onMessage
        disconnect()

        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        session = URLSession(configuration: config)

        let wsURL = APIConfig.baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        guard let url = URL(string: "\(wsURL)/ws/chat?userId=\(userId)") else { return }

        webSocket = session?.webSocketTask(with: url)
        webSocket?.resume()
        isConnected = true
        receiveMessage()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        session?.invalidateAndCancel()
        session = nil
        isConnected = false
    }

    func send(_ text: String) {
        webSocket?.send(.string(text)) { error in
            if let error {
                print("[WS] Send error: \(error)")
            }
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8) {
                            self.onMessage?(data)
                        }
                    case .data(let data):
                        self.onMessage?(data)
                    @unknown default:
                        break
                    }
                    self.receiveMessage()
                case .failure:
                    self.isConnected = false
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            if let userId = AuthService.shared.currentUser?.id, let onMessage {
                connect(userId: userId, onMessage: onMessage)
            }
        }
    }
}
