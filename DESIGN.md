# ClashDash — iOS App 详细设计文档

> 目标：开发一款 iOS app，远程连接和管理运行在路由器上的 mihomo (v1.19.27)，提供概览、代理管理、规则查看、连接监控四大功能。
>
> 参考项目：`authenticator/`（SwiftUI + @Observable + xcodebuild CLI 构建）。

---

## 一、总体架构

```
┌─────────────────────────────────────────────────────────┐
│  SwiftUI Views (4 Tabs)                                 │
│  ┌──────────┬──────────┬──────────┬──────────────────┐ │
│  │ 概览      │ 代理      │ 规则      │ 连接              │ │
│  │ Overview │ Proxies  │ Rules    │ Connections      │ │
│  └──────────┴──────────┴──────────┴──────────────────┘ │
│                         ↕                               │
│  @Observable ViewModels                                 │
│  ┌──────────┬──────────┬──────────┬──────────────────┐ │
│  │OverviewVM│ProxiesVM │ RulesVM  │ ConnectionsVM    │ │
│  └──────────┴──────────┴──────────┴──────────────────┘ │
│                         ↕                               │
│  Services Layer                                         │
│  ┌──────────────────┬──────────────────┐               │
│  │ MihomoAPIService │ WebSocketService │               │
│  │ (URLSession)     │ (URLSessionWS)   │               │
│  └──────────────────┴──────────────────┘               │
│                         ↕                               │
│  ┌──────────────────────────────────────┐               │
│  │ ServerConfigService (UserDefaults +  │               │
│  │   Keychain for secret)               │               │
│  └──────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────┘
                         │
                  HTTP / WebSocket
                         │
              ┌──────────┴──────────┐
              │   Mihomo Router     │
              │   external-controller│
              │   192.168.x.x:9090  │
              └─────────────────────┘
```

### 技术栈

| 层级 | 技术选型 | 理由 |
|------|----------|------|
| UI | SwiftUI (iOS 17+) | 与 authenticator 一致，声明式 UI |
| 状态管理 | `@Observable` (Observation) | Swift 6 标准宏，无第三方依赖 |
| 网络 | URLSession + async/await | 原生、无依赖、Swift Concurrency |
| WebSocket | URLSessionWebSocketTask | 原生支持，用于 /traffic 和 /connections 实时推送 |
| 持久化 | UserDefaults (配置) + Keychain (secret) | 与 authenticator 一致 |
| 认证 | HTTP `Authorization: Bearer {secret}` | 与 mihomo API 一致 |
| 导航 | TabView + NavigationStack | 标准 SwiftUI 导航 |

---

## 二、项目结构

用 Xcode 创建项目并管理所有源文件：

```
ClashDash/
├── ClashDash.xcodeproj/        # Xcode 项目管理
├── ClashDash/
│   ├── App/
│   │   └── ClashDashApp.swift           # @main 入口
│   │
│   ├── Models/
│   │   ├── ServerConfig.swift           # 服务器连接配置
│   │   ├── ProxyNode.swift              # 单个代理节点
│   │   ├── ProxyGroup.swift             # 代理组 (Selector/URLTest/Fallback/LoadBalance)
│   │   ├── ProxyProvider.swift          # 代理提供者
│   │   ├── RuleItem.swift               # 路由规则项
│   │   ├── ConnectionInfo.swift         # 连接信息
│   │   ├── ConnectionSnapshot.swift     # 连接快照 (含 delta 计算)
│   │   ├── TrafficInfo.swift            # 实时流量
│   │   ├── VersionInfo.swift            # 版本信息
│   │   └── MemoryInfo.swift             # 内存信息
│   │
│   ├── Services/
│   │   ├── MihomoAPIService.swift       # REST API 客户端 (async/await)
│   │   ├── WebSocketService.swift       # WebSocket 实时数据
│   │   └── ServerConfigService.swift    # 配置持久化 & Keychain
│   │
│   ├── ViewModels/
│   │   ├── OverviewViewModel.swift      # 概览页状态
│   │   ├── ProxiesViewModel.swift       # 代理页状态 & 操作
│   │   ├── RulesViewModel.swift         # 规则页状态
│   │   ├── ConnectionsViewModel.swift   # 连接页实时状态
│   │   └── SettingsViewModel.swift      # 服务器管理
│   │
│   ├── Views/
│   │   ├── ContentView.swift            # TabView 根视图
│   │   │
│   │   ├── Overview/                    # Tab 1: 概览
│   │   │   ├── OverviewView.swift       # 主视图
│   │   │   ├── TrafficChartCard.swift   # 流量趋势卡片
│   │   │   ├── StatusCard.swift         # 状态指示卡片
│   │   │   ├── StatsGridCard.swift      # 统计网格卡片
│   │   │   └── ProxyModeCard.swift      # 代理模式卡片
│   │   │
│   │   ├── Proxies/                     # Tab 2: 代理
│   │   │   ├── ProxiesView.swift        # 主视图
│   │   │   ├── ProxyGroupSection.swift  # 代理组折叠区域
│   │   │   ├── ProxyNodeRow.swift       # 代理节点行
│   │   │   ├── ProxyPickerSheet.swift   # 节点选择 Sheet
│   │   │   ├── ProxyProviderSection.swift
│   │   │   └── DelayTestButton.swift    # 延迟测试按钮
│   │   │
│   │   ├── Rules/                       # Tab 3: 规则
│   │   │   ├── RulesView.swift          # 主视图
│   │   │   ├── RuleRowView.swift        # 单条规则行
│   │   │   └── RuleDetailSheet.swift    # 规则详情
│   │   │
│   │   ├── Connections/                 # Tab 4: 连接
│   │   │   ├── ConnectionsView.swift    # 主视图
│   │   │   ├── ConnectionRowView.swift  # 连接行
│   │   │   ├── ConnectionDetailSheet.swift
│   │   │   └── ConnectionFilterBar.swift
│   │   │
│   │   └── Settings/                    # 设置
│   │       ├── SettingsView.swift       # 服务器列表
│   │       ├── AddServerView.swift      # 添加/编辑服务器
│   │       └── ServerRowView.swift      # 服务器行
│   │
│   └── Extensions/
│       ├── ByteCountFormatter+Ext.swift # 流量格式化
│       └── Color+Ext.swift              # 延迟颜色
```

