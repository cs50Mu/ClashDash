import Foundation

final class WebSocketService {
    private let config: ServerConfig
    private let secret: String

    private var trafficTask: URLSessionWebSocketTask?
    private var connectionsTask: URLSessionWebSocketTask?
    private var trafficSession: URLSession?
    private var connectionsSession: URLSession?
    private var isTrafficActive = false
    private var isConnectionsActive = false

    private var trafficContinuation: AsyncStream<TrafficInfo>.Continuation?
    private var connectionsContinuation: AsyncStream<ConnectionsResponse>.Continuation?

    init(config: ServerConfig, secret: String) {
        self.config = config
        self.secret = secret
    }

    // MARK: - Traffic Stream

    func trafficStream() -> AsyncStream<TrafficInfo> {
        AsyncStream { continuation in
            self.trafficContinuation = continuation
            self.startTrafficWebSocket()

            continuation.onTermination = { [weak self] _ in
                Task { await self?.stopTraffic() }
            }
        }
    }

    private func startTrafficWebSocket() {
        guard !isTrafficActive else { return }
        isTrafficActive = true

        let session = URLSession(configuration: .default)
        self.trafficSession = session

        let url = config.baseURL.appendingPathComponent("traffic")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let task = session.webSocketTask(with: request)
        self.trafficTask = task
        task.resume()
        receiveTrafficMessage(task: task)
    }

    private func receiveTrafficMessage(task: URLSessionWebSocketTask) {
        Task {
            let message = try? await task.receive()
            switch message {
            case .string(let text):
                if let data = text.data(using: .utf8),
                   let traffic = try? JSONDecoder().decode(TrafficInfo.self, from: data) {
                    trafficContinuation?.yield(traffic)
                }
                if isTrafficActive {
                    receiveTrafficMessage(task: task)
                }
            case .data(let data):
                if let traffic = try? JSONDecoder().decode(TrafficInfo.self, from: data) {
                    trafficContinuation?.yield(traffic)
                }
                if isTrafficActive {
                    receiveTrafficMessage(task: task)
                }
            case .none, _:
                if isTrafficActive {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    startTrafficWebSocket()
                }
            @unknown default:
                break
            }
        }
    }

    func stopTraffic() {
        isTrafficActive = false
        trafficTask?.cancel(with: .normalClosure, reason: nil)
        trafficTask = nil
        trafficSession?.finishTasksAndInvalidate()
        trafficSession = nil
        trafficContinuation?.finish()
        trafficContinuation = nil
    }

    // MARK: - Connections Stream

    func connectionsStream() -> AsyncStream<ConnectionsResponse> {
        AsyncStream { continuation in
            self.connectionsContinuation = continuation
            self.startConnectionsWebSocket()

            continuation.onTermination = { [weak self] _ in
                Task { await self?.stopConnections() }
            }
        }
    }

    private func startConnectionsWebSocket() {
        guard !isConnectionsActive else { return }
        isConnectionsActive = true

        let session = URLSession(configuration: .default)
        self.connectionsSession = session

        var components = URLComponents(url: config.baseURL.appendingPathComponent("connections"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "interval", value: "1000")]

        guard let url = components?.url else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        let task = session.webSocketTask(with: request)
        self.connectionsTask = task
        task.resume()
        receiveConnectionsMessage(task: task)
    }

    private func receiveConnectionsMessage(task: URLSessionWebSocketTask) {
        Task {
            let message = try? await task.receive()
            switch message {
            case .string(let text):
                if let data = text.data(using: .utf8),
                   let conn = try? JSONDecoder().decode(ConnectionsResponse.self, from: data) {
                    connectionsContinuation?.yield(conn)
                }
                if isConnectionsActive {
                    receiveConnectionsMessage(task: task)
                }
            case .data(let data):
                if let conn = try? JSONDecoder().decode(ConnectionsResponse.self, from: data) {
                    connectionsContinuation?.yield(conn)
                }
                if isConnectionsActive {
                    receiveConnectionsMessage(task: task)
                }
            case .none, _:
                if isConnectionsActive {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    startConnectionsWebSocket()
                }
            @unknown default:
                break
            }
        }
    }

    func stopConnections() {
        isConnectionsActive = false
        connectionsTask?.cancel(with: .normalClosure, reason: nil)
        connectionsTask = nil
        connectionsSession?.finishTasksAndInvalidate()
        connectionsSession = nil
        connectionsContinuation?.finish()
        connectionsContinuation = nil
    }

    // MARK: - Teardown

    func disconnectAll() {
        stopTraffic()
        stopConnections()
    }
}
