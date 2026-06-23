import Foundation
import Observation

@Observable
final class SettingsViewModel {
    private var configService = ServerConfigService()

    var servers: [ServerConfig] = []
    var activeServer: ServerConfig?
    var activeServerId: UUID? {
        didSet { configService.activeServerId = activeServerId }
    }

    var hasActiveServer: Bool { activeServer != nil }

    init() {
        load()
    }

    func load() {
        servers = configService.loadServers()
        activeServerId = configService.activeServerId
        activeServer = servers.first { $0.id == activeServerId }
    }

    func addServer(_ server: ServerConfig, secret: String) {
        servers.append(server)
        configService.saveServers(servers)
        configService.saveSecret(secret, for: server.id)
        if activeServerId == nil {
            activeServerId = server.id
            activeServer = server
        }
    }

    func updateServer(_ server: ServerConfig, secret: String?) {
        guard let index = servers.firstIndex(where: { $0.id == server.id }) else { return }
        servers[index] = server
        configService.saveServers(servers)
        if let secret {
            configService.saveSecret(secret, for: server.id)
        }
        if activeServerId == server.id {
            activeServer = server
        }
    }

    func deleteServer(_ server: ServerConfig) {
        servers.removeAll { $0.id == server.id }
        configService.saveServers(servers)
        configService.deleteSecret(for: server.id)
        if activeServerId == server.id {
            activeServerId = servers.first?.id
            activeServer = servers.first
        }
    }

    func setActive(_ server: ServerConfig) {
        activeServerId = server.id
        activeServer = server
    }

    func loadSecret(for server: ServerConfig) -> String {
        configService.loadSecret(for: server.id)
    }
}
