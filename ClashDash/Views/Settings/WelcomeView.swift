import SwiftUI

struct WelcomeView: View {
    @Bindable var settingsVM: SettingsViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                Text("ClashDash")
                    .font(.largeTitle.bold())

                Text("远程管理你的 mihomo 代理服务器")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("查看代理状态、切换节点、管理连接，\n一切尽在掌握。")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Spacer()

                NavigationLink {
                    AddServerView(settingsVM: settingsVM)
                } label: {
                    Label("添加服务器", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 60)
            }
            .padding()
            .navigationTitle("欢迎")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            settingsVM.load()
        }
    }
}
