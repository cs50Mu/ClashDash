import Foundation

struct TrafficInfo: Codable {
    let up: Int64
    let down: Int64
}

struct VersionInfo: Codable {
    let version: String
    let meta: Bool?
    let premium: Bool?
}

struct MemoryInfo: Codable {
    let inuse: Int64?
    let oslimit: Int64?
}

struct ProxyDelayResponse: Codable {
    let delay: Int
}

struct ErrorResponse: Codable {
    let error: String
}
