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
                // 同步服务端返回的延迟到 nodeDelayMap（含节点和子 group），展开时即可显示
                for node in fetchedNodes {
                    if let delay = node.delay {
                        self.nodeDelayMap[node.name] = delay
                    }
                }
                for group in self.groups {
                    if let delay = group.delay {
                        self.nodeDelayMap[group.name] = delay
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
