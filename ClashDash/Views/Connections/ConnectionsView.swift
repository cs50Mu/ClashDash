import SwiftUI

struct ConnectionsView: View {
    @State private var vm: ConnectionsViewModel
    @State private var selectedTab: ConnTab = .active
    @State private var showCloseAllConfirm = false
    @State private var selectedConnection: ConnectionInfo?
    @State private var showDetail = false

    enum ConnTab: String, CaseIterable {
        case active = "活跃"
        case closed = "已关闭"
    }

    init(api: MihomoAPIService, ws: WebSocketService) {
        _vm = State(initialValue: ConnectionsViewModel(api: api, ws: ws))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary bar
                summaryBar

                // Tab picker
                Picker("", selection: $selectedTab) {
                    ForEach(ConnTab.allCases, id: \.self) { tab in
                        Text("\(tab.rawValue) (\(tab == .active ? vm.activeCount : vm.closedCount))")
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Connection list
                Group {
                    if selectedTab == .active && vm.activeConnections.isEmpty && !vm.isLoading {
                        ContentUnavailableView(
                            "没有活跃连接",
                            systemImage: "point.3.connected.trianglepath.dotted",
                            description: Text("等待连接或检查服务器状态")
                        )
                    } else if selectedTab == .closed && vm.closedConnections.isEmpty {
                        ContentUnavailableView(
                            "没有已关闭连接",
                            systemImage: "xmark.circle",
                            description: Text("断开的连接将出现在这里")
                        )
                    } else {
                        List {
                            let connections = selectedTab == .active
                                ? vm.sortedFilteredConnections
                                : vm.closedConnections

                            ForEach(connections) { conn in
                                ConnectionRowView(connection: conn, isActive: selectedTab == .active, onClose: {
                                    Task { try? await vm.closeConnection(id: conn.id) }
                                })
                                .onTapGesture {
                                    selectedConnection = conn
                                    showDetail = true
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("连接")
            .searchable(text: $vm.filterText, prompt: "搜索 IP、域名、代理链...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(ConnectionsViewModel.SortOption.allCases, id: \.id) { option in
                            Button {
                                if vm.sortBy == option {
                                    vm.sortAscending.toggle()
                                } else {
                                    vm.sortBy = option
                                    vm.sortAscending = false
                                }
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                    if vm.sortBy == option {
                                        Image(systemName: vm.sortAscending ? "chevron.up" : "chevron.down")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showCloseAllConfirm = true
                        } label: {
                            Label("断开所有连接", systemImage: "xmark.circle")
                        }

                        if !vm.closedConnections.isEmpty {
                            Button {
                                vm.clearClosedConnections()
                            } label: {
                                Label("清除已关闭", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("断开所有连接", isPresented: $showCloseAllConfirm) {
                Button("取消", role: .cancel) {}
                Button("断开", role: .destructive) {
                    Task { try? await vm.closeAllConnections() }
                }
            } message: {
                Text("确定要断开全部 \(vm.activeCount) 个活跃连接吗？")
            }
            .sheet(isPresented: $showDetail) {
                if let conn = selectedConnection {
                    ConnectionDetailSheet(connection: conn)
                        .presentationDetents([.medium, .large])
                }
            }
        }
        .onAppear { vm.startMonitoring() }
        .onDisappear { vm.stopMonitoring() }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack(spacing: 24) {
            VStack(spacing: 2) {
                Text("\(vm.activeCount)")
                    .font(.title2.bold())
                Text("活跃")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 30)

            VStack(spacing: 2) {
                Text(vm.uploadTotal.formattedBytes())
                    .font(.headline.monospacedDigit())
                Text("总上传")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 30)

            VStack(spacing: 2) {
                Text(vm.downloadTotal.formattedBytes())
                    .font(.headline.monospacedDigit())
                Text("总下载")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Connection Row

struct ConnectionRowView: View {
    let connection: ConnectionInfo
    let isActive: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top: source → destination
            HStack(spacing: 6) {
                Image(systemName: connection.isTCP ? "arrow.left.arrow.right" : "arrow.up.arrow.down")
                    .font(.caption)
                    .foregroundStyle(connection.isTCP ? .blue : .orange)

                Text(connection.displaySource)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(connection.displayHost)
                    .font(.caption.bold())
                    .lineLimit(1)
            }

            // Chain
            if !connection.chains.isEmpty {
                Text(connection.displayChain)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            }

            // Bottom: speeds & rule
            HStack {
                Label(connection.uploadSpeed?.formattedSpeed() ?? "-", systemImage: "arrow.up")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Label(connection.downloadSpeed?.formattedSpeed() ?? "-", systemImage: "arrow.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(connection.rule)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.purple.opacity(0.12))
                    .foregroundStyle(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 4)
        .opacity(isActive ? 1 : 0.5)
        .swipeActions(edge: .trailing) {
            if isActive {
                Button("断开", role: .destructive) { onClose() }
            }
        }
    }
}

// MARK: - Connection Detail Sheet

struct ConnectionDetailSheet: View {
    let connection: ConnectionInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("概览") {
                    detailRow("协议", connection.displayNetwork)
                    detailRow("来源", connection.displaySource)
                    detailRow("目标", connection.displayHost)
                    detailRow("开始时间", connection.start)
                    detailRow("代理链", connection.displayChain)
                    detailRow("匹配规则", "\(connection.rule) / \(connection.rulePayload)")
                }

                Section("流量") {
                    detailRow("上传", connection.upload.formattedBytes())
                    detailRow("下载", connection.download.formattedBytes())
                    detailRow("上传速率", connection.uploadSpeed?.formattedSpeed() ?? "-")
                    detailRow("下载速率", connection.downloadSpeed?.formattedSpeed() ?? "-")
                }

                let meta = connection.metadata
                Section("元数据") {
                    if let host = meta.host { detailRow("Host", host) }
                    if let sniff = meta.sniffHost, sniff != meta.host { detailRow("SNI", sniff) }
                    if let dns = meta.dnsMode { detailRow("DNS 模式", dns) }
                    if let proc = meta.process { detailRow("进程", proc) }
                    if let uid = meta.uid, uid != 0 { detailRow("UID", "\(uid)") }
                    if let inbound = meta.inboundName { detailRow("入站", inbound) }
                }

                Section {
                    detailRow("连接 ID", connection.id)
                }
            }
            .navigationTitle("连接详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
        }
    }
}
