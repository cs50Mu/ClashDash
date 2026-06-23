# ClashDash 开发经验总结

> 环境：macOS 15.7.7 · Xcode 26.3 · iPhone iOS 26.4 · Swift 6.2.4 · mihomo v1.19.27

本文档总结了从零开发一个连接远程 mihomo API 的 iOS dashboard app 的全过程经验教训和最佳实践。

---

## 一、项目工程化

### 1.1 pbxproj 自动生成

Xcode 26 没有 CLI 创建项目的方式，但可以通过 Python 脚本自动扫描源文件目录生成 `.pbxproj`。

**关键约束：**

- **文件名中避免 `+` 号**：old-style plist 解析器对注释中的 `+` 极其敏感，会导致整个项目无法打开。采用 `ColorExt.swift` 而非 `Color+Ext.swift`
- **文件引用 path 只写文件名**，目录层级通过 PBXGroup 的 `path` 属性表达——这是 Xcode 的标准结构
- 使用固定 ID 模板（如 `F1F1F1...0001`）生成所有 PBXBuildFile、PBXFileReference、PBXGroup，每次新增文件时重新运行脚本

**教训：** 不要试图手动编辑 pbxproj，超过 5 个文件就该用脚本。脚本应该每次都全量重新生成，而不是增量修改。

### 1.2 构建与部署一键命令

```bash
# 构建
xcodebuild -project ClashDash.xcodeproj \
  -scheme ClashDash \
  -destination 'platform=iOS,id=<DEVICE_UDID>' \
  -configuration Debug \
  -allowProvisioningUpdates build

# 安装
xcrun devicectl device install app \
  --device <DEVICE_UDID> \
  <path-to-derived-data>/Debug-iphoneos/ClashDash.app

# 启动
xcrun devicectl device process launch \
  --device <DEVICE_UDID> \
  com.clashdash.app
```

获取设备 UDID：`xcrun devicectl list devices` 或从 xcodebuild 的 destination 列表中找真实的 `platform:iOS,id:00008150...`。

---

## 二、API 对接的教训

### 2.1 不要盲目信任文档

这是本次开发最大的教训。mihomo v1.19.27 的实际 API 响应格式与网上文档（包括官方 wiki 和 Go hub 包）存在差异：

| 端点 | 文档中的格式 | 实际返回格式 |
|------|-------------|-------------|
| `/rules` | `{"name":"DOMAIN", "type":"example.com"}` | `{"index":0, "type":"ProcessName", "payload":"...", "proxy":"节点组", "extra":{...}}` |
| `/memory` | 可能不可用（GET 被取消） | 从 `/connections` 响应的 `memory` 字段获取 |

**最佳实践：**
- 先用 `curl` 或浏览器直接访问 API 确认实际响应格式
- 在数据模型中用 optional 字段做好兜底
- 对于异构响应（如 `/proxies` 同时包含 proxy group 和 proxy node），用 `JSONSerialization` 而非 `Codable`

### 2.2 数据模型分层

API 返回的 JSON 结构和 UI 展示需要的结构可能不同。例如规则返回中 `extra.disabled` 指示是否禁用，但 UI 需要可变的 disabled 状态。应该分离：

```
API Model (Codable)  →  ViewModel (mutable, @Observable)  →  View
```

不要直接从 API model 驱动 UI，中间加一层 ViewModel 转换。

---

## 三、Swift Concurrency 踩坑

### 3.1 actor 不要滥用

最初将 `MihomoAPIService` 设计为 `actor`，导致：
- ViewModel 调用 API 需要额外的 `await` 跳转
- actor 串行化导致并发请求变慢
- `@Observable` 的 MainActor 隔离和 actor 隔离之间频繁切换

**最终方案：** 使用 `final class` + `async` 方法，让 Swift 的 structured concurrency 自然处理。`URLSession` 本身就是线程安全的。

### 3.2 @MainActor 与 @Observable

`@Observable` 类的属性变更必须在 MainActor 上进行。两种做法：
1. 在类上标注 `@MainActor`
2. 在修改属性的方法上标注 `@MainActor`

推荐方案 2，更精确。

### 3.3 Task 中的 [weak self]

在 actor 方法内创建 `Task { [weak self] in ... }` 会导致 Task 失去 actor 隔离。应使用 `Task { ... }` 直接捕获 self，actor 不会被提前释放。

