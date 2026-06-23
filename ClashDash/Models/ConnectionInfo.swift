import Foundation

struct ConnectionMetadata: Codable {
    let network: String
    let type: String?
    let sourceIP: String
    let sourcePort: String
    let destinationIP: String?
    let destinationPort: String?
    let host: String?
    let dnsMode: String?
    let uid: Int?
    let process: String?
    let processPath: String?
    let sniffHost: String?
    let sourceGeoIP: [String]?
    let destinationGeoIP: [String]?
    let inboundName: String?
    let remoteDestination: String?
    let specialProxy: String?
    let specialRules: String?
}

struct ConnectionInfo: Codable, Identifiable {
    let id: String
    let metadata: ConnectionMetadata
    let upload: Int64
    let download: Int64
    let start: String
    let chains: [String]
    let rule: String
    let rulePayload: String

    var uploadSpeed: Int64?
    var downloadSpeed: Int64?

    var displayHost: String {
        if let host = metadata.host, !host.isEmpty {
            return host
        }
        if let dstIP = metadata.destinationIP, let dstPort = metadata.destinationPort {
            return "\(dstIP):\(dstPort)"
        }
        return metadata.destinationIP ?? "unknown"
    }

    var displaySource: String {
        "\(metadata.sourceIP):\(metadata.sourcePort)"
    }

    var displayChain: String {
        chains.reversed().joined(separator: " → ")
    }

    var displayNetwork: String {
        metadata.network.uppercased()
    }

    var isTCP: Bool { metadata.network.lowercased() == "tcp" }

    // Manual Codable to handle extra fields
    private enum CodingKeys: String, CodingKey {
        case id, metadata, upload, download, start, chains, rule, rulePayload
    }
}

struct ConnectionsResponse: Codable {
    let connections: [ConnectionInfo]
    let uploadTotal: Int64?
    let downloadTotal: Int64?
    let memory: Int64?

    private enum CodingKeys: String, CodingKey {
        case connections, uploadTotal, downloadTotal, memory
    }
}
