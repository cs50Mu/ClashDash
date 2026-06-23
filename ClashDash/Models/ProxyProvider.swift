import Foundation

struct ProxyProvider: Codable, Identifiable {
    let name: String
    let type: String
    let vehicleType: String
    var proxies: [ProxyNode]?
    var updatedAt: String?

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name, type, vehicleType, proxies, updatedAt
    }
}