---

## 三、数据模型设计

### 3.1 ServerConfig（服务器配置）

```swift
struct ServerConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String            // 显示名称，如 "客厅路由器"
    var host: String            // IP 或域名，如 "192.168.1.1"
    var port: Int               // 端口，默认 9090
    var useTLS: Bool            // 是否 HTTPS
    // secret 不存这里，存 Keychain，key = "mihomo.secret.{id}"
}
```

### 3.2 ProxyGroup（代理组）

```swift
struct ProxyGroup: Codable, Identifiable {
    let name: String            // 如 "Proxy", "Auto"
    let type: GroupType         // Selector, URLTest, Fallback, LoadBalance
    let now: String?            // 当前选中节点名 (Selector/URLTest)
    let all: [String]?          // 可选节点名列表 (Selector)
    var delay: Int?             // 延迟 (ms)，由 delay test 填充
    var history: [DelayRecord]? // 延迟历史
}

enum GroupType: String, Codable {
    case selector = "Selector"
    case urlTest = "URLTest"
    case fallback = "Fallback"
    case loadBalance = "LoadBalance"
    case relay = "Relay"
}
```

### 3.3 ProxyNode（代理节点）

```swift
struct ProxyNode: Codable, Identifiable {
    let name: String            // 如 "HK-01", "US-West"
    let type: ProxyType         // ss, vmess, trojan, hysteria2, tuic 等
    var delay: Int?             // 延迟 (ms)，通过 delay test 获取
    let udp: Bool               // 是否支持 UDP
    let xudp: Bool?             // 是否支持 XUDP
}

enum ProxyType: String, Codable {
    case shadowsocks = "Shadowsocks"
    case shadowsocksR = "ShadowsocksR"
    case vmess = "Vmess"
    case trojan = "Trojan"
    case hysteria = "Hysteria"
    case hysteria2 = "Hysteria2"
    case tuic = "TUIC"
    case vless = "Vless"
    case socks5 = "Socks5"
    case http = "HTTP"
    case snell = "Snell"
    case wireguard = "WireGuard"
    case direct = "Direct"
    case reject = "Reject"
    case dns = "DNS"
    case unknown = "Unknown"
}
```

### 3.4 ProxyProvider（代理提供者）

```swift
struct ProxyProvider: Codable, Identifiable {
    let name: String
    let type: ProviderType      // http, file
    let vehicleType: String     // HTTP, File, Compatible
    var updatedAt: Date?
    var proxies: [ProxyNode]?
}

enum ProviderType: String, Codable {
    case http = "HTTP"
    case file = "File"
}
```

### 3.5 RuleItem（规则）

```swift
struct RuleItem: Codable, Identifiable {
    let index: Int              // 规则序号
    let type: String            // DOMAIN, DOMAIN-SUFFIX, GEOIP, MATCH 等
    let payload: String         // 匹配内容
    let proxy: String           // 目标策略/代理
    var isDisabled: Bool        // 是否被禁用（临时，重启重置）
}
```

### 3.6 ConnectionInfo（连接）

```swift
struct ConnectionInfo: Codable, Identifiable {
    let id: String
    let metadata: ConnectionMetadata
    let upload: Int64           // 累计上传字节
    let download: Int64         // 累计下载字节
    let start: Date
    let chains: [String]        // 代理链，如 ["Proxy", "HK-01"]
    let rule: String            // 匹配规则
    let rulePayload: String     // 规则描述
    let isActive: Bool

    // 客户端计算：
    var uploadSpeed: Int64?     // 上传速率 B/s (delta)
    var downloadSpeed: Int64?   // 下载速率 B/s (delta)
}

struct ConnectionMetadata: Codable {
    let network: String         // "tcp" | "udp"
    let type: String
    let sourceIP: String
    let sourcePort: String
    let destinationIP: String
    let destinationPort: String
    let host: String            // 目标域名
    let dnsMode: String
    let uid: Int
    let process: String
    let processPath: String
    let sniffHost: String
    let sourceGeoIP: [String]?
    let destinationGeoIP: [String]?
    let inboundName: String?
    let remoteDestination: String?
}
```

