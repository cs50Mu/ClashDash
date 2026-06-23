import Foundation

struct ServerConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var useTLS: Bool

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 9090,
        useTLS: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.useTLS = useTLS
    }

    var baseURL: URL {
        let scheme = useTLS ? "https" : "http"
        return URL(string: "\(scheme)://\(host):\(port)")!
    }

    var displayAddress: String {
        "\(host):\(port)"
    }
}
