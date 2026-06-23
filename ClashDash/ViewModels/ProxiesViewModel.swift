import Foundation
import Observation

@Observable
final class ProxiesViewModel {
    var groups: [ProxyGroup] = []
    var nodes: [ProxyNode] = []
    var providers: [ProxyProvider] = []
    var nodeDelayMap: [String: Int] = [:]
    var isLoading: Bool = false
    var errorMessage: String?
    var searchText: String = ""

    let testURL: String = "https://www.gstatic.com/generate_204"
    let testTimeout: Int = 3000

    private let api: MihomoAPIService
    private var refreshTimer: Timer?

    init(api: MihomoAPIService) {
        self.api = api
    }

    var filteredGroups: [ProxyGroup] {
        guard !searchText.isEmpty else { return groups }
        return groups.filter { group in
            group.name.localizedCaseInsensitiveContains(searchText) ||
            group.all?.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) == true
        }
    }

    var filteredNodes: [ProxyNode] {
        guard !searchText.isEmpty else { return nodes }
        return nodes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func loadProxies() async {
        isLoading = true
        errorMessage = nil

        do {
            let (groups, nodes, _) = try await api.fetchProxies()
            await MainActor.run {
                self.groups = groups.sorted {
                    if $0.isSwitching != $1.isSwitching { return $0.isSwitching }
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                self.nodes = nodes
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func loadProviders() async {
        do {
            let result = try await api.fetchProxyProviders()
            await MainActor.run {
                self.providers = result
            }
        } catch {
            // Providers are optional, don't show error
        }
    }

    func switchProxy(groupName: String, to nodeName: String) async throws {
        try await api.switchProxy(groupName: groupName, to: nodeName)
    }

    func testNodeDelay(nodeName: String) async {
        do {
            let delay = try await api.testDelay(proxyName: nodeName, url: testURL, timeout: testTimeout)
            await MainActor.run {
                self.nodeDelayMap[nodeName] = delay
                // Update delay in groups
                if let index = self.groups.firstIndex(where: { $0.name == nodeName }) {
                    self.groups[index].delay = delay
                }
            }
        } catch {
            await MainActor.run {
                self.nodeDelayMap[nodeName] = -1
            }
        }
    }

    func testGroupDelay(groupName: String) async {
        guard let group = groups.first(where: { $0.name == groupName }),
              let allNodes = group.all else { return }

        await withTaskGroup(of: (String, Int?).self) { taskGroup in
            for nodeName in allNodes {
                taskGroup.addTask { [weak self] in
                    guard let self else { return (nodeName, nil) }
                    do {
                        let delay = try await self.api.testDelay(proxyName: nodeName, url: self.testURL, timeout: self.testTimeout)
                        return (nodeName, delay)
                    } catch {
                        return (nodeName, -1)
                    }
                }
            }

            var results: [String: Int] = [:]
            for await (name, delay) in taskGroup {
                if let delay { results[name] = delay }
            }

            await MainActor.run {
                self.nodeDelayMap.merge(results) { _, new in new }
                // Update group delays
                if let idx = self.groups.firstIndex(where: { $0.name == groupName }) {
                    // Find the "now" node delay and set it on the group
                    if let now = self.groups[idx].now, let nowDelay = results[now] {
                        self.groups[idx].delay = nowDelay
                    }
                }
            }
        }
    }

    func clearFixedProxy(groupName: String) async throws {
        try await api.clearFixedProxy(groupName: groupName)
    }

    func refreshProvider(name: String) async throws {
        try await api.updateProvider(name: name)
    }

    func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadProxies()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