### 3.7 ConnectionSnapshot（连接聚合快照）

```swift
struct ConnectionSnapshot {
    var connections: [ConnectionInfo]
    var uploadTotal: Int64
    var downloadTotal: Int64
    var memory: Int64?          // 可选：内存使用
    var activeCount: Int
    var closedConnections: [ConnectionInfo]  // 最近断开的连接
}
```

### 3.8 TrafficInfo（流量）& VersionInfo（版本）& MemoryInfo（内存）

```swift
struct TrafficInfo: Codable {
    let up: Int64               // 当前上传速率 kbps
    let down: Int64             // 当前下载速率 kbps
}

struct VersionInfo: Codable {
    let version: String         // 如 "v1.19.27"
    let meta: Bool?
    let premium: Bool?
}

struct MemoryInfo: Codable {
    let inuse: Int64?           // 当前内存使用 KB
    let oslimit: Int64?         // 系统内存限制 KB
}
```

---

## 四、API 服务层设计

### 4.1 MihomoAPIService

核心使用 `URLSession` + Swift Concurrency (`async/await`)，所有请求携带 `Authorization: Bearer {secret}` 头。

```swift
actor MihomoAPIService {
    // 服务器信息从 ServerConfigService 获取
    private var config: ServerConfig
    private var secret: String
    private let session: URLSession

    // 构建 base URL: http(s)://{host}:{port}
    private var baseURL: URL

    // MARK: - 概览相关

    /// GET /version
    func fetchVersion() async throws -> VersionInfo

    /// GET /traffic  (同时支持 WS，由 WebSocketService 处理)
    /// GET /memory
    func fetchMemory() async throws -> MemoryInfo

    /// GET /configs
    func fetchConfigs() async throws -> MihomoConfig

    // MARK: - 代理相关

    /// GET /proxies
    /// 返回 { proxies: { "name": {...}, ... } }
    /// 需要解析: ProxyNode (普通节点)、ProxyGroup (策略组)
    func fetchProxies() async throws -> (groups: [ProxyGroup], nodes: [ProxyNode])

    /// PUT /proxies/{name}  切换代理
    func switchProxy(groupName: String, to proxyName: String) async throws

    /// GET /proxies/{name}/delay?url=...&timeout=5000  延迟测试
    func testDelay(proxyName: String, url: String, timeout: Int) async throws -> Int

    /// GET /group/{name}/delay?url=...&timeout=5000  组延迟测试
    func testGroupDelay(groupName: String, url: String, timeout: Int) async throws

    /// GET /providers/proxies
    func fetchProxyProviders() async throws -> [ProxyProvider]

    /// PUT /providers/proxies/{name}  更新代理提供者
    func updateProvider(name: String) async throws

    /// GET /providers/proxies/{provider}/{proxy}/healthcheck  健康检查
    func healthCheckProvider(provider: String, proxy: String, url: String, timeout: Int) async throws -> Int

    // MARK: - 规则相关

    /// GET /rules
    func fetchRules() async throws -> [RuleItem]

    /// PATCH /rules/disable  禁用/启用规则 { "0": true, "1": false }
    func updateRuleDisable(index: Int, disabled: Bool) async throws

    // MARK: - 连接相关

    /// GET /connections
    func fetchConnections() async throws -> ConnectionSnapshot

    /// DELETE /connections  断开所有连接
    func closeAllConnections() async throws

    /// DELETE /connections/{id}  断开特定连接
    func closeConnection(id: String) async throws

    // MARK: - 系统

    /// POST /restart
    func restartKernel() async throws

    /// PUT /configs?force=true  重载配置
    func reloadConfig() async throws

    /// POST /cache/fakeip/flush
    func flushFakeIPCache() async throws
}
```

### 4.2 WebSocketService

用于实时推送的场景：
- `GET /traffic` (WS) → 实时流量
- `GET /connections?interval=1000` (WS) → 实时连接

```swift
actor WebSocketService {
    private var trafficTask: URLSessionWebSocketTask?
    private var connectionsTask: URLSessionWebSocketTask?

    /// 订阅实时流量，回调返回 TrafficInfo
    func subscribeTraffic(
        onReceive: @escaping (TrafficInfo) -> Void,
        onError: @escaping (Error) -> Void
    )

    /// 订阅实时连接，回调返回 ConnectionSnapshot
    func subscribeConnections(
        onReceive: @escaping (ConnectionSnapshot) -> Void,
        onError: @escaping (Error) -> Void
    )

    /// 断开所有订阅
    func disconnectAll()
}
```

**WebSocket 实现细节**：
- 使用 `URLSessionWebSocketTask`，在建立连接时同样设置 `Authorization` header
- 收到文本消息后 JSON decode 为目标类型
- 断线自动重连（指数退避策略：1s → 2s → 4s → 8s → ... 最大 30s）
- 在 app 进入后台时断开，回到前台时重连

### 4.3 ServerConfigService

```swift
struct ServerConfigService {
    /// UserDefaults key
    private static let serversKey = "mihomo.servers"
    private static let activeServerKey = "mihomo.activeServerId"

    /// 获取所有服务器配置
    func loadServers() -> [ServerConfig]

    /// 保存服务器列表
    func saveServers(_ servers: [ServerConfig])

    /// 获取/设置当前活跃服务器
    var activeServerId: UUID?

    /// Keychain 存取 secret
    func loadSecret(for serverId: UUID) -> String?
    func saveSecret(_ secret: String, for serverId: UUID)
    func deleteSecret(for serverId: UUID)
}
```

