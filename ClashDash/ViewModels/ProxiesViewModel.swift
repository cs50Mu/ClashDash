import Foundation
import Observation

@Observable
final class ProxiesViewModel {
    var groups: [ProxyGroup] = []
    var nodes: [ProxyNode] = []
    var nodeDelayMap: [String: Int] = [:]
    var testingGroupNames: Set<String> = []
    var testingNodeNames: Set<String> = []
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

    /// 沿着 now 链递归查找叶子节点的测速延迟
    /// 例：一键连 → 台湾自动 → [某节点]，返回该节点的 delay
    private func resolveChainDelay(startName: String?, depth: Int = 0) -> Int? {
        guard let name = startName, depth < 10 else { return nil }

        // 是叶子节点（普通 proxy），直接返回其延迟
        if let delay = nodeDelayMap[name] {
            return delay
        }

        // 是另一个 group，沿着它的 now 继续追
        if let subGroup = groups.first(where: { $0.name == name }), let subNow = subGroup.now {
            return resolveChainDelay(startName: subNow, depth: depth + 1)
        }

        return nil
    }

    /// 按配置文件中的原始顺序展示（不做任何重排序）
    /// 排除 hidden: true 的组，仅当有搜索文本时额外过滤
    var sortedGroups: [ProxyGroup] {
        let visible = groups.filter { !$0.hidden }
        guard !searchText.isEmpty else { return visible }
        return visible.filter { group in
            group.name.localizedCaseInsensitiveContains(searchText) ||
            group.all?.contains(where: { $0.localizedCaseInsensitiveContains(searchText) }) == true
        }
    }

    func loadProxies() async {
        isLoading = true
        errorMessage = nil

        do {
            let (fetchedGroups, fetchedNodes, _, globalOrder) = try await api.fetchProxies()

            await MainActor.run {
                if !globalOrder.isEmpty {
                    // 按 GLOBAL.all 的顺序排列（= 配置文件 proxy-groups 的原始顺序）
                    let orderIndex = Dictionary(uniqueKeysWithValues: globalOrder.enumerated().map { ($1, $0) })
                    self.groups = fetchedGroups.sorted {
                        (orderIndex[$0.name] ?? Int.max) < (orderIndex[$1.name] ?? Int.max)
                    }
                } else {
                    self.groups = fetchedGroups
                }
                self.nodes = fetchedNodes
                // 同步服务端返回的节点延迟到 nodeDelayMap
                for node in fetchedNodes {
                    if let delay = node.delay {
                        self.nodeDelayMap[node.name] = delay
                    }
                }

                // 沿着 now 链解析每个 group 的延迟（不取 group 自己的 history）
                for i in self.groups.indices {
                    self.groups[i].delay = self.resolveChainDelay(startName: self.groups[i].now)
                    if let delay = self.groups[i].delay {
                        self.nodeDelayMap[self.groups[i].name] = delay
                    }
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func switchProxy(groupName: String, to nodeName: String) async throws {
        try await api.switchProxy(groupName: groupName, to: nodeName)
        // 切换代理后断开所有已有连接，使其立即使用新代理
        try? await api.closeAllConnections()
    }

    func testNodeDelay(nodeName: String) async {
        await MainActor.run { testingNodeNames.insert(nodeName) }
        do {
            let delay = try await api.testDelay(proxyName: nodeName, url: testURL, timeout: testTimeout)
            await MainActor.run {
                self.nodeDelayMap[nodeName] = delay
                if let index = self.groups.firstIndex(where: { $0.name == nodeName }) {
                    self.groups[index].delay = delay
                }
                self.testingNodeNames.remove(nodeName)
            }
        } catch {
            await MainActor.run {
                self.nodeDelayMap[nodeName] = -1
                self.testingNodeNames.remove(nodeName)
            }
        }
    }

    func testGroupDelay(groupName: String) async {
        guard let group = groups.first(where: { $0.name == groupName }),
              let allNodes = group.all else { return }

        await MainActor.run { testingGroupNames.insert(groupName) }

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

            for await (name, delay) in taskGroup {
                if let delay {
                    await MainActor.run {
                        self.nodeDelayMap[name] = delay
                    }
                }
            }

            await MainActor.run {
                // 用当前选中节点的延迟更新 group 延迟
                if let idx = self.groups.firstIndex(where: { $0.name == groupName }),
                   let now = self.groups[idx].now,
                   let nowDelay = self.nodeDelayMap[now] {
                    self.groups[idx].delay = nowDelay
                }
                self.testingGroupNames.remove(groupName)
            }
        }
    }

    func clearFixedProxy(groupName: String) async throws {
        try await api.clearFixedProxy(groupName: groupName)
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
