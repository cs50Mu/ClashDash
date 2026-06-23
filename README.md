# ClashDash

> 一个开源的 iOS 应用，用于远程连接和管理运行在路由器上的 [mihomo](https://github.com/MetaCubeX/mihomo) 代理内核。

ClashDash 提供了对 mihomo 代理的四大核心管理功能：**概览、代理管理、规则查看、连接监控**，帮助你随时随地掌控网络代理状态。

<p align="left">
  <img src="https://img.shields.io/badge/iOS-17.0+-blue.svg" alt="iOS 17.0+">
  <img src="https://img.shields.io/badge/Swift-6-blue.svg" alt="Swift 6">
  <img src="https://img.shields.io/badge/Xcode-26.3+-brightgreen.svg" alt="Xcode 26.3+">
  <img src="https://img.shields.io/badge/mihomo-v1.19.27+-orange.svg" alt="mihomo v1.19.27+">
</p>

---

## 功能概览

| 标签页 | 功能 |
|--------|------|
| 📊 **概览** | 实时流量图表、内存使用、版本信息、连接数统计 |
| 🔄 **代理** | 查看代理节点延迟、切换代理组策略、管理代理提供者 |
| 📜 **规则** | 查看完整的路由规则列表、匹配模式和代理节点映射 |
| 🔗 **连接** | 实时连接监控、按条件筛选、手动关闭连接 |

---

## 截图

| 概览 | 代理 | 规则 | 连接 |
|------|------|------|------|
| ![概览](screenshots/overview.png) | ![代理](screenshots/proxies.png) | ![规则](screenshots/rules.png) | ![连接](screenshots/connections.png) |

*(截图待补充)*

---

## 技术栈

| 层级 | 技术选型 |
|------|----------|
| UI | SwiftUI (iOS 17+) |
| 状态管理 | `@Observable` (Observation 框架) |
| 网络 | URLSession + async/await |
| WebSocket | URLSessionWebSocketTask |
| 持久化 | UserDefaults (配置) + Keychain (密钥) |
| 认证 | HTTP `Authorization: Bearer {secret}` |
| 导航 | TabView + NavigationStack |

---

## 架构设计

```
┌─────────────────────────────────────────────────────────┐
│  SwiftUI Views (4 Tabs + Settings)                      │
│  Overview · Proxies · Rules · Connections               │
│                         ↕                               │
│  @Observable ViewModels                                 │
│  OverviewVM · ProxiesVM · RulesVM · ConnectionsVM       │
│                         ↕                               │
│  Services Layer                                         │
│  MihomoAPIService · WebSocketService                    │
│  ServerConfigService · HapticService · DebugServer      │
│                         ↕                               │
│  ┌──────────────────────────────────────┐               │
│  │  mihomo Router (external-controller) │               │
│  │  192.168.x.x:9090                    │               │
│  └──────────────────────────────────────┘               │
└─────────────────────────────────────────────────────────┘
```

### 项目结构

```
ClashDash/
├── ClashDash.xcodeproj/        # Xcode 项目管理（脚本自动生成）
├── ClashDash/
│   ├── App/
│   │   └── ClashDashApp.swift   # @main 入口
│   ├── Models/                  # 数据模型
│   │   ├── ServerConfig.swift
│   │   ├── ProxyNode.swift
│   │   ├── ProxyGroup.swift
│   │   ├── ProxyProvider.swift
│   │   ├── RuleItem.swift
│   │   ├── ConnectionInfo.swift
│   │   ├── ConnectionSnapshot.swift
│   │   ├── TrafficInfo.swift
│   │   └── MemoryInfo.swift
│   ├── ViewModels/              # 状态管理
│   │   ├── OverviewViewModel.swift
│   │   ├── ProxiesViewModel.swift
│   │   ├── RulesViewModel.swift
│   │   ├── ConnectionsViewModel.swift
│   │   └── SettingsViewModel.swift
│   ├── Views/                   # UI 视图层
│   │   ├── ContentView.swift
│   │   ├── Overview/
│   │   ├── Proxies/
│   │   ├── Rules/
│   │   ├── Connections/
│   │   └── Settings/
│   ├── Services/                # 服务层
│   │   ├── MihomoAPIService.swift
│   │   ├── WebSocketService.swift
│   │   ├── ServerConfigService.swift
│   │   ├── HapticService.swift
│   │   ├── DebugServer.swift
│   │   └── DebugLog.swift
│   ├── Extensions/              # 扩展
│   │   ├── ColorExt.swift
│   │   └── Formatters.swift
│   ├── Assets.xcassets/         # 图标等资源
│   └── Info.plist
├── gen_pbxproj.py               # pbxproj 自动生成脚本
├── gen_icon.py                  # 应用图标生成脚本
├── DESIGN.md                    # 详细设计文档
└── DEV_EXPERIENCE.md            # 开发经验总结
```

---

## 快速开始

### 前置条件

- macOS 15.7+ / Xcode 26.3+
- iOS 17.0+ 真机或模拟器
- 已开启 `external-controller` 的 mihomo 实例（默认端口 9090）

### 构建 & 运行

```bash
# 1. 克隆仓库
git clone https://github.com/YOUR_USERNAME/ClashDash.git
cd ClashDash

# 2. 生成 pbxproj（首次或新增文件后运行）
python3 gen_pbxproj.py

# 3. 用 Xcode 打开项目
open ClashDash.xcodeproj

# 4. 或使用命令行构建
xcodebuild -project ClashDash.xcodeproj \
  -scheme ClashDash \
  -destination 'platform=iOS,name=Your iPhone' \
  -configuration Debug \
  -allowProvisioningUpdates build
```

### 配置服务器连接

1. 启动应用后，进入 **设置** 标签页
2. 点击 **添加服务器**，填写：
   - **名称**：任意标识（如 "Home Router"）
   - **地址**：mihomo 的 IP 和端口（如 `192.168.1.1:9090`）
   - **Secret**：mihomo 配置中的 API 密钥（可选）
3. 点击 **测试连接** 验证配置
4. 保存后即可切换并管理该服务器

---

## 开发

### pbxproj 自动生成

本项目使用 Python 脚本自动生成 Xcode 项目文件，避免手动维护 `.pbxproj` 的繁琐。

```bash
# 添加新源文件后，重新生成：
python3 gen_pbxproj.py
```

> **注意**：文件名中避免使用 `+` 号（如用 `ColorExt.swift` 而非 `Color+Ext.swift`），否则 old-style plist 解析器可能出错。

### 构建产物

构建产物位于 Xcode DerivedData 目录，可通过以下命令安装到真机：

```bash
xcrun devicectl device install app \
  --device <DEVICE_UDID> \
  /path/to/Debug-iphoneos/ClashDash.app

xcrun devicectl device process launch \
  --device <DEVICE_UDID> \
  com.clashdash.app
```

---

## API 兼容性

ClashDash 适配 mihomo **v1.19.27+** 的实际 API 响应格式。已知差异：

| 端点 | 文档格式 | 实际格式 |
|------|---------|---------|
| `/rules` | `{"name":"...", "type":"..."}` | `{"index":0, "type":"...", "payload":"...", "proxy":"...", "extra":{...}}` |
| `/memory` | 独立端点（已废弃） | 从 `/connections` 响应中获取 |

> 详细 API 对接经验请参考 [DEV_EXPERIENCE.md](./DEV_EXPERIENCE.md)。

---

## License

MIT License

---

## 致谢

- [mihomo](https://github.com/MetaCubeX/mihomo) — 提供强大的代理内核和开放 API
- 参考项目 `authenticator/` — 项目脚手架和工程化实践参考