---

## 五、ViewModel 设计

### 5.1 OverviewViewModel

```swift
@Observable
final class OverviewViewModel {
    // 状态
    var version: String?
    var mode: String?              // rule / global / direct
    var uploadSpeed: Int64 = 0     // B/s
    var downloadSpeed: Int64 = 0
    var uploadTotal: Int64 = 0
    var downloadTotal: Int64 = 0
    var memoryUsage: Int64 = 0     // KB
    var activeConnections: Int = 0
    var proxyCount: Int = 0
    var groupCount: Int = 0
    var ruleCount: Int = 0
    var isLoading: Bool = false
    var errorMessage: String?

    // 延迟测试 URL
    private var testURL: String = "https://www.gstatic.com/generate_204"

    private let api: MihomoAPIService
    private let ws: WebSocketService

    init(api: MihomoAPIService, ws: WebSocketService)

    /// 启动时调用：拉取版本 + 配置 + 连接实时流量 WS
    func load() async

    /// 启动实时流量订阅
    func startTrafficStream()

    /// 停止所有订阅
    func stopAll()

    /// 重启 mihomo 内核
    func restartKernel() async throws

    /// 重载配置
    func reloadConfig() async throws

    /// 刷新假 IP 缓存
    func flushFakeIP() async throws
}
```

**数据刷新策略：**
- 版本/配置/代理数量/规则数量：进入页面时拉取一次 + 下拉刷新
- 实时流量（上/下行速率）：WebSocket 持续推送
- 总流量/内存/活跃连接：WebSocket 的连接数据中也包含，或每 5 秒通过 WebSocket 的 connections 流获取
- 延迟测试 URL 可配置（在 SettingsView 中）

### 5.2 ProxiesViewModel

```swift
@Observable
final class ProxiesViewModel {
    var groups: [ProxyGroup] = []
    var nodes: [ProxyNode] = []
    var providers: [ProxyProvider] = []
    var nodeDelayMap: [String: Int] = [:]   // nodeName -> latency (ms)
    var isLoading: Bool = false
    var errorMessage: String?

    // 延迟测试配置
    var testURL: String = "https://www.gstatic.com/generate_204"
    var testTimeout: Int = 5000

    private let api: MihomoAPIService

    init(api: MihomoAPIService)

    /// 拉取代理数据
    func loadProxies() async

    /// 切换代理组选中节点
    func switchProxy(groupName: String, to nodeName: String) async throws

    /// 测试单个节点延迟
    func testNodeDelay(nodeName: String) async -> Int?

    /// 测试某个代理组所有节点延迟
    func testGroupDelay(groupName: String) async

    /// 刷新代理提供者
    func refreshProvider(name: String) async throws

    /// 健康检查某个 provider 下的 proxy
    func healthCheck(provider: String, proxy: String) async -> Int?

    /// 清除代理组固定选择 (DELETE /proxies/{name})
    func clearFixedProxy(groupName: String) async throws
}
```

**刷新策略：**
- 代理列表变化不频繁，默认 30 秒自动轮询一次
- 手动下拉刷新立即拉取
- 延迟测试为用户主动触发操作
- 切换代理后立即刷新该组状态

### 5.3 RulesViewModel

```swift
@Observable
final class RulesViewModel {
    var rules: [RuleItem] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // 筛选
    var searchText: String = ""
    var filterType: String?      // 按规则类型筛选

    private let api: MihomoAPIService

    init(api: MihomoAPIService)

    /// 拉取规则列表
    func loadRules() async

    /// 禁用/启用规则
    func toggleRule(index: Int) async throws

    /// 筛选后的规则列表
    var filteredRules: [RuleItem] { get }
}
```

**刷新策略：**
- 规则列表变化极少，仅在进入页面时拉取 + 手动下拉刷新

### 5.4 ConnectionsViewModel

```swift
@Observable
final class ConnectionsViewModel {
    var snapshot: ConnectionSnapshot?
    var activeConnections: [ConnectionInfo] = []
    var closedConnections: [ConnectionInfo] = []
    var uploadTotal: Int64 = 0
    var downloadTotal: Int64 = 0
    var memory: Int64?

    // 排序和筛选
    var sortBy: SortOption = .time
    var sortAscending: Bool = false
    var filterText: String = ""

    private let api: MihomoAPIService
    private let ws: WebSocketService
    private var lastSnapshot: ConnectionSnapshot?

    enum SortOption {
        case time, upload, download, uploadSpeed, downloadSpeed, host
    }

    init(api: MihomoAPIService, ws: WebSocketService)

    /// 启动实时连接监控 (WebSocket)
    func startMonitoring()

    /// 停止监控
    func stopMonitoring()

    /// 断开所有连接
    func closeAllConnections() async throws

    /// 断开单个连接
    func closeConnection(id: String) async throws

    /// 清除已关闭的连接记录
    func clearClosedConnections()

    /// 排序 & 筛选后的连接列表
    func sortedAndFilteredConnections() -> [ConnectionInfo]
}
```

