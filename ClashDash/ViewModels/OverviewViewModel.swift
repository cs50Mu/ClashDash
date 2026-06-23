import Foundation
import Observation

@Observable
final class OverviewViewModel {
    var version: String?
    var mode: String = "Rule"
    var uploadSpeed: Int64 = 0
    var downloadSpeed: Int64 = 0
    var uploadTotal: Int64 = 0
    var downloadTotal: Int64 = 0
    var memoryUsage: Int64 = 0
    var activeConnections: Int = 0
    var proxyCount: Int = 0
    var groupCount: Int = 0
    var ruleCount: Int = 0
    var isLoading: Bool = false
    var errorMessage: String?

    var isConnected: Bool { version != nil }

    // Traffic history for chart (last 60 data points, 1 per second)
    var uploadHistory: [Double] = []
    var downloadHistory: [Double] = []
    private let maxHistoryPoints = 60

    private let api: MihomoAPIService
    private let ws: WebSocketService
    private var trafficTask: Task<Void, Never>?
    private var isMonitoring = false

    init(api: MihomoAPIService, ws: WebSocketService) {
        self.api = api
        self.ws = ws
    }

    @MainActor func load() async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch version and configs in parallel
            async let versionTask = api.fetchVersion()
            async let configsTask = api.fetchConfigs()

            let ver = try await versionTask
            let configs = try await configsTask

            await MainActor.run {
                version = ver.version
                mode = (configs["mode"] as? String)?.capitalized ?? "Rule"
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func startTrafficStream() {
        guard !isMonitoring else { return }
        isMonitoring = true

        trafficTask = Task { [weak self] in
            guard let self else { return }
            let stream = await ws.trafficStream()
            for await traffic in stream {
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    self.uploadSpeed = traffic.up * 1024  // kbps -> B/s
                    self.downloadSpeed = traffic.down * 1024

                    self.uploadHistory.append(Double(traffic.up))
                    self.downloadHistory.append(Double(traffic.down))
                    if self.uploadHistory.count > self.maxHistoryPoints {
                        self.uploadHistory.removeFirst()
                        self.downloadHistory.removeFirst()
                    }
                }
            }
        }
    }

    @MainActor func refreshStats() async {
        do {
            let conn = try await api.fetchConnections()
            let proxies = try await api.fetchProxies()
            let rules = try await api.fetchRules()

            // Memory from connections response (already fetched above)
            if let mem = conn.memory {
                memoryUsage = mem
            }

            activeConnections = conn.connections.count
            uploadTotal = conn.uploadTotal ?? 0
            downloadTotal = conn.downloadTotal ?? 0
            proxyCount = proxies.nodes.count
            groupCount = proxies.groups.count
            ruleCount = rules.count
        } catch {
            errorMessage = "刷新统计失败: \(error.localizedDescription)"
        }
    }

    func restartKernel() async throws {
        try await api.restartKernel()
    }

    func reloadConfig() async throws {
        try await api.reloadConfig()
    }

    func flushFakeIP() async throws {
        try await api.flushFakeIPCache()
    }

    func stopAll() {
        isMonitoring = false
        trafficTask?.cancel()
        trafficTask = nil
        Task { await ws.stopTraffic() }
    }
}
