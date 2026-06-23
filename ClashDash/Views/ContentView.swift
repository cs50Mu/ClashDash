import SwiftUI

struct ContentView: View {
    @State private var settingsVM = SettingsViewModel()

    var body: some View {
        Group {
            if let server = settingsVM.activeServer {
                MainTabView(server: server, settingsVM: settingsVM)
                    .id(server.id)
            } else {
                WelcomeView(settingsVM: settingsVM)
            }
        }
        .onAppear {
            settingsVM.load()
        }
    }
}

struct MainTabView: View {
    let server: ServerConfig
    @Bindable var settingsVM: SettingsViewModel

    @State private var api: MihomoAPIService?
    @State private var ws: WebSocketService?

    var body: some View {
        TabView {
            if let api, let ws {
                OverviewView(api: api, ws: ws)
                    .tabItem {
                        Label("概览", systemImage: "gauge.with.dots.needle.33percent")
                    }

                ProxiesView(api: api)
                    .tabItem {
                        Label("代理", systemImage: "network")
                    }

                RulesView(api: api)
                    .tabItem {
                        Label("规则", systemImage: "arrow.triangle.branch")
                    }

                ConnectionsView(api: api, ws: ws)
                    .tabItem {
                        Label("连接", systemImage: "point.3.connected.trianglepath.dotted")
                    }
            }

            DebugLogView()
                .tabItem {
                    Label("日志", systemImage: "terminal")
                }

            SettingsView(settingsVM: settingsVM)
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
        }
        .onAppear {
            let secret = ServerConfigService().loadSecret(for: server.id)
            api = MihomoAPIService(config: server, secret: secret)
            ws = WebSocketService(config: server, secret: secret)
        }
    }
}