---

## 四、设备日志方案演进

这是迭代最多的环节，经历了四个阶段：

### 方案 1：os.Logger → log collect（可行但非实时）
```
echo password | sudo -S log collect --device --output /tmp/logs.logarchive
log show --archive /tmp/logs.logarchive --predicate 'subsystem == "..."' --info
```
- 缺点：抓全量日志慢、需要 sudo、非实时
- `--predicate` 在设备采集时被忽略（`Warning: --predicate is ignored when collecting from attached device`）
- 用 `--last 30s` 限制时间窗口可加速
- `os.Logger.debug` 的消息在 `log collect` 中会被过滤，需要 `.info` 级别

### 方案 2：os.Logger + log stream（不支持设备）
`log stream --predicate` 只在 macOS 本地或模拟器有效，不支持真机。

### 方案 3：NSLog + idevicesyslog（不可行）
iOS 17+ 将 `NSLog` 输出迁移到统一日志系统，传统 syslog 读不到。

### 方案 4：内嵌 HTTP Debug Server（最终方案 ✅）
在 app 内运行轻量 HTTP server，暴露 `/debug/logs` 端点：
```bash
curl -s http://phone-ip:8080/debug/logs
```
- 实时、无需 sudo、跨网络访问
- 用 `Network.framework` 的 `NWListener` 实现，零依赖
- 同时保留 `os.Logger` 写入统一日志，供 `log collect` 兜底

**教训：** 当系统工具受限时，自己造一个往往更简单。

---

## 五、SwiftUI 模式

### 5.1 @Observable + @Bindable 传递

View 之间共享 ViewModel 的正确方式：
```swift
// 父 View
@State private var vm = SettingsViewModel()

// 子 View
@Bindable var vm: SettingsViewModel  // 不要重新包 @State！
```

**致命错误：** 子 View 把接收到的 ViewModel 重新包一层 `@State`，会导致修改的是本地副本，父 View 感知不到变化。

### 5.2 .onTapGesture vs Button

当需要同时支持点击和长按菜单（`.contextMenu`）时，**不要用 `Button`**，用 `HStack` + `.onTapGesture` + `.contentShape(Rectangle())`。`Button` + `.contextMenu` 会互相干扰。

### 5.3 测速按钮放在组名旁边

交互直觉：与组相关的操作（测速全部节点）放在组名旁边，与节点相关的操作（切换、单独测速）放在节点行上。不要把所有操作都藏在长按菜单里。

---

## 六、Info.plist 必要配置

```xml
<key>UILaunchScreen</key>
<dict/>  <!-- 确保全屏，无黑边 -->

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>  <!-- 路由器通常 HTTP 非加密 -->
</dict>
```

---

## 七、App Icon 生成

- **格式：** 单一 1024x1024 PNG + 简化版 `Contents.json`（`idiom: universal`，不展开各尺寸）
- **工具：** ImageMagick (`magick`) 命令行
- **色谱匹配：** 先 `magick target.png -resize 1x1 txt:` 取目标主色，再模仿
- **不要预切圆角：** iOS 自动裁切

---

## 八、核心经验原则

| 原则 | 说明 |
|------|------|
| **先验证再建模** | API 响应格式以实际 curl 为准，不以文档为准 |
| **简单优于正确** | `final class` 够用就不要 `actor`；`JSONSerialization` 够用就不要死磕 `Codable` |
| **日志即调试** | 在 data 层内置可查询的日志系统，比依赖外部日志工具高效得多 |
| **命令行优先** | 确保每一步（构建/部署/调试）都能在终端完成 |
| **先跑通核心流程** | 概览和规则先显示数据，再迭代 UI 交互 |

---

## 九、技术栈

| 层级 | 技术 |
|------|------|
| UI | SwiftUI (iOS 17+) |
| 状态管理 | `@Observable` + `@Bindable` |
| 网络 | URLSession + async/await |
| WebSocket | URLSessionWebSocketTask |
| Debug HTTP | Network.framework NWListener |
| 持久化 | UserDefaults + Keychain Services |
| 日志 | os.Logger + 内嵌 HTTP debug server |
| 构建 | xcodebuild + Python pbxproj 生成 |
| 部署/调试 | devicectl + curl |
