import Foundation
import Observation

@Observable
final class ConnectionsViewModel {
    var activeConnections: [ConnectionInfo] = []
    var closedConnections: [ConnectionInfo] = []
    var uploadTotal: Int64 = 0
    var downloadTotal: Int64 = 0
    var memory: Int64?

    var sortBy: SortOption = .time
    var sortAscending: Bool = false
    var filterText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?

    enum SortOption: String, CaseIterable {
        case time = "时间"
        case upload = "上传量"
        case download = "下载量"
        case uploadSpeed = "上传速率"
        case downloadSpeed = "下载速率"
        case host = "目标"

        var id: String { rawValue }
    }

    private let api: MihomoAPIService
    private let ws: WebSocketService
    private var connectionsTask: Task<Void, Never>?
    private var previousSnapshot: [String: (upload: Int64, download: Int64)] = [:]
    private var isMonitoring = false

    private let maxClosedConnections = 200

    init(api: MihomoAPIService, ws: WebSocketService) {
        self.api = api
        self.ws = ws
    }

    var activeCount: Int { activeConnections.count }
    var closedCount: Int { closedConnections.count }

    var sortedFilteredConnections: [ConnectionInfo] {
        var result: [ConnectionInfo]

        if filterText.isEmpty {
            result = activeConnections
        } else {
            result = activeConnections.filter { conn in
                conn.displayHost.localizedCaseInsensitiveContains(filterText) ||
                conn.displaySource.localizedCaseInsensitiveContains(filterText) ||
                conn.displayChain.localizedCaseInsensitiveContains(filterText) ||
                conn.rule.localizedCaseInsensitiveContains(filterText)
            }
        }

        result.sort { a, b in
            let ascending = sortAscending
            switch sortBy {
            case .time:
                return ascending ? a.start < b.start : a.start > b.start
            case .upload:
                return ascending ? a.upload < b.upload : a.upload > b.upload
            case .download:
                return ascending ? a.download < b.download : a.download > b.download
            case .uploadSpeed:
                return ascending ? (a.uploadSpeed ?? 0) < (b.uploadSpeed ?? 0) : (a.uploadSpeed ?? 0) > (b.uploadSpeed ?? 0)
            case .downloadSpeed:
                return ascending ? (a.downloadSpeed ?? 0) < (b.downloadSpeed ?? 0) : (a.downloadSpeed ?? 0) > (b.downloadSpeed ?? 0)
            case .host:
                return ascending ? a.displayHost < b.displayHost : a.displayHost > b.displayHost
            }
        }
        return result
    }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        connectionsTask = Task { [weak self] in
            guard let self else { return }
            let stream = await ws.connectionsStream()
            var lastTime = Date()

            for await response in stream {
                guard !Task.isCancelled else { break }

                let now = Date()
                let interval = max(now.timeIntervalSince(lastTime), 0.5)
                lastTime = now

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.uploadTotal = response.uploadTotal ?? self.uploadTotal
                    self.downloadTotal = response.downloadTotal ?? self.downloadTotal
                    self.memory = response.memory

                    let incoming = response.connections

                    // Compute speeds via delta
                    var updatedConnections: [ConnectionInfo] = []
                    for var conn in incoming {
                        if let prev = self.previousSnapshot[conn.id] {
                            conn.uploadSpeed = Int64(Double(conn.upload - prev.upload) / interval)
                            conn.downloadSpeed = Int64(Double(conn.download - prev.download) / interval)
                        } else {
                            conn.uploadSpeed = 0
                            conn.downloadSpeed = 0
                        }
                        updatedConnections.append(conn)
                    }

                    // Track closed connections
                    let incomingIds = Set(incoming.map { $0.id })
                    let previousIds = Set(self.activeConnections.map { $0.id })
                    let closedIds = previousIds.subtracting(incomingIds)

                    for id in closedIds {
                        if let closed = self.activeConnections.first(where: { $0.id == id }) {
                            self.closedConnections.insert(closed, at: 0)
                        }
                    }
                    if self.closedConnections.count > self.maxClosedConnections {
                        self.closedConnections = Array(self.closedConnections.prefix(self.maxClosedConnections))
                    }

                    self.activeConnections = updatedConnections
                    self.previousSnapshot = Dictionary(uniqueKeysWithValues: incoming.map { ($0.id, ($0.upload, $0.download)) })

                    self.isLoading = false
                }
            }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        connectionsTask?.cancel()
        connectionsTask = nil
        Task { await ws.stopConnections() }
    }

    func closeAllConnections() async throws {
        try await api.closeAllConnections()
    }

    func closeConnection(id: String) async throws {
        try await api.closeConnection(id: id)
    }

    func clearClosedConnections() {
        closedConnections.removeAll()
    }
}
