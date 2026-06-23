import SwiftUI

struct SettingsView: View {
    @Bindable var settingsVM: SettingsViewModel
    @State private var showAddServer = false

    var body: some View {
        NavigationStack {
            List {
                Section("服务器") {
                    if settingsVM.servers.isEmpty {
                        ContentUnavailableView(
                            "没有服务器",
                            systemImage: "server.rack",
                            description: Text("添加你的 mihomo 路由器")
                        )
                    } else {
                        ForEach(settingsVM.servers) { server in
                            ServerRowView(
                                server: server,
                                isActive: settingsVM.activeServerId == server.id,
                                onActivate: { settingsVM.setActive(server) },
                                onEdit: { _ in },
                                onDelete: { settingsVM.deleteServer(server) }
                            )
                        }
                    }
                }

                Section {
                    NavigationLink {
                        AddServerView(settingsVM: settingsVM)
                    } label: {
                        Label("添加服务器", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("设置")
            .onAppear { settingsVM.load() }
        }
    }
}

struct ServerRowView: View {
    let server: ServerConfig
    let isActive: Bool
    let onActivate: () -> Void
    let onEdit: (ServerConfig) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(server.name)
                        .font(.headline)
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                Text(server.displayAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isActive {
                Button("启用") {
                    onActivate()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("删除", role: .destructive) { onDelete() }
        }
    }
}