**实时连接处理策略（参考 clash-verge-rev）：**

每次 WebSocket 推送完整连接快照时：
1. 将新快照的 `connections` 与上一次的 `activeConnections` 做 diff
2. 相同的 `id` 保留并更新 `upload`/`download`，计算 `uploadSpeed`/`downloadSpeed` (delta / 间隔)
3. `id` 不在新快照中的 → 标记为 `isActive = false`，移入 `closedConnections`
4. 新出现的 `id` → 新增到 `activeConnections`
5. `closedConnections` 保留最近 200 条（滚动淘汰），用户可手动清除

这样避免每次全量替换导致的列表抖动。

---

## 六、View 设计

### 6.1 ContentView（根视图）

```swift
struct ContentView: View {
    @State private var settingsVM = SettingsViewModel()

    var body: some View {
        Group {
            if settingsVM.hasActiveServer {
                MainTabView(serverConfig: settingsVM.activeServer!)
            } else {
                WelcomeView(onServerAdded: { settingsVM.reload() })
            }
        }
    }
}

struct MainTabView: View {
    let serverConfig: ServerConfig

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("概览", systemImage: "gauge.with.dots.needle.33percent") }

            ProxiesView()
                .tabItem { Label("代理", systemImage: "network") }

            RulesView()
                .tabItem { Label("规则", systemImage: "arrow.triangle.branch") }

            ConnectionsView()
                .tabItem { Label("连接", systemImage: "point.3.connected.trianglepath.dotted") }
        }
    }
}
```

**设计要点：**
- 首次启动如果没有配置服务器 → 显示引导页（WelcomeView），引导用户添加服务器
- 服务器配置完成后进入 MainTabView
- TabView 使用 `selection` 绑定，支持 deep link

---

### 6.2 Tab 1 — 概览页 (OverviewView)

**布局：** 顶部状态指示 + 流量卡片 + 统计网格 + 快捷操作

```
┌─────────────────────────────────┐
│  🔴 mihomo v1.19.27             │  ← 版本 & 运行状态指示
│  Rule Mode  |  Uptime: 3d 12h   │
├─────────────────────────────────┤
│  ┌─────────────────────────────┐│
│  │  📊 实时流量                ││
│  │  ⬆ 2.3 MB/s  ⬇ 12.5 MB/s  ││  ← 大字号显示当前速率
│  │  ▁▂▃▄▅▆▇█▇▆▅▄▃▂▁ (折线图)  ││  ← 最近 60 秒趋势
│  │  总计: ↑ 2.3GB  ↓ 15.8GB   ││
│  └─────────────────────────────┘│
├─────────────────────────────────┤
│  ┌───────────┬───────────┐     │
│  │  🧠 内存   │  🔗 连接   │     │
│  │  48.2 MB  │  127 活跃  │     │  ← 2×2 统计网格
│  ├───────────┼───────────┤     │
│  │  🌐 代理   │  📋 规则   │     │
│  │  45个节点  │  32条规则  │     │
│  └───────────┴───────────┘     │
├─────────────────────────────────┤
│  快捷操作                       │
│  [🔄 重载配置] [🗑 清FakeIP]    │
│  [🔌 断开所有连接] [♻️ 重启]    │  ← 带确认对话框
└─────────────────────────────────┘
```

**交互：**
- 下拉刷新全部数据
- 流量卡片可点击展开详细趋势图（Canvas 绘制 60 秒折线图）
- 统计网格每项可点击跳转到对应 tab
- 重启按钮需要确认弹窗

**流量折线图实现：**
- 使用 `Canvas` + `Path` 绘制
- 保存最近 60 个数据点（1 秒一个，来自 WebSocket 流量流）
- 支持左右滑动手势切换时间窗口（60s / 5min / 15min）

---

### 6.3 Tab 2 — 代理页 (ProxiesView)

**布局：** 代理组列表（可展开）+ 延迟测试 + 底部节点选择

```
┌─────────────────────────────────┐
│  🔍 搜索代理...                  │
├─────────────────────────────────┤
│  ▼ 🌐 Proxy  →  [HK-01]  45ms  │  ← 代理组（折叠/展开）
│    ├ ○ HK-01      45ms  🟢     │
│    ├ ○ US-West   180ms  🟡     │  ← 单选（当前组为 Selector 时）
│    ├ ○ JP-Tokyo   85ms  🟢     │
│    └ ○ SG-Node   120ms  🟡     │
│                                 │
│  ▶ 🤖 AI 选择   →  [Auto-1]    │  ← URLTest 组（不可手动选）
│                                 │
│  ▶ 📺 流媒体    →  [NF-Node]   │  ← Fallback 组
│                                 │
│  ▶ ⚖️ 负载均衡  →  [Active]    │  ← LoadBalance 组
│                                 │
│  ▼ 📦 Proxy Provider: MyNodes  │
│    ├ ○ HK-02     35ms  🟢      │
│    ├ ○ US-NY    210ms  🔴      │
│    └ ○ ...                     │
│      [🔄 更新 Provider]        │
└─────────────────────────────────┘
```

**交互设计：**

