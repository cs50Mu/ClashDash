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
                // Proxy groups only (no standalone nodes, no providers)
                ForEach(vm.sortedGroups) { group in
                    ProxyGroupSection(
                        group: group,
                        isExpanded: expandedGroups.contains(group.name),
                        nodeDelayMap: vm.nodeDelayMap,
                        isTesting: vm.testingGroupNames.contains(group.name),
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
    let isTesting: Bool
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

                // Speed test button for the group (shows spinner while testing)
                if group.isSwitching {
                    Button {
                        onTestDelay()
                    } label: {
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "bolt.fill")
                                .font(.body)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting)
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

                        let delay = nodeName == group.now ? group.delay : nodeDelayMap[nodeName]
                        if let delay {
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


