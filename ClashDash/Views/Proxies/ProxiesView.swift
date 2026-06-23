import SwiftUI

struct ProxiesView: View {
    @State private var vm: ProxiesViewModel
    @State private var expandedGroups: Set<String> = []
    @State private var showingPicker: (group: ProxyGroup, show: Bool)?
    @State private var toastMessage: String?
    @State private var showToast: Bool = false

    init(api: MihomoAPIService) {
        _vm = State(initialValue: ProxiesViewModel(api: api))
    }

    var body: some View {
        NavigationStack {
            List {
                // Groups
                ForEach(vm.filteredGroups) { group in
                    ProxyGroupSection(
                        group: group,
                        isExpanded: expandedGroups.contains(group.name),
                        nodeDelayMap: vm.nodeDelayMap,
                        onToggle: { toggleGroup(group.name) },
                        onSelectNode: { nodeName in
                            switchProxy(group: group, to: nodeName)
                        },
                        onTestDelay: {
                            testGroupDelay(group)
                        },
                        onClearFixed: {
                            clearFixedProxy(group)
                        },
                        onTestNodeDelay: { nodeName in
                            testNodeDelay(nodeName)
                        }
                    )
                }

                // Standalone nodes
                if !vm.filteredNodes.isEmpty {
                    Section("独立节点") {
                        ForEach(vm.filteredNodes) { node in
                            ProxyNodeRow(nodeName: node.name, type: node.type, delay: vm.nodeDelayMap[node.name])
                        }
                    }
                }

                // Providers
                if !vm.providers.isEmpty {
                    ForEach(vm.providers) { provider in
                        ProxyProviderSection(
                            provider: provider,
                            nodeDelayMap: vm.nodeDelayMap,
                            onRefresh: {
                                Task { try? await vm.refreshProvider(name: provider.name) }
                            },
                            onTestNode: { name in
                                testNodeDelay(name)
                            }
                        )
                    }
                }
            }
            .navigationTitle("代理")
            .searchable(text: $vm.searchText, prompt: "搜索代理名称...")
            .refreshable { await vm.loadProxies() }
            .overlay(alignment: .bottom) {
                if showToast, let msg = toastMessage {
                    Text(msg)
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showToast)
        }
        .task { await vm.loadProxies() }
        .task { await vm.loadProviders() }
        .onAppear { vm.startAutoRefresh() }
        .onDisappear { vm.stopAutoRefresh() }
    }

    private func toggleGroup(_ name: String) {
        if expandedGroups.contains(name) {
            expandedGroups.remove(name)
        } else {
            expandedGroups.insert(name)
        }
    }

    private func switchProxy(group: ProxyGroup, to nodeName: String) {
        Task {
            do {
                try await vm.switchProxy(groupName: group.name, to: nodeName)
                HapticService.selection()
                showToastMessage("已切换到 \(nodeName)")
                await vm.loadProxies()
            } catch {
                showToastMessage("切换失败: \(error.localizedDescription)")
            }
        }
    }

    private func testGroupDelay(_ group: ProxyGroup) {
        expandedGroups.insert(group.name)
        Task { await vm.testGroupDelay(groupName: group.name) }
    }

    private func testNodeDelay(_ name: String) {
        Task { await vm.testNodeDelay(nodeName: name) }
    }

    private func clearFixedProxy(_ group: ProxyGroup) {
        Task {
            try? await vm.clearFixedProxy(groupName: group.name)
            await vm.loadProxies()
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
        }
    }
}

// MARK: - Proxy Group Section

struct ProxyGroupSection: View {
    let group: ProxyGroup
    let isExpanded: Bool
    let nodeDelayMap: [String: Int]
    let onToggle: () -> Void
    let onSelectNode: (String) -> Void
    let onTestDelay: () -> Void
    let onClearFixed: () -> Void
    let onTestNodeDelay: (String) -> Void

    var body: some View {
        Section {
            // Group header
            HStack(spacing: 12) {
                Image(systemName: group.type.iconName)
                    .foregroundStyle(group.isSwitching ? .blue : .green)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.body)
                    HStack(spacing: 4) {
                        Text(group.type.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                        Text("→")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(group.currentNodeName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Speed test button for the group
                if group.isSwitching {
                    Button {
                        onTestDelay()
                    } label: {
                        Image(systemName: "bolt.fill")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }

                if let delay = group.delay {
                    Text(delay.formattedDelay())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.delayColor(delay))
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }

            // Expanded node list
            if isExpanded, let allNodes = group.all {
                ForEach(allNodes, id: \.self) { nodeName in
                    HStack(spacing: 12) {
                        Image(systemName: nodeName == group.now ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(nodeName == group.now ? Color.blue : Color.secondary)
                            .frame(width: 24)

                        Text(nodeName)
                            .font(.subheadline)

                        Spacer()

                        if let delay = nodeDelayMap[nodeName] {
                            Text(delay.formattedDelay())
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.delayColor(delay))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectNode(nodeName) }
                    .contextMenu {
                        Button {
                            onTestNodeDelay(nodeName)
                        } label: {
                            Label("测速", systemImage: "bolt")
                        }
                    }
                }

                // Clear fixed button for URLTest/Fallback
                if !group.isSwitching {
                    Button(action: onClearFixed) {
                        Label("清除固定选择", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                    }
                }
            }
        }
    }
}

// MARK: - Proxy Node Row

struct ProxyNodeRow: View {
    let nodeName: String
    let type: String
    let delay: Int?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(type == "Direct" ? .green : (type == "Reject" ? .red : .blue))

            Text(nodeName)
                .font(.subheadline)

            Spacer()

            Text(type)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let delay = delay {
                Text(delay.formattedDelay())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.delayColor(delay))
            }
        }
    }
}

// MARK: - Proxy Provider Section

struct ProxyProviderSection: View {
    let provider: ProxyProvider
    let nodeDelayMap: [String: Int]
    let onRefresh: () -> Void
    let onTestNode: (String) -> Void

    @State private var isExpanded = false

    var body: some View {
        Section {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(.orange)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text(provider.vehicleType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button("更新") { onRefresh() }
                    .tint(.orange)
            }

            if isExpanded, let proxies = provider.proxies {
                ForEach(proxies) { node in
                    ProxyNodeRow(nodeName: node.name, type: node.type, delay: nodeDelayMap[node.name])
                        .swipeActions(edge: .trailing) {
                            Button("测速") { onTestNode(node.name) }
                                .tint(.blue)
                        }
                }
            }
        }
    }
}