1. **代理组折叠/展开**：
   - 默认所有组折叠
   - 点击组名展开显示所有可选节点列表
   - Selector 类型组：显示单选列表（当前选中高亮 + 打钩）
   - URLTest/Fallback/LoadBalance 类型组：显示当前自动选中的节点（不可手动切换，但有"清除固定"按钮）

2. **切换代理节点**：
   - 长按或左滑节点行 → 显示"测速"和"切换"操作
   - 点击非当前选中节点 → 调用 `PUT /proxies/{groupName}` 切换
   - 切换成功后播放轻 haptic 反馈，显示 toast "已切换到 {nodeName}"
   - 或者：点击展开的节点行直接切换（因为只有 Selector 组允许展开）

3. **延迟测试**：
   - 每组右上角有 ⚡ 按钮，点击测试该组所有节点延迟
   - 单个节点长按 → 测速
   - 延迟显示按颜色区分：🟢 <200ms 🟡 200-500ms 🟠 500-1000ms 🔴 >1000ms ⚪ 超时/不可达

4. **搜索与筛选**：
   - 顶部搜索框支持模糊搜索节点名
   - 可筛选延迟范围
   - 可筛选代理类型（SS / VMess / Trojan / ...）

5. **Proxy Provider 管理**：
   - 底部区域展示所有 proxy provider
   - 每个 provider 可展开查看节点
   - 支持手动更新 provider

6. **自动刷新**：每 30 秒后台轮询，进入前台时立即刷新

---

### 6.4 Tab 3 — 规则页 (RulesView)

**布局：** 规则列表 + 筛选 + 禁用/启用

```
┌─────────────────────────────────┐
│  🔍 搜索规则...    [类型▼]      │
├─────────────────────────────────┤
│  规则 (32)                      │
│                                 │
│  #1  DOMAIN       🟢          │
│  example.com  →  Proxy         │
│  ─────────────────────────────  │
│  #2  DOMAIN-SUFFIX 🟢          │
│  google.com   →  Direct        │
│  ─────────────────────────────  │
│  #3  GEOIP       🟢           │
│  CN           →  Direct        │
│  ─────────────────────────────  │
│  #4  MATCH       🟢           │
│  all          →  Proxy         │
│  ─────────────────────────────  │
│  #5  DOMAIN-KEYWORD ⛔         │  ← 已禁用（灰色）
│  ad           →  REJECT        │
└─────────────────────────────────┘
```

**交互：**
- 左滑规则 → 禁用/启用切换（`PATCH /rules/disable`）
- 点击规则 → 展开详情 sheet（显示匹配类型、匹配值、目标策略、规则来源 provider）
- 顶部筛选器：按规则类型筛选（DOMAIN、DOMAIN-SUFFIX、GEOIP、IP-CIDR 等）
- 搜索框：同时搜索 payload 和 proxy
- Disabled 规则以灰色+删除线显示
- 规则序号从 1 开始递增

**规则类型 Badge 颜色：**
- DOMAIN 型：蓝色
- DOMAIN-SUFFIX 型：青色
- GEOIP 型：绿色
- IP-CIDR 型：橙色
- MATCH 型：紫色
- 其他：灰色

---

### 6.5 Tab 4 — 连接页 (ConnectionsView)

**布局：** 实时连接列表 + 聚合统计 + 断开操作

```
┌─────────────────────────────────┐
│  🔍 筛选连接...    [⏱️ 时间▼]  │
├─────────────────────────────────┤
│  活跃连接: 127                  │
│  总流量: ↑ 1.2GB  ↓ 8.7GB     │
│                                 │
│  [断开所有连接 (127)]           │  ← 红色按钮
│  [清除已关闭]                   │
├─────────────────────────────────┤
│  Tab: [活跃] [已关闭 (15)]      │
├─────────────────────────────────┤
│  🟢 TCP                      ↑  │
│  1.2.3.4:55678 → example.com  │
│  Proxy → HK-01                  │  ← 代理链
│  ⬆ 12KB/s ⬇ 345KB/s           │  ← 速率
│  RULE: DOMAIN-SUFFIX,google    │
│  ─────────────────────────────  │
│  🟡 UDP                        │
│  1.2.3.4:55679 → 8.8.8.8:53  │
│  DNS → Direct                   │
│  ⬆ 1KB/s ⬇ 2KB/s              │
│  RULE: DNS                     │
│  ─────────────────────────────  │
│  ...                            │
│                                 │
│  (左滑单个连接 → 断开)          │
└─────────────────────────────────┘
```

**交互设计：**

1. **实时更新**：WebSocket 持续推送连接状态（每秒一次），界面实时刷新
2. **连接行显示**：
   - 协议图标（TCP/UDP）
   - 源 IP:Port → 目标 (host 或 IP:Port)
   - 代理链：用箭头连接（如 `Proxy → HK-01`）
   - 实时上传/下载速率（B/s，自动格式化 KB/MB）
   - 命中规则
3. **排序**：顶部排序按钮，支持按时间、上传量、下载量、上传速率、下载速率排序
4. **筛选**：搜索框支持搜索 IP、域名、代理链名称
5. **断开操作**：
   - 单个连接：左滑 → 红色"断开"按钮 (`DELETE /connections/{id}`)
   - 全部断开：顶部红色按钮，需确认对话框
