import SwiftUI

struct OverviewView: View {
    @State private var vm: OverviewViewModel

    init(api: MihomoAPIService, ws: WebSocketService) {
        _vm = State(initialValue: OverviewViewModel(api: api, ws: ws))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Status & Version
                    statusCard

                    // Real-time Traffic
                    trafficCard

                    // Stats Grid
                    statsGrid

                    // Quick Actions
                    quickActions
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("概览")
            .refreshable {
                await vm.load()
                await vm.refreshStats()
            }
        }
        .task { await vm.load() }
        .task { await vm.refreshStats() }
        .onAppear { vm.startTrafficStream() }
        .onDisappear { vm.stopAll() }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(vm.isConnected ? .green : .red)
                    .frame(width: 10, height: 10)

                if let version = vm.version {
                    Text("mihomo \(version)")
                        .font(.subheadline.bold())
                } else if vm.isLoading {
                    Text("连接中...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("未连接")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(vm.mode)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Traffic Card

    private var trafficCard: some View {
        VStack(spacing: 12) {
            HStack {
                Label("实时流量", systemImage: "arrow.left.arrow.right")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("上传", systemImage: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.uploadSpeed.formattedSpeed())
                        .font(.title2.bold())
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Label("下载", systemImage: "arrow.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.downloadSpeed.formattedSpeed())
                        .font(.title2.bold())
                        .monospacedDigit()
                }
            }

            // Mini chart
            if !vm.uploadHistory.isEmpty {
                trafficChart
            }

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text("总上传")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.uploadTotal.formattedBytes())
                        .font(.subheadline.monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("总下载")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.downloadTotal.formattedBytes())
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var trafficChart: some View {
        Canvas { context, size in
            let maxDownload = vm.downloadHistory.max() ?? 1
            let maxUpload = vm.uploadHistory.max() ?? 1
            let maxVal = max(maxDownload, maxUpload, 1)
            let stepX = size.width / Double(max(1, vm.downloadHistory.count - 1))

            // Download line
            var downPath = Path()
            for (i, val) in vm.downloadHistory.enumerated() {
                let x = Double(i) * stepX
                let y = size.height * (1 - val / maxVal)
                if i == 0 { downPath.move(to: CGPoint(x: x, y: y)) }
                else { downPath.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(downPath, with: .color(.blue), lineWidth: 1.5)

            // Upload line
            var upPath = Path()
            for (i, val) in vm.uploadHistory.enumerated() {
                let x = Double(i) * stepX
                let y = size.height * (1 - val / maxVal)
                if i == 0 { upPath.move(to: CGPoint(x: x, y: y)) }
                else { upPath.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(upPath, with: .color(.green), lineWidth: 1.5)
        }
        .frame(height: 60)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statItem(title: "内存", value: vm.memoryUsage.formattedBytes(), icon: "memorychip", color: .orange)
            statItem(title: "活跃连接", value: "\(vm.activeConnections)", icon: "point.3.connected.trianglepath.dotted", color: .green)
            statItem(title: "代理节点", value: "\(vm.proxyCount)", icon: "network", color: .blue)
            statItem(title: "规则数", value: "\(vm.ruleCount)", icon: "arrow.triangle.branch", color: .purple)
        }
    }

    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("快捷操作")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                quickActionButton(title: "重载配置", icon: "arrow.triangle.2.circlepath") {
                    Task { try? await vm.reloadConfig() }
                }
                quickActionButton(title: "清 FakeIP", icon: "trash") {
                    Task { try? await vm.flushFakeIP() }
                }
                quickActionButton(title: "重启内核", icon: "power", isDestructive: true) {
                    Task { try? await vm.restartKernel() }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func quickActionButton(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(isDestructive ? .red : nil)
    }
}
