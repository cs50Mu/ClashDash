import SwiftUI

struct AddServerView: View {
    @Bindable var settingsVM: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = "9090"
    @State private var secret: String = ""
    @State private var useTLS: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: String?
    @State private var testSuccess: Bool = false

    var editingServer: ServerConfig?

    var body: some View {
        Form {
            Section("服务器信息") {
                TextField("名称", text: $name, prompt: Text("如：客厅路由器"))
                TextField("地址", text: $host, prompt: Text("192.168.1.1"))
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                TextField("端口", text: $port)
                    .keyboardType(.numberPad)
                SecureField("Secret", text: $secret, prompt: Text("mihomo API 密钥"))
                    .autocapitalization(.none)
                Toggle("启用 HTTPS", isOn: $useTLS)
            }

            Section {
                Button {
                    testConnection()
                } label: {
                    HStack {
                        if isTesting {
                            ProgressView()
                        }
                        Text("测试连接")
                    }
                }
                .disabled(isTesting || host.isEmpty)

                if let result = testResult {
                    HStack {
                        Image(systemName: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(testSuccess ? .green : .red)
                        Text(result)
                            .font(.caption)
                    }
                }
            }
        }
        .navigationTitle(editingServer != nil ? "编辑服务器" : "添加服务器")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(name.isEmpty || host.isEmpty)
            }
        }
        .onAppear {
            if let server = editingServer {
                name = server.name
                host = server.host
                port = String(server.port)
                secret = settingsVM.loadSecret(for: server)
                useTLS = server.useTLS
            }
        }
    }

    private func testConnection() {
        guard let portInt = Int(port) else {
            testResult = "请输入有效的端口号"
            testSuccess = false
            return
        }

        isTesting = true
        testResult = nil

        let config = ServerConfig(name: "test", host: host, port: portInt, useTLS: useTLS)
        let api = MihomoAPIService(config: config, secret: secret)

        Task {
            do {
                let version = try await api.fetchVersion()
                await MainActor.run {
                    testResult = "连接成功 — mihomo \(version.version)"
                    testSuccess = true
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = error.localizedDescription
                    testSuccess = false
                    isTesting = false
                }
            }
        }
    }

    private func save() {
        guard let portInt = Int(port), !name.isEmpty, !host.isEmpty else { return }

        let config = ServerConfig(
            id: editingServer?.id ?? UUID(),
            name: name,
            host: host,
            port: portInt,
            useTLS: useTLS
        )

        if editingServer != nil {
            settingsVM.updateServer(config, secret: secret)
        } else {
            settingsVM.addServer(config, secret: secret)
        }
        dismiss()
    }
}