6. **Tab 切换**：
   - 活跃连接 tab：实时展示
   - 已关闭 tab：展示最近断开的连接记录（灰色，显示持续时间和总流量）
7. **连接详情**：点击连接行 → 弹出 Sheet 显示详细信息：
   - 连接 ID
   - 持续时长
   - 完整 metadata（进程名、UID、DNS 模式、SNI 等）
   - 累计上传/下载总量
   - 完整代理链
   - 匹配规则详情

**delta 速率计算：**
- 维护一个 `[String: ConnectionInfo]` 字典
- 每次 WebSocket 推送时，diff 计算 `(新 upload - 旧 upload) / 时间间隔`
- 速率显示为 KiB/s 或 MiB/s

---

### 6.6 设置页 (SettingsView)

```
┌─────────────────────────────────┐
│  ⚙️ 设置                        │
├─────────────────────────────────┤
│  服务器                         │
│  ┌─────────────────────────────┐│
│  │ ✅ 客厅路由器                ││  ← 当前活跃
│  │    192.168.1.1:9090         ││
│  │    [编辑] [删除]            ││
│  ├─────────────────────────────┤│
│  │   书房路由器                  ││
│  │    192.168.2.1:9090         ││
│  │    [设为活跃] [编辑] [删除]  ││
│  └─────────────────────────────┘│
│  [+ 添加服务器]                  │
├─────────────────────────────────┤
│  延迟测试默认配置                 │
│  URL: [https://www.gstatic...]  │
│  超时: [5000 ms]                │
├─────────────────────────────────┤
│  关于                           │
│  ClashDash v1.0.0               │
│  基于 mihomo API                │
└─────────────────────────────────┘
```

**添加/编辑服务器页：**
```
┌─────────────────────────────────┐
│  取消          添加服务器    保存 │
├─────────────────────────────────┤
│  名称    [客厅路由器           ] │
│  地址    [192.168.1.1         ] │
│  端口    [9090                ] │
│  Secret  [••••••••            ] │  ← 存 Keychain
│  TLS     [🔲 启用 HTTPS      ] │
├─────────────────────────────────┤
│  [测试连接]                      │  ← 调用 GET /version 测试
│  状态: ✅ 连接成功 v1.19.27     │
└─────────────────────────────────┘
```

---

## 七、导航与状态管理

### 7.1 全局状态流

```
App Launch
  ↓
ServerConfigService.loadActiveServer()
  ↓
┌── hasActiveServer? ──→ WelcomeView (引导添加服务器)
│                            ↓ 添加完成
└── YES                     ↓
  ↓                    reload activeServer
MainTabView
  ↓
创建 MihomoAPIService(config, secret)
创建 WebSocketService(config, secret)
  ↓
注入到各 ViewModel
  ↓
OverviewViewModel.load()
ProxiesViewModel.loadProxies()
...
```

### 7.2 ViewModel 传参方式

参考 authenticator 的 `@State` + `@Environment` 模式：
- API Service 和 WebSocket Service 在 `MainTabView` 创建
- 通过 `.environment()` 向下传递
- 各子 View 使用 `@State private var viewModel = XXXViewModel()`
- 在 `.onAppear` 中注入 service 并开始加载

或者采用更简单的模式：在每个 View 的 `init` 中接收 service，创建 ViewModel：

```swift
struct OverviewView: View {
    @State private var vm: OverviewViewModel

    init(api: MihomoAPIService, ws: WebSocketService) {
        _vm = State(initialValue: OverviewViewModel(api: api, ws: ws))
    }

    var body: some View {
        // ...
        .task { await vm.load() }
        .onAppear { vm.startTrafficStream() }
        .onDisappear { vm.stopAll() }
    }
}
```

### 7.3 生命周期管理

| 场景 | 行为 |
|------|------|
| 进入 Tab | 对应 ViewModel 开始加载/订阅 |
| 离开 Tab | 轻量数据（规则）保留；重量流（WebSocket）可选择性断开 |
| App 进后台 | 断开所有 WebSocket，停止轮询 Timer |
| App 回前台 | 重连 WebSocket，重新拉取数据 |
| 切换服务器 | 断开所有连接，重建 Service，重新加载 |

---

## 八、UI/UX 细节

### 8.1 视觉风格

- **整体风格**：iOS 原生风格，与系统设置 app 类似
- **色彩**：使用系统 semantic colors（`.primary`, `.secondary`, `.green`, `.red`, `.orange`）
- **深色模式**：完全适配（使用 semantic colors 天然支持）
- **字体**：monospaced 用于数字（延迟、流量速率、IP 地址）；默认系统字体用于其他
- **间距**：遵循 iOS HIG，列表行高 44pt，卡片圆角 12pt

### 8.2 状态指示颜色

| 状态 | 颜色 | 用途 |
|------|------|------|
| 连接正常 | green | 服务器状态点 |
| 连接中 | yellow | 加载中 |
| 连接失败 | red | 错误状态 |
| 延迟 <200ms | green | 节点延迟 |
| 延迟 200-500ms | yellow | 节点延迟 |
| 延迟 500-1000ms | orange | 节点延迟 |
| 延迟 >1000ms / 超时 | red / gray | 节点延迟 |

