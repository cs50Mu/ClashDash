import SwiftUI

struct RulesView: View {
    @State private var vm: RulesViewModel

    init(api: MihomoAPIService) {
        _vm = State(initialValue: RulesViewModel(api: api))
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.filteredRules.isEmpty && !vm.isLoading {
                    ContentUnavailableView(
                        "没有规则",
                        systemImage: "arrow.triangle.branch",
                        description: Text(vm.searchText.isEmpty ? "加载规则数据" : "没有匹配的规则")
                    )
                } else {
                    List {
                        Section("规则 (\(vm.filteredRules.count))") {
                            ForEach(Array(vm.filteredRules.enumerated()), id: \.element.id) { idx, rule in
                                let isDisabled = vm.isRuleDisabled(rule.index)
                                RuleRowView(rule: rule, isDisabled: isDisabled, onToggle: {
                                    Task { await vm.toggleRule(arrayIndex: idx) }
                                })
                            }
                        }
                    }
                }
            }
            .navigationTitle("规则")
            .overlay(alignment: .top) {
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.top, 4)
                        .textSelection(.enabled)
                }
            }
            .searchable(text: $vm.searchText, prompt: "搜索规则...")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("全部") { vm.filterType = nil }
                        Divider()
                        ForEach(vm.availableTypes, id: \.self) { type in
                            Button(type) {
                                vm.filterType = (vm.filterType == type) ? nil : type
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolVariant(vm.filterType != nil ? .fill : .none)
                    }
                }
            }
            .refreshable { await vm.loadRules() }
        }
        .task { await vm.loadRules() }
    }
}

struct RuleRowView: View {
    let rule: RuleItem
    let isDisabled: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(rule.index)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(rule.type)
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(typeColor.opacity(0.15))
                    .foregroundStyle(typeColor)
                    .clipShape(Capsule())

                Spacer()

                if isDisabled {
                    Image(systemName: "eye.slash")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Text(rule.payload)
                    .font(.subheadline)
                    .strikethrough(isDisabled)
                    .foregroundStyle(isDisabled ? Color.secondary : Color.primary)

                Spacer()

                if !rule.proxy.isEmpty {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(rule.proxy)
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(isDisabled ? 0.5 : 1)
        .swipeActions(edge: .trailing) {
            Button(isDisabled ? "启用" : "禁用") {
                onToggle()
            }
            .tint(isDisabled ? .green : .orange)
        }
    }

    private var typeColor: Color {
        switch rule.type.lowercased() {
        case "domain": .blue
        case "domainsuffix": .cyan
        case "domainkeyword": .teal
        case "geoip": .green
        case "ipcidr", "ipcidr6": .orange
        case "match": .purple
        case "processname": .pink
        case "ruleset": .indigo
        default: .gray
        }
    }
}