### 8.3 Haptic 反馈

- 切换代理成功：`.success` (light impact)
- 断开连接：`.warning` (medium impact)
- 复制信息：`.light` (light impact)

### 8.4 错误处理

- 网络错误：显示 banner/toast，自动重试（3 次指数退避）
- API 错误（4xx/5xx）：解析 error JSON，显示具体错误信息
- 认证失败（401）：提示检查 secret
- 超时：显示 "连接超时，请检查服务器地址和端口"

---

## 九、构建与部署

### 9.1 项目创建
- 使用 Xcode 创建 iOS App 项目（SwiftUI, iOS 17+）
- 在 Xcode 中直接添加/管理源文件和文件夹
- 新增文件时通过 Xcode 的 "Add Files to Project" 即可，无需手动维护 pbxproj

### 9.2 编译命令
```bash
# 模拟器快速验证
xcodebuild -project ClashDash.xcodeproj \
  -scheme ClashDash \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -configuration Debug build

# 真机构建 + 部署
xcodebuild -project ClashDash.xcodeproj \
  -scheme ClashDash \
  -destination 'platform=iOS,id=<DEVICE_UDID>' \
  -configuration Debug \
  -allowProvisioningUpdates build && \
xcrun devicectl device install app --device <DEVICE_UDID> \
  /path/to/Debug-iphoneos/ClashDash.app
```

### 9.3 签名配置
- `CODE_SIGN_STYLE = Automatic`
- `DEVELOPMENT_TEAM = ZJB59HBZGC`
- `PRODUCT_BUNDLE_IDENTIFIER = com.clashdash.app`
- `UILaunchScreen` 设为空 dict（确保全屏）

### 9.4 网络权限
- Info.plist 添加 `NSAppTransportSecurity` → `NSAllowsArbitraryLoads = true`（路由器通常是 HTTP 非加密连接）

---

## 十、API 接口速查表

| 方法 | 端点 | 用途 | Tab |
|------|------|------|-----|
| GET | `/version` | 版本信息 | 概览 |
| GET/WS | `/traffic` | 实时流量 | 概览 |
| GET/WS | `/memory` | 内存使用 | 概览 |
| GET | `/configs` | 运行配置 | 概览 |
| PUT | `/configs?force=true` | 重载配置 | 概览 |
| POST | `/restart` | 重启内核 | 概览 |
| POST | `/cache/fakeip/flush` | 清空 FakeIP | 概览 |
| GET | `/proxies` | 所有代理 | 代理 |
| GET | `/proxies/{name}` | 单个代理 | 代理 |
| PUT | `/proxies/{name}` | 切换代理 | 代理 |
| DELETE | `/proxies/{name}` | 清除固定选择 | 代理 |
| GET | `/proxies/{name}/delay?url=&timeout=` | 延迟测试 | 代理 |
| GET | `/group` | 策略组信息 | 代理 |
| GET | `/group/{name}/delay?url=&timeout=` | 组延迟测试 | 代理 |
| GET | `/providers/proxies` | 代理提供者 | 代理 |
| PUT | `/providers/proxies/{name}` | 更新提供者 | 代理 |
| GET | `/rules` | 规则列表 | 规则 |
| PATCH | `/rules/disable` | 禁用规则 | 规则 |
| GET/WS | `/connections?interval=` | 连接列表 | 连接 |
| DELETE | `/connections` | 断开所有 | 连接 |
| DELETE | `/connections/{id}` | 断开单个 | 连接 |

---

## 十一、开发步骤建议

按优先级分阶段实现：

### Phase 1 — 基础骨架
1. 在 Xcode 中创建 iOS App 项目，搭建目录结构（App / Models / Services / ViewModels / Views / Extensions）
2. 实现 ServerConfigService（UserDefaults + Keychain）
3. 实现 SettingsView + AddServerView（服务器配置）
4. 实现 ContentView + WelcomeView（引导流程）
5. 实现 MainTabView（空壳 4 个 Tab）

### Phase 2 — 核心数据层
7. 实现 MihomoAPIService（所有 API 方法）
8. 实现所有数据模型（Codable 对接 API JSON）
9. 使用 playground / 临时测试验证 API 通信正常

### Phase 3 — Tab 页面
10. 实现 OverviewView + OverviewViewModel（概览页）
11. 实现 ProxiesView + ProxiesViewModel（代理页，含切换功能）
12. 实现 RulesView + RulesViewModel（规则页，含禁用功能）
13. 实现 ConnectionsView + ConnectionsViewModel（连接页，含断开功能）

### Phase 4 — 实时数据
14. 实现 WebSocketService
15. 接入实时流量流 → OverviewView
16. 接入实时连接流 → ConnectionsView
17. 实现断线重连逻辑

### Phase 5 — 体验打磨
18. 延迟测试功能（代理页测速）
19. 流量折线图（概览页 Canvas）
20. 搜索和筛选（代理页、连接页）
21. Haptic 反馈
22. 深色模式适配
23. Toast / 错误 banner
24. 下拉刷新

### Phase 6 — 高级功能（可选）
25. DNS 查询页面
26. 日志查看（WebSocket /logs）
27. 代理延迟历史图表
28. Widget（Today Widget 显示实时流量）
29. 多服务器快速切换
